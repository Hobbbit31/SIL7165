# RetroWrite Extensions - End-Term Submission

**Project:** RetroWrite: Adding Security Checks to Programs WITHOUT Source Code
**Course:** SIL765 - Networks & System Security (Semester 2, 2025-26)
**Team:** Chirag Suthar (MCS2105) & Haleel Sada (MCS2741)

---

## Overview

We implemented **3 extensions** to the RetroWrite binary rewriting framework, each adding new instrumentation capabilities to the x86-64 pipeline. These extensions demonstrate that RetroWrite's architecture is modular and extensible --- new security passes can be plugged in without modifying the core rewriting engine.

| # | Extension | What It Does | Files Modified/Created |
|---|-----------|-------------|----------------------|
| 1 | **Rep Movs/Stos ASan Fix** | Catches memcpy/memset buffer overflows | Modified: `rwtools_x64/asan/instrument.py` |
| 2 | **Basic Block Coverage** | Tracks which code paths execute at runtime | Created: `rwtools_x64/coverage/instrument.py` |
| 3 | **Function Call Tracing** | Logs every function entry for debugging | Created: `rwtools_x64/trace/instrument.py` |

---

## Extension 1: Fix `rep movs`/`rep stos` ASan Instrumentation

### The Problem

The original RetroWrite paper (Dinesh et al., IEEE S&P 2020) explicitly acknowledges a limitation:

> *"rep movsb and rep stosb instructions are not instrumented by our ASan pass."*

These instructions are used by the compiler to implement `memcpy()` and `memset()`. This means if a program has a buffer overflow through `memcpy(dst, src, too_large_size)`, RetroWrite's ASan will **silently miss it** --- the overflow corrupts memory without any error report.

The original code had a literal TODO at `instrument.py:320`:
```python
# XXX: THIS IS A TODO for more accurate check.
if instruction.mnemonic.startswith("rep stos"):
    pass
```

### What We Did

We extended the ASan instrumentation to check memory boundaries for both `rep movs` (memcpy) and `rep stos` (memset):

**For `rep stosb` (memset):** Already had partial support checking `(%rdi)` (start). We ensure the existing code also checks `(%rdi, %rcx)` (end of region).

**For `rep movsb` (memcpy):** Added 4 boundary checks:
1. Destination start: `(%rdi)` --- is the destination buffer start valid?
2. Destination end: `(%rdi, %rcx)` --- does the copy overflow the destination?
3. Source start: `(%rsi)` --- is the source buffer start valid?
4. Source end: `(%rsi, %rcx)` --- does the copy read past the source?

### How It Works

```
Before Extension 1:
  memcpy(small_buf, big_data, big_size)
  → rep movsb executes
  → ASan has NO check → overflow goes UNDETECTED

After Extension 1:
  memcpy(small_buf, big_data, big_size)
  → ASan checks (%rdi), (%rdi+%rcx), (%rsi), (%rsi+%rcx)
  → Shadow memory violation detected → ERROR REPORTED
```

### What Happens Without This Extension

- Programs with `memcpy`/`memset` overflows will **not be caught** by RetroWrite's ASan
- This is a significant blind spot because `memcpy` is one of the most common sources of buffer overflows in C/C++ programs
- The CWE-120 (Buffer Copy without Checking Size) vulnerability class would go undetected
- An attacker could exploit memcpy-based overflows in a binary that the user *thinks* is protected by ASan

### What Happens If Extended Incorrectly

- **Wrong boundary calculation:** If `(%rdi, %rcx)` is computed incorrectly, ASan will report false positives (flagging valid memcpy operations as overflows) or false negatives (still missing real overflows)
- **Register clobbering:** If the instrumentation code doesn't properly save/restore registers, the program will crash or produce wrong results --- the `rep movs` instruction depends on `%rdi`, `%rsi`, and `%rcx` being intact
- **Missing one boundary:** If only destination is checked but not source, read-past-end-of-buffer bugs (information leaks) will still be missed

### How to Test

```bash
./scripts/06_ext1_rep_movs_demo.sh
```

This compiles `src/test_rep_movs.c` (which has memcpy and memset overflows), runs it with and without ASan, and shows the bugs being caught.

### Files Changed

- `retrowrite/rwtools_x64/asan/instrument.py` --- Added `rep movs` detection, boundary checks for both source and destination buffers

---

## Extension 2: Basic Block Coverage Pass for x86-64

### The Problem

RetroWrite's AFL integration requires the full AFL++ toolchain to be installed and configured. There is no standalone coverage tracking pass for x86-64 (the ARM64 version exists at `rwtools_arm64/coverage/instrument.py`, but x64 was missing).

Users who want to know "which code paths does this binary execute?" without setting up AFL have no option.

### What We Did

Created a new instrumentation module `rwtools_x64/coverage/instrument.py` that:

