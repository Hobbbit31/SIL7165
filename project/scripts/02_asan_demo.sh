#!/bin/bash
# ──────────────────────────────────────────────────────
# STEP 2: ASan Demo - Finding Memory Bugs in Binaries
# ──────────────────────────────────────────────────────
# What this does:
#   1. Compiles heap.c into a normal binary (no source-level checks)
#   2. Uses RetroWrite to add ASan (memory bug detector) to the BINARY
#   3. Runs both versions to show: original misses bugs, ASan catches them
#
# This is the CORE demo of the paper:
#   "We can add memory safety checks to a binary WITHOUT source code"
# ──────────────────────────────────────────────────────

set +e  # Don't exit on errors (ASan binaries return non-zero on purpose)

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
SRC_DIR="$RW_DIR/demos/user_demo"   # heap.c and stack.c are from the original repo
OUT_DIR="$PROJ_DIR/output/asan_demo"

source "$RW_DIR/retro/bin/activate"
mkdir -p "$OUT_DIR"

# ─── Step 1: Compile the vulnerable program as a PIE binary ───
echo "=== Step 1: Compile heap.c as a PIE binary (no sanitizers) ==="
echo ""
echo "  heap.c has two bugs:"
echo "    - Out-of-bounds write (writes past allocated memory)"
echo "    - Use-after-free (uses memory after freeing it)"
echo ""
clang -O0 -fPIC -fPIE -pie "$SRC_DIR/heap.c" -o "$OUT_DIR/heap"
echo "  Created: output/asan_demo/heap"
echo ""

# ─── Step 2: RetroWrite adds ASan to the binary ───
echo "=== Step 2: RetroWrite adds ASan checks to the binary ==="
echo ""
echo "  Binary -> RetroWrite --asan -> Assembly with guards -> New binary"
echo ""
python3 "$RW_DIR/retrowrite" --asan "$OUT_DIR/heap" "$OUT_DIR/heap.asan.s" 2>&1

# Fix compatibility: older RetroWrite references asan_init_v4, modern libasan uses asan_init
sed -i 's/asan_init_v4/asan_init/g' "$OUT_DIR/heap.asan.s"

clang "$OUT_DIR/heap.asan.s" -lasan -o "$OUT_DIR/heap.asan"
echo "  Created: output/asan_demo/heap.asan (instrumented binary)"
echo ""

# ─── Step 3: Test - Original binary MISSES the bugs ───
echo "=== Step 3: Run ORIGINAL binary (bugs go undetected) ==="
echo ""
echo "  Testing out-of-bounds access:"
"$OUT_DIR/heap" 1
echo "  ^ No crash. The bug silently corrupted memory."
echo ""

echo "  Testing use-after-free:"
"$OUT_DIR/heap" 2
echo "  ^ No crash. The bug silently corrupted memory."
echo ""

# ─── Step 4: Test - ASan binary CATCHES the bugs ───
echo "=== Step 4: Run ASan-INSTRUMENTED binary (bugs DETECTED!) ==="
echo ""
echo "  Testing out-of-bounds access:"
"$OUT_DIR/heap.asan" 1 2>&1 | head -10
echo ""

echo "  Testing use-after-free:"
"$OUT_DIR/heap.asan" 2 2>&1 | head -10
echo ""

echo "=== RESULT ==="
echo "  Original binary: bugs go UNDETECTED (silent corruption)"
echo "  RetroWrite ASan: bugs CAUGHT immediately with detailed report"
echo "  All done WITHOUT source code - only the binary was needed!"
