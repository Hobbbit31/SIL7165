# Presentation Transcript: RetroWrite Reproduction
## SIL765 - Networks & System Security | ~10 min Presentation + 10 min Q&A

---

## PART 1: PRESENTATION TRANSCRIPT (~10 minutes)

---

### SLIDE 1: Title Slide (30 seconds)

"Good morning/afternoon everyone. I'm Chirag Suthar and this is Haleel Sada. Today we're presenting our NSS project titled **Rewriting Binaries for Bug Hunting: Reproducing RetroWrite for Binary-Only Fuzzing and Sanitization**.

This is based on the paper by Dinesh et al. published at IEEE S&P 2020, which is one of the top-tier security conferences. The paper has over 300 citations, so it's a highly impactful piece of work in binary security."

---

### SLIDE 2: The Problem (1 minute)

"Let's start with the problem. Most software we use daily -- browsers, media players, OS components -- is **closed-source**. We only get the compiled binary, not the source code. These binaries contain **memory corruption bugs** like buffer overflows, use-after-free, and out-of-bounds reads/writes. These are among the most dangerous security vulnerabilities -- they lead to arbitrary code execution, data theft, and system compromise.

Now, we have excellent tools to find these bugs:
- **AddressSanitizer (ASan)** by Google -- it instruments every memory access and catches illegal ones.
- **AFL (American Fuzzy Lop)** -- it feeds millions of random inputs to a program to find crashes.

**But here's the catch:** Both ASan and AFL require the source code to work. For closed-source binaries, the only option has been **Dynamic Binary Translation** tools like QEMU and Valgrind. These translate code at runtime, instruction by instruction. The problem? They are **10x to 100x slower** than native execution. When you need to run millions of test inputs for fuzzing, this slowness is a dealbreaker.

Other static tools like Uroboros and ramblr try to produce reassembleable assembly, but they use **heuristics** to guess which values in the binary are addresses vs. plain numbers. These heuristics are often wrong, leading to broken binaries. So we had no tool that was simultaneously **sound**, **fast**, and **scalable**."

---

### SLIDE 3: RetroWrite's Key Insight & Solution (1.5 minutes)

"This is where RetroWrite comes in with a very clever insight. Modern 64-bit Linux binaries are compiled as **Position-Independent Code (PIC)** -- this is required for ASLR, Address Space Layout Randomization. And PIC binaries contain something very useful: **relocation entries**.

Relocations are metadata left in the binary that tell the dynamic linker which values are addresses that need to be adjusted when the program is loaded at a random location. RetroWrite's key insight is: **we can use these same relocations to solve the symbolization problem**. Instead of guessing which values are addresses, we know exactly which ones are, because the binary already tells us through its relocation table.

The RetroWrite pipeline has 5 steps:

1. **Preprocessing** -- Load the ELF binary, parse sections (.text, .data, .rodata), read the relocation table and symbol table using pyelftools.

2. **Disassembly** -- Convert machine code to assembly instructions using the Capstone disassembly engine. This uses linear sweep through the .text section.

3. **Symbolization** -- This is the core step. For every relocation entry (like R_X86_64_RELATIVE), replace the hardcoded address with a symbolic label. This also handles control-flow references (calls, jumps) and PC-relative addressing. The output is a **reassembleable assembly file** where all addresses are represented as labels.

4. **Instrumentation** -- This is where we add security checks. Two passes are available:
   - **ASan pass**: Before every memory read/write, insert code to check shadow memory. If the memory is poisoned (freed, out-of-bounds), report an error.
   - **AFL pass**: At every basic block entry, insert a counter increment into a coverage bitmap so AFL can track which paths are exercised.

5. **Reassembly** -- Compile the modified assembly using a standard assembler (GCC/Clang), link with libasan or AFL runtime, and produce the final instrumented binary.

The entire process is done **offline, before execution**. There is zero runtime translation overhead."

---

### SLIDE 4: Technical Deep Dive - ASan Instrumentation (1.5 minutes)

"Let me explain how the ASan instrumentation actually works at the assembly level, because this is the most technically interesting part.

ASan uses a concept called **shadow memory**. For every 8 bytes of real memory, there is 1 byte in shadow memory that indicates whether those bytes are safe to access. The mapping is simple:

```
shadow_address = (real_address >> 3) + 0x7fff8000
```

So when RetroWrite encounters a memory access like `mov [rax+15], 0x58`, it inserts a check **before** this instruction:

