#!/usr/bin/env bash
# Compare bug detection + runtime overhead:
#   (a) original binary  -- no instrumentation
#   (b) Valgrind Memcheck -- dynamic shadow VM
#   (c) QEMU user-mode    -- dynamic binary translation
#   (d) RetroWrite + Binary-ASan -- static rewrite (this project)
#
# Targets the existing heap demo at output/asan_demo/{heap, heap.asan}
# Usage:  bash scripts/10_qemu_valgrind_compare.sh

set -u
cd "$(dirname "$0")/.."

ORIG=output/asan_demo/heap
ASAN=output/asan_demo/heap.asan

bar() { printf '\n\033[1;34m===== %s =====\033[0m\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { echo "missing: $1 (install: $2)"; exit 1; }; }

need valgrind     "sudo apt install valgrind"
need qemu-x86_64  "sudo apt install qemu-user"
[[ -x $ORIG && -x $ASAN ]] || { echo "missing $ORIG or $ASAN"; exit 1; }

for TEST in 1 2; do
  case $TEST in
    1) LABEL="Test 1: heap out-of-bounds write" ;;
    2) LABEL="Test 2: use-after-free read" ;;
  esac
  bar "$LABEL"

  echo -e "\n[a] Original binary (no instrumentation) -- bug is silent"
  $ORIG $TEST; echo "    exit=$?"

  echo -e "\n[b] Valgrind Memcheck -- dynamic shadow memory"
  valgrind -q --error-exitcode=99 $ORIG $TEST 2>&1 | sed 's/^/    /' | head -20
  echo "    exit=$?"

  echo -e "\n[c] QEMU user-mode -- dynamic translation (no bug detection by default)"
  qemu-x86_64 $ORIG $TEST 2>&1 | sed 's/^/    /' | head -5
  echo "    exit=$?"

  echo -e "\n[d] RetroWrite Binary-ASan -- static rewrite"
  $ASAN $TEST 2>&1 | sed 's/^/    /' | head -12
  echo "    exit=$?"
done

bar "Wall-clock timing (test 1, best of 3)"
time_best() {
  local best="" t
  for i in 1 2 3; do
    t=$( { /usr/bin/time -f "%e" "$@" >/dev/null; } 2>&1 | tail -1 )
    if [[ -z $best ]] || awk -v a="$t" -v b="$best" 'BEGIN{exit !(a<b)}'; then best=$t; fi
  done
  echo "$best"
}
printf "  %-32s %s s\n" "original"            "$(time_best $ORIG 1)"
printf "  %-32s %s s\n" "valgrind memcheck"   "$(time_best valgrind -q $ORIG 1)"
printf "  %-32s %s s\n" "qemu-x86_64"         "$(time_best qemu-x86_64 $ORIG 1)"
printf "  %-32s %s s\n" "retrowrite asan"     "$(time_best $ASAN 1)"

bar "Takeaway"
cat <<'EOF'
  - QEMU runs the binary but does NOT detect memory bugs (it's an emulator,
    not a sanitizer) -- shown to contrast "dynamic translation" vs "dynamic
    shadow memory" vs "static rewrite + ASan".
  - Valgrind detects the bug but pays a 10-30x slowdown.
  - RetroWrite-ASan detects the same bug at near source-level speed
    -- without source code, on the COTS x86-64 PIE binary.
EOF
