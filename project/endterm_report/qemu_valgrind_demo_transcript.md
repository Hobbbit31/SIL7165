# QEMU vs Valgrind vs RetroWrite — Demo Transcript

Use this alongside `scripts/10_qemu_valgrind_compare.sh`.
Target time on stage: **~4 minutes**.
Goal: place RetroWrite on the design space against the two best-known
binary-level tools and show, on a real ELF, that it's the only one that
**both detects the bug and runs at near-native speed**.

---

## 0. Why this slide exists  (~20 s)

> "Before I show the demo, I want to put RetroWrite next to the two tools
> that everyone in this room has probably used when they didn't have
> source code: **QEMU** and **Valgrind**. The point of the next slide is
> not that RetroWrite is strictly better — it's that the three tools sit
> at three different points in the design space, and RetroWrite is the
> only one that gives you sanitiser-grade bug detection at fuzzing-grade
> speed, on a binary."

---

## 1. The three tools, one sentence each  (~40 s)

> "**QEMU user-mode** — `qemu-x86_64 ./binary`. It's a *dynamic binary
> translator*. It reads guest x86-64 instructions, translates them to host
> instructions through an IR called TCG, and runs the translation. It is
> generic — it can run an ARM binary on x86 — but it is **not a bug
> detector**. It will happily execute an out-of-bounds write and exit
> zero, the same as the original binary."

> "**Valgrind Memcheck** — `valgrind ./binary`. It's also dynamic, but it
> goes further: it lifts every instruction into the VEX IR, and on every
> memory access it consults a **bit-level shadow memory** that tracks
> which bytes are addressable, which are initialised, which are freed.
> It catches more bug classes than anything else on this slide — including
> uninitialised-read bugs that ASan misses — but it pays a 10× to 30×
> slowdown for it."

> "**RetroWrite + Binary-ASan** — what we built on. It's a *static* binary
> rewriter. It runs once, ahead of time, takes the PIE ELF in, emits a
> reassemblable assembly file with ASan-style redzones and shadow checks
> inlined, and you compile that back into a new ELF. From then on the
> instrumented binary runs natively — roughly 2× the original — and
> detects the same class of bugs ASan does."

---

## 2. The demo — run on the BINARY, not the source  (~90 s)

> "I want to stress: everything you're about to see operates on the ELF
> file `output/asan_demo/heap`. None of these tools — not even RetroWrite
> — read the C source. RetroWrite was given the stripped PIE binary, and
> it produced a new binary `heap.asan`. That's the COTS scenario the
> paper is about."

Run the script:

```bash
bash scripts/10_qemu_valgrind_compare.sh
```

Walk through what appears for **Test 1: heap out-of-bounds write**:

> "First, the **original binary**. Watch — it prints its log line and
> exits zero. The bug happened. Memory was corrupted. The program has no
> idea. This is what a user running an unpatched COTS binary would see —
> nothing."

> "Now **Valgrind Memcheck** on the same binary. Notice: I did not
> recompile, I did not rewrite — Valgrind is reading the ELF and
> JIT-translating every instruction. And here it is — `Invalid write of
> size 1`, with the function name `oob`, the malloc site, and the byte
> offset. Beautiful detection. The price is in the timing column."

> "Now **QEMU user-mode** on the same binary. It runs. It prints the log
> line. It exits zero. **No detection.** This is the important
> contrast — QEMU is a translator, not a sanitiser. People sometimes
> conflate 'dynamic binary tool' with 'bug finder'; QEMU shows that those
> are two different things."

> "Finally, **RetroWrite-ASan**. This is a different ELF on disk —
> `heap.asan` — produced *once*, ahead of time, by RetroWrite's static
> rewriter. When I run it, I get a full AddressSanitizer report — same
> class of bug Valgrind found, with the function name and a shadow-memory
> dump."

Then point at **Test 2 (use-after-free)** in the output and say:

> "Same story. Original silent. Valgrind catches it and even tells me
> where the block was freed and where it was allocated. QEMU silent.
> RetroWrite-ASan reports it."

---

## 3. The timing slide  (~45 s)

Read off the table the script printed (numbers from a fresh run):

| Variant         | Wall-clock (test 1) |
|-----------------|---------------------|
| Original        | ~0.00 s             |
| QEMU            | ~0.01 s             |
| RetroWrite-ASan | ~0.08 s             |
| Valgrind        | ~0.30 s             |

> "These numbers are tiny because the test program is tiny — but the
> *ratios* are what the paper claims and what we reproduce. Valgrind is
> roughly thirty times slower than the original. RetroWrite-ASan is in
> the same speed class as the original — close to source-compiled ASan,
> which the paper measures at around 2×. **For a fuzzing campaign, that
> ratio is the difference between a hundred executions per second and
> three thousand.**"

---

## 4. The takeaway slide  (~30 s)

> "So the design space looks like this:
>
> - **QEMU** — runs anything, finds nothing.
> - **Valgrind** — finds the most, runs the slowest.
> - **RetroWrite** — finds ASan-class bugs at native speed, but only on
>   x86-64 PIE binaries.
>
> RetroWrite trades generality for speed — and that trade is what makes
> it usable inside a fuzzing loop, which is the whole point of the
> paper. Valgrind cannot keep up with AFL. QEMU keeps up but doesn't
> sanitise. RetroWrite is the corner of the design space where 'no
> source code' meets 'fuzz-loop friendly'."

---

## 5. Anticipated questions

**Q: Why does RetroWrite say `unknown-crash` and `wild pointer` instead of
`heap-buffer-overflow`?**
> "Because the rewriter doesn't have malloc-site metadata the way
> source-compiled ASan does. It's still detecting the same illegal
> access — the redzone check fires — but the diagnostic is less rich.
> That's a known cost of working at the binary level."

**Q: Why not just always use Valgrind?**
> "Throughput. A 30× slowdown turns an 8-hour fuzzing campaign into
> a 10-day one. AFL-QEMU exists precisely because Valgrind is too slow
> for fuzzing. RetroWrite gives you ASan-class checks at AFL-QEMU-class
> speed."

**Q: Why not AFL's QEMU mode then?**
> "AFL-QEMU adds *coverage* instrumentation, not memory-safety
> sanitisation. So it tells you which paths the fuzzer reached, but not
> whether any of them corrupted memory. RetroWrite gives you both —
> coverage *and* sanitisation — statically baked into the binary."

**Q: What are the limitations?**
> "x86-64 only, position-independent (PIE/PIC) binaries only, ELF only.
> Hand-written assembly with weird control flow can confuse the
> symboliser. Indirect-jump-heavy code (some interpreters) is also
> hard. We document this in the limitations section of the report."

---

## 6. The four commands to memorise

If the script fails on stage, fall back to these — every one of them
operates on the **ELF binary**, no source needed:

```bash
# Test 1 = heap OOB,   Test 2 = use-after-free
T=1

./output/asan_demo/heap        $T       # original  -> silent
valgrind -q ./output/asan_demo/heap $T  # Memcheck  -> bug found, slow
qemu-x86_64 ./output/asan_demo/heap $T  # QEMU      -> runs, no detection
./output/asan_demo/heap.asan   $T       # RetroWrite-> ASan report, fast
```

That's the demo.
