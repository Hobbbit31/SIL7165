#!/usr/bin/env bash
# Demo 6+: AFL fuzzing with "blind" seeds.
# Shows AFL trying to discover the FUZZ/CRASH magic strings and planted bugs
# from scratch — starting with single-byte seeds (A, x). Results are reported
# from the crashes actually saved in this run.
#
# Requires: output/afl_fuzzing/fuzz_target_afl_asan  (built by demo 6 or below)
# Usage: bash scripts/11_afl_blind_seeds_demo.sh [duration_seconds]

set -u
cd "$(dirname "$0")/.."

DUR="${1:-60}"
SEEDS=/tmp/seeds_blind
OUT=/tmp/fuzz_blind
TARGET=output/afl_fuzzing/fuzz_target_afl_asan

bar() { printf '\n\033[1;34m===== %s =====\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }

classify_crash() {
    local f=$1
    local report

    report=$("$TARGET" < "$f" 2>&1 | head -30)

    if grep -q "stack-buffer-overflow" <<<"$report"; then
        echo "stack overflow"
    elif grep -q "heap-buffer-overflow" <<<"$report"; then
        echo "heap overflow"
    elif grep -q "SEGV" <<<"$report" && LC_ALL=C grep -a -q '^CRASH' "$f"; then
        echo "null deref"
    else
        echo "unclassified"
    fi
}

prefix_hint() {
    local f=$1

    if LC_ALL=C grep -a -q '^FUZZ' "$f"; then
        echo "FUZZ"
    elif LC_ALL=C grep -a -q '^CRASH' "$f"; then
        echo "CRASH"
    elif LC_ALL=C grep -a -q '^CRAS' "$f"; then
        echo "CRAS"
    elif LC_ALL=C grep -a -q '^CRA' "$f"; then
        echo "CRA"
    elif LC_ALL=C grep -a -q '^CR' "$f"; then
        echo "CR"
    elif LC_ALL=C grep -a -q '^FU' "$f"; then
        echo "FU"
    elif LC_ALL=C grep -a -q '^F' "$f"; then
        echo "F"
    else
        echo "-"
    fi
}

# ─── Build target if missing ───
if [[ ! -x "$TARGET" || src/fuzz_target.c -nt "$TARGET" ]]; then
    bar "Building target with AFL coverage + ASan"
    AFL_USE_ASAN=1 afl-clang-fast -O0 src/fuzz_target.c -o "$TARGET" \
        || { echo "afl-clang-fast build failed"; exit 1; }
fi

# ─── Make blind 1-byte seeds ───
bar "Preparing blind seeds (1 byte each, NO bug-trigger hints)"
rm -rf "$SEEDS" "$OUT"
mkdir -p "$SEEDS"
printf 'A' > "$SEEDS/s1.txt"
printf 'x' > "$SEEDS/s2.txt"
note "seed1: '$(cat "$SEEDS/s1.txt")'"
note "seed2: '$(cat "$SEEDS/s2.txt")'"
note "Neither seed contains FUZZ, CRASH, or a long crashing input."

# ─── Run AFL ───
bar "Fuzzing for ${DUR}s"
note "target: $TARGET"
note "seeds:  $SEEDS"
note "out:    $OUT"
echo

AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
AFL_SKIP_CPUFREQ=1 \
AFL_NO_UI=1 \
AFL_NO_COLOR=1 \
AFL_NO_AFFINITY=1 \
AFL_IGNORE_PROBLEMS=1 \
    timeout "$DUR" afl-fuzz -i "$SEEDS" -o "$OUT" -- "$TARGET" 2>&1 | tail -3

bar "Stats"
if [[ -f "$OUT/default/fuzzer_stats" ]]; then
    while IFS=':' read -r key value; do
        value=${value## }
        case "$key" in
            execs_per_sec*) note "speed:          $value executions/second" ;;
            saved_crashes*) note "saved crashes:  $value" ;;
            edges_found*)   note "coverage edges: $value" ;;
            total_execs*)   note "total execs:    $value" ;;
        esac
    done < <(grep -E "execs_per_sec|saved_crashes|edges_found|total_execs" \
        "$OUT/default/fuzzer_stats" 2>/dev/null)
