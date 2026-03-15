#!/bin/bash
# ──────────────────────────────────────────────────────
# Run ALL steps in order
# ──────────────────────────────────────────────────────
# Usage: ./scripts/run_all.sh
#
# This runs: Setup -> ASan Demo -> bzip2 Rewrite -> AFL Fuzzing
# ──────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=============================="
echo "  Running all project steps"
echo "=============================="
echo ""

echo ">>> STEP 1: Setup"
bash "$SCRIPT_DIR/01_setup.sh"
echo ""

echo ">>> STEP 2: ASan Demo"
bash "$SCRIPT_DIR/02_asan_demo.sh"
echo ""

echo ">>> STEP 3: Rewrite bzip2"
bash "$SCRIPT_DIR/03_rewrite_bzip2.sh"
echo ""

echo ">>> STEP 4: AFL Fuzzing"
bash "$SCRIPT_DIR/04_afl_fuzzing.sh"
echo ""

echo "=============================="
echo "  All steps complete!"
echo "  Check output/ for all generated files."
echo "=============================="
