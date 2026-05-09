# RetroWrite — TA Questions & Answers

**Project:** RetroWrite: Adding Security Checks to Programs WITHOUT Source Code
**Course:** SIL765 - Networks & System Security (Semester 2, 2025-26)
**Team:** Chirag Suthar (MCS2105) & Haleel Sada (MCS2741)

---

## Table of Contents

1. [On the Core Concept](#on-the-core-concept)
2. [On RetroWrite Internals](#on-retrowrite-internals)
3. [On ASan (Demo 1)](#on-asan-demo-1)
4. [On ASan Internals](#on-asan-internals)
5. [On Extension 1 — rep movs fix](#on-extension-1-rep-movs-fix)
6. [On Extension 1 — Deep](#on-extension-1-rep-movs--deep)
7. [On Extension 2 — Basic Block Coverage](#on-extension-2-basic-block-coverage)
8. [On Extension 2 — Deep](#on-extension-2-coverage--deep)
9. [On Extension 3 — Function Call Tracing](#on-extension-3-function-call-tracing)
10. [On Extension 3 — Deep](#on-extension-3-tracing--deep)
11. [On the Project Overall](#on-the-project-overall)

---

## On the Core Concept

**Q: What exactly is RetroWrite doing under the hood?**

It disassembles the ELF binary, lifts it to symbolized assembly (`.s` file), lets you inject instrumentation code, then recompiles. The key insight is "symbolized" — it recovers labels and relocations so the recompiled binary is correct.

---

**Q: Why can't you just use GDB or Valgrind instead?**

Valgrind is 3x–10x slower because it interprets every instruction at runtime. RetroWrite statically rewrites the binary once, so the checks run natively. GDB requires manual setup per function.

---

**Q: What makes a binary "suitable" for RetroWrite? Can it work on any binary?**

No. It requires x86-64 ELF, compiled as PIE (Position Independent Executable), and non-stripped (symbols help but aren't strictly required). Binaries with hand-written assembly, obfuscation, or self-modifying code will break it.

---

**Q: What does "symbolized assembly" mean and why does it matter?**

A raw disassembly has hardcoded addresses — if you add code, all addresses shift and the binary breaks. Symbolized assembly uses labels instead of addresses, so adding instrumentation code doesn't corrupt jump targets.

---

## On RetroWrite Internals

**Q: Walk me through exactly what happens when you run `python3 retrowrite --asan binary output.s`. What are the internal pipeline stages?**

1. **ELF Parsing** (`librw_x64/container.py`) — reads sections, symbol table, relocation entries
2. **Disassembly** — uses Capstone to decode instructions
3. **Symbolization** — replaces hardcoded addresses with labels. Uses relocation entries in the ELF to know which immediate values are addresses vs constants
4. **Control flow recovery** — builds basic blocks using `fn.bbstarts`
5. **Instrumentation pass** — your pass walks every instruction and calls `instrument_before()`
6. **Code generation** — emits the `.s` file with all injected trampolines
7. You then `clang output.s -lasan -o binary.asan` to produce the final binary

---

**Q: How does RetroWrite handle indirect jumps like `jmp *%rax`? Can it go wrong?**

This is a known hard problem. RetroWrite uses a conservative assumption — if it can't statically resolve the target, it leaves the jump as-is. The symbolization step tries to recover jump tables from `.rodata` using relocation info. If the binary uses computed gotos or hand-crafted jump tables without relocations, RetroWrite can misidentify code as data or vice versa, producing a broken rewrite. This is one of the core limitations of static binary rewriting.

---

**Q: What is the difference between static binary rewriting (RetroWrite) and dynamic binary instrumentation (Pin/DynamoRIO)?**

Static rewriting modifies the binary on disk before execution — instrumentation runs natively, no interpreter in the loop, near-zero overhead. Dynamic instrumentation runs a JIT engine alongside the program at runtime — it can handle self-modifying code and indirect jumps perfectly, but pays 10–100x overhead. RetroWrite trades correctness on edge cases for performance.

---

**Q: Why does RetroWrite require PIE (Position Independent Executable)? What breaks without it?**

Non-PIE binaries have hardcoded absolute addresses in the text segment (e.g., `mov $0x400abc, %rdi`). When you add instrumentation code, all subsequent addresses shift, making those hardcoded values wrong. PIE uses relative addressing and relocations throughout, so RetroWrite can update all references correctly via the relocation table. Without PIE, symbolization is incomplete and the rewritten binary will crash or misbehave.

---

**Q: What is a "trampoline" in the context of binary instrumentation?**

A trampoline is a small stub of injected code that: saves registers/flags, does the instrumentation work (shadow memory check, counter increment, etc.), restores registers/flags, then falls through to the original instruction. The term comes from the fact that execution "bounces" through the stub before landing on the real instruction. RetroWrite injects these via `instrument_before()` which inserts assembly lines directly before the target instruction in the `.s` file.

---

## On ASan (Demo 1)

**Q: How does ASan shadow memory actually work?**

Every 8 bytes of real memory maps to 1 byte of shadow memory. Before each memory access, ASan checks the shadow byte. If it's non-zero (poisoned), that region is invalid — freed, out-of-bounds, etc. The formula is: `shadow_addr = (real_addr >> 3) + 0x7fff8000`.

---

**Q: The error says `unknown-crash` not `heap-buffer-overflow` — why?**

Because the binary is rewritten assembly, not compiled with `-fsanitize=address`. Some metadata ASan uses to classify the error type is missing. The crash is still detected, just with a generic label.

---

**Q: What's the difference between what RetroWrite does vs compiling with `-fsanitize=address`?**

`-fsanitize=address` requires source code. RetroWrite works on the binary directly — no source needed. That's the entire point: protecting closed-source or third-party binaries.

---

## On ASan Internals

**Q: Explain the shadow memory formula. Why `>> 3` and why `+ 0x7fff8000`?**

Every 8 bytes of application memory is summarized by 1 shadow byte — hence `>> 3` (divide by 8). The shadow byte value encodes: 0 = all 8 bytes accessible, k (1–7) = first k bytes accessible, negative = entire 8-byte region poisoned (freed, redzone, etc.). The offset `0x7fff8000` (= `0x100000000 >> 3`) maps the shadow region to a fixed virtual address range that doesn't overlap with the application. On 64-bit Linux, ASan reserves this range at startup via `mmap`.

---

**Q: What is a "redzone" in ASan and does RetroWrite's instrumentation add redzones?**

A redzone is poisoned shadow memory placed around heap allocations — before and after the buffer. When you do `buf[SIZE]` (one past end), you hit the redzone and ASan reports it. Source-compiled ASan adds redzones by hooking `malloc`. RetroWrite's binary ASan relies on the existing `malloc` being linked with ASan (`-lasan`), which adds redzones automatically. RetroWrite itself just adds the shadow memory checks — the redzones come from the ASan runtime library.

---

**Q: Why does the error say `unknown-crash` instead of `heap-buffer-overflow` in your demo?**

`heap-buffer-overflow` requires ASan's allocator metadata to identify that the accessed address is in a heap redzone. When compiling from source with `-fsanitize=address`, the allocator is replaced entirely by ASan's custom allocator which tracks every allocation. In RetroWrite's case, the binary was originally compiled without ASan, so the original `malloc` metadata format doesn't match what ASan's classifier expects. The check fires correctly (crash detected), but the classifier can't categorize it precisely.

---

**Q: How does ASan detect use-after-free? What shadow value does a freed region get?**

When `free()` is called under ASan, instead of returning memory to the OS, the region is "quarantined" — its shadow bytes are set to `0xfd` (the freed-memory poison value). Any subsequent access hits the shadow check, reads `0xfd`, and reports use-after-free. The quarantine prevents the allocator from reusing that memory immediately, giving ASan time to catch the dangling pointer access.

---

## On Extension 1 — rep movs fix

**Q: What was the original gap in RetroWrite's ASan pass?**

The original RetroWrite paper (IEEE S&P 2020) explicitly acknowledges: *"rep movsb and rep stosb instructions are not instrumented by our ASan pass."* The code had a literal `pass` with a `# XXX: TODO` comment. This means any buffer overflow via `memcpy` or `memset` was silently missed.

---

**Q: Show me the actual code change you made.**

Open `retrowrite/rwtools_x64/asan/instrument.py` around line 260. The `rep movs` block detects the mnemonic and sets `is_rep_movs = True`, which triggers 4 boundary checks later in `get_mem_instrumentation()`.

---

**Q: Why does memcpy become `rep movsb`? Isn't memcpy a function call?**

For small sizes the compiler inlines it as `rep movsb`. We force it with inline assembly in our test to guarantee the instruction appears in the binary — otherwise the compiler emits `call memcpy@PLT` which goes to libc, not into the binary itself.

---

**Q: What are the 4 checks you added and why each one?**

- `(%rdi)` — destination start valid?
- `(%rdi + %rcx - 1)` — destination doesn't overflow?
- `(%rsi)` — source start valid?
- `(%rsi + %rcx - 1)` — not reading past source end?

You need all 4 to catch both overflow and information-leak scenarios.

---

## On Extension 1 (rep movs) — Deep

**Q: Show me exactly what assembly your extension injects before a `rep movsb` instruction.**

```asm
; Check 1: destination start (%rdi)
mov %rdi, %r11
sar $3, %r11
cmpb $0, 0x7fff8000(%r11)
je .ok1
callq __asan_report_store1
.ok1:
; Check 2: destination end (%rdi + %rcx - 1)
lea -1(%rdi,%rcx), %r11
sar $3, %r11
cmpb $0, 0x7fff8000(%r11)
je .ok2
callq __asan_report_store1
.ok2:
; Check 3: source start (%rsi)
; Check 4: source end (%rsi + %rcx - 1)
; ... same pattern with __asan_report_load1
rep movsb   ; original instruction
```

---

**Q: Why do you check `%rdi + %rcx - 1` instead of `%rdi + %rcx`?**

Because `%rcx` is the count of bytes being copied. The last byte written is at address `%rdi + %rcx - 1`, not `%rdi + %rcx`. Checking `%rdi + %rcx` would check one byte past the end of the copy — that would be a false positive for every valid memcpy where the buffer is exactly `%rcx` bytes.

---

**Q: Does your extension handle `rep movsd` (doubleword) and `rep movsq` (quadword) or only `rep movsb`?**

Currently it handles any instruction whose mnemonic starts with `rep movs` — so `rep movsb`, `rep movsw`, `rep movsd`, `rep movsq` all match. The boundary calculation uses `%rcx` as the element count, so for `rep movsq` you'd need to multiply by 8 for the byte offset. This is a known limitation — we handle the byte case correctly but the scaling factor for wider variants needs an additional fix.

---

**Q: What registers does `rep movsb` implicitly use and how does your trampoline avoid corrupting them?**

`rep movsb` implicitly reads/writes `%rdi` (destination pointer), `%rsi` (source pointer), and `%rcx` (count — decremented to 0 after copy). The trampoline uses `%r11` as a scratch register (caller-saved, not used by `rep movs`) and does not modify `%rdi`, `%rsi`, or `%rcx`. The original values must be intact when `rep movsb` executes — if any of those three were clobbered, the copy would go to the wrong address or copy the wrong number of bytes.

---

**Q: What happens if `%rcx` is 0? Does your check break?**

If `%rcx` is 0, the copy does nothing. The boundary check `(%rdi + 0 - 1)` would underflow — but this is handled: when `%rcx` is 0 the `rep movsb` is a no-op and no memory is accessed, so we can skip the end-boundary checks. If the pointer itself is invalid, the start check `(%rdi)` will still fire correctly.

---

**Q: What happens if `%rcx` is 0? Does your check break?**

If `%rcx` is 0, the copy does nothing. The boundary check `(%rdi + 0)` = `(%rdi)` which is the same as the start check — it either passes or the pointer itself is invalid. No false positive.

---

**Q: Why was this a TODO in the paper for 5 years?**

`rep movs` is tricky because it uses 3 registers simultaneously (`%rdi`, `%rsi`, `%rcx`) and the instrumentation must save/restore all of them without corrupting the copy operation. It's more complex than a simple load/store check.

---

## On Extension 2 — Basic Block Coverage

**Q: What was the gap RetroWrite had before this extension?**

RetroWrite had a coverage pass for ARM64 (`rwtools_arm64/coverage/instrument.py`) but nothing for x86-64. Users who wanted coverage data on x64 binaries had to install and configure the entire AFL++ toolchain.

---

**Q: How is this different from gcov or lcov?**

gcov requires source code and recompilation. This works on binary-only code post-compilation with no source access.

---

**Q: What is edge-hashing and why use it instead of just counting block hits?**

`bitmap[cur ^ prev]++` captures the transition between blocks, not just which block was hit. This means taking path A→B→C vs A→C→B registers differently — it's path-sensitive, which is what AFL uses for better coverage feedback.

---

**Q: How big is the overhead of your coverage instrumentation?**

The trampoline is ~10 instructions per basic block entry: save 2 registers + flags, XOR + increment bitmap, restore. For most programs this is under 5% overhead.

---

**Q: What happens when the bitmap fills up (all 65536 slots used)?**

Collisions — two different edges hash to the same slot. Same behavior as AFL. It's a probabilistic structure, not exact. For most binaries with fewer than 10K basic blocks, collision rate is negligible.

---

## On Extension 2 (Coverage) — Deep

**Q: Walk me through exactly how edge-hashing works with your bitmap.**

Each basic block is assigned a unique ID at instrumentation time. The trampoline does:
```asm
xorq $BLOCK_ID, prev_loc(%rip)    ; prev_loc XOR current = edge ID
incb area_ptr(%rip, prev_loc, 1)  ; increment that edge's counter
movq $BLOCK_ID_SHIFTED, prev_loc(%rip) ; store current>>1 as new prev
```
The `>>1` shift prevents `A→B` and `B→A` from hashing to the same edge (XOR is commutative, shifting breaks the symmetry).

---

**Q: Why 64KB for the bitmap? What happens if you have more than 65536 unique edges?**

64KB = 65536 bytes, same as AFL's default `MAP_SIZE`. Above 65536 edges, XOR collisions increase — two distinct edges hash to the same counter. Coverage becomes approximate. AFL uses the same size for the same reason: it's a practical balance between memory usage and collision rate for typical program sizes.

---

**Q: How does your pass allocate the bitmap at runtime? Walk through the `.init_array` mechanism.**

We add a function to the binary's `.init_array` section. The ELF runtime calls all functions in `.init_array` before `main()`. Our constructor calls `mmap(NULL, MAP_SIZE, PROT_READ|PROT_WRITE, MAP_ANON|MAP_PRIVATE, -1, 0)` and stores the pointer in a global `area_ptr`. By the time `main` runs, the bitmap is ready. This is the same mechanism C++ uses for global constructors.

---

**Q: Does your coverage pass interfere with the program's own use of `%rax` and flags?**

Yes, that's exactly why we save them. The trampoline does `pushq %rax`, `lahf` (load flags into `%ah`), `seto %al` (overflow flag into `%al`) before any work, and `sahf` + `popq %rax` after. If we didn't, a basic block instrumented in the middle of a comparison sequence like `cmp; je` could corrupt the flags between the `cmp` and the `je`, completely changing control flow.

---

## On Extension 3 — Function Call Tracing

**Q: What was the gap before this extension?**

To trace internal function calls in a binary-only program, the only options were Pin/DynamoRIO (10–100x overhead) or manual GDB breakpoints. `strace`/`ltrace` only see syscalls/library calls — not internal function calls.

---

**Q: How is this different from `ltrace`?**

`ltrace` only captures calls to shared library functions (like `malloc`, `printf`). Our tracing captures every internal function call — even static functions, inlined-then-outlined functions, anything that has an entry point in the binary.

---

**Q: How do you enable the trace output?**

```bash
RETRO_TRACE_PRINT=1 ./binary_traced
```
Without the env var, traces go only to the in-memory circular buffer (no overhead from I/O). With it, each call is printed to stderr in real time.

---

**Q: What does the output look like?**

```
[TRACE] main
[TRACE] process_data
[TRACE] helper_a
[TRACE] compute
[TRACE] helper_c
[TRACE] cleanup
```

---

## On Extension 3 (Tracing) — Deep

**Q: How do you store function names in the binary? Where do they live?**

We add a new `.rodata`-style data section via `container.add_section(DataSection(...))`. Each function name is a null-terminated string stored there. The trampoline passes a pointer to that string as the argument to `__trace_log_entry`. Since this is done at instrumentation time (static), the strings are baked into the binary — no runtime string construction needed.

---

**Q: Why do you skip instrumenting the tracing function itself? What would happen if you didn't?**

If `__trace_log_entry` itself gets instrumented, calling any function triggers `__trace_log_entry`, which calls itself to log that call, which triggers again — infinite recursion, stack overflow. We guard against this by checking `fn.name` against a blacklist of our own injected functions before instrumenting.

---

**Q: The x86-64 ABI has 6 integer argument registers. If you're tracing a function that takes 6 arguments, do you corrupt them?**

No — we push all 6 argument registers (`%rdi`, `%rsi`, `%rdx`, `%rcx`, `%r8`, `%r9`) onto the stack before our trampoline runs, then pop them all back before the function prologue executes. The function sees its arguments untouched. The total push count (9 registers + flags word) = 10 × 8 = 80 bytes, which maintains 16-byte stack alignment.

---

**Q: You mentioned stack alignment — explain the 16-byte rule.**

x86-64 ABI requires `%rsp` to be 16-byte aligned before a `call` instruction. We push 9 registers + flags = 10 pushes = 80 bytes. 80 % 16 = 0, so alignment is maintained. If it was 9 pushes (72 bytes), SSE instructions inside `dprintf` would segfault.

---

**Q: Your trace buffer is 64K entries. For a program that calls millions of functions, you lose the early trace. Is that acceptable?**

For the use case of "what happened just before a crash", yes — the circular buffer gives you the most recent 64K calls, which is exactly what you want for post-mortem debugging. If you need the full trace from start, switch to `RETRO_TRACE_PRINT=1` mode which streams to stderr, but that adds I/O overhead. It's a deliberate design tradeoff: low overhead by default, full verbosity on demand.

---

**Q: What if a function is called recursively — does the trace buffer handle it?**

Yes. The circular buffer just keeps writing. Recursive calls appear as repeated entries. The 64K buffer wraps around — for deep recursion you'd see the tail of the call chain, not the beginning.

---

## On the Project Overall

**Q: Did you modify the core RetroWrite rewriting engine?**

No. All 3 extensions use only the public API: `fn.cache` for instructions, `fn.bbstarts` for basic blocks, `instruction.instrument_before()` to inject code, and `container.add_section()` for data. The core `librw_x64/` is untouched.

---

**Q: Which extension do you think is the most impactful and why?**

Extension 1 — because it directly plugs a security hole in the published tool. Extensions 2 and 3 add new capabilities, but Extension 1 means bugs that users thought were covered were actually being missed. That's a false sense of security, which is worse than no security at all.

---

**Q: How would you test that your extension has no false positives?**

Run it on a correct program with no overflows and verify it doesn't report any errors. The test for this is a `memcpy` where `n <= sizeof(dst)` — should pass silently with the extension active.

---

**Q: The paper is from 2020. Are there newer binary rewriting tools that do better?**

Yes — tools like `e9patch` (2021) do in-place binary rewriting without requiring PIE, and `BOLT` (Facebook, now in LLVM) handles non-PIE x86-64 for performance optimization. But RetroWrite's strength is its clean plugin API and the direct ASan/AFL integration, which makes it uniquely suited as an extensible research platform.

---

**Q: Could these extensions be upstreamed to the official RetroWrite repo?**

Extension 1 directly fixes a paper-acknowledged TODO, so it's a strong candidate. Extensions 2 and 3 follow the exact same pattern as existing passes (`kcov`, `kasan`). The main blocker would be test coverage and handling the edge cases we identified (e.g., `rep movsq` scaling). The PR would need those plus regression tests on the existing demo binaries.

---

**Q: What's the biggest risk of using RetroWrite-instrumented binaries in production?**

Correctness of the rewrite. If the symbolization step misidentifies data as code or misses a jump table entry, the rewritten binary has subtly wrong control flow. The original binary worked; the instrumented one silently takes wrong branches. You'd never know unless you had thorough test coverage. This is why RetroWrite is a security research tool, not a production hardening solution.

---

**Q: Without any of your extensions, what could the original RetroWrite detect vs miss?**

| Capability | Original RetroWrite | With All 3 Extensions |
|---|---|---|
| Heap overflow via direct write | Detected | Detected |
| Use-after-free | Detected | Detected |
| memcpy/memset overflow (`rep movsb`) | **Missed** | **Detected (Ext 1)** |
| Standalone coverage tracking | **Not available** | **Available (Ext 2)** |
| Function call tracing | **Not available** | **Available (Ext 3)** |

---

**Q: What is the academic significance of Extension 1 specifically?**

It directly addresses a limitation explicitly acknowledged in the IEEE S&P 2020 paper — this is an improvement over published work. The other two extensions fill capability gaps, but Extension 1 fixes a correctness bug in a security tool, which has direct practical impact.




-- can we do the demo with qemu first and explain the full process
