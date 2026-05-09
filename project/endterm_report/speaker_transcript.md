# Endterm Demo — Speaker Transcript (Detailed)

Target: ~20–22 minutes. Roughly 60–90 seconds per slide.
Speak conversationally. Pause between slides. Lines in quotes are what you say.

---

## Slide 1 — Title   (~60s)

> Good afternoon everyone, and thank you for the time. Our end-term project
> for SIL765 / SIL7165 is titled **Beyond the Binary Barrier: Extending
> RetroWrite with Memcpy-Safe Sanitization, Standalone Coverage, and Native
> Function Tracing**.
>
> I'm Chirag Suthar — 2025MCS2105 — and with me is Haleel Sada — 2025MCS2741.
>
> Our reference paper is Dinesh, Burow, Xu, and Payer's *RetroWrite:
> Statically Instrumenting COTS Binaries for Fuzzing and Sanitization*,
> from IEEE Security & Privacy 2020. This is the paper we reproduced for
> the midterm, and for the end-term we've extended it in three concrete
> directions.
>
> The goal of the project, at a high level, is to take a technique that
> normally needs source code — **memory-safety sanitisation and fuzzing
> coverage** — and push it *past* the binary barrier. We want to do this
> for real-world stripped ELF binaries where source isn't available. The
> next fifteen minutes walk through why this matters, how RetroWrite
> approaches it, where it falls short, and what we added.

---

## Slide 2 — Motivation   (~75s)

> Let's start with the number that motivates the entire field.
> **Seventy percent.** That is the fraction of CVEs — published security
> vulnerabilities — that Szekeres and colleagues attribute to memory-safety
> issues, in their 2013 IEEE S&P paper *Eternal War in Memory*. Buffer
> overflows, out-of-bounds reads and writes, use-after-free, double-free,
> stack corruption. These are not new bugs — we've known about them since
> the nineties — and yet they keep coming back.
>
> So why can't we just run AddressSanitizer or fuzz with AFL on everything?
> Three reasons.
>
> **First**, most of the code we actually need to audit is closed source —
> modern browsers, game engines, router firmware, proprietary server
> binaries. They ship as stripped ELF or PE executables. AddressSanitizer
> and AFL both normally need source to insert instrumentation.
>
> **Second**, the dynamic tools that don't need source — things like QEMU's
> user-mode emulation, or Valgrind — are incredibly slow. Valgrind can be
> three hundred times slower than native; QEMU is ten to a hundred times
> slower. A fuzzer running at a few hundred executions per second instead
> of several thousand makes deep bug discovery impractical.
>
> **Third**, the static rewriters that *are* fast — Uroboros, ramblr, and
> others — all rely on **heuristics** to figure out which bytes in the
> binary are addresses and which are just numbers. When those heuristics
> misclassify something, the reassembled binary crashes.
>
> Our project closes **three specific gaps** on top of RetroWrite, which
> is the tool that cracks this trilemma.

---

## Slide 3 — The classical trilemma   (~80s)

> Let me make the trade-off concrete with a quick mental map.
>
> Put **soundness** on the vertical axis and **runtime speed** on the
> horizontal. Soundness means: every instrumentation decision is provably
> correct — no guessing. Speed means: the rewritten or instrumented binary
> runs close to native.
>
> **Bottom-left** — you'll find Valgrind, QEMU, and Intel Pin. These are
> dynamic binary-translation tools. They are fully sound, because they
> interpret instructions at runtime, but they pay a big runtime cost —
> anywhere from two-x to three-hundred-x depending on the tool. Too slow
> for real fuzzing campaigns.
>
> **Bottom-right** — Uroboros and ramblr. Static rewriters. They produce
> fast binaries because instrumentation is baked in at build time, but
> they guess at the disassembly — and those guesses sometimes silently
> break the binary.
>
> **Top-right** — this is the corner everybody wants, and this is where
> RetroWrite lives. Sound *and* fast *and* source-free.
>
> The reason, summarised on the right-hand card, is elegant. Modern
> position-independent executables — PIE ELFs — carry a `.rela.dyn`
> section. It is a **relocation oracle**: every address-valued immediate
> in the code section is already labelled, because the loader needs those
> labels to relocate the binary at load time. RetroWrite uses this oracle
> to do exact — not heuristic — symbolisation. No guessing is required.
>
> Our three passes plug into this and inherit the same soundness
> guarantee. That's the whole research bet.

