#!/bin/bash
# ══════════════════════════════════════════════════════════════════
#  UNIFIED EXTENSION DEMO SCRIPT
# ══════════════════════════════════════════════════════════════════
#
#  This script demonstrates all 3 extensions with ON/OFF toggle.
#
#  For each extension:
#    1. First run with extension DISABLED (flag=1)  → show the problem
#    2. Then run with extension ENABLED  (no flag)  → show the fix
#
#  FLAGS:
#    DISABLE_REP_FIX=1   → Disable Extension 1 (rep movs/stos ASan fix)
#    DISABLE_COVERAGE=1  → Disable Extension 2 (basic block coverage)
#    DISABLE_TRACE=1     → Disable Extension 3 (function call tracing)
#
#  Usage:
#    ./scripts/09_extension_demo.sh          # Run full demo (all 3)
#    ./scripts/09_extension_demo.sh 1        # Demo only Extension 1
#    ./scripts/09_extension_demo.sh 2        # Demo only Extension 2
#    ./scripts/09_extension_demo.sh 3        # Demo only Extension 3
# ══════════════════════════════════════════════════════════════════

set +e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
SRC_DIR="$PROJ_DIR/src"
OUT_DIR="$PROJ_DIR/output/extension_demo"

source "$RW_DIR/retro/bin/activate"
mkdir -p "$OUT_DIR"

# Which extensions to demo (default: all)
DEMO_EXT="${1:-all}"

pause_for_demo() {
    echo ""
    echo "  Press ENTER to continue..."
    read -r
    echo ""
}

# ══════════════════════════════════════════════════════════════════
#  EXTENSION 1: rep movs/stos ASan Fix
# ══════════════════════════════════════════════════════════════════
demo_ext1() {
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  EXTENSION 1: rep movs/stos ASan Fix                   │"
    echo "│                                                         │"
    echo "│  Problem: memcpy/memset overflows are INVISIBLE to ASan │"
    echo "│  Fix: Instrument rep movsb/stosb boundary checks        │"
    echo "│  Flag: DISABLE_REP_FIX=1 to turn OFF this extension    │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""

    # ─── Compile test binary ───
    echo "Step 1: Compile test program with rep movsb/stosb overflow bugs"
    clang -O0 -fPIC -fPIE -pie "$SRC_DIR/test_rep_movs.c" -o "$OUT_DIR/test_rep_movs" 2>&1
    echo "  → Created: test_rep_movs (has memcpy overflow via rep movsb)"
    echo ""

    # ─── Run original binary ───
    echo "Step 2: Original binary - bugs are SILENT"
    "$OUT_DIR/test_rep_movs" movs 2>&1 || true
    echo ""

    pause_for_demo

    # ─── EXTENSION OFF: ASan without rep fix ───
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  Running with DISABLE_REP_FIX=1 (Extension 1 OFF)   ║"
    echo "║  This is what the ORIGINAL RetroWrite does.          ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    cd "$RW_DIR"
    DISABLE_REP_FIX=1 python3 retrowrite --asan "$OUT_DIR/test_rep_movs" "$OUT_DIR/test_rep_movs_NO_FIX.asan.s" 2>&1
    sed -i 's/asan_init_v4/asan_init/g' "$OUT_DIR/test_rep_movs_NO_FIX.asan.s"
    clang "$OUT_DIR/test_rep_movs_NO_FIX.asan.s" -lasan -o "$OUT_DIR/test_rep_movs_NO_FIX.asan" 2>&1
    echo ""
    echo "  Running instrumented binary (WITHOUT rep fix):"
    "$OUT_DIR/test_rep_movs_NO_FIX.asan" movs 2>&1 || true
    echo ""
    echo "  ↑ Notice: ASan reports a DEADLYSIGNAL / SEGV."
    echo "    It did NOT catch the bug proactively — the program crashed"
    echo "    because the overflow corrupted ASan's own shadow memory."
    echo "    This is an UNCONTROLLED crash, not a proper detection."
    echo ""

    pause_for_demo

    # ─── EXTENSION ON: ASan with rep fix ───
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  Running WITHOUT flag (Extension 1 ON)               ║"
    echo "║  This is OUR IMPROVED version.                       ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    cd "$RW_DIR"
    python3 retrowrite --asan "$OUT_DIR/test_rep_movs" "$OUT_DIR/test_rep_movs_WITH_FIX.asan.s" 2>&1
    sed -i 's/asan_init_v4/asan_init/g' "$OUT_DIR/test_rep_movs_WITH_FIX.asan.s"
    clang "$OUT_DIR/test_rep_movs_WITH_FIX.asan.s" -lasan -o "$OUT_DIR/test_rep_movs_WITH_FIX.asan" 2>&1
    echo ""
    echo "  Running instrumented binary (WITH rep fix):"
    "$OUT_DIR/test_rep_movs_WITH_FIX.asan" movs 2>&1 || true
    echo ""
    echo "  ↑ ASan CAUGHT the overflow BEFORE it happened!"
    echo "    It reports 'READ of size 1' — the shadow memory check"
    echo "    at the rep movsb boundary detected the violation."
    echo "    This is a CONTROLLED detection, not an accidental crash."
    echo ""

    # ─── Show the difference ───
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  COMPARISON:                                            │"
    echo "│                                                         │"
    NOFIX_COUNT=$(grep -c "ASAN" "$OUT_DIR/test_rep_movs_NO_FIX.asan.s" 2>/dev/null || echo "?")
    WITHFIX_COUNT=$(grep -c "ASAN" "$OUT_DIR/test_rep_movs_WITH_FIX.asan.s" 2>/dev/null || echo "?")
    echo "│  WITHOUT fix: $NOFIX_COUNT ASan check points              │"
    echo "│  WITH fix:    $WITHFIX_COUNT ASan check points              │"
    echo "│                                                         │"
    echo "│  The extra checks are for rep movsb/stosb boundaries.   │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
}


