# How to Run the Entire Project — Step by Step Commands

Every command below is meant to be run from the project root directory:
```bash
cd /home/hobbbit31/Desktop/NSS/project
```

---

## 0. Prerequisites & Setup (Run Once)

```bash
# Activate RetroWrite virtual environment
source retrowrite/retro/bin/activate

# Verify all tools are present
python3 -c "import capstone; import archinfo; print('Python deps OK')"
which clang gcc afl-gcc
dpkg -l | grep libasan
```

If RetroWrite venv doesn't exist, set it up:
```bash
cd retrowrite
python3 -m venv retro
source retro/bin/activate
pip install -r requirements.txt
cd ..
```

**NOTE:** Run `source retrowrite/retro/bin/activate` before every section below. All commands assume this environment is active.

---

## 1. Basic Binary Rewrite (No Instrumentation)

This proves RetroWrite can disassemble and reassemble a binary correctly.

```bash
# Compile a simple program as PIE binary
clang -O0 -fPIC -fPIE -pie retrowrite/demos/user_demo/heap.c -o output/asan_demo/heap

# RetroWrite: binary → assembly
cd retrowrite
python3 retrowrite output/asan_demo/heap output/asan_demo/heap.s

# Reassemble: assembly → binary
cd ..
gcc output/asan_demo/heap.s -o output/asan_demo/heap_rewritten

# Verify both work
output/asan_demo/heap
output/asan_demo/heap_rewritten
```

---

## 2. ASan Demo — Finding Memory Bugs in Binaries

This is the **core demo** of the paper: adding memory safety checks to a binary WITHOUT source code.

```bash
# Compile heap.c (has 2 bugs: out-of-bounds write + use-after-free)
clang -O0 -fPIC -fPIE -pie retrowrite/demos/user_demo/heap.c -o output/asan_demo/heap

# RetroWrite adds ASan instrumentation to the binary
cd retrowrite
python3 retrowrite --asan ../output/asan_demo/heap ../output/asan_demo/heap.asan.s
cd ..

# Fix compatibility (older RetroWrite uses asan_init_v4, modern libasan uses asan_init)
sed -i 's/asan_init_v4/asan_init/g' output/asan_demo/heap.asan.s

# Assemble the instrumented binary
clang output/asan_demo/heap.asan.s -lasan -o output/asan_demo/heap.asan

# Run ORIGINAL binary — bugs go undetected
output/asan_demo/heap 1    # out-of-bounds: silently corrupts memory
output/asan_demo/heap 2    # use-after-free: silently reads freed memory

# Run INSTRUMENTED binary — ASan catches the bugs
output/asan_demo/heap.asan 1    # out-of-bounds: ASan reports ERROR
output/asan_demo/heap.asan 2    # use-after-free: ASan reports ERROR
```

---

## 3. AFL Fuzzing — Binary-Only vs Source-Level Speed

Compares RetroWrite's binary-only fuzzing speed against source-level AFL.

```bash
# Compile fuzz target (has 3 input-triggered bugs)
clang -O0 -fPIC -fPIE -pie src/fuzz_target.c -o output/afl_fuzzing/fuzz_target

# RetroWrite: binary → assembly
cd retrowrite
python3 retrowrite ../output/afl_fuzzing/fuzz_target ../output/afl_fuzzing/fuzz_target.s
cd ..

# AFL-instrument the RetroWrite assembly (binary-only path)
afl-gcc output/afl_fuzzing/fuzz_target.s -o output/afl_fuzzing/fuzz_target_retrowrite_afl

# AFL-instrument from source (baseline for comparison)
afl-gcc -O0 src/fuzz_target.c -o output/afl_fuzzing/fuzz_target_source_afl

# Create seed inputs
mkdir -p output/afl_fuzzing/seeds
echo "test" > output/afl_fuzzing/seeds/seed1.txt

# Run AFL on RetroWrite binary (10 seconds)
timeout 10 afl-fuzz -i output/afl_fuzzing/seeds -o /tmp/afl_out_rw -- output/afl_fuzzing/fuzz_target_retrowrite_afl

# Run AFL on source binary (10 seconds)
timeout 10 afl-fuzz -i output/afl_fuzzing/seeds -o /tmp/afl_out_src -- output/afl_fuzzing/fuzz_target_source_afl

# Compare exec/sec from both runs (shown in AFL UI)
# Expected: RetroWrite AFL ≈ 88% of source AFL speed
```

---

## 4. Custom asan_test.c — 4 Memory Bugs

Tests all 4 types of memory bugs ASan can detect.