else
    note "No AFL stats file was produced."
fi

# ─── Classify saved crashes by replaying them ───
bar "Saved crashes explained"
STACK_FOUND=0
HEAP_FOUND=0
NULL_FOUND=0
UNCLASSIFIED_FOUND=0
CRASH_COUNT=0

printf "  %-4s %-13s %-8s %-15s %s\n" "No." "AFL id" "prefix" "bug class" "first bytes"
printf "  %-4s %-13s %-8s %-15s %s\n" "---" "------" "------" "---------" "-----------"

for f in "$OUT/default/crashes/"id:*; do
    [[ -f $f ]] || continue
    CRASH_COUNT=$((CRASH_COUNT + 1))
    NAME=$(basename "$f" | cut -d, -f1)
    BUG_CLASS=$(classify_crash "$f")
    PREFIX=$(prefix_hint "$f")
    BYTES=$(xxd -l 12 -p "$f" | sed 's/../& /g;s/ $//')

    case "$BUG_CLASS" in
        "stack overflow")
        STACK_FOUND=$((STACK_FOUND + 1))
            ;;
        "heap overflow")
        HEAP_FOUND=$((HEAP_FOUND + 1))
            ;;
        "null deref")
        NULL_FOUND=$((NULL_FOUND + 1))
            ;;
        *)
            UNCLASSIFIED_FOUND=$((UNCLASSIFIED_FOUND + 1))
            ;;
    esac

    printf "  %-4d %-13s %-8s %-15s %s\n" \
        "$CRASH_COUNT" "$NAME" "$PREFIX" "$BUG_CLASS" "$BYTES"
done

if [[ $CRASH_COUNT -eq 0 ]]; then
    note "No crashes saved in this run."
else
    echo
    note "summary: $CRASH_COUNT crash files saved"
    note "stack overflow: $STACK_FOUND"
    note "heap overflow:  $HEAP_FOUND"
    note "null deref:     $NULL_FOUND"
    note "unclassified:   $UNCLASSIFIED_FOUND"
fi

# ─── Replay one crash to see ASan ───
FIRST=$(ls "$OUT/default/crashes/"id:* 2>/dev/null | head -1)
if [[ -n $FIRST ]]; then
    bar "ASan proof for the first saved crash"
    note "AFL saved bytes that crash the program. Replaying them through the"
    note "ASan build gives the precise memory-safety error:"
    echo
    note "input bytes:"
    xxd "$FIRST" | head -2 | sed 's/^/    /'
    echo
    note "ASan report:"
    "$TARGET" < "$FIRST" 2>&1 | head -6 | sed 's/^/    /'
fi

bar "Takeaway"
cat <<EOF
  This was a blind-seed run: AFL started only from 'A' and 'x'.
  It used coverage feedback to keep mutations that reached new branches.
EOF

if [[ $STACK_FOUND -gt 0 ]]; then
    note "FOUND: stack overflow from generated inputs longer than 32 bytes."
else
    note "NOT FOUND THIS RUN: stack overflow."
fi

if [[ $HEAP_FOUND -gt 0 ]]; then
    note "FOUND: heap overflow after discovering the FUZZ prefix."
else
    note "NOT FOUND THIS RUN: FUZZ-prefixed heap overflow."
fi

if [[ $NULL_FOUND -gt 0 ]]; then
    note "FOUND: null deref after discovering the CRASH prefix."
else
    note "NOT FOUND THIS RUN: CRASH-prefixed null deref."
fi

cat <<'EOF'
  Important: fuzzing is stochastic. A 60s run may find only some bug classes.
  Longer runs or repeated trials make the deeper FUZZ/CRASH paths more likely.
EOF
