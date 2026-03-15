# How RetroWrite Works (Simple Explanation)

## The Problem

Most software you use is **closed-source** -- you get the compiled program (binary), not the original code (source).

These binaries have **memory bugs** -- mistakes where the program reads/writes memory it shouldn't. Hackers exploit these to steal data or take control.

To find these bugs, we need two tools:
- **ASan (AddressSanitizer):** A "security guard" that watches every memory access and screams if something is wrong.
- **AFL (Fuzzer):** A tool that feeds random inputs to a program thousands of times per second, trying to make it crash.

**The catch:** Both tools normally need the source code. For binary-only software, the only option was QEMU (a slow translator), which is **10x-100x slower**.

## RetroWrite's Solution

RetroWrite is clever. Modern binaries (PIE/PIC) leave behind **breadcrumbs** called "relocations" that tell the system which values are code addresses. RetroWrite uses these breadcrumbs to:

```
Step 1: Load the binary and read its relocations (breadcrumbs)
Step 2: Disassemble the machine code into assembly instructions
Step 3: Replace hardcoded addresses with labels (symbolization)
Step 4: Insert ASan checks / AFL coverage before memory accesses
Step 5: Reassemble into a new working binary
```

The result? A binary with built-in security checks, running at **near-native speed**.

## What ASan Checks Look Like

For every memory access, RetroWrite adds a check:

```
BEFORE (original binary):
    mov [rax+15], 0x58          <-- writes to memory at rax+15

AFTER (RetroWrite + ASan):
    # Check: is this memory address safe?
    lea  rdi, [rax+15]          # address we want to access
    shr  rdi, 3                 # look up in shadow memory
    cmpb [rdi + 0x7fff8000], 0  # is it poisoned?
    jnz  __asan_report_store1   # YES -> BUG FOUND!

    mov [rax+15], 0x58          # NO  -> safe, proceed normally
```

Shadow memory = a lookup table. Every 8 bytes of real memory has 1 byte in shadow memory that says "safe" or "poisoned". Only 12.5% extra memory.

## What AFL Coverage Looks Like

At every "basic block" (chunk of straight-line code), RetroWrite adds:

```
    inc byte [coverage_map + BLOCK_ID]   # "I was here!"
```

AFL reads this map after each input, finds which new paths were discovered, and mutates the best inputs to explore further. Much smarter than blind random testing.

## Results from the Paper

| What                              | Speed                    |
|-----------------------------------|--------------------------|
| Source AFL (best possible)        | 4790 exec/sec            |
| **RetroWrite AFL (binary only!)** | **4244 exec/sec (88.6%)**|
| QEMU AFL (old way)                | ~800 exec/sec            |
| Valgrind (very old way)           | ~100 exec/sec            |

RetroWrite also finds **80% more bugs** than Valgrind and is **3x faster**.

## Limitations

- Only works on **x86-64 PIE** binaries (position-independent executables)
- No C++ exception handling support
- Stack ASan: frame-level only (may miss some intra-frame overflows)
- `rep movsb`/`rep stosb` instructions (memcpy/memset) not fully instrumented


- RetroWrite + ASan catches memory safety bugs. It cannot catch logic bugs where the memory operations are valid but semantically wrong.