```
lea  rdi, [rax+15]          # compute the address being accessed
shr  rdi, 3                 # divide by 8 to get shadow index
cmpb [rdi + 0x7fff8000], 0  # check shadow byte
jnz  __asan_report_store1   # if non-zero, memory is poisoned -- BUG!
mov  [rax+15], 0x58         # otherwise, proceed normally
```

Now, a critical challenge here is **register allocation**. The instrumentation code needs registers to work with, but all registers might be in use. RetroWrite solves this with **register liveness analysis** -- a backward dataflow analysis that tracks which registers are 'dead' (not needed) at each instruction. It picks dead registers for instrumentation, avoiding the need to save and restore live registers.

There is also a subtle difference from source-level ASan. For **heap**, both work identically at object granularity. For **stack**, source ASan uses 32-byte redzones per variable, but RetroWrite can only do frame-level redzones (8-byte) because the binary doesn't contain variable boundary information. For **globals**, RetroWrite cannot add redzones at all because the disassembly can't recover semantic boundaries between adjacent global variables."

---

### SLIDE 5: Our Experimental Setup & Results (2 minutes)

"Now let me walk you through what we actually did for reproduction. We set up the complete RetroWrite pipeline on Ubuntu Linux with x86-64 architecture, using Python 3.12, Capstone, AFL++, GCC, and Clang.

**Experiment 1: ASan Bug Detection on Demo Program**
We compiled the paper's demo program `heap.c` -- which has a heap buffer overflow and a use-after-free bug -- as a normal PIE binary. The original binary ran the buggy code **silently**, no crash, no error. Then we ran it through RetroWrite with the `--asan` flag, assembled the output, and ran it again. This time, the instrumented binary **immediately caught both bugs** and printed detailed ASan error reports showing exactly where the illegal memory access happened.

**Experiment 2: Real-World Binary Rewriting (bzip2)**
This was our soundness test. We compiled bzip2 1.0.8 (a real-world compression tool, 105KB binary) as PIE, ran it through RetroWrite, and reassembled it. The rewritten binary (101KB) produced **identical output** to the original when compressing and decompressing files. This confirms RetroWrite's symbolization is sound on real-world binaries. We also generated an ASan-instrumented version (2.5MB assembly).

**Experiment 3: Extended ASan Testing**
We wrote our own test program `asan_test.c` with four distinct memory bugs: heap buffer overflow, use-after-free, stack buffer overflow, and double free. The original binary missed all four -- two were silent corruption, two were crashes with no useful error message. The RetroWrite-instrumented binary **detected all four** with precise error reports.

**Experiment 4: Attack Surface Analysis**
We did a systematic analysis on our fuzz target program across 10 different attack types. RetroWrite's ASan detected all three possible memory safety attacks including the silent heap buffer overflow -- which is the most dangerous type because the attacker remains undetected.

**Experiment 5: AFL Fuzzing Performance**
This is the key performance result. We compared RetroWrite's binary-only AFL against source-level AFL:
- Source-level AFL: **4790 exec/sec** (this is the best possible baseline)
- RetroWrite AFL (binary-only): **4244 exec/sec** -- that's **88.6%** of source-level speed
- QEMU AFL (from the paper): ~800 exec/sec

So RetroWrite is approximately **5.3x faster than QEMU** while working on binaries without source code. This confirms the paper's claim of near-native performance."

---

### SLIDE 6: Comparison with Existing Solutions (1 minute)

"Let me put this in context with a comparison table.

| Tool | Needs Source? | Runtime Overhead | Bug Detection |
|------|--------------|-----------------|---------------|
| Source ASan | Yes | 1.73x | Best |
| **RetroWrite ASan** | **No** | **1.65x** | **Good** |
| Valgrind memcheck | No | 20-300x | Lower |
| QEMU + AFL | No | 10-100x | Low throughput |
| **RetroWrite + AFL** | **No** | **~1x** | **Near source-level** |

RetroWrite is the first tool that achieves all three goals simultaneously: **soundness** (no heuristic guessing), **speed** (near-native performance), and **scalability** (works on real-world binaries). The only limitation is it requires 64-bit PIC/PIE binaries -- but this covers most modern Linux software since compilers default to PIE."

---

### SLIDE 7: Planned Extensions for End-Term (1 minute)

"For the end-term submission, we plan three extensions:

1. **Fix rep prefix ASan instrumentation** -- The paper explicitly acknowledges that `rep movsb` and `rep stosb` instructions (used internally by memcpy and memset) are not instrumented. There's literally a `pass # XXX: THIS IS A TODO` in the source code at `instrument.py` line 320. We plan to add shadow memory checks for both the start and end addresses of the memory region accessed by these instructions.

