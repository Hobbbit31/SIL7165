# RetroWrite Paper — Limitations (Detailed)

## Abbreviations & Terminology Used

| Term | Full Form | Meaning |
|------|-----------|---------|
| **PIE** | Position-Independent Executable | Binary compiled so it can be loaded at any memory address (required for ASLR) |
| **PIC** | Position-Independent Code | Code that works regardless of where it's loaded in memory (PIE uses PIC internally) |
| **ASan** | AddressSanitizer | A memory error detector by Google that catches buffer overflows, use-after-free, etc. |
| **AFL** | American Fuzzy Lop | A coverage-guided fuzzer that feeds random inputs to find crashes |
| **ASLR** | Address Space Layout Randomization | OS security feature that loads programs at random addresses to prevent exploitation |
| **ELF** | Executable and Linkable Format | The standard binary file format on Linux |
| **DBT** | Dynamic Binary Translation | Translating binary code at runtime, instruction by instruction (e.g., QEMU, Valgrind) |
| **COTS** | Commercial Off-The-Shelf | Pre-built software you buy/download, without source code |
| **CFG** | Control Flow Graph | A graph showing all possible execution paths through a program |
| **ROP** | Return-Oriented Programming | An exploit technique that chains small code snippets ("gadgets") already in the binary |
| **JIT** | Just-In-Time Compilation | Generating machine code at runtime (used by JavaScript engines, Java VM, etc.) |
| **CVE** | Common Vulnerabilities and Exposures | A public database of known security vulnerabilities |
| **SPEC CPU2006** | Standard Performance Evaluation Corporation CPU 2006 | A widely-used benchmark suite for measuring CPU performance |
| **STL** | Standard Template Library | The C++ standard library (containers, algorithms, etc.) |
| **IoT** | Internet of Things | Embedded devices like routers, cameras, sensors connected to the internet |
| **Redzone** | — | Poisoned (marked as inaccessible) memory placed around allocated buffers to detect overflows |
| **Shadow Memory** | — | A metadata structure where 1 byte tracks the accessibility of 8 bytes of real memory |
| **Symbolization** | — | The process of replacing hardcoded numeric addresses in a binary with symbolic labels |
| **Relocation Entry** | — | Metadata in a PIE binary that tells the loader which values are addresses that need adjustment |

---

## Limitation 1: Only Works on 64-bit PIE/PIC Binaries

### What is the limitation?

RetroWrite **cannot rewrite** the following types of binaries:
- 32-bit binaries (x86, ARM32)
- Non-PIE executables (statically linked, fixed-address binaries)
- Stripped binaries where the relocation table has been removed

### Why does this limitation exist?

RetroWrite's entire approach depends on **relocation entries** to solve the symbolization problem. PIE binaries have relocations because the dynamic linker needs them to fix up addresses at load time (this is required for ASLR — Address Space Layout Randomization). Non-PIE binaries are loaded at a fixed address, so they **do not contain relocation entries**.

Without relocations, RetroWrite has no way to distinguish whether a value like `0x4005a0` is:
- A **code address** pointing to a function, OR
- Just the **plain integer 4195744** used in a calculation

If RetroWrite guesses wrong, the rewritten binary either crashes or produces incorrect results.

### What does this mean in practice?

- **Old legacy software** compiled before PIE became the default (pre-GCC 6, i.e., before 2016) cannot be analyzed
- **Embedded firmware**, bootloaders, and kernel images are usually not PIE, so they are out of scope
- **Statically linked binaries** (common in Go, Rust, and container images) have no relocation table, so RetroWrite fails on them
- **Windows PE binaries** and **macOS Mach-O binaries** use completely different formats and are not supported at all
- **Stripped binaries** where the relocation section has been explicitly removed by the developer also cannot be processed

### How significant is this?

Moderate in 2026, because most modern Linux distributions now default to PIE compilation. However, a huge chunk of legacy software, embedded systems, and non-Linux platforms is completely excluded from RetroWrite's scope. This is a **fundamental limitation** of the approach — it cannot be fixed without adopting an entirely different symbolization strategy.

---

## Limitation 2: No C++ Exception Handling Support

### What is the limitation?

