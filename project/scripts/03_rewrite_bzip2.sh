#!/bin/bash
# ──────────────────────────────────────────────────────
# STEP 3: Rewrite a Real-World Binary (bzip2)
# ──────────────────────────────────────────────────────
# What this does:
#   1. Compiles bzip2 from source as a PIE binary
#   2. Uses RetroWrite to disassemble and rewrite it
#   3. Reassembles it into a new working binary
#   4. Verifies the rewritten binary works correctly
#
# This proves RetroWrite works on REAL software, not just toy examples.
# ──────────────────────────────────────────────────────

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
BZIP2_SRC="$RW_DIR/targets/bzip2-1.0.8"
OUT_DIR="$PROJ_DIR/output/bzip2_rewrite"

source "$RW_DIR/retro/bin/activate"
mkdir -p "$OUT_DIR"

# ─── Step 1: Compile bzip2 as PIE ───
echo "=== Step 1: Compile bzip2 as a PIE binary ==="
cd "$BZIP2_SRC"
make clean 2>/dev/null || true
make CC=gcc CFLAGS="-O2 -fPIC -fPIE -pie" LDFLAGS="-pie" bzip2 2>&1 | tail -1
cp bzip2 "$OUT_DIR/bzip2_original"
echo "  Created: output/bzip2_rewrite/bzip2_original"
echo ""

# ─── Step 2: RetroWrite rewrites the binary ───
echo "=== Step 2: RetroWrite converts binary -> reassembleable assembly ==="
python3 "$RW_DIR/retrowrite" "$OUT_DIR/bzip2_original" "$OUT_DIR/bzip2_rewritten.s" 2>&1
echo "  Created: output/bzip2_rewrite/bzip2_rewritten.s"
echo ""

# ─── Step 3: Reassemble into a new binary ───
echo "=== Step 3: Reassemble the assembly back into a binary ==="
gcc "$OUT_DIR/bzip2_rewritten.s" -o "$OUT_DIR/bzip2_rewritten" -L"$BZIP2_SRC" -lbz2
echo "  Created: output/bzip2_rewrite/bzip2_rewritten"
echo ""

# ─── Step 4: Verify correctness ───
echo "=== Step 4: Verify the rewritten binary works correctly ==="
TEST_STR="Hello, this is a RetroWrite correctness test!"
RESULT=$(echo "$TEST_STR" | "$OUT_DIR/bzip2_rewritten" -z 2>/dev/null | "$OUT_DIR/bzip2_rewritten" -d 2>/dev/null)
echo "  Input:  '$TEST_STR'"
echo "  Output: '$RESULT'"

if [ "$RESULT" = "$TEST_STR" ]; then
    echo ""
    echo "  PASS: Rewritten binary produces identical output!"
    echo "  RetroWrite successfully rewrote a real-world binary."
else
    echo "  FAIL: Output mismatch!"
    exit 1
fi

# ─── Step 5: ASan instrumentation on bzip2 ───
echo ""
echo "=== Step 5: Add ASan instrumentation to bzip2 ==="
python3 "$RW_DIR/retrowrite" --asan "$OUT_DIR/bzip2_original" "$OUT_DIR/bzip2_asan.s" 2>&1
ASAN_COUNT=$(grep -c "asan_report" "$OUT_DIR/bzip2_asan.s" 2>/dev/null || echo "0")
echo "  ASan instrumented $ASAN_COUNT memory access locations in bzip2!"
echo "  Created: output/bzip2_rewrite/bzip2_asan.s"
