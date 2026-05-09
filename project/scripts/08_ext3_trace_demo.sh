#!/bin/bash
# ──────────────────────────────────────────────────────
# EXTENSION 3: Function Call Tracing Demo
# ──────────────────────────────────────────────────────
# Shows why the trace pass matters:
#   - Original binary: visible output only
#   - RetroWrite with tracing OFF: rewritten, but no trace points
#   - RetroWrite with tracing ON: function entries emit [TRACE] lines
#
# This extension is for binary-only behavior visibility.
# ──────────────────────────────────────────────────────

set +e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
SRC_DIR="$PROJ_DIR/src"
OUT_DIR="$PROJ_DIR/output/ext3_trace"

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
    "$@" 2>&1 | sed 's/^/    /'
}

count_trace_points() {
    if [ -f "$1" ]; then
        grep -c "TRACE_ENTER_" "$1" 2>/dev/null
    else
        echo "0"
    fi
}

filter_rewrite_log() {
    grep -E "Rewriting|DISABLE_TRACE|Trace:|Trace buffer" || true
}

bar "Extension 3: Function Call Tracing"
cat <<'EOF'
  Goal:
    Reveal internal function-call order in a binary-only program.

  Idea:
    RetroWrite injects a small trampoline at each function entry.
    The trampoline records the function name and optionally prints it.

  Why this matters:
    Program output tells us what happened at the surface.
    Function tracing tells us how the binary reached that behavior internally.
EOF

bar "Step 1: Build the original test binary"
note "source: $SRC_DIR/test_trace.c"
note "output: $OUT_DIR/test_trace"
clang -O0 -fPIC -fPIE -pie "$SRC_DIR/test_trace.c" -o "$OUT_DIR/test_trace"
if [ $? -ne 0 ]; then
    echo "  [!] Compile failed"
    exit 1
fi
note "compiled as PIE binary"

bar "Step 2: Baseline behavior, no tracing"
note "The original binary prints output, but it does not expose function order."
run_case "Original binary" "$OUT_DIR/test_trace"

bar "Step 3: Rewrite with tracing DISABLED"
note "This gives a clean OFF comparison: rewritten binary, 0 trace points."
cd "$RW_DIR"
DISABLE_TRACE=1 python3 retrowrite -m trace \
    "$OUT_DIR/test_trace" \
    "$OUT_DIR/test_trace_NO_TRACE.s" 2>&1 | filter_rewrite_log | sed 's/^/  /'

TRACE_OFF=$(count_trace_points "$OUT_DIR/test_trace_NO_TRACE.s")
note "function trace points with extension OFF: $TRACE_OFF"

clang "$OUT_DIR/test_trace_NO_TRACE.s" -o "$OUT_DIR/test_trace_NO_TRACE" 2>&1 | sed 's/^/  /'
if [ -x "$OUT_DIR/test_trace_NO_TRACE" ]; then
    run_case "Rewritten binary, tracing OFF" "$OUT_DIR/test_trace_NO_TRACE"
else
    note "trace-OFF assembly did not build; continuing to trace-ON evidence"
fi

bar "Step 4: Rewrite with tracing ENABLED"
cd "$RW_DIR"
python3 retrowrite -m trace \
    "$OUT_DIR/test_trace" \
    "$OUT_DIR/test_trace_WITH_TRACE.s" 2>&1 | filter_rewrite_log | sed 's/^/  /'

TRACE_ON=$(count_trace_points "$OUT_DIR/test_trace_WITH_TRACE.s")
note "function trace points with extension ON: $TRACE_ON"

bar "Step 5: Show inserted trace points"
note "These TRACE_ENTER labels are injected at function entries:"
grep -n "TRACE_ENTER_" "$OUT_DIR/test_trace_WITH_TRACE.s" 2>/dev/null | head -10 | sed 's/^/  /'
echo ""
note "Each trace point calls the injected __trace_log_entry runtime."

bar "Step 6: Build traced binary"
clang "$OUT_DIR/test_trace_WITH_TRACE.s" -o "$OUT_DIR/test_trace_WITH_TRACE" 2>&1 | sed 's/^/  /'
if [ ! -x "$OUT_DIR/test_trace_WITH_TRACE" ]; then
    echo "  [!] Trace-instrumented assembly failed to build"
    exit 1
fi
note "created: $OUT_DIR/test_trace_WITH_TRACE"

bar "Step 7: Run traced binary with printing OFF"
note "Instrumentation is present, but RETRO_TRACE_PRINT is not set."
note "Visible output remains normal."
run_case "Tracing compiled in, printing OFF" "$OUT_DIR/test_trace_WITH_TRACE"

bar "Step 8: Run traced binary with printing ON"
note "Setting RETRO_TRACE_PRINT=1 exposes the internal function-call sequence."
TRACE_OUTPUT=$(RETRO_TRACE_PRINT=1 "$OUT_DIR/test_trace_WITH_TRACE" 2>&1)

echo ""
echo "  --- Trace lines only ---"
printf "%s\n" "$TRACE_OUTPUT" | grep "^\[TRACE\]" | sed 's/^/    /'

echo ""
echo "  --- Program output only ---"
printf "%s\n" "$TRACE_OUTPUT" | grep -v "^\[TRACE\]" | sed 's/^/    /'

bar "Demo result"
printf "  %-30s %s\n" "Mode" "Function trace points"
printf "  %-30s %s\n" "----" "---------------------"
printf "  %-30s %s\n" "Original binary" "0"
printf "  %-30s %s\n" "RetroWrite trace OFF" "$TRACE_OFF"
printf "  %-30s %s\n" "RetroWrite trace ON" "$TRACE_ON"

cat <<EOF

  Takeaway:
    Extension 3 turns a black-box binary into a traceable binary.
    The normal program output is preserved, but with RETRO_TRACE_PRINT=1
    we can observe internal function execution order.

    Without this pass:
      You see only final output and printed messages.

    With this pass:
      You see function-level behavior without source code, GDB breakpoints,
      strace, Pin, DynamoRIO, or QEMU tracing.
EOF