RetroWrite **breaks programs that use C++ exceptions** (`try`/`catch`/`throw`).

### Why does this limitation exist?

C++ exception handling relies on **unwinding tables** stored in the `.eh_frame` and `.gcc_except_table` sections of the ELF binary. These tables map instruction addresses to cleanup actions — they tell the runtime "if an exception is thrown while executing instruction at address X, jump to cleanup handler at address Y."

When RetroWrite rewrites the binary, it **changes instruction addresses** because it inserts instrumentation code (ASan checks, AFL counters). However, it **does not update the unwinding tables** to reflect the new addresses.

So when an exception is thrown at runtime:
1. The C++ runtime looks up the **old address** in the unwinding table
2. The old address doesn't match any current instruction location
3. The unwinding fails, and the program **crashes** or behaves unpredictably

### What does this mean in practice?

- Most C++ applications heavily use exceptions — STL (Standard Template Library) containers, I/O operations, and any `new` operator that can fail all rely on exceptions
- Large C++ codebases like web browsers (Chrome, Firefox), databases (MongoDB, MySQL), and game engines **cannot be reliably rewritten** by RetroWrite
- Even C programs that link against C++ libraries (like `libstdc++`) may break if those libraries throw exceptions internally
- This effectively limits RetroWrite to **pure C programs** or C++ programs that are compiled with `-fno-exceptions`

### How significant is this?

Very significant. C++ is one of the most common languages for the kind of performance-critical, security-sensitive software (browsers, network services, media codecs) that needs binary analysis the most. This limitation rules out a large portion of real-world targets.

---

## Limitation 3: Coarser Stack ASan Compared to Source-Level ASan

### What is the limitation?

RetroWrite's ASan uses **frame-level redzones (8 bytes)** for stack memory, while source-level ASan uses **individual variable redzones (32 bytes)** between every local variable.

### Why does this limitation exist?

When source code is compiled, the compiler knows every local variable's exact position on the stack:
```c
void foo() {
    char a[16];   // at [rbp-16]
    char b[16];   // at [rbp-32]
}
```
Source ASan inserts a 32-byte poisoned redzone between `a` and `b`. If `a` overflows even by 1 byte, it hits the redzone and the overflow is **detected immediately**.

But in the compiled binary, this variable boundary information is **permanently lost**. RetroWrite sees a single stack frame of 32 bytes — it has no way to know where `a` ends and `b` begins. It can only add a redzone at the **outer frame boundary** (after the entire frame), not between individual variables within the frame.

### What does this mean in practice?

Consider this code:
```c
char a[16];
char b[16];
memcpy(a, input, 20);  // overflows 4 bytes from a into b
```
- **Source ASan:** Catches it immediately — the overflow from `a` crosses the redzone before `b`
- **RetroWrite ASan:** **Misses it completely** — the overflow stays within the same stack frame, no redzone is crossed

RetroWrite's ASan only catches stack overflows that **go past the entire stack frame** (e.g., writing 40+ bytes into this 32-byte frame).

### How significant is this?

Significant for security. Intra-frame stack overflows are a real attack vector. An attacker might overflow one local buffer to overwrite an adjacent function pointer or security-critical flag **on the same stack frame**, and RetroWrite's ASan would completely miss it.

---

## Limitation 4: No Global Variable Redzones

### What is the limitation?

RetroWrite **cannot add redzones between global variables** at all. There is zero detection capability for overflows between adjacent globals.

### Why does this limitation exist?

In source code, the compiler knows each global variable's boundaries:
```c
int secret_key = 12345;     // global variable 1
char user_input[64];        // global variable 2 (right after secret_key)
```
Source ASan pads each global variable to a 64-byte boundary with poisoned redzones between them. Any overflow from one global into another crosses the redzone and is detected.

But in the compiled binary, the `.data` section is just a **flat blob of bytes**. RetroWrite cannot tell where `secret_key` ends and `user_input` begins — they are just adjacent bytes with no boundary marker. If RetroWrite tried to insert redzones arbitrarily, it would break the memory layout that other parts of the code depend on.

### What does this mean in practice?

Consider this attack scenario:
```c
char buffer[32];       // global at address 0x4000
int is_admin = 0;      // global at address 0x4020 (right after buffer)
```
An attacker overflows `buffer` by 4 bytes, overwriting `is_admin` to `1`, achieving **privilege escalation**.