---

## Slide 4 — How binary rewriting works   (~75s)

> Before we get to our extensions, let me show you the pipeline. It has
> six steps, shown here left to right.
>
> **Step one** — we take a PIE x86-64 ELF binary as input.
> **Step two** — we load it into Python. We parse the ELF sections, the
> dynamic symbols, and importantly the `.rela.dyn` relocations.
> **Step three** — we disassemble every executable section using Capstone,
> Nguyen Anh Quynh's disassembly framework. This gives us an instruction
> stream with operand metadata.
> **Step four** — and this is the crucial one, highlighted in green —
> **symbolisation**. For every address-valued immediate or memory operand,
> we consult the relocation table and replace the raw address with a
> symbolic label. After symbolisation we have real assembly that a regular
> assembler can understand.
> **Step five** — we run instrumentation passes. Upstream RetroWrite ships
> with ASan and AFL passes. Our three passes plug in at this same stage.
> **Step six** — we reassemble the instrumented assembly back to an ELF
> using gcc or clang.
>
> The contrast at the bottom is what makes RetroWrite special. **Prior
> static rewriters** had to *guess* whether a constant like `0x401050` was
> an address the loader cares about, or just an integer the program is
> computing with. Get it wrong and the reassembled binary crashes at
> load time or misbehaves silently.
>
> **RetroWrite** doesn't guess. `.rela.dyn` already says which bytes are
> addresses. It's a ground-truth oracle. That's the whole key insight.

---

## Slide 5 — ASan and AFL in a sentence   (~60s)

> Quick primer on the two source-level tools that RetroWrite brings to
> stripped binaries, because our extensions build directly on them.
>
> **AddressSanitizer**, on the left. Every eight bytes of application
> memory get one byte of *shadow* memory, living at a fixed offset. The
> shadow byte encodes how many of those eight bytes are addressable. Every
> load and store is wrapped in a call to `__asan_load1`, `__asan_load4`,
> `__asan_load8`, or the store equivalents. If the access hits a poisoned
> shadow byte, you get a crash with a precise report — out-of-bounds,
> use-after-free, stack-use-after-scope, and so on. Heap and stack
> allocations get red-zones around them so even off-by-one reads are
> caught.
>
> **AFL — American Fuzzy Lop**, on the right. AFL uses a 64-kilobyte
> bitmap indexed by a hash of the current and previous basic block —
> `bitmap[cur XOR prev]++`. It inserts a small stub at every basic-block
> entry that writes that hash. The fuzzer drives the binary with mutated
> inputs; if a new bit appears in the bitmap, AFL has discovered a new
> edge in the program's control-flow graph, saves that input, and keeps
> mutating.
>
> Both tools are phenomenal. Both normally need source. RetroWrite closes
> that gap — and our passes extend it further.

---

## Slide 6 — Related work   (~70s)

> Let's ground this in the broader literature. This table is the landscape
> of binary-analysis tools relevant to our problem.
>
> **The first three rows — QEMU, Valgrind, Intel Pin** — are
> dynamic-binary-translation tools. All sound, all slow. QEMU ten to a
> hundred times slower, Valgrind twenty to three hundred, Pin two to
> five-x, but proprietary.
>
> **Uroboros and ramblr** — classical static reassembleable disassembly.
> Fast, but their soundness is only *partial*, because their symbolisation
> is heuristic. You'll see reassembled binaries that crash or silently
> miscompute.
>
> **DynInst** — Bernat and Miller's instrumentation framework. Part-sound,
> generally unsafe on stripped ELF.
>
> **E9Patch** — Duck, Gao, Roychoudhury at PLDI 2020. Clever trampoline-
> patching approach. Sound and fast, but limited in semantic instrumentation
> — difficult to do full ASan with it.
>
> **RetroWrite** — the paper we extend — sits in the top-right: sound,
> fast, source-free. But it has three gaps: `rep movs` is not
> instrumented, x86-64 coverage is missing, and there's no call tracer.
>
> **Our row, the last one**, keeps all three checks and fills all three
> gaps. That's the contribution in one row.

