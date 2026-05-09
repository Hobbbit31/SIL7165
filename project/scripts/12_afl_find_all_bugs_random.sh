#!/usr/bin/env bash
# AFL demo: fuzz the RetroWrite-instrumented binary from blind, non-triggering
# seeds and replay crashes through ASan to classify the bugs.
#
# Usage:
#   bash scripts/12_afl_find_all_bugs_random.sh [total_seconds] [round_seconds]
#
# Example:
#   bash scripts/12_afl_find_all_bugs_random.sh 180 30

set -Eeuo pipefail
cd "$(dirname "$0")/.."

PROJ_DIR="$(pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
TOTAL_BUDGET="${1:-300}"
ROUND_SECONDS="${2:-30}"
SEEDS=/tmp/seeds_random_blind
OUT=/tmp/fuzz_all_bugs_random
PIE_TARGET=output/afl_fuzzing/fuzz_target
FUZZ_TARGET=output/afl_fuzzing/fuzz_target_retrowrite_afl
REPLAY_TARGET=output/afl_fuzzing/fuzz_target_afl_asan

bar() { printf '\n\033[1;34m===== %s =====\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

bar "Checking prerequisites"
[[ -f "$RW_DIR/retro/bin/activate" ]] || die "missing RetroWrite virtualenv: $RW_DIR/retro/bin/activate"
source "$RW_DIR/retro/bin/activate"

for cmd in clang python3 afl-fuzz afl-gcc afl-clang-fast timeout xxd grep sed head tail; do
    require_cmd "$cmd"
done
note "All required tools are available."

make_seed() {
    local path=$1
    local size=$2

    local mode=${3:-raw}

    while true; do
        if [[ $mode == "neutral" ]]; then
            set +o pipefail
            LC_ALL=C tr -dc 'Aax0_' </dev/urandom | head -c "$size" > "$path"
            set -o pipefail
        else
            dd if=/dev/urandom of="$path" bs="$size" count=1 status=none
        fi

        if ! LC_ALL=C grep -a -q '^FUZZ' "$path" &&
           ! LC_ALL=C grep -a -q '^CRASH' "$path"; then
            break
        fi
    done
}

hex_bytes() {
    xxd -l "${2:-12}" -p "$1" | sed 's/../& /g;s/ $//'
}

ascii_preview() {
    set +o pipefail
    LC_ALL=C tr -c '[:print:]' '.' < "$1" | head -c "${2:-12}"
    set -o pipefail
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
    elif LC_ALL=C grep -a -q '^FUZ' "$f"; then
        echo "FUZ"
    elif LC_ALL=C grep -a -q '^FU' "$f"; then
        echo "FU"
    elif LC_ALL=C grep -a -q '^F' "$f"; then
        echo "F"
    else
        echo "-"
    fi
}

classify_crash() {
    local f=$1
    local report

    report=$("$REPLAY_TARGET" < "$f" 2>&1 | head -40)

    if grep -q "heap-buffer-overflow" <<<"$report"; then
        echo "heap overflow"
    elif grep -q "stack-buffer-overflow" <<<"$report"; then
        echo "stack overflow"
    elif grep -q "SEGV" <<<"$report" && LC_ALL=C grep -a -q '^CRASH' "$f"; then
        echo "null deref"
    else
        echo "unclassified"
    fi
}

scan_crashes() {
    STACK_FOUND=0
    HEAP_FOUND=0
    NULL_FOUND=0
    UNCLASSIFIED_FOUND=0
    STACK_EXAMPLE=
    HEAP_EXAMPLE=
    NULL_EXAMPLE=
    CRASH_COUNT=0

    for f in "$OUT/default/crashes/"id:*; do
        [[ -f $f ]] || continue
        CRASH_COUNT=$((CRASH_COUNT + 1))

        case "$(classify_crash "$f")" in
            "stack overflow")
                STACK_FOUND=$((STACK_FOUND + 1))
                [[ -z ${STACK_EXAMPLE:-} ]] && STACK_EXAMPLE=$f
                ;;
            "heap overflow")
                HEAP_FOUND=$((HEAP_FOUND + 1))
                [[ -z ${HEAP_EXAMPLE:-} ]] && HEAP_EXAMPLE=$f
                ;;
            "null deref")
                NULL_FOUND=$((NULL_FOUND + 1))
                [[ -z ${NULL_EXAMPLE:-} ]] && NULL_EXAMPLE=$f
                ;;
            *)
                UNCLASSIFIED_FOUND=$((UNCLASSIFIED_FOUND + 1))
                ;;
        esac
    done
}

