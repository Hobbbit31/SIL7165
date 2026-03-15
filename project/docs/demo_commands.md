# RetroWrite Demo Commands

Run all commands from the project root: `cd ~/Desktop/NSS/project`

---

## What Are the Numbers 1, 2, 3, 4 We Pass to the Binary?

When we run `./output/asan_test/asan_test 1`, the `1` is a **command-line argument** (`argv[1]`).

The program's `main()` function uses a `switch` statement to decide which bug to trigger:

```c
// src/asan_test.c — main() at line 52
int main(int argc, char *argv[]) {
    if (argc != 2) usage(argv[0]);    // must pass exactly 1 argument
    switch (atoi(argv[1])) {          // convert argument "1"/"2"/"3"/"4" to integer
        case 1: heap_overflow();      // argument 1 → calls heap_overflow()
        case 2: use_after_free();     // argument 2 → calls use_after_free()
        case 3: stack_overflow();     // argument 3 → calls stack_overflow()
        case 4: double_free();        // argument 4 → calls double_free()
    }
}
```

So:
- `./asan_test 1` → runs `heap_overflow()` — triggers heap buffer overflow bug
- `./asan_test 2` → runs `use_after_free()` — triggers use-after-free bug
- `./asan_test 3` → runs `stack_overflow()` — triggers stack buffer overflow bug
- `./asan_test 4` → runs `double_free()` — triggers double free bug

Similarly for `heap.c` (the RetroWrite demo):
- `./heap 1` → runs `oob()` — triggers out-of-bounds heap write
- `./heap 2` → runs `uaf()` — triggers use-after-free

For `fuzz_target.c`, there are no arguments — it reads from **stdin** instead. AFL feeds it random inputs automatically.

---

## File Locations

```
~/Desktop/NSS/project/
│
├── src/                                    ← OUR source code
│   ├── asan_test.c                         ← Custom test program with 4 bugs (Tests 1-4)
│   │                                         Location: ~/Desktop/NSS/project/src/asan_test.c
│   └── fuzz_target.c                       ← AFL fuzzing target with 3 bugs
│                                             Location: ~/Desktop/NSS/project/src/fuzz_target.c
│
├── retrowrite/demos/user_demo/             ← Original RetroWrite demo code (NOT ours)
│   ├── heap.c                              ← Heap bugs demo (OOB + UAF)
│   │                                         Location: ~/Desktop/NSS/project/retrowrite/demos/user_demo/heap.c
│   └── stack.c                             ← Stack bugs demo
│                                             Location: ~/Desktop/NSS/project/retrowrite/demos/user_demo/stack.c
│
├── output/                                 ← ALL compiled binaries go here
│   ├── asan_test/                          ← Binaries built from src/asan_test.c
│   │   ├── asan_test                       ← No protection (clang -pie)
│   │   ├── asan_test.asan                  ← Binary ASan via RetroWrite (paper's method)
│   │   ├── asan_test.asan.s                ← Instrumented assembly (intermediate file)
│   │   └── asan_test.source_asan           ← Source ASan (clang -fsanitize=address)
│   │
│   ├── asan_demo/                          ← Binaries built from retrowrite/demos/user_demo/heap.c
│   │   ├── heap                            ← No protection
│   │   ├── heap.asan                       ← Binary ASan via RetroWrite
│   │   └── heap.asan.s                     ← Instrumented assembly
│   │
│   ├── bzip2_rewrite/                      ← Binaries built from retrowrite/targets/bzip2-1.0.8/
│   │   ├── bzip2_original                  ← Original bzip2 compiled as PIE
│   │   ├── bzip2_rewritten                 ← Disassembled + reassembled by RetroWrite
│   │   ├── bzip2_rewritten.s               ← RetroWrite-generated assembly
│   │   └── bzip2_asan.s                    ← bzip2 with ASan instrumentation
│   │
│   └── afl_fuzzing/                        ← Binaries built from src/fuzz_target.c
│       ├── fuzz_target                     ← No protection
│       ├── fuzz_target_retrowrite_afl      ← AFL instrumented via RetroWrite
│       ├── fuzz_target_source_afl          ← AFL instrumented from source (baseline)
│       ├── fuzz_target.s                   ← RetroWrite-generated assembly
│       └── seeds/                          ← Input seeds for AFL fuzzer
│
├── scripts/                                ← Automation scripts
│   ├── 01_setup.sh                         ← Install dependencies
│   ├── 02_asan_demo.sh                     ← Builds heap → heap.asan
│   ├── 03_rewrite_bzip2.sh                 ← Builds bzip2_original → bzip2_rewritten
│   ├── 04_afl_fuzzing.sh                   ← Builds fuzz_target → fuzz_target_retrowrite_afl
│   ├── run_all.sh                          ← Runs all above in order
│   └── demo_for_ta.sh                      ← Interactive step-by-step demo
│
├── docs/                                   ← Documentation
│   ├── demo_commands.md                    ← THIS FILE — all demo commands explained
│   ├── how_it_works.md                     ← Technical explanation of RetroWrite
│   └── extensions.md                       ← 5 possible extensions to implement
│
└── retrowrite/                             ← Original RetroWrite repo (git clone, UNTOUCHED)
    ├── retrowrite                          ← Main CLI entry point
    ├── librw_x64/                          ← Core rewriting library
    │   ├── loader.py                       ← Step 1: Loads ELF binary
    │   ├── disasm.py                       ← Step 2: Disassembles machine code
    │   └── rw.py                           ← Step 3: Symbolization engine (key innovation)
    └── rwtools_x64/asan/
        ├── instrument.py                   ← Step 4: Inserts ASan shadow memory checks
        └── snippets.py                     ← Assembly templates for ASan checks
```