1. **Iterates all basic blocks** in the binary (using `fn.bbstarts`)
2. **Injects a counter increment** at each basic block entry
3. **Uses edge-hashing** (same as AFL): `bitmap[cur_id ^ prev_id]++` for path-sensitive coverage
4. **Allocates a coverage bitmap** (64KB) via `mmap` in an `.init_array` constructor
5. **Requires no external dependencies** --- the runtime is entirely self-contained in the instrumented binary

### How It Works

```
Original binary:               Instrumented binary:

  func_a:                        func_a:
    cmp %rax, %rbx                 [coverage: block 0x1234]
    je .label                      cmp %rax, %rbx
    mov %rcx, %rdx                 je .label
    ...                            [coverage: block 0x5678]
  .label:                          mov %rcx, %rdx
    ret                            ...
                                 .label:
                                   [coverage: block 0x9abc]
                                   ret
```

Each `[coverage: block N]` is an instrumented trampoline that:
```asm
pushq %rax              ; save registers
lahf / seto %al         ; save flags
pushq %rcx
; bitmap[cur ^ prev]++
xorq $BLOCK_ID, prev_loc
incb (area_ptr, prev_loc)
; prev = cur >> 1
movq $BLOCK_ID_SHIFTED, prev_loc
popq %rcx
; restore flags
popq %rax / sahf
popq %rax
```

### What Happens Without This Extension

- Users must install and configure AFL++ just to get basic coverage information
- There is no way to answer "which functions/blocks did this input exercise?" for binary-only code without a heavy external tool
- Coverage-guided testing of closed-source software requires a complex setup

### What Happens If Extended Incorrectly

- **Register corruption:** If `%rax` or flags are not properly saved/restored, the instrumented binary will produce wrong results or crash. This is the #1 risk --- every basic block entry runs the trampoline, so even one register corruption cascades everywhere
- **Wrong bitmap indexing:** If `BLOCK_ID` is not masked to `MAP_SIZE-1`, the counter increment writes out of bounds, causing a segfault
- **Missing basic blocks:** If `fn.bbstarts` is not checked properly, some blocks won't be instrumented, giving incomplete coverage data
- **Performance regression:** If the trampoline is too heavy (e.g., saving all 16 registers), overhead becomes unacceptable for large programs

### How to Use

```bash
# Via RetroWrite module system:
python3 retrowrite -m coverage <binary> <output.s>
gcc -o <output> <output.s>

# Or use the demo script:
./scripts/07_ext2_coverage_demo.sh
```

### Files Created

- `retrowrite/rwtools_x64/coverage/__init__.py`
- `retrowrite/rwtools_x64/coverage/instrument.py` --- Full coverage pass (~150 lines)

---

## Extension 3: Function Call Tracing

### The Problem

When analyzing binary-only software (malware, proprietary code, firmware), a common first step is understanding "what functions does this program call and in what order?" Without source code, the only options are:
- **strace/ltrace:** Only shows system calls or library calls, not internal function calls
- **GDB breakpoints:** Requires manual setup for each function
- **Dynamic binary instrumentation (Pin/DynamoRIO):** 10-100x overhead

RetroWrite can do this at near-native speed with a simple instrumentation pass.

### What We Did

Created `rwtools_x64/trace/instrument.py` that:

1. **Instruments every function entry** with a call to `__trace_log_entry`
2. **Maintains a circular trace buffer** (64K entries) in memory for post-mortem analysis
3. **Optionally prints to stderr** when `RETRO_TRACE_PRINT=1` environment variable is set
4. **Saves/restores all caller-saved registers** to avoid disrupting program behavior
5. **Stores function names** as string literals in the binary for human-readable output

### How It Works

```
Without tracing:                 With tracing:

$ ./binary                       $ RETRO_TRACE_PRINT=1 ./binary_traced
Processing data...               [TRACE] main
Done.                            [TRACE] process_data
                                 [TRACE] helper_a
                                 [TRACE] compute
                                 [TRACE] helper_c
                                 Processing data...
                                 [TRACE] cleanup
                                 Done.
```

The trace buffer is a circular array in mmap'd memory:
```
┌─────────────────────────────────────────┐
│ trace_buffer[0] = &"main"               │
│ trace_buffer[1] = &"process_data"       │
│ trace_buffer[2] = &"helper_a"           │
│ trace_buffer[3] = &"compute"            │
│ ...                                     │
│ trace_buffer[65535] = ... (wraps around) │
└─────────────────────────────────────────┘
```

### What Happens Without This Extension

- Binary-only analysis requires heavy-weight tools (Pin, DynamoRIO, QEMU) with 10-100x overhead
- strace only shows syscalls, not internal function calls
- No way to get a quick "call graph" of a closed-source binary at near-native speed
- Malware analysis and reverse engineering workflows are significantly slower

### What Happens If Extended Incorrectly

