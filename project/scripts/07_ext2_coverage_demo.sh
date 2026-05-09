#!/bin/bash
# ──────────────────────────────────────────────────────
# EXTENSION 2: Basic Block Coverage Pass Demo
# ──────────────────────────────────────────────────────
# Shows why the coverage pass matters:
#   - Original binary: runs, but gives no internal path visibility
#   - RetroWrite with coverage OFF: rewritten, but 0 blocks instrumented
#   - RetroWrite with coverage ON: basic blocks get runtime counters
#
# This extension is standalone. It does not require AFL.
# ──────────────────────────────────────────────────────

set +e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
SRC_DIR="$PROJ_DIR/src"
OUT_DIR="$PROJ_DIR/output/ext2_coverage"

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
    local binary="$2"
    shift 2

    echo ""
    echo "  --- $title ---"
    "$binary" "$@" 2>&1 | sed 's/^/    /'
}

count_blocks() {
    if [ -f "$1" ]; then
        grep -c "COV_BB_" "$1" 2>/dev/null
    else
        echo "0"
    fi
}

filter_rewrite_log() {
    grep -E "Rewriting|DISABLE_COVERAGE|Coverage:|process_input:|loop_paths:|main:" \
        || true
}

bar "Extension 2: Basic Block Coverage"
cat <<'EOF'
  Goal:
    Add path-visibility to a binary without source code and without AFL.

  Idea:
    RetroWrite inserts a small counter at each basic block entry.
    At runtime those counters update a 64KB coverage bitmap.

  Demo question:
    Can we rewrite a binary so it still behaves the same, but now has
    measurable internal execution-path tracking?
EOF

bar "Step 1: Build the original test binary"
note "source: $SRC_DIR/test_coverage.c"
note "output: $OUT_DIR/test_coverage"
clang -O0 -fPIC -fPIE -pie "$SRC_DIR/test_coverage.c" -o "$OUT_DIR/test_coverage"
if [ $? -ne 0 ]; then
    echo "  [!] Compile failed"
    exit 1
fi
note "compiled as PIE binary"

bar "Step 2: Baseline behavior, no coverage"
note "The original binary prints program output, but no internal coverage data."
run_case "Input: Hello World" "$OUT_DIR/test_coverage" "Hello World"
run_case "Input: Hi" "$OUT_DIR/test_coverage" "Hi"

bar "Step 3: Rewrite with coverage DISABLED"
note "This proves the module can be switched off for comparison."
cd "$RW_DIR"
DISABLE_COVERAGE=1 python3 retrowrite -m coverage \
    "$OUT_DIR/test_coverage" \
    "$OUT_DIR/test_coverage_NO_COV.s" 2>&1 | filter_rewrite_log | sed 's/^/  /'

BB_OFF=$(count_blocks "$OUT_DIR/test_coverage_NO_COV.s")
note "instrumented basic blocks with extension OFF: $BB_OFF"

clang "$OUT_DIR/test_coverage_NO_COV.s" -o "$OUT_DIR/test_coverage_NO_COV" 2>&1 | sed 's/^/  /'
if [ -x "$OUT_DIR/test_coverage_NO_COV" ]; then
    run_case "Rewritten binary, coverage OFF" "$OUT_DIR/test_coverage_NO_COV" "Hello World"
else
    note "coverage-OFF assembly did not build; continuing to coverage-ON evidence"
fi

bar "Step 4: Rewrite with coverage ENABLED"
cd "$RW_DIR"
python3 retrowrite -m coverage \
    "$OUT_DIR/test_coverage" \
    "$OUT_DIR/test_coverage_WITH_COV.s" 2>&1 | filter_rewrite_log | sed 's/^/  /'

BB_ON=$(count_blocks "$OUT_DIR/test_coverage_WITH_COV.s")
note "instrumented basic blocks with extension ON: $BB_ON"

bar "Step 5: Show inserted instrumentation"
note "These COV_BB labels are code injected by our coverage pass:"
grep -n "COV_BB_" "$OUT_DIR/test_coverage_WITH_COV.s" 2>/dev/null | head -8 | sed 's/^/  /'
echo ""
note "Each label marks a basic-block counter update before original code continues."

bar "Step 6: Build and run coverage-instrumented binary"
clang "$OUT_DIR/test_coverage_WITH_COV.s" -o "$OUT_DIR/test_coverage_WITH_COV" 2>&1 | sed 's/^/  /'
if [ ! -x "$OUT_DIR/test_coverage_WITH_COV" ]; then
    echo "  [!] Instrumented assembly failed to build"
    exit 1
fi

note "The visible program output should stay the same."
note "The difference is internal: coverage counters now update at runtime."
run_case "Instrumented input: Hello World" "$OUT_DIR/test_coverage_WITH_COV" "Hello World"
run_case "Instrumented input: Hi" "$OUT_DIR/test_coverage_WITH_COV" "Hi"
run_case "Instrumented input: no argument" "$OUT_DIR/test_coverage_WITH_COV"

bar "Demo result"
printf "  %-32s %s\n" "Mode" "Basic blocks instrumented"
printf "  %-32s %s\n" "----" "-------------------------"
printf "  %-32s %s\n" "Original binary" "0"
printf "  %-32s %s\n" "RetroWrite coverage OFF" "$BB_OFF"
printf "  %-32s %s\n" "RetroWrite coverage ON" "$BB_ON"

cat <<EOF

  Takeaway:
    Extension 2 turns a black-box binary into a measurable binary.
    The program output remains normal, but RetroWrite has inserted runtime
    path tracking into $BB_ON basic blocks.

    Without this pass:
      You can run the binary, but you cannot tell which internal paths ran.

    With this pass:
      You get binary-only path visibility without needing source code or AFL.
EOF
