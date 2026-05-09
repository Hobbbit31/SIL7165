# Demo Commands — With vs Without Extensions

---

> **Before running any command below, run the setup script first:**
> ```bash
> cd ~/Desktop/NSS/project
> source retrowrite/retro/bin/activate
> bash scripts/01_setup.sh   # setup
> bash scripts/02_asan_demo.sh   # builds heap + heap.asan
> bash scripts/04_afl_fuzzing.sh # builds AFL binaries
> bash scripts/06_ext1_rep_movs_demo.sh # builds ext1 binaries
> bash scripts/07_ext2_coverage_demo.sh # builds ext2 binaries
> bash scripts/08_ext3_trace_demo.sh    # builds ext3 binaries
> ```

---

## 1. Heap Overflow (direct write)
> Built by: `bash scripts/02_asan_demo.sh`

```bash
# original binary — no ASan, bug silently ignored
~/Desktop/NSS/project/output/asan_demo/heap 1
```
```bash
# retrowrite ASan binary — catches the overflow immediately
~/Desktop/NSS/project/output/asan_demo/heap.asan 1 2>&1 | head -10
```

---

## 2. Use-After-Free
> Built by: `bash scripts/02_asan_demo.sh`

```bash
# original binary — accesses freed memory, no error
~/Desktop/NSS/project/output/asan_demo/heap 2
```
```bash
# retrowrite ASan binary — catches the freed memory access
~/Desktop/NSS/project/output/asan_demo/heap.asan 2 2>&1 | head -10
```

---

## 3. memcpy overflow — Extension 1
> Built by: `bash scripts/06_ext1_rep_movs_demo.sh`

```bash
# compile the test binary that does memcpy overflow via rep movsb
clang -O0 -fPIC -fPIE -pie ~/Desktop/NSS/project/src/test_rep_movs.c -o /tmp/test_rep_movs
```

```bash
# WITHOUT ext1 — rep movsb not instrumented, overflow missed
cd ~/Desktop/NSS/project/retrowrite
DISABLE_REP_FIX=1 python3 retrowrite --asan /tmp/test_rep_movs /tmp/noext.s
sed -i 's/asan_init_v4/asan_init/g' /tmp/noext.s
clang /tmp/noext.s -lasan -o /tmp/test_noext
/tmp/test_noext 2>&1
```

```bash
# WITH ext1 — 4 boundary checks injected before rep movsb, overflow caught
python3 retrowrite --asan /tmp/test_rep_movs /tmp/ext.s
sed -i 's/asan_init_v4/asan_init/g' /tmp/ext.s
clang /tmp/ext.s -lasan -o /tmp/test_ext
/tmp/test_ext 2>&1 | head -10
```

---

## 4. Standalone Coverage — Extension 2
> Built by: `bash scripts/07_ext2_coverage_demo.sh`

```bash
# compile the test binary
clang -O0 -fPIC -fPIE -pie ~/Desktop/NSS/project/src/test_coverage.c -o /tmp/test_cov
```

```bash
# WITHOUT ext2 — plain binary, no idea which paths executed
/tmp/test_cov
```

```bash
# WITH ext2 — coverage pass injected, AFL-style edge bitmap fills on every run
cd ~/Desktop/NSS/project/retrowrite
python3 retrowrite -m coverage /tmp/test_cov /tmp/test_cov.s
gcc /tmp/test_cov.s -o /tmp/test_cov_instrumented
/tmp/test_cov_instrumented && echo "ran with coverage tracking — no AFL needed"
```

---

## 5. Function Call Tracing — Extension 3
> Built by: `bash scripts/08_ext3_trace_demo.sh`

```bash
# compile the test binary
clang -O0 -fPIC -fPIE -pie ~/Desktop/NSS/project/src/test_trace.c -o /tmp/test_trace
```

```bash
# WITHOUT ext3 — runs silently, zero visibility into internal calls
/tmp/test_trace
```

```bash
# WITH ext3 — every internal function call logged in order
cd ~/Desktop/NSS/project/retrowrite
python3 retrowrite -m trace /tmp/test_trace /tmp/test_trace.s
gcc /tmp/test_trace.s -o /tmp/test_trace_instrumented
RETRO_TRACE_PRINT=1 /tmp/test_trace_instrumented 2>&1
```

---

## AFL Fuzzing — Speed Comparison
> Built by: `bash scripts/04_afl_fuzzing.sh`

```bash
# Terminal 1 — RetroWrite AFL (binary-only instrumentation)
source ~/Desktop/NSS/project/retrowrite/retro/bin/activate
mkdir -p /tmp/afl_out_retro
afl-fuzz -i ~/Desktop/NSS/project/output/afl_fuzzing/seeds \
         -o /tmp/afl_out_retro \
         -- ~/Desktop/NSS/project/output/afl_fuzzing/fuzz_target_retrowrite_afl
```

```bash
# Terminal 2 — Source AFL (compiled with AFL instrumentation, has source)
mkdir -p /tmp/afl_out_source
afl-fuzz -i ~/Desktop/NSS/project/output/afl_fuzzing/seeds \
         -o /tmp/afl_out_source \
         -- ~/Desktop/NSS/project/output/afl_fuzzing/fuzz_target_source_afl
```

```bash
# after stopping — check crashes found by RetroWrite AFL
ls /tmp/afl_out_retro/crashes/

# replay a crash
cat /tmp/afl_out_retro/crashes/id:000000* | \
    ~/Desktop/NSS/project/output/afl_fuzzing/fuzz_target_retrowrite_afl
```