---

## Slide 7 — System model   (~65s)

> Now the formal system model — entities and data flow.
>
> **Inputs**, top row. The analyst supplies a PIE x86-64 ELF binary and
> its `.rela.dyn` relocation table. In a real deployment `.rela.dyn`
> already lives inside the binary — it's not a separate file.
>
> **Core**, middle row, leftmost. `librw_x64` — RetroWrite's core rewriter
> for x86-64. We did **not** modify this. Every extension we added lives
> in a separate rewriter module.
>
> **Our three passes**, middle row, to the right:
> - `E1` is our fix for rep-movs ASan — coloured red because it's a
>   safety-critical pass.
> - `E2` is our new coverage pass for x86-64 — the original paper only
>   had coverage for ARM64.
> - `E3` is our new tracer module.
>
> **Outputs**, bottom row. Once the instrumented assembly goes through
> gcc or clang, we get a hardened binary. That binary can be handed to
> an analyst to run directly, or to AFL++ for a fuzzing campaign. The
> output artefacts are ASan reports when bugs fire, a coverage bitmap,
> and a `[TRACE]` log stream.
>
> One design rule for the end-term: every new pass obeys RetroWrite's
> existing `python3 retrowrite -m <module>` CLI contract. No changes to
> the user interface, no changes to the core.

---

## Slide 8 — Threat model   (~55s)

> The threat model is standard for a sanitiser plus fuzzer.
>
> **Attacker**, in red.
> - Supplies arbitrary input through any standard channel — stdin, network
>   sockets, files, command-line arguments.
> - No binary patching, no kernel access — it's a user-space adversary.
> - Assumes the platform's standard defences are on: ASLR, non-executable
>   stack (NX), RELRO.
> - Goal: hijack control flow, leak data, or cause a denial of service.
>
> **Defender**, in green.
> - Has only the stripped PIE ELF — no source code.
> - Uses RetroWrite plus our three passes to add sanitisation and
>   coverage.
> - Wants to find memory-safety bugs before the binary ships.
> - Hard constraint: near-native speed. A defender who has to wait hours
>   for one fuzzing iteration won't use the tool.
>
> **Out of scope**, in grey.
> - Logic bugs and authentication bypasses — those are semantic, not
>   memory-safety.
> - Side-channels and timing attacks — a different threat class.
> - Non-PIE binaries — without relocations we lose our oracle. Our
>   soundness guarantee is explicitly conditional on PIE plus intact
>   relocations.
> - Kernel or hypervisor compromise — outside user-space.

---

## Slide 9 — Three extensions overview   (~60s)

> Now the proposed solution in one picture. Three cards, left to right.
>
> **E1 — rep-movs / rep-stos ASan.** The `rep` instruction prefix on x86
> performs a fast block memory copy or initialisation. RetroWrite's
> upstream ASan pass silently skipped both of these. We add four shadow
> probes — two at each end of the destination and source ranges — that
> make the full copy visible to ASan. This closes a real soundness hole.
>
> **E2 — basic-block coverage.** A new coverage pass specifically for
> x86-64. The original paper shipped coverage only for ARM64. Our
> implementation uses the same edge-hash bitmap that AFL uses, but we
> allocate it ourselves via a raw `mmap` syscall — which means the
> instrumented binary is self-contained and does not need to link against
> the AFL runtime at all.
>
> **E3 — function-call tracer.** A trampoline at every function entry
> logs the function name into a circular buffer. No tracer of this kind
> existed in the baseline.
>
> Each pass is cleanly toggleable by an environment variable — the pill
> at the bottom of each card shows the exact variable name. If you want
> to disable a pass at rewrite time, just set it.

---

## Slide 10 — E1 detail: memcpy safety, finally   (~90s)