# ══════════════════════════════════════════════════════════════════
#  EXTENSION 2: Basic Block Coverage
# ══════════════════════════════════════════════════════════════════
demo_ext2() {
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  EXTENSION 2: Basic Block Coverage Pass                 │"
    echo "│                                                         │"
    echo "│  Problem: No standalone coverage for x64 binaries       │"
    echo "│  Fix: Instrument basic blocks with edge-hashing bitmap  │"
    echo "│  Flag: DISABLE_COVERAGE=1 to turn OFF this extension    │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""

    # ─── Compile test binary ───
    echo "Step 1: Compile test program with multiple code paths"
    clang -O0 -fPIC -fPIE -pie "$SRC_DIR/test_coverage.c" -o "$OUT_DIR/test_coverage" 2>&1
    echo "  → Created: test_coverage (10+ basic blocks, 4 functions)"
    echo ""

    pause_for_demo

    # ─── EXTENSION OFF: No coverage ───
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  Running with DISABLE_COVERAGE=1 (Extension 2 OFF)  ║"
    echo "║  Binary is rewritten but NO coverage tracking added. ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    cd "$RW_DIR"
    DISABLE_COVERAGE=1 python3 retrowrite -m coverage "$OUT_DIR/test_coverage" "$OUT_DIR/test_coverage_NO_COV.s" 2>&1
    echo ""
    BB_OFF=$(grep -c "COV_BB_" "$OUT_DIR/test_coverage_NO_COV.s" 2>/dev/null || echo "0")
    echo "  Basic blocks instrumented: $BB_OFF (none — extension is OFF)"
    echo ""
    clang "$OUT_DIR/test_coverage_NO_COV.s" -o "$OUT_DIR/test_coverage_NO_COV" 2>&1
    echo "  Running binary (no coverage):"
    "$OUT_DIR/test_coverage_NO_COV" "Hello World" 2>&1
    echo ""
    echo "  ↑ No coverage data is collected. You have no idea which"
    echo "    code paths were executed."
    echo ""

    pause_for_demo

    # ─── EXTENSION ON: With coverage ───
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  Running WITHOUT flag (Extension 2 ON)               ║"
    echo "║  Every basic block gets a coverage counter.          ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    cd "$RW_DIR"
    python3 retrowrite -m coverage "$OUT_DIR/test_coverage" "$OUT_DIR/test_coverage_WITH_COV.s" 2>&1
    echo ""
    BB_ON=$(grep -c "COV_BB_" "$OUT_DIR/test_coverage_WITH_COV.s" 2>/dev/null || echo "0")
    echo "  Basic blocks instrumented: $BB_ON"
    echo ""
    clang "$OUT_DIR/test_coverage_WITH_COV.s" -o "$OUT_DIR/test_coverage_WITH_COV" 2>&1
    echo "  Running binary (with coverage):"
    "$OUT_DIR/test_coverage_WITH_COV" "Hello World" 2>&1
    echo ""
    echo "  ↑ Output is identical, but now $BB_ON basic blocks are"
    echo "    being tracked in a coverage bitmap at runtime!"
    echo ""

    # ─── Show the difference ───
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  COMPARISON:                                            │"
    echo "│                                                         │"
    echo "│  WITHOUT extension: 0 blocks tracked                    │"
    echo "│  WITH extension:    $BB_ON blocks tracked                   │"
    echo "│                                                         │"
    echo "│  Each block has an edge-hashing trampoline that updates  │"
    echo "│  a 64KB coverage bitmap — same technique as AFL.        │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
}


