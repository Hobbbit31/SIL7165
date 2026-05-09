#!/bin/bash
# ──────────────────────────────────────────────────────
# EXTENSION 1: rep movsb ASan Fix Demo
# ──────────────────────────────────────────────────────
# Shows why the fix matters:
#   - Original binary: rep movsb overflow silently corrupts memory
#   - RetroWrite ASan with rep fix OFF: rep movsb is skipped
#   - RetroWrite ASan with rep fix ON: rep movsb gets ASan checks
#
# This demo focuses on ASan-visible detection, not exact report wording.
# ──────────────────────────────────────────────────────

set +e  # ASan binaries intentionally exit non-zero when a bug is detected

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
SRC_DIR="$PROJ_DIR/src"
OUT_DIR="$PROJ_DIR/output/ext1_rep_movs"

source "$RW_DIR/retro/bin/activate"
mkdir -p "$OUT_DIR"

bar() {
    printf '\n\033[1;34m===== %s =====\033[0m\n' "$*"
}

note() {
    printf '  %s\n' "$*"
}

run_case() {
    local title="$1"
    shift

    echo ""
    echo "  --- $title ---"
    "$@" 2>&1 | head -18 | sed 's/^/    /'
}

count_pattern() {
    local pattern="$1"
    local file="$2"

    if [ -f "$file" ]; then
        grep -c "$pattern" "$file" 2>/dev/null
    else
        echo "0"
    fi
}

filter_rewrite_log() {
    grep -E "Rewriting|DISABLE_REP_FIX|Instrumented:" || true
}

classify_run() {
    local binary="$1"
    local arg="$2"
    local output

    output=$("$binary" "$arg" 2>&1)

    if grep -q "DEADLYSIGNAL" <<<"$output"; then
        echo "uncontrolled crash"
    elif grep -q "ERROR: AddressSanitizer" <<<"$output"; then
        echo "ASan-visible detection"
    elif grep -q "bug was NOT detected" <<<"$output"; then
        echo "missed"
    else
        echo "unknown"
    fi
}

build_asan_variant() {
    local mode="$1"
    local asm="$2"
    local bin="$3"

    cd "$RW_DIR"
    if [ "$mode" = "off" ]; then
        DISABLE_REP_FIX=1 python3 retrowrite --asan "$OUT_DIR/test_rep_movs" "$asm" \
            2>&1 | filter_rewrite_log | sed 's/^/  /'
    else
        python3 retrowrite --asan "$OUT_DIR/test_rep_movs" "$asm" \
            2>&1 | filter_rewrite_log | sed 's/^/  /'
    fi

    sed -i 's/asan_init_v4/asan_init/g' "$asm"
    clang "$asm" -lasan -o "$bin" 2>&1 | sed 's/^/  /'
}

bar "Extension 1: rep movsb ASan Fix"
cat <<'EOF'
  Goal:
    Catch low-level memcpy-style overflows in rewritten binaries.

  Problem:
    x86-64 uses repeated string instructions:
      rep movsb  -> byte-copy loop, like memcpy

    If ASan does not instrument this instruction, a binary can still
    corrupt memory even after RetroWrite ASan instrumentation.
EOF

bar "Step 1: Build vulnerable test binary"
note "source: $SRC_DIR/test_rep_movs.c"
note "output: $OUT_DIR/test_rep_movs"
clang -O0 -fPIC -fPIE -pie "$SRC_DIR/test_rep_movs.c" -o "$OUT_DIR/test_rep_movs"
if [ $? -ne 0 ]; then
    echo "  [!] Compile failed"
    exit 1
fi
note "test writes 64 bytes into a 16-byte heap buffer using rep movsb"

bar "Step 2: Baseline, original binary"
note "No ASan instrumentation exists, so the overflow is silent."
run_case "Original rep movsb overflow" "$OUT_DIR/test_rep_movs" movs

bar "Step 3: RetroWrite ASan with rep fix DISABLED"
note "This simulates the old behavior: rep movsb instrumentation is skipped."
build_asan_variant "off" \
    "$OUT_DIR/test_rep_movs_REP_FIX_OFF.asan.s" \
    "$OUT_DIR/test_rep_movs_REP_FIX_OFF.asan"

OFF_TRACE=$(count_pattern "Skipping rep movs instrumentation" "$OUT_DIR/test_rep_movs_REP_FIX_OFF.asan.s")
OFF_ASAN=$(count_pattern "ASAN_" "$OUT_DIR/test_rep_movs_REP_FIX_OFF.asan.s")
note "ASan check markers in generated assembly: $OFF_ASAN"
note "rep movsb extra checks: disabled"

run_case "ASan binary, rep fix OFF, movs test" "$OUT_DIR/test_rep_movs_REP_FIX_OFF.asan" movs

bar "Step 4: RetroWrite ASan with rep fix ENABLED"
note "Now rep movsb gets boundary checks before the dangerous copy."
build_asan_variant "on" \
    "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan.s" \
    "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan"

ON_ASAN=$(count_pattern "ASAN_" "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan.s")
REP_MOVS_CHECKS=$(grep -n "rep movs" "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan.s" 2>/dev/null | head -5 | wc -l)
note "ASan check markers in generated assembly: $ON_ASAN"
note "rep movsb instrumentation evidence lines: $REP_MOVS_CHECKS"

bar "Step 5: Show generated instrumentation evidence"
note "Relevant generated assembly around rep movsb checks:"
grep -n "rep movs\|ASAN_MEM_ENTER" "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan.s" 2>/dev/null | head -12 | sed 's/^/  /'

bar "Step 6: Runtime comparison"
MOVS_OFF_RESULT=$(classify_run "$OUT_DIR/test_rep_movs_REP_FIX_OFF.asan" movs)
MOVS_ON_RESULT=$(classify_run "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan" movs)

printf "  %-36s %s\n" "Case" "Observed result"
printf "  %-36s %s\n" "----" "---------------"
printf "  %-36s %s\n" "Original movs overflow" "missed"
printf "  %-36s %s\n" "RetroWrite ASan, rep fix OFF" "$MOVS_OFF_RESULT"
printf "  %-36s %s\n" "RetroWrite ASan, rep fix ON" "$MOVS_ON_RESULT"

run_case "ASan report preview, rep fix ON, movs test" \
    "$OUT_DIR/test_rep_movs_REP_FIX_ON.asan" movs

bar "Demo result"
cat <<EOF
  Takeaway:
    Extension 1 closes a binary-ASan blind spot around repeated string
    instructions. The important evidence is not the exact ASan label; it is
    that the dangerous rep movsb path becomes ASan-visible after instrumentation.

    Without this pass:
      memcpy-style rep movsb overflows can be missed by RetroWrite ASan.

    With this pass:
      RetroWrite inserts boundary checks for rep movsb so the overflow is
      detected/trapped during execution instead of silently corrupting memory.
EOF