---

## Source Files and Where the Bugs Are

### File 1: `src/asan_test.c` (our custom test program)

**Full path**: `~/Desktop/NSS/project/src/asan_test.c`

Used by: Tests 1-4 (all 3 versions: no protection, binary ASan, source ASan)

Binaries built from this file:
- `output/asan_test/asan_test` — no protection
- `output/asan_test/asan_test.asan` — binary ASan (RetroWrite)
- `output/asan_test/asan_test.source_asan` — source ASan

```c
// Test 1 — Heap buffer overflow (line 11)
void heap_overflow() {                        // called when you pass argument "1"
    char *buf = (char *)malloc(32);           // allocates 32 bytes on heap
    memset(buf, 'A', 32);
    buf[40] = 'X';                            // BUG: writes at index 40, 8 bytes past the end
    free(buf);
}

// Test 2 — Use-after-free (line 23)
void use_after_free() {                       // called when you pass argument "2"
    char *buf = (char *)malloc(64);
    memset(buf, 'B', 64);
    free(buf);                                // memory freed here
    printf("...: %c\n", buf[0]);              // BUG: reads buf[0] after free
}

// Test 3 — Stack buffer overflow (line 31)
void stack_overflow() {                       // called when you pass argument "3"
    char buf[16];                             // 16 bytes on stack
    memset(buf, 'C', 48);                     // BUG: writes 48 bytes into 16-byte buffer
}

// Test 4 — Double free (lines 39-40)
void double_free() {                          // called when you pass argument "4"
    char *buf = (char *)malloc(32);
    free(buf);                                // first free
    free(buf);                                // BUG: second free on same pointer
}
```

### File 2: `retrowrite/demos/user_demo/heap.c` (original RetroWrite demo)

**Full path**: `~/Desktop/NSS/project/retrowrite/demos/user_demo/heap.c`

Used by: ASan demo (`output/asan_demo/heap` and `output/asan_demo/heap.asan`)

Binaries built from this file:
- `output/asan_demo/heap` — no protection
- `output/asan_demo/heap.asan` — binary ASan (RetroWrite)

```c
// Out-of-bounds (line 9)
void oob() {                                 // called when you pass argument "1"
    char *buf = (char*)malloc(15);            // allocates 15 bytes
    buf[15] = 42;                             // BUG: writes 1 byte past the end
    free(buf);
}

// Use-after-free (lines 16-17)
void uaf() {                                 // called when you pass argument "2"
    char *buf = (char*)malloc(15);
    free(buf);                                // freed here
    buf[7] = 42;                              // BUG: writes to freed memory
}
```

### File 3: `src/fuzz_target.c` (AFL fuzzing target)

**Full path**: `~/Desktop/NSS/project/src/fuzz_target.c`

Used by: AFL fuzzing demo (`output/afl_fuzzing/`)

Binaries built from this file:
- `output/afl_fuzzing/fuzz_target` — no protection
- `output/afl_fuzzing/fuzz_target_retrowrite_afl` — AFL via RetroWrite
- `output/afl_fuzzing/fuzz_target_source_afl` — AFL from source