> Let's go deep on Extension One — this is the most safety-critical piece.
>
> **Before our fix**, the left panel. Imagine a destination buffer of
> just ten bytes, shown in green. A `rep movsb` instruction copies
> fifty bytes into it. The last forty bytes spill past the end of the
> buffer — the red zone — which is classic CWE-120, buffer-copy without
> checking size.
>
> Now look at the code snippet — this is the **upstream** RetroWrite ASan
> pass, around line 320.
> ```
> if mnemonic.startswith("rep stos"):
>     pass   # XXX: TODO for more accurate check
> # rep movs — not handled at all
> ```
> For `rep stos` — the block-initialisation form — they literally have a
> `pass` statement and an `XXX: TODO` comment. For `rep movs` — the
> block-copy form — there's no case at all. The consequence at runtime
> is a `DEADLYSIGNAL` — a raw SEGV with no diagnostic, no way to know
> what corrupted what.
>
> **After our fix**, the right panel. We emit four probes around each
> `rep` instruction. For the destination we probe `(%rdi)` — the start
> of the range — and `(%rdi, %rcx)` — the end, since `%rcx` holds the
> byte count. For the source we probe `(%rsi)` and `(%rsi, %rcx)`
> similarly.
>
> Each probe is a single-byte load through the ASan shadow-memory
> machinery. If any of the four probes hits a poisoned shadow byte —
> meaning that end of the range is out-of-bounds — ASan fires with a
> precise report: `AddressSanitizer: heap-buffer-overflow … READ of
> size 1`. You get the faulting address, the allocation site, and a
> backtrace. That is a massive improvement over a silent SEGV.
>
> On our test binary the instrumented-site count goes from fifty-one to
> fifty-two — one new site for the `rep movsb`. Tiny cost, real safety
> win.

---

## Slide 11 — E2 and E3 detail   (~90s)

> Extension Two — basic-block coverage — on the left.
>
> The diagram on the left is a stylised control-flow graph. `BB1` is the
> entry block, `BB4` the join. At every basic-block entry we insert a
> trampoline — that's the red dot. The trampoline computes
> `bitmap[cur XOR prev]++` where `cur` is the block ID, `prev` is the
> previous block ID shifted right by one — this is exactly AFL's edge-hash
> scheme.
>
> The bitmap is a sixty-four kilobyte region that our pass allocates
> itself via a raw `mmap` syscall at program start. This is important —
> the binary does *not* link against AFL's `afl-compiler-rt`. It is
> self-contained. You can use the coverage output directly, or feed it
> to AFL via the standard shared-memory protocol. On our test harness
> we hit twenty out of twenty basic blocks on the test program.
>
> Extension Three — function-call tracer — on the right.
>
> The row of pills at the top is a sample trace from the `test_trace.c`
> program. You see `main`, `process_data`, `helper_a`, `compute`,
> `cleanup` — seven calls, recorded in order.
>
> The code snippet underneath is the trampoline itself. Let me walk through
> it:
> - `subq $8, %rsp` — re-align the stack to 16 bytes, because the SysV
>   ABI requires 16-byte alignment at the call site.
> - `pushq %rdi … %r11` — save the nine caller-saved registers so the
>   callee has a clean register file.
> - `leaq .LTRACE_NAME(%rip), %rdi` — load a pointer to the function's
>   name string, which we emit as a local label.
> - `callq __trace_log_entry` — call our logging helper, which appends
>   to a circular 64K-entry buffer.
>
> On exit we restore everything and jump to the original function body.
> Overhead is a few nanoseconds per call, and if you set
> `RETRO_TRACE_PRINT=1` the buffer also streams to stderr as a `[TRACE]`
> log.
>
> Both passes use the same trampoline pattern — spill, call, restore.

---

## Slide 12 — Midterm results   (~75s)

