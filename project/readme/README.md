# RetroWrite: Adding Security Checks to Programs WITHOUT Source Code

**Course:** SIL765 - Networks & System Security (Semester 2, 2025-26)

**Paper:** Dinesh et al., *"RetroWrite: Statically Instrumenting COTS Binaries for Fuzzing and Sanitization"*, IEEE S&P 2020 | 300+ citations | [GitHub](https://github.com/HexHive/retrowrite)

---

## What Does This Project Do?

Most software you use is **closed-source** -- you only get the compiled program, not the code that made it.

**Problem:** These programs have hidden memory bugs. To find them, we need tools like ASan (bug detector) and AFL (fuzzer), but they normally need the source code.

**Old solution:** Run the program through a slow translator (QEMU) -- **10x-100x slower**. Too slow.

**RetroWrite's solution:** Convert the binary back into editable assembly, add security checks, reassemble. Runs at **near-native speed**.

```
Binary (program) --> RetroWrite --> Assembly (editable) --> Add ASan/AFL --> New Safe Binary
```

---

## Project Structure

```
project/
|
|-- README.md                  <-- You are here
|
|-- src/                       <-- OUR code (what we wrote)
|   |-- fuzz_target.c              Custom program with hidden bugs for fuzzing
|
|-- scripts/                   <-- OUR scripts (run these to reproduce everything)
|   |-- 01_setup.sh                Install dependencies (run ONCE)
|   |-- 02_asan_demo.sh            ASan demo: find memory bugs in binaries
|   |-- 04_afl_fuzzing.sh          AFL fuzzing: RetroWrite vs source AFL comparison
|   |-- 06_ext1_rep_movs_demo.sh   Extension 1: rep movsb ASan fix
|   |-- 07_ext2_coverage_demo.sh   Extension 2: x86-64 coverage pass
|   |-- 08_ext3_trace_demo.sh      Extension 3: native function tracing
|   |-- run_all.sh                 Run all steps in order
|   |-- demo_for_ta.sh             Interactive demo for TA presentation
|
|-- output/                    <-- Generated files (created by scripts)
|   |-- asan_demo/                  Compiled binaries from ASan demo
|   |-- afl_fuzzing/                AFL-instrumented binaries
|
|-- docs/                      <-- Documentation
|   |-- how_it_works.md             Simple explanation of RetroWrite
|   |-- extensions.md               5 possible extensions to implement
|
|-- retrowrite/                <-- GIT CLONE (untouched, do NOT modify)
|   |-- retrowrite                  Main tool (the entry point)
|   |-- librw_x64/                  Core rewriting library (Python)
|   |   |-- loader.py               Loads the binary (ELF format)
|   |   |-- disasm.py               Disassembles machine code
|   |   |-- rw.py                   Symbolization engine (the key innovation)
|   |   |-- container.py            Data structures (Function, Instruction)
|   |-- rwtools_x64/                Instrumentation passes
|   |   |-- asan/                   ASan (memory bug detection)
|   |   |-- jumparound/             Instruction reordering
|   |-- demos/user_demo/            Demo programs (heap.c, stack.c)
|   |-- retro/                      Python virtual environment (created by setup)
|
|-- RetroWrite_...paper.pdf    <-- The original research paper
|-- sil765_...guideline.pdf    <-- Course project guidelines
```

**Rule: `retrowrite/` is the original git clone. We did NOT modify any of its code. All our work is in `src/`, `scripts/`, `docs/`, and `output/`.**

---

## How to Run (Step by Step)

### Prerequisites

```bash
sudo apt install python3 python3-venv gcc clang afl++ libasan8
```

### Option 1: Run Everything at Once

```bash
./scripts/run_all.sh
```

### Option 2: Run Step by Step

```bash
# Step 1: Install dependencies (only need to do this once)
./scripts/01_setup.sh

# Step 2: ASan demo -- find memory bugs in a binary
./scripts/02_asan_demo.sh

# Step 3: AFL fuzzing -- find bugs with random inputs
./scripts/04_afl_fuzzing.sh
```

### Option 3: Interactive Demo (for TA)

```bash
./scripts/demo_for_ta.sh
```

---

## What We Did (and What We Found)

### 1. ASan: Found Memory Bugs Without Source Code

We compiled a vulnerable program (heap.c from the RetroWrite repo) as a normal binary, then used RetroWrite to add ASan checks to the **binary only**.

| Bug Type           | Original Binary  | After RetroWrite ASan |
|--------------------|------------------|-----------------------|
| Heap out-of-bounds | Silent (no crash)| **CAUGHT!**           |
| Use-after-free     | Silent (no crash)| **CAUGHT!**           |

```
$ ./output/asan_demo/heap 1           <-- original: bug goes unnoticed
LOG: Incoming out of bounds access

$ ./output/asan_demo/heap.asan 1      <-- ASan version: bug CAUGHT
==ERROR: AddressSanitizer: heap-buffer-overflow
WRITE of size 1 at 0x602000000020
```

### 2. AFL Fuzzing at Near-Source Speed

| Method                          | Speed (exec/sec) |
|---------------------------------|-------------------|
| Source AFL (best possible)      | 4790              |
| **RetroWrite AFL (binary only)**| **4244 (88.6%)**  |
| QEMU AFL (old way)              | ~800 (slow!)      |

RetroWrite gets **near source-level speed** without needing source code. The paper claims 4.2x-5.6x faster than QEMU-based fuzzing.

### 3. Extension 1: rep movsb ASan Fix

RetroWrite's original ASan pass had a blind spot for `rep movsb`, the x86-64 repeated-string copy instruction used by memcpy-style code. Our Extension 1 adds the missing boundary checks around that instruction.

| Case | Result |
|------|--------|
| Original binary | Silent overflow |
| RetroWrite ASan with fix off | Uncontrolled crash |
| RetroWrite ASan with fix on | ASan-visible detection |

This makes inline `rep movsb` copies visible to ASan in rewritten binaries.

### 4. Extension 2: x86-64 Coverage

We added a standalone coverage pass for x86-64 that records basic-block execution in a bitmap. This makes it possible to gather AFL-style coverage feedback from the rewritten binary itself.

### 5. Extension 3: Native Function Tracing

We also added a function-entry tracer that logs native call flow from rewritten binaries. This is useful for debugging and for understanding execution order in stripped binaries.

---

## How RetroWrite Works (The Big Idea)

```
Step 1: LOAD         Read the binary file, its sections, and relocation table
Step 2: DISASSEMBLE  Convert machine code into assembly instructions
Step 3: SYMBOLIZE    Replace hardcoded addresses with labels (using relocations)
Step 4: INSTRUMENT   Insert ASan checks / AFL coverage before memory accesses
Step 5: REASSEMBLE   Compile the modified assembly back into a working binary
```

**The key trick:** Modern binaries (PIE) have "relocation" info that tells RetroWrite exactly which values are addresses vs. plain numbers. No guessing needed.

For more details, see [docs/how_it_works.md](docs/how_it_works.md).

---

## Paper's Key Results (IEEE S&P 2020)

| Comparison                        | Result                              |
|-----------------------------------|-------------------------------------|
| ASan-retrowrite vs Valgrind       | **3x faster**, finds **80% more bugs** |
| ASan-retrowrite vs source ASan    | Only **0.65x slower**               |
| AFL-retrowrite vs AFL-QEMU        | **4.2x-5.6x faster**               |
| AFL-retrowrite vs source AFL      | Statistically **identical**         |

### Limitations

- Only x86-64 PIE binaries (non-PIE binaries are out of scope for the relocation-guided approach)
- No C++ exception handling
- Stack ASan: frame-level only (may miss some overflows)
- `rep movsb` now has an Extension 1 fix; other repeated-string forms remain a narrower edge case

---

## Possible Extensions

See [docs/extensions.md](docs/extensions.md) for 5 possible extensions:

1. **Fix rep prefix ASan** - implemented as Extension 1 for `rep movsb`
2. **Coverage pass for x64** - implemented as Extension 2
3. **Stack canary insertion** - possible follow-up
4. **Function call tracing** - implemented as Extension 3
5. **Forward-edge CFI** - possible follow-up

---

## References

1. Dinesh et al., "RetroWrite: Statically Instrumenting COTS Binaries for Fuzzing and Sanitization," IEEE S&P 2020
2. Serebryany et al., "AddressSanitizer: A Fast Address Sanity Checker," USENIX ATC 2012
3. Zalewski, "American Fuzzy Lop (AFL)," 2017
4. RetroWrite GitHub: https://github.com/HexHive/retrowrite
