#!/bin/bash
# ──────────────────────────────────────────────────────
# STEP 1: Setup RetroWrite
# ──────────────────────────────────────────────────────
# What this does:
#   - Creates a Python virtual environment inside retrowrite/
#   - Installs the Python libraries RetroWrite needs
#
# You only need to run this ONCE.
# ──────────────────────────────────────────────────────

set -e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RW_DIR="$PROJ_DIR/retrowrite"
VENV="$RW_DIR/retro"

echo "[1/3] Creating Python virtual environment..."
if [ ! -d "$VENV" ]; then
    python3 -m venv "$VENV"
fi

echo "[2/3] Installing dependencies..."
source "$VENV/bin/activate"
pip install -r "$RW_DIR/requirements.txt" -q

echo "[3/3] Checking system tools..."
echo "  Python:  $(python3 --version)"
echo "  GCC:     $(gcc --version | head -1)"
echo "  Clang:   $(clang --version | head -1)"

if command -v afl-fuzz &>/dev/null; then
    echo "  AFL++:   $(afl-fuzz --version 2>&1 | head -1)"
else
    echo "  AFL++:   NOT FOUND (install with: sudo apt install afl++)"
fi

echo ""
echo "Setup complete! You can now run the other scripts."