- **Source ASan:** Catches it (redzone exists between `buffer` and `is_admin`)
- **RetroWrite ASan:** **Completely misses it** (no global redzones exist at all)

### How significant is this?

High. Global buffer overflows that corrupt adjacent global variables are a **classic attack pattern**. RetroWrite has absolutely **zero detection capability** for this entire class of bugs. This is one of the key reasons why RetroWrite's ASan finds fewer bugs than source-level ASan despite having similar runtime overhead.

---

## Limitation 5: `rep movsb`/`rep stosb` Instructions Not Instrumented

### What is the limitation?

Memory operations performed via `rep movsb` (used by optimized `memcpy`) and `rep stosb` (used by optimized `memset`) are **completely skipped** by RetroWrite's ASan instrumentation. There is a literal `pass # XXX: THIS IS A TODO` in the source code at `rwtools_x64/asan/instrument.py:320`.

### Why does this limitation exist?

Normal memory instructions like `mov [rax], rbx` access a **fixed-size region** (1, 2, 4, or 8 bytes). RetroWrite knows the exact size at rewrite time and can insert a proper shadow memory check.

But `rep movsb` copies **rcx bytes** from memory at `[rsi]` to memory at `[rdi]`. The number of bytes is a **runtime value** stored in a register — RetroWrite doesn't know at rewrite time how many bytes will be copied. The current code simply skips these instructions entirely.

### What does this mean in practice?

Consider this code:
```c
char dest[32];
memcpy(dest, src, 1024);  // copies 1024 bytes into 32-byte buffer
```
The compiler optimizes `memcpy` into a `rep movsb` instruction. Since RetroWrite's ASan doesn't instrument `rep movsb`, the overflow is **completely invisible**.

This affects all the following common C functions, because compilers typically optimize them into `rep` instructions:
- `memcpy()`, `memmove()` → `rep movsb`
- `memset()` → `rep stosb`
- `strcpy()`, `strcat()`, `sprintf()` (when inlined/optimized)

### How significant is this?

**Critical.** These functions are among the **top causes of buffer overflows** in CVE databases worldwide. Vulnerabilities like Heartbleed, WannaCry, and countless others involve `memcpy`-related overflows. Skipping them means RetroWrite misses the **single most common real-world overflow pattern**.

This gives users a **false sense of security** — they believe the binary is fully sanitized with ASan, but an entire class of the most dangerous bugs is being silently ignored.

**Note:** This is one of our proposed extensions (Extension 1) for the end-term submission.

---

## Limitation 6: Linear Sweep Disassembly

### What is the limitation?

RetroWrite uses **linear sweep** disassembly (processes bytes sequentially from start to end), rather than **recursive descent** disassembly (follows the control flow of the program).

### Why does this limitation exist?

Linear sweep is simpler to implement and works well for standard compiler-generated code. However, it can be confused by certain binary patterns:

- **Inline data in code sections** — constants or lookup tables embedded between functions in the `.text` section are incorrectly interpreted as instructions
- **Hand-written assembly** with non-standard patterns (common in crypto libraries and media codecs)
- **Obfuscated code** with deliberately inserted junk bytes between real instructions
- **Compiler optimizations** that produce non-contiguous code layouts

### What does this mean in practice?

- Binaries with inline jump tables or lookup tables in `.text` may be disassembled as **garbage instructions**, producing a broken rewrite
- **Obfuscated malware** uses anti-disassembly tricks that specifically target linear sweep — RetroWrite would produce completely wrong disassembly
- Hand-optimized assembly in **crypto libraries** (OpenSSL, libsodium) or **media codecs** (ffmpeg, x264) may contain patterns that confuse linear sweep

### How significant is this?

Low for normal COTS (Commercial Off-The-Shelf) software, because standard compilers produce clean, well-structured code that linear sweep handles perfectly. However, this completely rules out **malware analysis** and **obfuscated binary** use cases.

---

## Limitation 7: No Support for Self-Modifying Code or JIT

### What is the limitation?

RetroWrite assumes the code section is **static** — it does not change at runtime. Programs that generate or modify code dynamically are not supported.