2. **Basic block coverage pass for x64** -- The RetroWrite repo has a coverage pass for ARM64 but not for x64. We'll create a standalone coverage pass that inserts `inc byte [bitmap + BLOCK_ID]` at each basic block -- useful for coverage measurement without the full AFL setup.

3. **Stack canary insertion** -- A pass that adds stack canaries to binaries compiled without `-fstack-protector`. At function entry, push a random canary value; before every `ret`, verify the canary is intact. If overwritten, abort -- this prevents stack buffer overflow exploitation.

We'll evaluate each extension on programs with known vulnerabilities and measure the performance overhead."

---

### SLIDE 8: Conclusion (30 seconds)

"To summarize: We successfully reproduced the core functionality of RetroWrite. We confirmed that it can soundly rewrite real-world binaries, its ASan instrumentation catches memory bugs that the original binary misses silently, and its AFL instrumentation achieves 88.6% of source-level fuzzing speed -- which is 5x faster than the QEMU-based alternative. The key takeaway is that for the large class of modern PIC binaries, relocation information makes sound static binary rewriting possible, bringing source-level security tools to closed-source software at near-native performance. Thank you."

---

---

## PART 2: ANTICIPATED Q&A (~10 minutes)

---

### Q1: "Why does RetroWrite only work on PIE/PIC binaries? What about non-PIE binaries?"

**Answer:** "Great question. RetroWrite's entire approach depends on relocation information to solve the symbolization problem -- that is, distinguishing addresses from plain numbers in the binary. PIE (Position-Independent Executable) binaries contain relocation entries because the dynamic linker needs them to fix up addresses at load time for ASLR. Non-PIE binaries are loaded at a fixed address, so they don't have these relocations. Without relocations, we'd have to fall back to heuristics to guess which values are addresses, which is exactly what tools like Uroboros and ramblr do -- and those heuristics are unreliable. So the limitation is fundamental to the approach, not just an implementation gap. However, this is less of a problem in practice because most modern Linux distributions compile everything as PIE by default -- GCC has had `-pie` as default since version 6."

---

### Q2: "What is symbolization exactly? Why is it the hardest part of binary rewriting?"

**Answer:** "Symbolization is the process of replacing hardcoded numeric addresses in a binary with symbolic labels. Here's why it's hard: in a binary, the number `0x4005a0` could be a code address (pointing to a function), a data address (pointing to a global variable), or just a plain integer that happens to have that value. If you wrongly treat a plain number as an address and replace it with a label, the program's logic breaks. If you wrongly treat an address as a number and don't update it, the program will jump or read from the wrong location after reassembly and crash.

RetroWrite solves this by using relocation entries. Every value that is an address has a corresponding relocation entry (like R_X86_64_RELATIVE or R_X86_64_GLOB_DAT). So instead of guessing, RetroWrite knows with certainty which values are addresses. This is why the approach is called 'sound' -- it doesn't produce false positives or false negatives in address identification."

---

### Q3: "How does shadow memory work in ASan? What's the overhead?"

**Answer:** "Shadow memory is a compact metadata structure. The entire virtual address space is divided into 8-byte chunks, and each chunk gets 1 byte of shadow memory. The mapping is: `shadow_addr = (addr >> 3) + offset`, where the offset is `0x7fff8000` on x86-64.

The shadow byte value indicates accessibility:
- **0** means all 8 bytes are accessible (safe)
- **k (1-7)** means only the first k bytes are accessible
- **Negative values** indicate different types of poisoning: `-1` for heap redzones, `-2` for stack redzones, `-3` for freed memory (use-after-free detection)

The memory overhead is about **12.5%** (1 byte per 8 bytes = 1/8). The runtime overhead comes from the check instructions inserted before every memory access. For source-level ASan, the paper reports 73% overhead on SPEC CPU2006. For RetroWrite's binary ASan, it's about 65% overhead -- actually slightly better because it instruments fewer things (no global redzones). But that's also a limitation since it misses some bugs that source ASan would catch."

---

### Q4: "You said RetroWrite achieves 88.6% of source-level AFL speed. Where does the remaining 11.4% overhead come from?"

**Answer:** "The overhead comes from a few sources. First, RetroWrite's instrumentation is slightly less optimized than what the compiler can do with source-level AFL. When you compile with `afl-clang`, the compiler can make intelligent decisions about where to place instrumentation based on the full program structure -- it knows about loop headers, function boundaries, and can optimize accordingly.