> Now results. The midterm slide shows our **paper reproduction**.
>
> **Left card — bug detection.** We ran the `asan_test.c` harness through
> RetroWrite's original ASan pass, on Ubuntu 24 with AFL++ 4.30c.
>
> Four canonical bug classes:
> - **Heap out-of-bounds** — originally silent, because the write didn't
>   hit an unmapped page. After instrumentation, caught with a precise
>   ASan report.
> - **Use-after-free** — also originally silent. Caught.
> - **Stack overflow** — originally produced a raw SEGV. Caught with a
>   proper stack-buffer-overflow report.
> - **Double free** — originally aborted through glibc with an obscure
>   message. Caught cleanly.
>
> Four-for-four. And we also verified that bzip2 round-trips through
> RetroWrite with a **zero-byte diff** — the rewritten binary is
> bit-identical to the original when no instrumentation is applied.
>
> **Right card — AFL throughput.** Three bars.
> - **Source-level AFL** — the gold standard — hits four thousand seven
>   hundred and ninety executions per second.
> - **RetroWrite + AFL** — four thousand two hundred and forty-four,
>   which is **eighty-eight-point-six percent** of source speed.
> - **QEMU-mode AFL** — the usual source-free alternative — just eight
>   hundred exec per second, about five-point-three times slower.
>
> So RetroWrite gives you nearly the performance of source-level AFL
> without requiring source. That's the midterm claim, reproduced.

---

## Slide 13 — Endterm results   (~80s)

> And the endterm — our three extensions evaluated, one row each.
>
> **Row one, E1 — rep-movs ASan.** We compiled a test with a deliberate
> memcpy overflow — fifty bytes into a ten-byte destination. Baseline
> binary, meaning stock RetroWrite, gives us a `DEADLYSIGNAL` — an
> uncategorised SEGV. With our pass enabled, we get an ASan `READ of
> size 1` — a precise, actionable report showing exactly which end of
> the buffer overflowed. Silent corruption becomes a diagnosed bug.
>
> **Row two, E2 — coverage.** Baseline: zero blocks recorded, because
> the pass doesn't exist upstream for x86-64. After our pass, all twenty
> out of twenty basic blocks in the test program are recorded in the
> bitmap — every hash bucket populated as expected.
>
> **Row three, E3 — tracer.** Baseline: zero functions logged — again,
> the pass doesn't exist upstream. After our pass, all seven function
> calls in `test_trace.c` are captured in the circular 64K-entry buffer
> and optionally streamed via `write(2)` to stderr.
>
> Each pass is opt-out-able — set `DISABLE_REP_FIX`, `DISABLE_COVERAGE`,
> or `DISABLE_TRACE` to skip it at rewrite time. This makes it easy to
> A/B compare with the baseline, and means our work **composes** cleanly
> with anything else RetroWrite does.

---

## Slide 14 — Future work   (~60s)

> Six concrete next passes — not hand-waves, but things we scoped during
> the project.
>
> **One — non-PIE binaries.** We depend on relocations. Miller et al.'s
> 2019 *Probabilistic Disassembly* at ICSE shows how to fall back to
> statistical disassembly when relocations aren't available.
>
> **Two — stack canaries.** A simple prologue / epilogue pass would add
> a stack cookie around every function, catching CWE-121 stack-based
> overflows.
>
> **Three — per-object redzones.** DWARF debug info, when present, tells
> us exact boundaries of every local and global variable. We can emit
> fine-grained redzones instead of the coarse allocator-level ones ASan
> uses by default.
>
> **Four — forward-edge CFI.** Using Intel's Control-Flow Enforcement
> Technology — CET — we can validate indirect call targets.
>
> **Five — call-graph export.** Extend E3 to dump a DOT graph at program
> exit. Callgrind-style analysis, but on stripped binaries.
>
> **Six — trace-guided fuzzing.** Combine E2's bitmap with E3's
> call-stack as input to a fuzzer like Angora — richer than coverage alone.
>
> Each item maps to an open CWE or a clear gap in the literature.

---

## Slide 15 — Summary   (~60s)