### Why does this limitation exist?

RetroWrite rewrites the binary **once, offline**. The instrumentation (ASan checks, AFL counters) is inserted into the existing code. If the program generates **new code at runtime** (JIT compilation) or **modifies existing code** (self-modifying code), that dynamically created/modified code:
- Was never seen by RetroWrite during the rewriting phase
- Contains no ASan checks or AFL instrumentation
- May conflict with RetroWrite's modifications

### What does this mean in practice?

- **JavaScript engines** (V8 in Chrome, SpiderMonkey in Firefox) use JIT compilation — the JIT-generated code runs completely uninstrumented
- **.NET and Java applications** with native interop may have managed-to-native calls that break
- **Self-unpacking executables** where the real code is compressed/encrypted and unpacked at runtime — the unpacked code is never processed by RetroWrite
- **Runtime code generation libraries** (e.g., `libffi`, `libjit`) create code that bypasses all instrumentation

### How significant is this?

Moderate. Most pure C/C++ programs do not use JIT or self-modifying code. But many modern applications embed scripting engines (Lua, Python, JavaScript) that rely on JIT compilation, making this a practical limitation for complex software.

---

## Limitation 8: Architecture Limited to x86-64 (and Partial ARM64)

### What is the limitation?

Only **x86-64** is fully supported with both ASan and AFL passes. **ARM64** support exists but is less mature and less tested. All other architectures are **completely unsupported**.

### What architectures are missing?

| Architecture | Used In | RetroWrite Support |
|---|---|---|
| x86-64 | Desktops, servers, cloud | Fully supported |
| ARM64 (AArch64) | Smartphones, Apple M-series, servers | Partial support |
| x86 (32-bit) | Legacy desktops, embedded | Not supported |
| ARM32 | IoT devices, older smartphones | Not supported |
| MIPS | Routers, networking equipment | Not supported |
| RISC-V | Emerging IoT, academic | Not supported |
| PowerPC | Legacy servers, game consoles | Not supported |

### What does this mean in practice?

- **IoT security** is one of the biggest concerns today — most IoT devices run ARM32 or MIPS, which RetroWrite cannot analyze
- **Router firmware** (Netgear, TP-Link, etc.) is typically MIPS-based — cannot be instrumented
- **Legacy 32-bit applications** still running on servers — cannot be tested
- **RISC-V**, an increasingly popular architecture, has no support

### How significant is this?

Significant for **IoT and embedded security** where ARM32, MIPS, and RISC-V are dominant. These are exactly the devices with the worst security practices and the most need for binary analysis tools. Extending RetroWrite to these architectures would require implementing new disassembly, symbolization, and instrumentation modules for each architecture.

---

## Summary Table

| # | Limitation | What's Affected | Severity | Can It Be Fixed? |
|---|---|---|---|---|
| 1 | PIE/PIC binaries only | Legacy, embedded, static binaries | High | Fundamental — needs a different approach |
| 2 | No C++ exception handling | Most C++ applications | High | Hard — needs unwinding table rewriting |
| 3 | Coarse stack redzones | Intra-frame stack overflows | Medium | Very hard — variable boundaries are lost during compilation |
| 4 | No global redzones | Global variable overflows | High | Very hard — variable boundaries are lost during compilation |
| 5 | `rep` instructions skipped | memcpy/memset overflows | **Critical** | **Easy — our Extension 1 addresses this** |
| 6 | Linear sweep disassembly | Obfuscated/hand-written code | Low | Medium — could switch to recursive descent |
| 7 | No JIT/self-modifying code | JIT engines, packed binaries | Medium | Fundamental — static rewriting cannot handle dynamic code |
| 8 | x86-64 architecture only | IoT, embedded, 32-bit systems | High | Engineering effort — each architecture needs new modules |

### Key Takeaway

Limitations 1, 2, 7, and 8 are **fundamental** to RetroWrite's design — they define the **scope** of where static binary rewriting can be applied. Limitations 3 and 4 are **inherent to binary analysis** — the information needed to fix them is permanently lost during compilation. Limitations 5 and 6 are **implementation gaps** that can be addressed with engineering effort — and Limitation 5 is exactly what our Extension 1 proposes to fix.
