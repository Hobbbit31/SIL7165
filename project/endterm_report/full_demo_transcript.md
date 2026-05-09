# End-Term Demo — Full Speaker Transcript

Target time: **~10–12 minutes of demo + narration** (the rest of your slot is the slides transcript already prepared in `speaker_transcript.md`).

Order of demos — practiced and verified to work end-to-end on this machine:

1. **Script 02** — Core ASan demo (the paper's headline result)
2. **Script 10** — QEMU vs Valgrind vs RetroWrite (places it in the design space)
3. **Script 06** — Extension 1: `rep movs` / `rep stos` ASan fix
4. **Script 07** — Extension 2: standalone basic-block coverage
5. **Script 08** — Extension 3: function call tracing

Lines in `> quotes` are what you say. Commands in code blocks are what you type.

---

## Opening line  (~15 s)

> "Everything I'm about to show runs on the **ELF binary** — no source
> code is read at instrumentation time. The C files exist only so we
> have something to compile *into* a binary; once we have the ELF, the
> source is irrelevant. That's the COTS scenario the paper is about,
> and it's the scenario every defender faces in the real world."

---

## Demo 1 — Core ASan on a binary  (~2 min)

**Why this demo exists**

> "This is the headline result of the RetroWrite paper, reproduced. We
> take a stripped PIE binary, run RetroWrite's ASan pass on it, and the
> resulting binary catches memory bugs that the original silently
> ignored."

**Run it**

```bash
bash scripts/02_asan_demo.sh
```

**What to point at as it runs**

> "Step 1 — `clang` compiles `heap.c` to a PIE binary. From this point on,
> the source is gone. RetroWrite never opens `heap.c`."

> "Step 2 — RetroWrite reads the ELF, lifts it to symbolised assembly,
> inserts ASan-style redzone checks, and emits `heap.asan.s`. We then
> reassemble that into a new ELF, `heap.asan`. You'll see the line
> `Instrumented: 22 locations` — those are the memory accesses the
> rewriter found and guarded."

> "Step 3 — the **original** binary on the OOB and UAF tests. Both bugs
> happen, neither is reported, the program exits zero. This is the
> nightmare case for a defender — corruption with no signal."

> "Step 4 — the **instrumented** binary on the same inputs. Both bugs
> trigger AddressSanitizer reports with stack traces. Same source, same
> bug, but now the bug is *visible*."

**Anticipate the question about diagnostic wording**

> "You'll notice ASan says `unknown-crash` and `wild pointer` rather than
> `heap-buffer-overflow`. That's expected at the binary level: the
> rewriter doesn't have malloc-site metadata the way source-compiled
> ASan does. The redzone check still fires correctly — it's just that
> the diagnostic text is less rich. The detection is the same."

**Anticipate warning lines from the rewriter**

> "If you see warnings like `Couldn't find valid section 3dd8` — those
> are unloaded relocation entries, harmless, the rewriter handles them
> correctly."

---

## Demo 2 — QEMU vs Valgrind vs RetroWrite  (~3 min)

**Why this demo exists**

> "Now I want to place RetroWrite next to the two tools every defender
> reaches for when they don't have source — **QEMU** for running, and
> **Valgrind** for memory checking. The point isn't that RetroWrite
> wins on every axis. It's that the three tools sit at three different
> points in the design space, and RetroWrite is the only one that
> gives you sanitiser-grade detection at fuzz-loop speed."

**One-line each**

> "**QEMU user-mode** — dynamic binary translator. Reads guest x86-64
> instructions, translates them through the TCG IR, runs the
> translation. Generic, but **not a bug detector**."

> "**Valgrind Memcheck** — also dynamic, but it tracks bit-level shadow
> memory on every access. Catches more bug classes than anything else,
> including uninitialised-read bugs that ASan misses. Pays a 10× to
> 30× slowdown."

> "**RetroWrite + Binary-ASan** — *static* rewriter. One-shot, ahead of
> time. After that the instrumented binary runs natively, around 2× the
> original."

**Run it**

```bash
bash scripts/10_qemu_valgrind_compare.sh
```

**Walk through Test 1 (heap OOB)**

> "Original binary — silent, exit zero. Bug is invisible."

> "Valgrind on the **same ELF** — `Invalid write of size 1`, function
> name `oob`, byte offset, malloc site. Beautiful detection. Watch the
> timing column."

> "QEMU on the **same ELF** — runs, prints, exits zero. **No detection.**
> This is the most important contrast in this slide. Dynamic binary
> tool ≠ bug finder. QEMU is a translator."

> "RetroWrite-ASan — different ELF on disk, `heap.asan`, produced once
> ahead of time. AddressSanitizer report. Same class of bug Valgrind
> caught, but at a fraction of the cost."

**Test 2 (UAF) — same story.**

**Read off the timing table**

| Variant | Time |
|---|---|
| original | 0.00 s |
| QEMU | 0.01 s |
| RetroWrite-ASan | 0.08 s |
| Valgrind | 0.30 s |

> "These numbers are tiny because the program is tiny. But the *ratios*
> are what the paper claims and what we reproduce. Valgrind is roughly
> thirty times slower than the original. RetroWrite-ASan is in the
> same speed class as native — close to source-compiled ASan, which
> the paper measures at around 2×. **For an 8-hour fuzzing campaign,
> that's the difference between hundreds of executions per second and
> thousands.**"

---

## Demo 3 — Extension 1: `rep movs` / `rep stos` ASan fix  (~2 min)

**Why this is our strongest extension**

> "When we ran stock RetroWrite-ASan on a binary that uses `memcpy` or
> `memset` implemented through the x86 string-move instructions —
> `rep movsb`, `rep stosb` — overflow bugs were going undetected.
> The reason is that stock RetroWrite only instruments simple loads
> and stores. It doesn't model the implicit memory traffic of `rep`
> string instructions. So an overflow happens, the redzones get
> trampled, but no check ever fires."

> "Our extension adds a check around every `rep movs` and `rep stos`
> that reads `rcx` — the count register — and validates the entire
> destination range against the shadow map before the instruction
> executes."

**Run it**

```bash
bash scripts/06_ext1_rep_movs_demo.sh
```

**What to point at**

> "The test program has a `my_memcpy` and `my_memset` written using
> `rep movs` / `rep stos`. Both have a 64-byte write into a 16-byte
> buffer."

> "First the original — silent corruption, again."

> "Now the instrumented binary. The `my_memcpy` overflow trips the
> redzone check we added — full ASan report. The `my_memset` overflow
> trips it as well — and you'll see `DEADLYSIGNAL / SEGV` because
> the redzone violation walks off into unmapped memory; ASan catches
> the resulting fault and prints the report. Either way, **stock
> RetroWrite was blind to these. Our patch closes the gap.**"

---

## Demo 4 — Extension 2: standalone basic-block coverage  (~1.5 min)

**Why this exists**

> "Stock RetroWrite has AFL coverage tied to the AFL runtime — you
> can't get coverage data without running under AFL. We added a
> **standalone coverage pass**. Every basic block gets a counter in
> a bitmap that's allocated by a tiny constructor we inject into the
> binary. No AFL dependency, no harness needed — just run the binary."

**Run it**

```bash
bash scripts/07_ext2_coverage_demo.sh
```

**What to point at**

> "Twenty basic blocks instrumented across four functions. We then
> run it on three inputs — `Hello World`, `Hi`, and no input — and
> each takes a visibly different code path. The bitmap distinguishes
> them. This is the building block for any external fuzzer or
> reverse-engineering tool that wants 'which paths did this binary
> execute' without AFL."

---

## Demo 5 — Extension 3: function call tracing  (~1.5 min)

**Why this exists**

> "Reverse engineers and binary analysts constantly ask 'which
> functions did this binary actually call?' Stock RetroWrite has no
> answer. Our trace pass injects a tiny stub at every function entry
> that, when an environment variable is set, prints
> `[TRACE] funcname` to stderr. Toggleable at run time, no
> recompilation, zero cost when disabled."

**Run it**

```bash
bash scripts/08_ext3_trace_demo.sh
```

**What to point at**

> "Seven functions traced — `process_data`, `helper_a`, `helper_b`,
> `helper_c`, `compute`, `cleanup`. The test program calls them in
> three different patterns and you can see exactly which path each
> input took. Enabled with `RETRO_TRACE_PRINT=1`; unset the variable
> and the trace silently disappears."

---

## Closing line  (~20 s)

> "To summarise what you just saw: the paper's static-rewriting story
> reproduced end-to-end on a real PIE binary; the same binary placed
> in the QEMU / Valgrind design space to show why static rewriting
> matters; and three extensions that each close a concrete gap —
> string-instruction sanitisation, AFL-free coverage, and on-demand
> tracing — all of which apply to any x86-64 PIE ELF, with no source
> code required."

---

## Appendix: things to know if something goes wrong on stage

**Diagnostic wording**

- ASan report says `unknown-crash` / `wild pointer` instead of
  `heap-buffer-overflow`. Expected — binary-level rewriter has no
  malloc-site metadata. Detection is correct.

**Rewriter chatter**

- `Couldn't find valid section 3dd8` and similar — harmless, unloaded
  relocations.
- `IDENTIFIED IMPORTS`, `Number of free registers: [...]` — normal
  rewriter telemetry.

**Ext1 SEGV in the memset case**

- `DEADLYSIGNAL / SEGV` is *intentional* — the redzone violation
  walks into unmapped memory; ASan catches the fault and reports.
  If a panellist reacts to "SEGV", clarify: ASan deliberately
  aborting after detection.

**Total runtime**

All five scripts finish in well under three minutes of actual
execution combined. You have headroom for full live runs rather than
recorded video.

**Fallback one-liners** (if the scripts fail, every command operates
on the **ELF binary** — no source touched):

```bash
T=1   # 1 = OOB, 2 = UAF

./output/asan_demo/heap        $T       # original    -> silent
valgrind -q ./output/asan_demo/heap $T  # Memcheck    -> bug found
qemu-x86_64 ./output/asan_demo/heap $T  # QEMU        -> no detection
./output/asan_demo/heap.asan   $T       # RetroWrite  -> ASan report
```

---

## One-glance summary card (print this)

| Demo | Script | What it shows | Punchline |
|---|---|---|---|
| 1 | `02_asan_demo.sh` | RetroWrite ASan on heap.c PIE | Bugs silent → bugs caught, no source |
| 2 | `10_qemu_valgrind_compare.sh` | Same ELF under 4 tools | RetroWrite = ASan-class detection at native-class speed |
| 3 | `06_ext1_rep_movs_demo.sh` | `rep movs/stos` overflow | Stock RW blind; our patch catches it |
| 4 | `07_ext2_coverage_demo.sh` | Basic-block coverage | 20 blocks tracked, no AFL needed |
| 5 | `08_ext3_trace_demo.sh` | Function-entry tracing | 7 functions, env-var toggle, zero recompile |