Second, RetroWrite has to be conservative with register usage. The register liveness analysis identifies dead registers, but it must be sound -- if there's any uncertainty, it saves and restores registers using push/pop, which adds overhead. The compiler, on the other hand, has perfect knowledge of register usage.

Third, the reassembled binary may have slightly different code layout and alignment compared to what a compiler would produce, which can affect instruction cache performance. But 88.6% is remarkable -- it means RetroWrite adds only about 12-13% overhead compared to the theoretical best, while being 5x faster than the QEMU alternative."

---

### Q5: "What's the difference between Dynamic Binary Translation (QEMU/Valgrind) and RetroWrite's static approach?"

**Answer:** "The fundamental difference is **when** the instrumentation happens.

**Dynamic Binary Translation (DBT)** tools like QEMU and Valgrind work at runtime. They intercept the program one basic block at a time, translate the machine code, add instrumentation, cache the translated block, and execute it. This is very flexible -- it works on any binary regardless of format or architecture. But the translation step happens during execution, so you pay a heavy performance cost: 10-100x for QEMU, 20-300x for Valgrind.

**RetroWrite's static approach** does everything offline, before the program runs. It produces a new binary with instrumentation baked in. At runtime, this binary executes natively -- there's no translator in the loop. The trade-off is that it needs relocation information (so only PIE binaries), and it needs to solve the symbolization problem correctly.

Think of it like this: DBT is like having a simultaneous interpreter translating a speech in real-time (slow but works for any language). RetroWrite is like translating the speech beforehand and giving the audience the translated text (fast but needs a good dictionary, i.e., relocations)."

---

### Q6: "How does register liveness analysis work? Why is it important?"

**Answer:** "When RetroWrite inserts ASan check code before a memory access, that code needs registers to compute the shadow memory address and perform the comparison. But the program might be using all registers at that point. If we carelessly overwrite a register the program is using, we corrupt its state.

Register liveness analysis solves this by performing a **backward dataflow analysis**. Starting from the end of each basic block, it tracks which registers are 'live' (their values will be used later) and which are 'dead' (their values are about to be overwritten anyway). A register is dead at a point if the next time it appears, it's being written to, not read from.

The analysis gives RetroWrite a list of dead registers at each instruction. The ASan instrumenter picks from dead registers first, in a preferred order: rdi, rsi, rcx, rdx, rbx, r8-r15, rax, rbp. If no dead register is available, it falls back to saving a live register using `push/pop` -- which works but adds overhead. If flags (RFLAGS) are live, it saves them using `lahf/sahf` or `pushf/popf`.

This optimization is crucial -- without it, every instrumentation point would need push/pop for register saving, roughly doubling the overhead."

---

### Q7: "What are the limitations of RetroWrite's ASan compared to source-level ASan?"

**Answer:** "There are three main limitations, all stemming from information loss during compilation:

1. **No global variable redzones**: Source ASan pads each global variable with a redzone (poisoned memory) so it can detect overflows between adjacent globals. RetroWrite can't do this because the binary doesn't preserve the boundaries between global variables -- in the .data section, you just see a blob of bytes, you can't tell where one variable ends and the next begins.

2. **Coarser stack redzones**: Source ASan adds 32-byte redzones between individual stack variables. RetroWrite can only add 8-byte redzones at the stack frame level because it doesn't know the layout of local variables within a frame. This means it can detect overflows that go beyond the stack frame but may miss intra-frame overflows between adjacent local variables.

3. **rep prefix instructions**: `rep movsb` and `rep stosb` are used by compiled memcpy/memset. The current implementation doesn't instrument these at all -- there's literally a TODO comment in the code. This means buffer overflows caused by large memcpy operations might go undetected. This is one of our planned extensions to fix.

Despite these limitations, RetroWrite's ASan still catches the most critical bugs like heap overflows, use-after-free, and large stack overflows -- as we demonstrated in our experiments."

---

### Q8: "Can RetroWrite handle stripped binaries? What about obfuscated binaries?"

**Answer:** "For **stripped binaries** -- it partially depends on what's stripped. If the symbol table is stripped but the relocation table is intact, RetroWrite can still work because symbolization depends on relocations, not symbols. However, if the relocation table itself is stripped, RetroWrite cannot work because its entire approach relies on relocation information.