print_status() {
    note "crash files:    ${CRASH_COUNT:-0}"
    note "stack overflow: $([[ ${STACK_FOUND:-0} -gt 0 ]] && echo FOUND || echo missing)"
    note "heap overflow:  $([[ ${HEAP_FOUND:-0} -gt 0 ]] && echo FOUND || echo missing)"
    note "null deref:     $([[ ${NULL_FOUND:-0} -gt 0 ]] && echo FOUND || echo missing)"
}

print_examples() {
    bar "Confirmed bug examples"
    printf "  %-15s %-8s %-16s %-25s %s\n" "bug class" "prefix" "ascii" "hex" "file"
    printf "  %-15s %-8s %-16s %-25s %s\n" "---------" "------" "-----" "---" "----"

    if [[ -n ${STACK_EXAMPLE:-} ]]; then
        printf "  %-15s %-8s %-16s %-25s %s\n" \
            "stack overflow" "$(prefix_hint "$STACK_EXAMPLE")" \
            "$(ascii_preview "$STACK_EXAMPLE" 12)" "$(hex_bytes "$STACK_EXAMPLE" 12)" \
            "$(basename "$STACK_EXAMPLE" | cut -d, -f1)"
    fi

    if [[ -n ${HEAP_EXAMPLE:-} ]]; then
        printf "  %-15s %-8s %-16s %-25s %s\n" \
            "heap overflow" "$(prefix_hint "$HEAP_EXAMPLE")" \
            "$(ascii_preview "$HEAP_EXAMPLE" 12)" "$(hex_bytes "$HEAP_EXAMPLE" 12)" \
            "$(basename "$HEAP_EXAMPLE" | cut -d, -f1)"
    fi

    if [[ -n ${NULL_EXAMPLE:-} ]]; then
        printf "  %-15s %-8s %-16s %-25s %s\n" \
            "null deref" "$(prefix_hint "$NULL_EXAMPLE")" \
            "$(ascii_preview "$NULL_EXAMPLE" 12)" "$(hex_bytes "$NULL_EXAMPLE" 12)" \
            "$(basename "$NULL_EXAMPLE" | cut -d, -f1)"
    fi
}

run_afl_round() {
    local input_arg=$1
    local log_file="$OUT/afl_round_${ROUND}.log"
    local status

    set +e
    AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 \
    AFL_SKIP_CPUFREQ=1 \
    AFL_NO_UI=1 \
    AFL_NO_COLOR=1 \
    AFL_NO_AFFINITY=1 \
    AFL_IGNORE_PROBLEMS=1 \
        timeout "$ROUND_SECONDS" afl-fuzz -i "$input_arg" -o "$OUT" -- "$FUZZ_TARGET" \
        >"$log_file" 2>&1
    status=$?
    set -e

    tail -2 "$log_file"

    if [[ $status -ne 0 && $status -ne 124 ]]; then
        note "AFL failed; last 20 log lines:"
        tail -20 "$log_file" | sed 's/^/    /'
        exit "$status"
    fi
}

if [[ ! -x "$FUZZ_TARGET" || src/fuzz_target.c -nt "$FUZZ_TARGET" ]]; then
    bar "Building RetroWrite AFL target"
    mkdir -p "$(dirname "$FUZZ_TARGET")"
    clang -O0 -fPIC -fPIE -pie src/fuzz_target.c -o "$PIE_TARGET" \
        || { echo "pie build failed"; exit 1; }
    mkdir -p "$OUT"
    python3 "$RW_DIR/retrowrite" "$PIE_TARGET" "$OUT/fuzz_target.s" \
        || { echo "retrowrite failed"; exit 1; }
    afl-gcc "$OUT/fuzz_target.s" -o "$FUZZ_TARGET" \
        || { echo "afl-gcc failed"; exit 1; }
