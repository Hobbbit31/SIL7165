# End-Term Demo — Command Cheat Sheet

Run these one-by-one in a terminal. Order matters.
Everything operates on the **ELF binary** — no source code is touched at instrumentation time.

---

## SETUP (run once before starting)

```bash
cd ~/Desktop/NSS/project
source retrowrite/retro/bin/activate
clear
```

---

## DEMO 1 — Core ASan (paper's headline result)

> "Everything runs on the ELF binary. No source code involved."

```bash
# 1. Compile vulnerable program to a stripped PIE binary
clang -O0 -fPIC -fPIE -pie retrowrite/demos/user_demo/heap.c -o output/asan_demo/heap

# 2. Run the ORIGINAL — bug is silent
./output/asan_demo/heap 1            # OOB
./output/asan_demo/heap 2            # use-after-free

# 3. RetroWrite rewrites the binary, adds ASan
python3 retrowrite/retrowrite --asan output/asan_demo/heap output/asan_demo/heap.asan.s

# 4. Reassemble the instrumented .s back into a binary
gcc -fsanitize=address -lrt -no-pie output/asan_demo/heap.asan.s -o output/asan_demo/heap.asan

# 5. Run the INSTRUMENTED binary — bug caught
./output/asan_demo/heap.asan 1
./output/asan_demo/heap.asan 2
```

> "Original silent. Instrumented binary fires AddressSanitizer reports for both bugs."

---

## DEMO 2 — QEMU vs Valgrind vs RetroWrite

> "Same ELF, four tools. Watch detection AND speed."

```bash
T=1   # 1 = OOB, 2 = use-after-free

# (a) original — silent
./output/asan_demo/heap $T

# (b) Valgrind — detects, slow
valgrind -q ./output/asan_demo/heap $T

# (c) QEMU — runs, no detection
qemu-x86_64 ./output/asan_demo/heap $T

# (d) RetroWrite-ASan — detects, fast
./output/asan_demo/heap.asan $T

# Timing comparison
time ./output/asan_demo/heap $T          >/dev/null
time qemu-x86_64 ./output/asan_demo/heap $T >/dev/null
time ./output/asan_demo/heap.asan $T     >/dev/null
time valgrind -q ./output/asan_demo/heap $T >/dev/null
```

> "QEMU runs but finds nothing. Valgrind finds it but is ~30× slower. RetroWrite finds it at native speed."

---

## DEMO 3 — Extension 1: rep movs / rep stos

> "Stock RetroWrite was BLIND to memcpy/memset overflows. Our patch closes that gap."

```bash
# 1. Compile test program with rep movs/stos overflows
clang -O0 -fPIC -fPIE -pie src/test_rep_movs.c -o output/ext1_rep_movs/test_rep_movs

# 2. Original — silent
./output/ext1_rep_movs/test_rep_movs movs
./output/ext1_rep_movs/test_rep_movs stos

# 3. RetroWrite (with Ext 1 active by default)
python3 retrowrite/retrowrite --asan output/ext1_rep_movs/test_rep_movs output/ext1_rep_movs/test_rep_movs.asan.s
gcc -fsanitize=address -lrt -no-pie output/ext1_rep_movs/test_rep_movs.asan.s -o output/ext1_rep_movs/test_rep_movs.asan

# 4. Instrumented — bugs caught
./output/ext1_rep_movs/test_rep_movs.asan movs
./output/ext1_rep_movs/test_rep_movs.asan stos
```

> "memcpy overflow → ASan report. memset overflow → DEADLYSIGNAL/SEGV. Both invisible without our patch."

---

## DEMO 4 — Extension 2: standalone coverage

> "Coverage tracking on a binary, no AFL needed."

```bash
# 1. Compile test program
clang -O0 -fPIC -fPIE -pie src/test_coverage.c -o output/ext2_coverage/test_coverage

# 2. RetroWrite with coverage pass
python3 retrowrite/retrowrite -m coverage output/ext2_coverage/test_coverage output/ext2_coverage/test_coverage.cov.s
gcc -no-pie output/ext2_coverage/test_coverage.cov.s -o output/ext2_coverage/test_coverage.cov

# 3. Run on three different inputs — different paths exercised
./output/ext2_coverage/test_coverage.cov "Hello World"
./output/ext2_coverage/test_coverage.cov "Hi"
./output/ext2_coverage/test_coverage.cov
```

> "20 basic blocks instrumented. Each input drives a different path through the bitmap. No AFL runtime."

---

## DEMO 5 — Extension 3: function tracing

> "Internal function calls visible in a stripped binary, env-var toggleable."

```bash
# 1. Compile test program
clang -O0 -fPIC -fPIE -pie src/test_trace.c -o output/ext3_trace/test_trace

# 2. RetroWrite with trace pass
python3 retrowrite/retrowrite -m trace output/ext3_trace/test_trace output/ext3_trace/test_trace.trace.s
gcc -no-pie output/ext3_trace/test_trace.trace.s -o output/ext3_trace/test_trace.trace

# 3. Run WITHOUT tracing — silent
./output/ext3_trace/test_trace.trace

# 4. Run WITH tracing — full call log on stderr
RETRO_TRACE_PRINT=1 ./output/ext3_trace/test_trace.trace
```