For **obfuscated binaries** -- generally no. Obfuscation techniques like control-flow flattening, opaque predicates, and code virtualization break the assumptions RetroWrite makes about the binary structure. The disassembly step uses linear sweep, which can be confused by code that interleaves data with instructions or uses anti-disassembly tricks.

It's important to note that RetroWrite's target use case is **COTS (Commercial Off-The-Shelf) software** -- regular applications compiled with standard compilers. This covers the vast majority of real-world software. Malware analysis, which often involves obfuscated code, would need different tools."

---

### Q9: "What are position-independent executables (PIE) and why do they contain relocations?"

**Answer:** "PIE is a compilation mode where the binary doesn't assume it will be loaded at any specific memory address. This is essential for **ASLR (Address Space Layout Randomization)** -- a security feature where the OS loads programs at random addresses to make exploitation harder.

Because a PIE binary doesn't know where it will be loaded, any internal reference to an absolute address needs to be adjusted at load time. These adjustments are recorded as **relocation entries** in the `.rela.dyn` and `.rela.plt` sections of the ELF file.

For example, if a function at offset `0x1000` references a global variable at offset `0x3000`, the binary contains a relocation entry saying 'at offset `0x1000`, there's an address that needs to be adjusted by the load base.' The dynamic linker reads these entries and patches the addresses when the program is loaded.

RetroWrite cleverly repurposes this information: if the binary says 'this value at offset X is an address,' then RetroWrite knows to replace it with a symbolic label. This is why the approach is sound -- it's using information the compiler already put there, not guessing.

Since GCC 6 and most modern distros default to PIE, the vast majority of Linux binaries today are PIE, making RetroWrite widely applicable."

---

### Q10: "How does AFL coverage-guided fuzzing work with RetroWrite?"

**Answer:** "AFL works by tracking **code coverage** -- which parts of the program are reached by each input. It does this using a shared bitmap (coverage map) of 64KB.

At each **basic block** (a straight-line sequence of instructions with no branches), RetroWrite inserts:
```
inc byte [coverage_map + BLOCK_ID]
```

Each basic block gets a unique random ID. When the block executes, its counter in the bitmap is incremented.

After each test input, AFL reads this bitmap. If a new input reached a basic block (or combination of blocks) that no previous input reached, AFL considers it 'interesting' and keeps it in its corpus for further mutation. This is much smarter than blind random testing because it focuses effort on inputs that explore new program paths.

With source-level AFL, the compiler inserts these counters during compilation. With RetroWrite, we first disassemble the binary, then use AFL's assembler to add the counters to the assembly, and reassemble. The end result is functionally identical -- the bitmap works the same way -- but RetroWrite achieves this without source code.

Our measurement showed 4244 exec/sec with RetroWrite vs 4790 exec/sec with source AFL -- 88.6% throughput with zero source code access."

---

### Q11: "What challenges did you face during reproduction?"

**Answer:** "Several practical challenges:

1. **Dependency version issues** -- RetroWrite was originally built for older Python and library versions. We had to ensure compatibility with Python 3.12 and newer Capstone versions.

2. **ASan version compatibility** -- The generated assembly referenced `__asan_init_v4` but our system's libasan expected `__asan_init`. We had to add a `sed` fixup step to patch the assembly before compilation.

3. **SPEC CPU2006 unavailability** -- The paper's main evaluation used SPEC CPU2006 benchmarks, which require a paid license. We used alternative benchmarks -- bzip2 for real-world soundness testing, and custom test programs for bug detection validation.

4. **Understanding the codebase** -- The RetroWrite codebase is about 2000 lines of Python across multiple modules. Understanding the interaction between the loader, disassembler, symbolizer, and instrumenter took significant effort, especially the register liveness analysis component.

5. **Build environment setup** -- Getting RetroWrite, AFL++, libasan, Capstone, and all Python dependencies to work together correctly required careful environment management with a Python virtual environment."

---

### Q12: "Why is this project relevant to network and system security?"

**Answer:** "This project sits at the intersection of **system security** and **software security**, both core topics of this course.

First, memory corruption vulnerabilities are the root cause of most critical security exploits -- remote code execution, privilege escalation, data breaches. Tools like ASan and AFL are frontline defenses used by security teams worldwide.

Second, the threat model is very realistic. Most software in enterprise environments is closed-source -- think proprietary network appliances, embedded firmware, commercial applications. Security analysts need to test this software for vulnerabilities without source code access.

Third, the concept of **binary analysis and instrumentation** is fundamental to many security applications beyond fuzzing: malware analysis, intrusion detection, binary hardening, and security auditing.

