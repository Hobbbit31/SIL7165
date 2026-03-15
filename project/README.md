# RetroWrite: Adding Security Checks to Programs WITHOUT Source Code

**Course:** SIL765 - Networks & System Security (Semester 2, 2025-26)

**Paper:** Dinesh et al., *"RetroWrite: Statically Instrumenting COTS Binaries for Fuzzing and Sanitization"*, IEEE S&P 2020 | 300+ citations | [GitHub](https://github.com/HexHive/retrowrite)

---

## What Does This Project Do?

Most software you use is **closed-source** -- you only get the compiled program, not the code that made it.

**Problem:** These programs have hidden memory bugs that hackers can exploit. To find them, we need tools like ASan (bug detector) and AFL (fuzzer), but they normally need the source code.

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
|   |-- 03_rewrite_bzip2.sh        Rewrite real-world bzip2 binary
|   |-- 04_afl_fuzzing.sh          AFL fuzzing: find bugs with random inputs
|   |-- run_all.sh                 Run all steps in order
|   |-- demo_for_ta.sh             Interactive demo for TA presentation
|
|-- output/                    <-- Generated files (created by scripts)
|   |-- asan_demo/                  Compiled binaries from ASan demo
|   |-- bzip2_rewrite/              Rewritten bzip2 binaries
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
|   |-- targets/                    Real-world targets (bzip2)
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

# Step 3: Rewrite real-world bzip2 binary
./scripts/03_rewrite_bzip2.sh

# Step 4: AFL fuzzing -- find bugs with random inputs
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

### 2. Rewrote Real-World Software (bzip2)

RetroWrite successfully disassembled and reassembled bzip2 (a real compression tool). The rewritten binary produces **identical output** to the original.

### 3. AFL Fuzzing at Near-Source Speed

| Method                          | Speed (exec/sec) |
|---------------------------------|-------------------|
| Source AFL (best possible)      | 4790              |
| **RetroWrite AFL (binary only)**| **4244 (88.6%)**  |
| QEMU AFL (old way)              | ~800 (slow!)      |

RetroWrite gets **88.6% of source-level speed** without needing source code. The paper claims 4.2x-5.6x faster than QEMU-based fuzzing.

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

- Only x86-64 PIE binaries (no stripped or non-PIE)
- No C++ exception handling
- Stack ASan: frame-level only (may miss some overflows)
- `rep movsb`/`rep stosb` (memcpy/memset) not fully instrumented

---

## Possible Extensions

See [docs/extensions.md](docs/extensions.md) for 5 possible extensions:

1. **Fix rep prefix ASan** (Medium) -- directly addresses a paper limitation
2. **Coverage pass for x64** (Easy) -- standalone AFL-style coverage
3. **Stack canary insertion** (Medium) -- add stack protection post-compilation
4. **Function call tracing** (Easy) -- debug binary-only software
5. **Forward-edge CFI** (Hard) -- prevent code-reuse attacks

---

## References

1. Dinesh et al., "RetroWrite: Statically Instrumenting COTS Binaries for Fuzzing and Sanitization," IEEE S&P 2020
2. Serebryany et al., "AddressSanitizer: A Fast Address Sanity Checker," USENIX ATC 2012
3. Zalewski, "American Fuzzy Lop (AFL)," 2017
4. RetroWrite GitHub: https://github.com/HexHive/retrowrite