fi

if [[ ! -x "$REPLAY_TARGET" || src/fuzz_target.c -nt "$REPLAY_TARGET" ]]; then
    bar "Building ASan replay target"
    mkdir -p "$(dirname "$REPLAY_TARGET")"
    AFL_USE_ASAN=1 afl-clang-fast -O0 src/fuzz_target.c -o "$REPLAY_TARGET" \
        || { echo "replay build failed"; exit 1; }
fi

bar "Preparing blind non-triggering seeds"
rm -rf "$SEEDS" "$OUT"
mkdir -p "$SEEDS" "$OUT"

printf 'A' > "$SEEDS/neutral_len_1_A.bin"
printf 'AAAA' > "$SEEDS/neutral_len_4_A.bin"
printf 'AAAAA' > "$SEEDS/neutral_len_5_A.bin"
printf 'AAAAAAAAAAAA' > "$SEEDS/neutral_len_12_A.bin"
printf 'xxxxxxxxxxxx' > "$SEEDS/neutral_len_12_x.bin"
make_seed "$SEEDS/random_len_5.bin" 5 neutral
make_seed "$SEEDS/random_len_12.bin" 12 neutral

note "Seeds are blind, non-crashing inputs with useful lengths: 1, 4, 5, 12."
note "They contain no FUZZ/CRASH strings and are too short for the stack bug."
note "Some seeds are fixed neutral bytes, not bug hints; AFL must mutate them."
for f in "$SEEDS"/*; do
    note "$(basename "$f"): hex=$(hex_bytes "$f" 12) ascii='$(ascii_preview "$f" 12)'"
done

bar "Fuzzing until all three bugs are confirmed"
note "fuzz target:   $FUZZ_TARGET"
note "replay target:  $REPLAY_TARGET"
note "output:       $OUT"
note "time budget:  ${TOTAL_BUDGET}s"
note "round size:   ${ROUND_SECONDS}s"
note "Note: AFL is stochastic. The script reports exactly what this run confirms."

ELAPSED=0
ROUND=1

while [[ $ELAPSED -lt $TOTAL_BUDGET ]]; do
    REMAINING=$((TOTAL_BUDGET - ELAPSED))
    if [[ $REMAINING -lt $ROUND_SECONDS ]]; then
        ROUND_SECONDS=$REMAINING
    fi

    bar "AFL round $ROUND (${ROUND_SECONDS}s)"
    run_afl_round "$SEEDS"

    ELAPSED=$((ELAPSED + ROUND_SECONDS))

    scan_crashes
    print_status

    if [[ $STACK_FOUND -gt 0 && $HEAP_FOUND -gt 0 && $NULL_FOUND -gt 0 ]]; then
        break
    fi

    ROUND=$((ROUND + 1))
done

scan_crashes
print_examples

bar "Final result"
print_status

if [[ $STACK_FOUND -gt 0 && $HEAP_FOUND -gt 0 && $NULL_FOUND -gt 0 ]]; then
    note "SUCCESS: all three planted bug classes were found from blind seeds."
else
    note "PARTIAL: AFL did not confirm all three bug classes in this time budget."
    note "Increase the first argument, for example:"
    note "bash scripts/12_afl_find_all_bugs_random.sh 300 30"
fi

cat <<'EOF'

  What this proves:
    AFL fuzzed the RetroWrite-instrumented binary, not the source binary.
    The seeds are blind but demo-friendly: they do not contain FUZZ, CRASH,
    or a long crashing input.
    Crashes are replayed on a separate ASan binary for diagnosis.
    The workflow is: blind seeds -> AFL on RetroWrite binary -> ASan replay.
EOF