```bash
# Compile
clang -O0 -fPIC -fPIE -pie src/asan_test.c -o output/asan_demo/asan_test

# RetroWrite --asan
cd retrowrite
python3 retrowrite --asan ../output/asan_demo/asan_test ../output/asan_demo/asan_test.asan.s
cd ..
sed -i 's/asan_init_v4/asan_init/g' output/asan_demo/asan_test.asan.s
clang output/asan_demo/asan_test.asan.s -lasan -o output/asan_demo/asan_test.asan

# Test all 4 bugs
output/asan_demo/asan_test.asan 1    # Heap buffer overflow → CAUGHT
output/asan_demo/asan_test.asan 2    # Use-after-free → CAUGHT
output/asan_demo/asan_test.asan 3    # Stack buffer overflow → CAUGHT
output/asan_demo/asan_test.asan 4    # Double-free → CAUGHT
```

---

## 5. Extension 1 — rep movs/stos ASan Fix

Fixes a **limitation acknowledged in the IEEE S&P 2020 paper**: `memcpy`/`memset` overflows via `rep movsb`/`rep stosb` were not detected.

### With Extension DISABLED (shows the problem)

```bash
# Compile test program (uses inline rep movsb/stosb)
clang -O0 -fPIC -fPIE -pie src/test_rep_movs.c -o output/ext1_rep_movs/test_rep_movs

# Verify rep movsb is in the binary
objdump -d output/ext1_rep_movs/test_rep_movs | grep "rep movs"

# Run original — overflow is silent
output/ext1_rep_movs/test_rep_movs movs

# RetroWrite ASan WITH EXTENSION DISABLED
cd retrowrite
DISABLE_REP_FIX=1 python3 retrowrite --asan ../output/ext1_rep_movs/test_rep_movs ../output/ext1_rep_movs/ext1_OFF.s
cd ..
sed -i 's/asan_init_v4/asan_init/g' output/ext1_rep_movs/ext1_OFF.s
clang output/ext1_rep_movs/ext1_OFF.s -lasan -o output/ext1_rep_movs/ext1_OFF

# Run — SEGV crash (uncontrolled, ASan didn't catch it properly)
output/ext1_rep_movs/ext1_OFF movs
```

### With Extension ENABLED (shows the fix)

```bash
# RetroWrite ASan WITH EXTENSION ENABLED (no flag)
cd retrowrite
python3 retrowrite --asan ../output/ext1_rep_movs/test_rep_movs ../output/ext1_rep_movs/ext1_ON.s
cd ..
sed -i 's/asan_init_v4/asan_init/g' output/ext1_rep_movs/ext1_ON.s
clang output/ext1_rep_movs/ext1_ON.s -lasan -o output/ext1_rep_movs/ext1_ON

# Run — ASan CATCHES the overflow before it happens
output/ext1_rep_movs/ext1_ON movs
```

**What to observe:**
- `DISABLE_REP_FIX=1`: 51 instrumented locations, crash is `DEADLYSIGNAL` / `SEGV` (uncontrolled)
- No flag: 52 instrumented locations, crash is `READ of size 1` (ASan caught it at shadow memory check)

---

## 6. Extension 2 — Basic Block Coverage Pass

Adds standalone code coverage tracking to x64 binaries — no AFL dependency needed.

### With Extension DISABLED

```bash
# Compile test program (10+ basic blocks, multiple paths)
clang -O0 -fPIC -fPIE -pie src/test_coverage.c -o output/ext2_coverage/test_coverage

# RetroWrite coverage WITH EXTENSION DISABLED
cd retrowrite
DISABLE_COVERAGE=1 python3 retrowrite -m coverage ../output/ext2_coverage/test_coverage ../output/ext2_coverage/ext2_OFF.s
cd ..

# Check: 0 basic blocks instrumented
grep -c "COV_BB_" output/ext2_coverage/ext2_OFF.s

# Build and run
clang output/ext2_coverage/ext2_OFF.s -o output/ext2_coverage/ext2_OFF
output/ext2_coverage/ext2_OFF "Hello World"
```

### With Extension ENABLED

```bash
# RetroWrite coverage WITH EXTENSION ENABLED (no flag)
cd retrowrite
python3 retrowrite -m coverage ../output/ext2_coverage/test_coverage ../output/ext2_coverage/ext2_ON.s
cd ..

# Check: 20 basic blocks instrumented
grep -c "COV_BB_" output/ext2_coverage/ext2_ON.s

# Build and run
clang output/ext2_coverage/ext2_ON.s -o output/ext2_coverage/ext2_ON
output/ext2_coverage/ext2_ON "Hello World"

# Try different inputs — different paths exercised
output/ext2_coverage/ext2_ON "Hi"
output/ext2_coverage/ext2_ON
```

**What to observe:**
- `DISABLE_COVERAGE=1`: 0 basic blocks, no coverage tracking
- No flag: 20 basic blocks instrumented across 3 functions (process_input: 9, loop_paths: 8, main: 3)
- Output is identical in both cases — coverage adds zero visible overhead

---