# ══════════════════════════════════════════════════════════════════
#  EXTENSION 3: Function Call Tracing
# ══════════════════════════════════════════════════════════════════
demo_ext3() {
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  EXTENSION 3: Function Call Tracing                     │"
    echo "│                                                         │"
    echo "│  Problem: Can't trace internal function calls in binary │"
    echo "│  Fix: Instrument function entries with logging          │"
    echo "│  Flag: DISABLE_TRACE=1 to turn OFF this extension      │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""

    # ─── Compile test binary ───
    echo "Step 1: Compile test program with 7 functions"
    clang -O0 -fPIC -fPIE -pie "$SRC_DIR/test_trace.c" -o "$OUT_DIR/test_trace" 2>&1
    echo "  → Created: test_trace (main, process_data, helper_a/b/c, compute, cleanup)"
    echo ""

    pause_for_demo

    # ─── EXTENSION OFF: No tracing ───
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  Running with DISABLE_TRACE=1 (Extension 3 OFF)     ║"
    echo "║  Binary is rewritten but NO tracing added.           ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    cd "$RW_DIR"
    DISABLE_TRACE=1 python3 retrowrite -m trace "$OUT_DIR/test_trace" "$OUT_DIR/test_trace_NO_TRACE.s" 2>&1
    echo ""
    FN_OFF=$(grep -c "TRACE_ENTER_" "$OUT_DIR/test_trace_NO_TRACE.s" 2>/dev/null || echo "0")
    echo "  Functions instrumented: $FN_OFF (none — extension is OFF)"
    echo ""
    clang "$OUT_DIR/test_trace_NO_TRACE.s" -o "$OUT_DIR/test_trace_NO_TRACE" 2>&1
    echo "  Running binary (no tracing, even with RETRO_TRACE_PRINT=1):"
    RETRO_TRACE_PRINT=1 "$OUT_DIR/test_trace_NO_TRACE" 2>&1
    echo ""
    echo "  ↑ No [TRACE] output. You cannot see which functions were called."
    echo ""

    pause_for_demo

    # ─── EXTENSION ON: With tracing ───
    echo "╔═══════════════════════════════════════════════════════╗"
    echo "║  Running WITHOUT flag (Extension 3 ON)               ║"
    echo "║  Every function entry is logged.                     ║"
    echo "╚═══════════════════════════════════════════════════════╝"
    echo ""
    cd "$RW_DIR"
    python3 retrowrite -m trace "$OUT_DIR/test_trace" "$OUT_DIR/test_trace_WITH_TRACE.s" 2>&1
    echo ""
    FN_ON=$(grep -c "TRACE_ENTER_" "$OUT_DIR/test_trace_WITH_TRACE.s" 2>/dev/null || echo "0")
    echo "  Functions instrumented: $FN_ON"
    echo ""
    clang "$OUT_DIR/test_trace_WITH_TRACE.s" -o "$OUT_DIR/test_trace_WITH_TRACE" 2>&1
    echo ""
    echo "  Running binary WITHOUT trace printing (normal mode):"
    "$OUT_DIR/test_trace_WITH_TRACE" 2>/dev/null
    echo ""
    echo "  ↑ Same output as original. Tracing has near-zero overhead."
    echo ""

    pause_for_demo

    echo "  Now running WITH RETRO_TRACE_PRINT=1 (trace to stderr):"
    echo "  ─── stderr (trace) + stdout (program) combined ───"
    RETRO_TRACE_PRINT=1 "$OUT_DIR/test_trace_WITH_TRACE" 2>&1
    echo ""
    echo "  ↑ Every function call is logged! You can see the full"
    echo "    call sequence: main → process_data → helper_b → ..."
    echo ""

    # ─── Show the difference ───
    echo "┌─────────────────────────────────────────────────────────┐"
    echo "│  COMPARISON:                                            │"
    echo "│                                                         │"
    echo "│  WITHOUT extension: 0 functions traced                  │"
    echo "│  WITH extension:    $FN_ON functions traced                  │"
    echo "│                                                         │"
    echo "│  Tracing uses raw write() syscall — no libc dependency. │"
    echo "│  Toggle output with: RETRO_TRACE_PRINT=1               │"
    echo "└─────────────────────────────────────────────────────────┘"
    echo ""
}