- **Stack misalignment:** x86-64 ABI requires 16-byte stack alignment before `call`. If we push an odd number of registers, the `callq dprintf` inside the trampoline will segfault on SSE instructions. Our code pushes 9 registers + 1 flags = 10 pushes (80 bytes), maintaining alignment
- **Register clobbering:** If any register is not restored, the traced function receives wrong arguments. Since we instrument at function *entry* (before the prologue uses the arguments), we must preserve `%rdi`, `%rsi`, `%rdx`, `%rcx`, `%r8`, `%r9` (the argument registers)
- **Infinite recursion:** If the tracing function itself gets instrumented, it calls itself forever and crashes with stack overflow. We skip instrumented functions (`fn.instrumented`) and compiler-generated functions to prevent this
- **Buffer overflow:** If the circular index is not masked with `(BUFFER_SIZE - 1)`, the buffer write goes out of bounds

### How to Use

```bash
# Via RetroWrite module system:
python3 retrowrite -m trace <binary> <output.s>
gcc -o <output> <output.s>

# Run normally (tracing to buffer only, no visible output):
./<output>

# Run with trace printing to stderr:
RETRO_TRACE_PRINT=1 ./<output>

# Or use the demo script:
./scripts/08_ext3_trace_demo.sh
```

### Files Created

- `retrowrite/rwtools_x64/trace/__init__.py`
- `retrowrite/rwtools_x64/trace/instrument.py` --- Full tracing pass (~180 lines)

---

## Integration with RetroWrite

All three extensions integrate through RetroWrite's existing **module system**. The main `retrowrite` CLI script (line 331-340) supports:

```bash
python3 retrowrite -m <module_name> <binary> <output.s>
```

This dynamically loads `rwtools_x64/<module_name>/instrument.py` and calls `Instrument(rewriter).do_instrument()`. Our extensions follow this exact pattern:

```
retrowrite/rwtools_x64/
├── asan/                  # Original ASan pass (Extension 1 modifies this)
│   ├── instrument.py      # ← rep movs/stos fix added here
│   └── snippets.py
├── coverage/              # NEW: Extension 2
│   ├── __init__.py
│   └── instrument.py
├── trace/                 # NEW: Extension 3
│   ├── __init__.py
│   └── instrument.py
├── jumparound/            # Original (obfuscation pass)
├── kasan/                 # Original (kernel ASan)
└── kcov/                  # Original (kernel coverage)
```

No changes were made to the core rewriting engine (`librw_x64/`). All extensions use the public API:
- `self.rewriter.container.functions` --- iterate functions
- `fn.cache` --- iterate instructions
- `fn.bbstarts` --- basic block entry addresses
- `instruction.instrument_before(InstrumentedInstruction(...))` --- inject code
- `self.rewriter.container.add_section(DataSection(...))` --- add data sections
- `self.rewriter.container.add_function(Function(...))` --- add runtime functions

---

## How to Run All Extensions

```bash
# Run all extension demos in sequence:
./scripts/06_ext1_rep_movs_demo.sh
./scripts/07_ext2_coverage_demo.sh
./scripts/08_ext3_trace_demo.sh
```

### Prerequisites

- RetroWrite setup completed (`./scripts/01_setup.sh`)
- Clang/GCC installed
- libasan installed (for Extension 1)

---

## Test Programs

| Test File | Extension | Bugs/Features |
|-----------|-----------|---------------|
| `src/test_rep_movs.c` | Ext 1 | memcpy overflow (64→16 bytes), memset overflow (64→16 bytes) |
| `src/test_coverage.c` | Ext 2 | 10+ basic blocks, 4 functions, multiple code paths |
| `src/test_trace.c` | Ext 3 | 7 functions, nested calls, conditional call patterns |

---

## Summary: What Changes With vs Without Each Extension

### Without Any Extensions (Original RetroWrite)

| Capability | Status |
|---|---|
| Detect heap overflow via direct write | YES |
| Detect use-after-free | YES |
| Detect memcpy/memset overflow | **NO** (missed by `rep movs`/`rep stos`) |
| Standalone coverage tracking | **NO** (requires full AFL setup) |
| Function call tracing | **NO** (need Pin/DynamoRIO, 10-100x overhead) |

### With All 3 Extensions

| Capability | Status |
|---|---|
| Detect heap overflow via direct write | YES |
| Detect use-after-free | YES |
| Detect memcpy/memset overflow | **YES** (Extension 1) |
| Standalone coverage tracking | **YES** (Extension 2, no AFL needed) |
| Function call tracing | **YES** (Extension 3, near-native speed) |

---

## Academic Significance

- **Extension 1** directly addresses a **limitation acknowledged in the IEEE S&P 2020 paper**. This is an improvement over the published work.
- **Extension 2** fills a missing feature --- x64 had no coverage pass while ARM64 did.
- **Extension 3** demonstrates a new use case for binary rewriting beyond security: **debugging and program understanding**.

All three extensions together show that RetroWrite's plugin architecture is sound and can support diverse instrumentation passes without modifying the core engine.