**No argument needed** — this program reads input from **stdin** (AFL pipes random data into it).

```c
void process_input(char *buf, int len) {
    char local[32];

    // BUG 1 — Heap overflow (line 15): triggered when input starts with "FUZZ"
    if (buf matches "FUZZ") {
        char *heap = (char *)malloc(8);
        memcpy(heap, buf, len);               // BUG: copies len bytes into 8-byte buffer
    }

    // BUG 2 — Null pointer deref (line 28): triggered when input starts with "CRASH"
    if (buf matches "CRASH") {
        char *p = NULL;
        *p = buf[5];                          // BUG: writes to NULL
    }

    // BUG 3 — Stack overflow (line 32): triggered when input > 32 bytes
    if (len > 2) {
        memcpy(local, buf, len);              // BUG: copies len bytes into 32-byte stack buffer
    }
}
```

---

## Which Binary Comes From Which Source File

| Binary | Source File | How It Was Built |
|--------|-----------|------------------|
| `output/asan_test/asan_test` | `src/asan_test.c` | `clang -O0 -fPIC -fPIE -pie` — normal PIE binary, no protection |
| `output/asan_test/asan_test.asan` | `src/asan_test.c` | Binary above → RetroWrite `--asan` → assembly → `clang -lasan` |
| `output/asan_test/asan_test.source_asan` | `src/asan_test.c` | `clang -fsanitize=address` — compiled from source with ASan |
| `output/asan_demo/heap` | `retrowrite/demos/user_demo/heap.c` | `clang -O0 -fPIC -fPIE -pie` — normal PIE binary |
| `output/asan_demo/heap.asan` | `retrowrite/demos/user_demo/heap.c` | Binary above → RetroWrite `--asan` → assembly → `clang -lasan` |
| `output/bzip2_rewrite/bzip2_original` | `retrowrite/targets/bzip2-1.0.8/` | Compiled as PIE from bzip2 source |
| `output/bzip2_rewrite/bzip2_rewritten` | `retrowrite/targets/bzip2-1.0.8/` | Binary above → RetroWrite → reassembled (no instrumentation) |
| `output/afl_fuzzing/fuzz_target` | `src/fuzz_target.c` | `clang -O0 -fPIC -fPIE -pie` — normal PIE binary |
| `output/afl_fuzzing/fuzz_target_retrowrite_afl` | `src/fuzz_target.c` | Binary above → RetroWrite AFL → `afl-clang-fast` |
| `output/afl_fuzzing/fuzz_target_source_afl` | `src/fuzz_target.c` | `afl-clang-fast` from source (baseline) |

---

## 3-Way Comparison Tests (src/asan_test.c)

We compare **3 versions** of the same vulnerable program:

| Version | Binary Path | What It Shows |
|---------|-------------|---------------|
| **No protection** | `output/asan_test/asan_test` | Normal binary, bugs go undetected |
| **Binary ASan (RetroWrite)** | `output/asan_test/asan_test.asan` | ASan added to the **compiled binary** without source code (paper's contribution) |
| **Source ASan** | `output/asan_test/asan_test.source_asan` | ASan compiled from source, best detection but **requires source code** |

---

## How to Build Everything (if binaries are missing)

If the `output/` directory is empty, rebuild everything:

```bash
# Step 1: Run the main pipeline (builds heap.c demo, bzip2 rewrite, AFL fuzzing)
./scripts/run_all.sh

# Step 2: Build the asan_test binaries (our custom 3-way comparison)
mkdir -p output/asan_test

# 2a: Compile asan_test.c as a normal PIE binary (no protection)
#     This produces a regular binary — bugs will be silent
clang -O0 -fPIC -fPIE -pie src/asan_test.c -o output/asan_test/asan_test

# 2b: Use RetroWrite to add ASan to the BINARY (no source needed for this step)
#     retrowrite reads the binary, disassembles it, inserts shadow memory checks,
#     and outputs instrumented assembly. Then we compile that assembly with libasan.
source retrowrite/retro/bin/activate
python3 retrowrite/retrowrite --asan output/asan_test/asan_test output/asan_test/asan_test.asan.s
sed -i 's/asan_init_v4/asan_init/g' output/asan_test/asan_test.asan.s
clang output/asan_test/asan_test.asan.s -lasan -o output/asan_test/asan_test.asan

# 2c: Compile asan_test.c with source-level ASan (baseline for comparison)
#     This uses the compiler's built-in ASan — best possible detection but needs source code
clang -O0 -fsanitize=address src/asan_test.c -o output/asan_test/asan_test.source_asan
```

---

## Test 1 — Heap Buffer Overflow

**Bug location**: `src/asan_test.c` line 11 — `buf[40] = 'X'` writes 8 bytes past a 32-byte malloc buffer.

**No protection** — runs `asan_test.c → heap_overflow()`. The write goes past the buffer but nothing checks it. Program prints "exited normally":
```bash
./output/asan_test/asan_test 1
```
- **What runs**: the normal PIE binary compiled from `src/asan_test.c`
- **Expected output**: `[*] Test: Heap buffer overflow` → `[+] Program exited normally (bug went undetected!)`

**Binary ASan (RetroWrite)** — runs the same program but RetroWrite injected shadow memory checks before every memory access. When `buf[40]` is accessed, the check finds the shadow byte is poisoned (redzone) and calls `__asan_report`, aborting the program:
```bash
./output/asan_test/asan_test.asan 1
```
- **What runs**: the RetroWrite-instrumented binary (ASan added to compiled binary, no source needed)
- **Expected output**: `ERROR: AddressSanitizer: unknown-crash` → program aborts
- **Why "unknown-crash"**: binary ASan lacks type info to classify it as "heap-buffer-overflow"

**Source ASan** — the compiler knows the malloc size and can precisely identify the overflow:
```bash
./output/asan_test/asan_test.source_asan 1
```
- **What runs**: binary compiled from source with `-fsanitize=address`
- **Expected output**: `ERROR: AddressSanitizer: heap-buffer-overflow` with exact allocation details

---

## Test 2 — Use-After-Free

**Bug location**: `src/asan_test.c` line 23 — reads `buf[0]` after `free(buf)`.

**No protection** — `free()` marks memory as available but doesn't erase it. The read returns stale garbage data. Program continues as if nothing happened:
```bash
./output/asan_test/asan_test 2
```
- **What runs**: normal PIE binary
- **Expected output**: `Reading freed memory: <garbage char>` → `exited normally`

**Binary ASan (RetroWrite)** — after `free()`, ASan poisons the freed region's shadow bytes. When `buf[0]` is read, the shadow check finds poisoned memory and aborts:
```bash
./output/asan_test/asan_test.asan 2
```
- **What runs**: RetroWrite-instrumented binary
- **Expected output**: `ERROR: AddressSanitizer: unknown-crash` → aborts

**Source ASan** — knows the exact allocation/free call sites, gives full backtrace:
```bash
./output/asan_test/asan_test.source_asan 2
```
- **What runs**: source-compiled ASan binary
- **Expected output**: `ERROR: AddressSanitizer: heap-use-after-free` with malloc/free backtrace

---

## Test 3 — Stack Buffer Overflow

**Bug location**: `src/asan_test.c` line 31 — `memset(buf, 'C', 48)` writes 48 bytes into a 16-byte stack buffer.

**No protection** — overwrites the return address and other stack data. Crashes with a raw segfault, no useful info:
```bash
./output/asan_test/asan_test 3
```
- **What runs**: normal PIE binary
- **Expected output**: `Segmentation fault (core dumped)` — no details about what went wrong

**Binary ASan (RetroWrite)** — RetroWrite adds redzones around stack frames. The overflow writes into the redzone, shadow check catches it:
```bash
./output/asan_test/asan_test.asan 3
```
- **What runs**: RetroWrite-instrumented binary
- **Expected output**: ASan error report → aborts (note: paper says stack ASan works at frame granularity, may not catch all intra-frame overflows)

**Source ASan** — compiler knows exact variable layout on the stack, catches it precisely:
```bash
./output/asan_test/asan_test.source_asan 3
```
- **What runs**: source-compiled ASan binary
- **Expected output**: `ERROR: AddressSanitizer: stack-buffer-overflow` with variable name `buf`

---

## Test 4 — Double Free

**Bug location**: `src/asan_test.c` lines 39-40 — `free(buf)` called twice on the same pointer.

**No protection** — glibc's allocator has its own basic double-free detection via tcache:
```bash
./output/asan_test/asan_test 4
```
- **What runs**: normal PIE binary
- **Expected output**: `free(): double free detected in tcache 2` → `Aborted`

**Binary ASan (RetroWrite)** — ASan replaces malloc/free with its own allocator that tracks all allocations:
```bash
./output/asan_test/asan_test.asan 4
```
- **What runs**: RetroWrite-instrumented binary (linked with `-lasan` which intercepts malloc/free)
- **Expected output**: ASan double-free error → aborts

**Source ASan** — same ASan allocator, but with precise source-level backtrace:
```bash
./output/asan_test/asan_test.source_asan 4
```
- **What runs**: source-compiled ASan binary
- **Expected output**: `ERROR: AddressSanitizer: attempting double-free` with both free() call sites

---

## Other Demo Commands

### Show the vulnerable source code
This is the C file that all 3 binaries (no protection, binary ASan, source ASan) are built from:
```bash
cat src/asan_test.c
```

### Show ASan-instrumented assembly (shadow memory checks)
RetroWrite converts the binary into assembly and inserts checks like this before every memory access:
1. Compute shadow address: `addr >> 3 + 0x7fff8000`
2. Check if shadow byte is 0 (accessible) or non-zero (poisoned)
3. If poisoned, call `__asan_report` to abort
```bash
grep -B2 -A8 "asan_report" output/asan_test/asan_test.asan.s | head -25
```

### bzip2 rewrite correctness test
Pipes text through the **rewritten** bzip2 binary (compress then decompress). If the output matches the input, RetroWrite's rewriting preserved correctness:
```bash
echo "hello retrowrite" | ./output/bzip2_rewrite/bzip2_rewritten -z | ./output/bzip2_rewrite/bzip2_rewritten -d
```
- `-z` = compress, `-d` = decompress
- `bzip2_rewritten` was built by: bzip2 source → compile as PIE → RetroWrite disassemble → reassemble (no instrumentation, just rewrite)

### Show original RetroWrite demo (heap.c)
This is the demo program from the RetroWrite repo — simpler bugs (1-byte overflow, use-after-free):
```bash
cat retrowrite/demos/user_demo/heap.c       # show the source code
./output/asan_demo/heap 1                    # run original binary — bug silent
./output/asan_demo/heap.asan 1               # run RetroWrite ASan binary — bug caught
```

### Show the AFL fuzzing target
This program has bugs triggered by specific input patterns ("FUZZ", "CRASH"). AFL generates random inputs to find these patterns:
```bash
cat src/fuzz_target.c                        # show the source code with hidden bugs
```

---

## How RetroWrite Pipeline Works (what happens behind the scenes)

When you run `python3 retrowrite/retrowrite --asan binary output.s`, this happens:

```
Step 1: LOAD        Read the ELF binary, parse sections (.text, .data, .rodata)
                    Extract relocations and symbol table
                    Source: retrowrite/librw_x64/loader.py

Step 2: DISASSEMBLE Convert machine code bytes into assembly instructions
                    Uses Capstone disassembler for x86-64
                    Source: retrowrite/librw_x64/disasm.py

Step 3: SYMBOLIZE   Replace hardcoded addresses with assembler labels
                    Uses relocations to distinguish addresses from constants
                    This is the KEY INNOVATION — no guessing, sound by construction
                    Source: retrowrite/librw_x64/rw.py

Step 4: INSTRUMENT  Insert ASan shadow memory checks before every memory access
                    Performs register liveness analysis to minimize overhead
                    Source: retrowrite/rwtools_x64/asan/instrument.py

Step 5: OUTPUT      Write instrumented assembly to .s file
                    This file can be compiled with clang/gcc like normal assembly
```

Then `clang output.s -lasan -o binary.asan` compiles the assembly and links it with the ASan runtime library (`libasan`), which provides `__asan_report_*` functions and replaces malloc/free.

---

## Expected Results Summary

| Test | No ASan | Binary ASan (RetroWrite) | Source ASan |
|------|---------|--------------------------|------------|
| Heap overflow | Silent, exits normally | **CAUGHT** (`unknown-crash`) | **CAUGHT** (`heap-buffer-overflow`) |
| Use-after-free | Silent, reads garbage | **CAUGHT** (`unknown-crash`) | **CAUGHT** (`heap-use-after-free`) |
| Stack overflow | Segfault (no details) | **CAUGHT** | **CAUGHT** (`stack-buffer-overflow`) |
| Double free | glibc abort (basic) | **CAUGHT** | **CAUGHT** (`attempting double-free`) |

**Key takeaway**: RetroWrite's binary ASan catches all the same bugs as source ASan, but with less precise error classification. This is the expected tradeoff — binary-only tools lack type information that the compiler has. The paper explicitly discusses this in Section IV and Table I.