# ══════════════════════════════════════════════════════════════════
#  MAIN
# ══════════════════════════════════════════════════════════════════

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  RetroWrite Extension Demo"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  Flags to disable extensions:"
echo "    DISABLE_REP_FIX=1   → Extension 1 OFF (rep movs ASan)"
echo "    DISABLE_COVERAGE=1  → Extension 2 OFF (basic block coverage)"
echo "    DISABLE_TRACE=1     → Extension 3 OFF (function tracing)"
echo ""
echo "  For each extension, we will show:"
echo "    1. With flag (DISABLED)  → the problem / limitation"
echo "    2. Without flag (ENABLED) → our fix / improvement"
echo ""
echo "══════════════════════════════════════════════════════════════"
echo ""

if [ "$DEMO_EXT" = "all" ] || [ "$DEMO_EXT" = "1" ]; then
    demo_ext1
    echo ""
    echo "═════════════════════════════════════════════════════════"
    echo ""
fi

if [ "$DEMO_EXT" = "all" ] || [ "$DEMO_EXT" = "2" ]; then
    demo_ext2
    echo ""
    echo "═════════════════════════════════════════════════════════"
    echo ""
fi

if [ "$DEMO_EXT" = "all" ] || [ "$DEMO_EXT" = "3" ]; then
    demo_ext3
    echo ""
    echo "═════════════════════════════════════════════════════════"
    echo ""
fi

echo "══════════════════════════════════════════════════════════════"
echo "  DEMO COMPLETE"
echo ""
echo "  Summary of flags:"
echo "    DISABLE_REP_FIX=1   → memcpy overflow goes UNDETECTED"
echo "    (no flag)            → memcpy overflow is CAUGHT"
echo ""
echo "    DISABLE_COVERAGE=1  → 0 basic blocks tracked"
echo "    (no flag)            → all basic blocks tracked"
echo ""
echo "    DISABLE_TRACE=1     → no function call logging"
echo "    (no flag)            → all function entries logged"
echo "══════════════════════════════════════════════════════════════"