Finally, the techniques involved -- ELF parsing, disassembly, ASLR, shadow memory, coverage-guided fuzzing -- are all core system security concepts that this course covers. RetroWrite brings them all together in one practical system."

---

### Q13: "What is the difference between your custom test programs and the paper's demo?"

**Answer:** "The paper's repository includes a simple `heap.c` demo with two bugs: a heap buffer overflow and a use-after-free. This was good for verifying basic functionality.

We went beyond this in two ways:

First, our `asan_test.c` adds **two more bug types**: stack buffer overflow and double free. This validates that RetroWrite's ASan catches a broader range of memory safety issues, not just heap bugs. The stack overflow test is particularly important because it exercises RetroWrite's stack frame redzone mechanism, which works differently from source ASan.

Second, our `fuzz_target.c` is designed for **AFL fuzzing validation**. It has three distinct input-triggered bugs: a heap overflow triggered by the prefix 'FUZZ', a null pointer dereference triggered by 'CRASH', and a stack overflow triggered by long inputs. This lets us verify that AFL can discover these bugs through fuzzing, and compare the discovery rate between RetroWrite-instrumented and source-instrumented binaries.

We also did a systematic **attack surface analysis** across 10 different attack types on the fuzz target, which is an evaluation methodology not present in the original paper."

---

### Q14: "Can you explain the threat model more clearly?"

**Answer:** "Sure. The threat model has two parties:

**The Attacker:** Wants to exploit memory corruption vulnerabilities in a target binary -- buffer overflows, use-after-free, etc. -- to achieve arbitrary code execution, data theft, or denial of service. The attacker can provide crafted inputs to the program. They know it's a 64-bit PIC binary running on Linux with standard protections (ASLR, DEP).

**The Defender (Security Analyst):** Wants to find and fix these bugs before the attacker exploits them. But the defender doesn't have the source code. They want to test the binary by adding ASan (to catch memory bugs) and AFL fuzzing (to automatically discover crash-inducing inputs).

**RetroWrite's role:** It enables the defender to add ASan and AFL to the closed-source binary at near-native speed, something that was previously only possible with source code or with extremely slow dynamic tools.

**Assumptions:** The binary is compiled as PIC/PIE (standard for modern Linux), is not obfuscated, has relocation information intact, and targets x86-64 architecture."

---

### Q15: "What are your planned extensions and how do they improve RetroWrite?"

**Answer:** "We have three planned extensions:

**1. Fix rep prefix ASan (Medium difficulty, ~150 lines):**
The current code has a literal TODO at line 320 of `instrument.py` where `rep movsb` and `rep stosb` instructions are skipped. These are used by optimized memcpy/memset. Our fix will add shadow memory checks for both the source and destination memory ranges before these instructions execute. This directly addresses a known limitation mentioned in the paper.

**2. Basic block coverage pass for x64 (Easy, ~60 lines):**
The repository has an AFL coverage pass for ARM64 but not x64. We'll create a standalone pass at `rwtools_x64/coverage/instrument.py` that inserts `inc byte [bitmap + BLOCK_ID]` at each basic block. This is useful for coverage measurement and analysis without needing the full AFL fuzzing setup.

**3. Stack canary insertion (Medium, ~100 lines):**
We'll add a pass that inserts stack canaries into binaries that were compiled without `-fstack-protector`. At function entry, a random canary value is pushed onto the stack. Before every `ret` instruction, the canary is verified. If it's been overwritten by a stack buffer overflow, the program aborts immediately. This adds an extra layer of defense to binaries that lack this protection."

---

### CLOSING NOTE FOR Q&A:

If you run out of questions to answer, a good closing statement:

"To wrap up -- we believe this project demonstrates a practical and important capability: bringing source-level security tools to binary-only software without sacrificing performance. The relocation-based approach is elegant because it leverages information the binary already contains, rather than trying to guess. Thank you for your questions."

---

## TIPS FOR THE PRESENTATION

1. **Keep demos ready** -- Run `scripts/demo_for_ta.sh` beforehand so you can show live output if asked.
2. **Have terminal open** -- Show the `output/` directory with the actual binaries and assembly files.
3. **Key numbers to remember**: 88.6% AFL speed, 5.3x faster than QEMU, 65% ASan overhead, 4244 exec/sec.
4. **If asked to show code**: Open `src/asan_test.c` or `src/fuzz_target.c` -- these are your original contributions.
5. **If asked about the pipeline**: Show `output/asan_demo/heap.asan.s` -- the instrumented assembly with ASan checks.