> To wrap up.
>
> Three hero numbers up top.
> **Under six hundred lines of new Python** — that's all of E1, E2, E3
> combined, including their tests.
> **Zero lines changed in `librw_x64`** — the core rewriter is untouched.
> We add, we don't modify. That is deliberate — it means our work
> composes cleanly with anything else RetroWrite ships.
> **Three new passes shipped** — all working, all tested, all toggleable.
>
> Three takeaways below.
> **We reproduced the paper** — bzip2 round-trips with zero diff, AFL
> throughput hits eighty-eight percent of source, and RetroWrite is
> five-point-three times faster than QEMU-mode AFL.
> **We closed a TODO in upstream** — `rep movs` and `rep stos` are now
> instrumented, and a silent SEGV becomes a precise ASan report.
> **We added coverage and a tracer** — the x86-64 coverage pass is about
> two hundred and forty lines; the tracer is about three hundred and
> thirty; and every pass is toggleable.
>
> The meta-message — the bar at the bottom — is that relocation-guided
> rewriting is not a one-off trick. It's an **extensible platform**.
> Three people, one semester, six hundred lines of Python, three new
> passes. Thank you.

---

## Slides 16 and 17 — References   (~10s each)

> Slides sixteen and seventeen are our references in IEEE format — every
> citation from the prior slides resolves to a line here. I'll leave the
> references up during the Q&A.
>
> We're happy to take any questions now.

---

## Timing check

| Section                         | Slides | Estimated time |
|---------------------------------|--------|----------------|
| Intro + motivation + trilemma   | 1–3    | ~3:35          |
| Background + related work       | 4–6    | ~3:25          |
| Problem statement               | 7–8    | ~2:00          |
| Proposed solution + details     | 9–11   | ~4:00          |
| Evaluation (midterm + endterm)  | 12–13  | ~2:35          |
| Future + summary + refs         | 14–17  | ~2:20          |
| **Total**                       |        | **~17:55**     |

Leaves 2–3 minutes of buffer. Trim wherever comfortable —
the shortest safe cuts are slides 5, 8, 14.

---

## Appendix A — Anticipated questions and suggested answers

These are the questions the panel is most likely to ask. Rehearse the
short answer and keep the long version in reserve.

---

**Q1. Why does RetroWrite only work on PIE binaries? Can't you use it on
legacy non-PIE executables?**

> Short answer: no, and that's a deliberate design choice.
>
> The whole soundness argument rests on `.rela.dyn` — the relocation
> table. The loader uses that table to fix up address-valued immediates
> at load time, which means every byte in the code section that is an
> address is already labelled. We reuse those labels for symbolisation,
> which is why our disassembly is exact rather than heuristic.
>
> Non-PIE binaries don't carry that table — the kernel loads them at a
> fixed address and the linker bakes absolute addresses in at link time.
> Without the oracle, we're back in Uroboros / ramblr territory —
> heuristic guessing, reassembled binaries that crash.
>
> That's listed on slide 14 as one of our future-work items:
> probabilistic disassembly, following Miller et al. ICSE 2019, is the
> usual fallback, and it trades soundness for broader applicability.

---

**Q2. How does `rep movs` differ from a regular `mov` loop? Why is it
hard to instrument?**

> `rep movsb` is a single instruction that performs a variable-length
> block copy. The CPU reads `%rcx` to decide how many bytes to copy, then
> copies from `(%rsi)` to `(%rdi)` in a tight microcode loop.
>
> The hard part for ASan is that the upstream pass instruments each
> load and store individually, and that works fine for discrete `mov`
> instructions. But `rep movsb` doesn't expose its internal loads and
> stores — it's one instruction from the disassembler's point of view,
> and you can't insert instrumentation in the middle.
>
> So you have to treat it specially. We emit four probes at the endpoints
> of the source and destination ranges — `(%rdi)`, `(%rdi, %rcx)`,
> `(%rsi)`, `(%rsi, %rcx)`. That catches the off-by-one-at-either-end
> case, which is what real CWE-120 bugs look like. It won't catch
> middle-of-the-range poisoning, but in practice ASan's redzones wrap
> allocations, so the endpoints are where the interesting violations
> happen.

---

**Q3. Why only x86-64 coverage? Why didn't you do ARM64 too?**