> "Same binary. One env var difference. 7 functions, 12 calls, in exact order."

---

## DEMO 6 — AFL fuzzing breaks the code (RetroWrite + ASan in the loop)

> "Coverage-guided fuzzer + ASan = real bug discovery. 9 crashes in 30 seconds."

```bash
# 1. Compile fuzz_target with AFL coverage AND ASan combined
AFL_USE_ASAN=1 afl-clang-fast -O0 src/fuzz_target.c -o output/afl_fuzzing/fuzz_target_afl_asan

# 2. Confirm seed corpus (just three trivial inputs)
ls output/afl_fuzzing/seeds/
cat output/afl_fuzzing/seeds/seed1.txt    # hello
cat output/afl_fuzzing/seeds/seed2.txt    # FUZZ
cat output/afl_fuzzing/seeds/seed3.txt    # CRASH

# 3. Fuzz for 30 seconds
rm -rf /tmp/fuzz_aflasan
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 AFL_SKIP_CPUFREQ=1 AFL_NO_UI=1 \
AFL_NO_AFFINITY=1 AFL_IGNORE_PROBLEMS=1 \
    timeout 30 afl-fuzz -i output/afl_fuzzing/seeds -o /tmp/fuzz_aflasan \
    -- output/afl_fuzzing/fuzz_target_afl_asan

# 4. Show what AFL found
ls /tmp/fuzz_aflasan/default/crashes/ | grep -v README
cat /tmp/fuzz_aflasan/default/fuzzer_stats | grep -E "execs_per_sec|saved_crashes|edges_found"

# 5. Replay one crash to see the ASan report
cat /tmp/fuzz_aflasan/default/crashes/id:000001* | ./output/afl_fuzzing/fuzz_target_afl_asan

# 6. Show the input that crashed it
xxd /tmp/fuzz_aflasan/default/crashes/id:000001* | head -2
```

> "Three seeds in. Nine crashes out. Stack overflow, null deref, heap corruption — all caught because ASan converts silent memory corruption into a SIGABRT/SIGSEGV, which AFL records as a crash."

**Expected output:** ~9 crashes saved (`sig:06` = SIGABRT from ASan, `sig:11` = SIGSEGV from null deref). Throughput ~600 exec/sec (lower than plain AFL because ASan also runs).

---

## QUICK REFERENCE — short version (under 1 minute)

If pre-built binaries already exist, skip the rewrite/recompile steps and just run:

```bash
# ── DEMO 1: Core ASan ──
./output/asan_demo/heap 1
./output/asan_demo/heap.asan 1

# ── DEMO 2: QEMU vs Valgrind vs RetroWrite ──
./output/asan_demo/heap 1
valgrind -q ./output/asan_demo/heap 1
qemu-x86_64 ./output/asan_demo/heap 1
./output/asan_demo/heap.asan 1
time valgrind -q ./output/asan_demo/heap 1 >/dev/null
time ./output/asan_demo/heap.asan 1 >/dev/null

# ── DEMO 3: Ext 1 (rep movs/stos) ──
./output/ext1_rep_movs/test_rep_movs movs
./output/ext1_rep_movs/test_rep_movs.asan movs
./output/ext1_rep_movs/test_rep_movs.asan stos

# ── DEMO 4: Ext 2 (coverage) ──
./output/ext2_coverage/test_coverage.cov "Hello World"
./output/ext2_coverage/test_coverage.cov "Hi"

# ── DEMO 5: Ext 3 (tracing) ──
./output/ext3_trace/test_trace.trace
RETRO_TRACE_PRINT=1 ./output/ext3_trace/test_trace.trace

# ── DEMO 6: AFL fuzzing (breaks the code) ──
rm -rf /tmp/fuzz_aflasan
AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 AFL_SKIP_CPUFREQ=1 AFL_NO_UI=1 \
AFL_NO_AFFINITY=1 AFL_IGNORE_PROBLEMS=1 \
    timeout 30 afl-fuzz -i output/afl_fuzzing/seeds -o /tmp/fuzz_aflasan \
    -- output/afl_fuzzing/fuzz_target_afl_asan
ls /tmp/fuzz_aflasan/default/crashes/ | grep -v README
cat /tmp/fuzz_aflasan/default/crashes/id:000001* | ./output/afl_fuzzing/fuzz_target_afl_asan
```

---

## Watch-out moments

- **`unknown-crash` / `wild pointer`** in ASan output — expected at the binary level (no malloc-site metadata). Detection is correct.
- **`SEGV` / `DEADLYSIGNAL`** in Ext 1 memset case — *intentional*, ASan aborting after redzone violation walks into unmapped memory.
- **Rewriter chatter** like `Couldn't find valid section 3dd8` — harmless, unloaded relocations.

---

## Toggle flags (for showing "without the extension" behaviour)

```bash
DISABLE_REP_FIX=1 ./output/ext1_rep_movs/test_rep_movs.asan movs   # show stock RetroWrite blindness
DISABLE_COVERAGE=1 ./output/ext2_coverage/test_coverage.cov         # disable coverage at runtime
# Trace is OFF by default; enable with RETRO_TRACE_PRINT=1
```
