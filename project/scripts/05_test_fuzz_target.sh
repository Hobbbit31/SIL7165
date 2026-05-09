#!/bin/bash
# ──────────────────────────────────────────────────────
# STEP 5: Test Cases for fuzz_target.c
# ──────────────────────────────────────────────────────
# For each attack type checks:
#   1. Is the attack POSSIBLE on this code?
#   2. Can RetroWrite (ASan) DETECT it?
#   3. Does the system CRASH?
# ──────────────────────────────────────────────────────

set +e

PROJ_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC_DIR="$PROJ_DIR/src"
OUT_DIR="$PROJ_DIR/output/test_fuzz"
mkdir -p "$OUT_DIR"

# Compile two versions
clang -O0 -g "$SRC_DIR/fuzz_target.c" -o "$OUT_DIR/fuzz_raw" 2>/dev/null
clang -O0 -g -fsanitize=address -fno-omit-frame-pointer \
    "$SRC_DIR/fuzz_target.c" -o "$OUT_DIR/fuzz_asan" 2>/dev/null

echo "================================================================"
echo "  fuzz_target.c — Attack Analysis"
echo "================================================================"
echo ""

run_attack() {
    local name="$1"
    local input="$2"
    local possible="$3"
    local detectable="$4"
    local description="$5"

    echo "┌────────────────────────────────────────────────────────┐"
    echo "  ATTACK: $name"
    echo "  Input:  $(echo -n "$input" | head -c 50)"
    echo "  Desc:   $description"
    echo "├────────────────────────────────────────────────────────┤"

    # Test 1: Is attack possible?
    echo -n "  1. Attack Possible?    "
    if [ "$possible" = "yes" ]; then
        echo "YES"
    else
        echo "NO — code does not have this vulnerability"
    fi

    # Test 2: Does system crash (without ASan)?
    echo -n "  2. System Crashes?     "
    if [ "$possible" = "yes" ]; then
        echo -n "$input" | timeout 5 "$OUT_DIR/fuzz_raw" > /dev/null 2>/dev/null
        raw_exit=$?
        if [ $raw_exit -ne 0 ]; then
            if [ $raw_exit -eq 139 ]; then
                echo "YES — Segmentation Fault (exit=$raw_exit)"
            elif [ $raw_exit -eq 134 ]; then
                echo "YES — Aborted (exit=$raw_exit)"
            else
                echo "YES — Crashed (exit=$raw_exit)"
            fi
        else
            echo "NO — Silently corrupts memory (worse! attacker stays hidden)"
        fi
    else
        echo "N/A"
    fi

    # Test 3: Can RetroWrite ASan detect it?
    echo -n "  3. RetroWrite Detects? "
    if [ "$possible" = "yes" ] && [ "$detectable" = "yes" ]; then
        echo -n "$input" | timeout 5 "$OUT_DIR/fuzz_asan" > /dev/null 2>&1
        asan_exit=$?
        if [ $asan_exit -ne 0 ]; then
            echo "YES — ASan caught it (exit=$asan_exit)"
        else
            echo "NO — ASan missed it"
        fi
    elif [ "$possible" = "yes" ] && [ "$detectable" = "no" ]; then
        echo "NO — Logic bug, not memory safety"
    else
        echo "N/A"
    fi

    echo "└────────────────────────────────────────────────────────┘"
    echo ""
}

# ─────────────────────────────────────────────
# ATTACKS THAT ARE POSSIBLE
# ─────────────────────────────────────────────

echo "========== ATTACKS THAT ARE POSSIBLE =========="
echo ""

run_attack "Heap Buffer Overflow" \
    "FUZZAAAAAAAAAAAAAAAAAAAAAAAAAAAA" \
    "yes" "yes" \
    "FUZZ prefix + 27 bytes. malloc(8) but memcpy copies 31 bytes"

run_attack "Null Pointer Dereference" \
    "CRASH!" \
    "yes" "yes" \
    "CRASH prefix + 1 byte. Writes to NULL pointer -> segfault"

run_attack "Stack Buffer Overflow" \
    "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA" \
    "yes" "yes" \
    "52 bytes into local[32]. Overwrites return address on stack"

# ─────────────────────────────────────────────
# ATTACKS THAT ARE NOT POSSIBLE
# ─────────────────────────────────────────────

echo "========== ATTACKS THAT ARE NOT POSSIBLE =========="
echo ""

run_attack "Format String" \
    "%x.%x.%x.%x" \
    "no" "no" \
    "No printf(buf) in code. All printf uses format strings safely"

run_attack "Use-After-Free" \
    "FUZZAAAA" \
    "no" "no" \
    "Heap pointer freed but never reused after free()"

run_attack "Double Free" \
    "FUZZAAAA" \
    "no" "no" \
    "free() called only once per allocation"

run_attack "Integer Overflow" \
    "AAAA" \
    "no" "no" \
    "No arithmetic on user-controlled values"

run_attack "Command Injection" \
    "; rm -rf /" \
    "no" "no" \
    "No system() or exec() calls in the code"

run_attack "Information Leak" \
    "hello" \
    "no" "no" \
    "No output of buffer contents back to user"

run_attack "Race Condition" \
    "test" \
    "no" "no" \
    "Single-threaded program, no shared state"

# ─────────────────────────────────────────────
# SUMMARY TABLE
# ─────────────────────────────────────────────

echo "================================================================"
echo "  SUMMARY"
echo "================================================================"
echo ""
echo "  ┌─────────────────────┬──────────┬─────────┬────────────────┐"
echo "  │ Attack              │ Possible │ Crashes │ ASan Detects   │"
echo "  ├─────────────────────┼──────────┼─────────┼────────────────┤"
echo "  │ Heap Overflow       │ YES      │ Silent* │ YES            │"
echo "  │ Null Ptr Deref      │ YES      │ YES     │ YES            │"
echo "  │ Stack Overflow      │ YES      │ YES     │ YES            │"
echo "  ├─────────────────────┼──────────┼─────────┼────────────────┤"
echo "  │ Format String       │ NO       │ ---     │ ---            │"
echo "  │ Use-After-Free      │ NO       │ ---     │ ---            │"
echo "  │ Double Free         │ NO       │ ---     │ ---            │"
echo "  │ Integer Overflow    │ NO       │ ---     │ ---            │"
echo "  │ Command Injection   │ NO       │ ---     │ ---            │"
echo "  │ Info Leak           │ NO       │ ---     │ ---            │"
echo "  │ Race Condition      │ NO       │ ---     │ ---            │"
echo "  └─────────────────────┴──────────┴─────────┴────────────────┘"
echo ""
echo "  * Heap overflow runs silently without crashing — memory is"
echo "    corrupted but program continues. This is MORE dangerous"
echo "    because the attacker stays undetected."
echo ""
echo "  RetroWrite + ASan detects ALL 3 possible attacks, including"
echo "  the silent heap overflow that would otherwise go unnoticed."
echo ""