> The original paper's ARM64 coverage pass already exists upstream —
> it's in `rwtools_arm64/`. The gap is specifically on x86-64, which is
> the platform almost all real-world fuzzing happens on.
>
> Porting coverage to x86-64 was non-trivial because the ABI constraints
> differ: register-spill cost, calling conventions, and the way Linux
> shared memory is mapped. Our pass uses a raw `mmap` syscall to avoid
> linking against AFL's runtime, which makes the rewritten binary
> self-contained.

---

**Q4. The tracer adds a trampoline to every function entry. What's the
overhead? Doesn't that slow the binary significantly?**

> Per call, the trampoline does: one stack re-align, nine register
> pushes, a `leaq`, a `call`, then the reverse on return. On modern
> x86-64 that's roughly twenty to forty cycles of overhead per traced
> function — well under a microsecond.
>
> For a typical program with a call rate in the low millions per second,
> that's about one to two percent overall. For a call-heavy workload
> like a tree walker, you can see five to ten percent. Still far below
> Pin's two-to-five-x.
>
> If overhead matters, you set `DISABLE_TRACE=1` at rewrite time and the
> trampolines are never emitted.

---

**Q5. How do you handle indirect calls? Virtual dispatches, function
pointers?**

> For E3, we trampoline on the callee side — at the function's first
> instruction — not at the caller. So it doesn't matter how the call
> reached us. Direct, indirect, via a function pointer, or through a
> vtable entry — the callee's prologue runs either way, and our
> trampoline sits there.
>
> That said, we do need a list of function entry points. We get those
> from the binary's symbol table when it's available. For stripped
> binaries without symbols, we fall back to the instructions Capstone
> flags as call targets during disassembly. It's not perfect — we might
> miss a function that's only reached through dynamic dispatch and
> isn't in the symbol table — but for the typical stripped-but-not-
> obfuscated binary it's sound.

---

**Q6. What's the soundness limitation? You claim exact symbolisation —
are there edge cases where it fails?**

> Yes. Three main ones.
>
> **One** — if the binary is not PIE, `.rela.dyn` doesn't exist and
> we degrade to heuristics.
>
> **Two** — if the binary has been stripped *and* had its relocations
> discarded — for example via `objcopy --strip-all` with the relocation
> section removed — we lose the oracle.
>
> **Three** — hand-written assembly that computes addresses through
> arithmetic on non-relocated constants. This is rare in real binaries,
> but it exists in some high-performance math libraries. RetroWrite's
> paper discusses this and ours inherits the same caveat.

---

**Q7. How does your work compare with E9Patch?**

> E9Patch and RetroWrite are neighbours in the landscape — both static,
> both sound, both fast. The difference is *mechanism*.
>
> E9Patch rewrites by patching trampolines at arbitrary binary
> offsets — you don't disassemble the whole binary, you just punch in
> jumps where you want instrumentation. That makes E9Patch great for
> lightweight, surgical instrumentation, but hard to use for full ASan
> or coverage passes that need to reason about every instruction.
>
> RetroWrite disassembles and reassembles everything, with symbolic
> operands. That gives you full semantic access — which is why ASan-
> style instrumentation works there and is harder with E9Patch.
>
> Our three passes specifically need that semantic access — we rewrite
> memory accesses and insert calls, which is in RetroWrite's comfort
> zone.

---

**Q8. Why did you pick environment-variable toggles instead of CLI flags?**

> Mostly pragmatics. The RetroWrite CLI contract is
> `python3 retrowrite -m <module> <input> <output>`, and adding new
> per-module flags would have meant modifying the core argument parser.
>
> Environment variables let each module read its own config without
> touching the core. `DISABLE_REP_FIX=1`, `DISABLE_COVERAGE=1`,
> `DISABLE_TRACE=1`, `RETRO_TRACE_PRINT=1`. Same pattern across all
> three passes, consistent mental model.
>
> Also, environment variables compose cleanly with shell scripts and CI —
> if you want to sweep across configurations, a `for` loop setting
> different env vars is shorter than rebuilding CLI arguments.

---