## 7. Extension 3 — Function Call Tracing

Logs every function entry at runtime for binary-only debugging.

### With Extension DISABLED

```bash
# Compile test program (7 functions with nested calls)
clang -O0 -fPIC -fPIE -pie src/test_trace.c -o output/ext3_trace/test_trace

# RetroWrite trace WITH EXTENSION DISABLED
cd retrowrite
DISABLE_TRACE=1 python3 retrowrite -m trace ../output/ext3_trace/test_trace ../output/ext3_trace/ext3_OFF.s
cd ..

# Check: 0 functions instrumented
grep -c "TRACE_ENTER_" output/ext3_trace/ext3_OFF.s

# Build and run — no [TRACE] output even with env var
clang output/ext3_trace/ext3_OFF.s -o output/ext3_trace/ext3_OFF
RETRO_TRACE_PRINT=1 output/ext3_trace/ext3_OFF
```

### With Extension ENABLED

```bash
# RetroWrite trace WITH EXTENSION ENABLED (no flag)
cd retrowrite
python3 retrowrite -m trace ../output/ext3_trace/test_trace ../output/ext3_trace/ext3_ON.s
cd ..

# Check: 7 functions instrumented
grep -c "TRACE_ENTER_" output/ext3_trace/ext3_ON.s

# Build
clang output/ext3_trace/ext3_ON.s -o output/ext3_trace/ext3_ON

# Run WITHOUT tracing — identical to original, no overhead
output/ext3_trace/ext3_ON

# Run WITH tracing — see every function call on stderr
RETRO_TRACE_PRINT=1 output/ext3_trace/ext3_ON
```

**What to observe:**
- `DISABLE_TRACE=1`: 0 functions, no `[TRACE]` output
- No flag: 7 functions, `RETRO_TRACE_PRINT=1` shows:
  ```
  [TRACE] main
  [TRACE] process_data
  [TRACE] helper_b
  [TRACE] helper_c
  [TRACE] process_data
  [TRACE] helper_a
  [TRACE] compute
  [TRACE] helper_c
  [TRACE] helper_a
  [TRACE] helper_b
  [TRACE] compute
  [TRACE] cleanup
  ```
- Without `RETRO_TRACE_PRINT=1`, output is identical to original (tracing is silent)

---

## 8. Extension Toggle Demo (All 3 in One)

Interactive demo that shows each extension ON vs OFF with pauses for explanation.

```bash
# Demo all 3 extensions
source retrowrite/retro/bin/activate
bash scripts/09_extension_demo.sh

# Demo only one specific extension
bash scripts/09_extension_demo.sh 1    # Extension 1 only
bash scripts/09_extension_demo.sh 2    # Extension 2 only
bash scripts/09_extension_demo.sh 3    # Extension 3 only
```

---

## Quick Reference — All Flags

| Flag | Set before | What it does |
|------|-----------|-------------|
| `DISABLE_REP_FIX=1` | `python3 retrowrite --asan ...` | Extension 1 OFF: rep movsb/stosb not instrumented |
| `DISABLE_COVERAGE=1` | `python3 retrowrite -m coverage ...` | Extension 2 OFF: no basic block coverage |
| `DISABLE_TRACE=1` | `python3 retrowrite -m trace ...` | Extension 3 OFF: no function tracing |
| `RETRO_TRACE_PRINT=1` | Running the traced binary | Enables [TRACE] output to stderr |

---

## Quick Reference — All Test Programs

| File | What it tests | Bugs/Features |
|------|--------------|---------------|
| `retrowrite/demos/user_demo/heap.c` | Original ASan demo | Heap OOB write, use-after-free |
| `src/asan_test.c` | Extended ASan demo | Heap overflow, UAF, stack overflow, double-free |
| `src/fuzz_target.c` | AFL fuzzing demo | 3 input-triggered bugs (FUZZ, CRASH, long input) |
| `src/test_rep_movs.c` | Extension 1 | memcpy overflow via rep movsb, memset overflow via rep stosb |
| `src/test_coverage.c` | Extension 2 | 10+ basic blocks, 4 functions, multiple code paths |
| `src/test_trace.c` | Extension 3 | 7 functions, nested calls, conditional call patterns |

---

## Troubleshooting

**"asan_init_v4 not found" linker error:**
```bash
sed -i 's/asan_init_v4/asan_init/g' <output.s file>
```

**"not a position-independent executable" error:**
Make sure you compiled with `-fPIC -fPIE -pie`:
```bash
clang -O0 -fPIC -fPIE -pie source.c -o output
```

**RetroWrite virtual env not found:**
```bash
cd retrowrite
python3 -m venv retro
source retro/bin/activate
pip install -r requirements.txt
```

**AFL "core_pattern" error:**
```bash
echo core | sudo tee /proc/sys/kernel/core_pattern
```