**Q9. Does the rewritten binary work on every Linux distribution?**

> It depends on two things: the glibc version and the AFL-compiler-rt
> linkage.
>
> For E1 (ASan), the rewritten binary links against `libasan.so`, so
> the target system needs a compatible ASan runtime. Ubuntu 22 / 24 work
> out of the box. Alpine (musl) would not.
>
> For E2 (coverage), because we `mmap` the bitmap ourselves, the binary
> is self-contained — works anywhere.
>
> For E3 (tracer), we use `write(2)` directly via syscall — also
> self-contained.
>
> We tested on Ubuntu 24 with AFL++ 4.30c and gcc 13. Portability
> outside that matrix is future work.

---

**Q10. Your coverage uses raw `mmap`. Doesn't that break if `mmap`
fails — say, in a sandboxed environment?**

> Good question. If `mmap` fails, we currently bail with a perror and
> the binary continues without coverage — the instrumentation becomes
> a no-op. We chose graceful degradation over a hard abort because in
> a fuzzing loop you don't want a transient `mmap` failure to kill the
> run.
>
> For a sandboxed environment where `mmap` is restricted — a seccomp
> filter that disallows it — we'd need to fall back to a pre-allocated
> static BSS region. That's about a twenty-line change and is on the
> follow-up list.

---

**Q11. Can your three passes run simultaneously, or do they conflict?**

> They run simultaneously by default, and they are designed to compose.
>
> E1 (rep-movs ASan) works only when the ASan pass is active — it
> piggybacks on the existing shadow-memory machinery. E2 (coverage) and
> E3 (tracer) are fully independent — different trampolines, different
> memory regions, different toggle flags.
>
> Running all three together on bzip2 gave us ASan reports, a populated
> coverage bitmap, and a trace stream in one rewrite.

---

## Appendix B — Demo command cheat-sheet

If you plan to run a live demo during Q&A, here are the commands to have
ready. These all live in `scripts/09_extension_demo.sh`.

**Rewrite with all three passes:**
```bash
python3 -m retrowrite.retrowrite -m asan    src/test_rep_movs.c    out/rep.s
python3 -m retrowrite.retrowrite -m coverage src/test_coverage.c   out/cov.s
python3 -m retrowrite.retrowrite -m trace    src/test_trace.c      out/trace.s
```

**Rebuild and run:**
```bash
gcc -no-pie -fsanitize=address out/rep.s   -o out/rep
gcc -no-pie                    out/cov.s   -o out/cov
gcc -no-pie                    out/trace.s -o out/trace
RETRO_TRACE_PRINT=1 ./out/trace
```

**Disable a pass at rewrite time:**
```bash
DISABLE_REP_FIX=1   python3 -m retrowrite.retrowrite -m asan     ...
DISABLE_COVERAGE=1  python3 -m retrowrite.retrowrite -m coverage ...
DISABLE_TRACE=1     python3 -m retrowrite.retrowrite -m trace    ...
```

**Expected outputs during demo:**

| Binary       | Output                                              |
|--------------|-----------------------------------------------------|
| `out/rep`    | `AddressSanitizer: heap-buffer-overflow ... READ of size 1` |
| `out/cov`    | `COVERAGE: 20/20 basic blocks recorded`             |
| `out/trace`  | `[TRACE] main` → `process_data` → `helper_a` → `compute` → `cleanup` |

If the panel asks "show me this works", run `out/rep` first — the ASan
report is the most visually striking.

---

## Appendix C — Stage presence tips

- **Speak slowly on slide 2.** The 70% stat is the hook — let it land.
- **Point at the green box on slide 4** when you say "this is where
  soundness lives." It's the single most important visual cue in the deck.
- **Don't read the code snippet on slide 10** — paraphrase. "Upstream
  literally wrote `pass` and a TODO comment" is better than reading the
  lines verbatim.
- **If you stumble, pause.** Silence reads as confidence. Filler words
  (um, so, like) read as nerves.
- **On slide 15, look up** when you say "relocation-guided rewriting
  is an extensible platform." It's your closing line — sell it.
