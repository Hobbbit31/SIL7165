# Demo Speaker Script

Use this while running the live demo scripts in order:

1. `scripts/02_asan_demo.sh`
2. `scripts/06_ext1_rep_movs_demo.sh`
3. `scripts/07_ext2_coverage_demo.sh`
4. `scripts/08_ext3_trace_demo.sh`
5. `scripts/12_afl_find_all_bugs_random.sh`

Keep the tone simple and direct. The lines in quotes are what you can say.

## Opening

> This project is about taking RetroWrite, which rewrites PIE ELF binaries into assembly, and extending it with three practical passes: a fix for `rep movs` and `rep stos` ASan blind spots, a standalone coverage pass, and a function call tracing pass.
>
> The main idea is binary-only instrumentation. We start from compiled code, not source code, and still add useful security and analysis features.

## Demo 1: Core ASan

> I’ll start with the core RetroWrite result: adding AddressSanitizer to a binary without source code.
>
> First, the original binary runs and the bugs are silent. That is the problem RetroWrite tries to solve.
>
> Next, the RetroWrite-instrumented binary reports the memory bug through ASan. The important part is not just that the program crashes, but that the bug becomes visible and actionable.
>
> This shows the base capability that all of the extensions build on.

## Demo 2: Extension 1, rep movs / rep stos ASan fix

> This extension closes a blind spot in binary-level ASan.
>
> x86-64 often uses `rep movsb` and `rep stosb` for low-level memory copy and memory set operations. Without this fix, those instructions can escape ASan instrumentation.
>
> I’ll first show the original binary. The overflow happens, but there is no protection, so the bug is silent.
>
> Then I’ll show RetroWrite ASan with the rep fix disabled. That simulates the old behavior. The dangerous `rep movsb` path is still not properly handled.
>
> Finally, I’ll show the rep fix enabled. At that point RetroWrite adds boundary checks around the repeated string instruction, so the overflow becomes visible to ASan instead of being missed.
>
> For the presentation, I should be careful here: the exact ASan label may vary. The key point is that the `rep movsb` path is no longer invisible.

## Demo 3: Extension 2, standalone coverage

> This extension adds path visibility to a binary without needing AFL.
>
> The original binary still runs normally, but it does not expose which internal paths were executed.
>
> With the coverage pass disabled, the binary is still rewritten, but zero basic blocks are instrumented.
>
> With the coverage pass enabled, RetroWrite inserts counters at basic-block entries. In this demo, it instruments 20 basic blocks across 3 functions.
>
> The output stays the same, but now the binary becomes measurable. That is the useful part: we can see which internal paths an input exercised.

## Demo 4: Extension 3, function tracing

> This extension makes the binary traceable at function-entry level.
>
> The original binary prints output, but it does not expose the internal call order.
>
> With tracing disabled, RetroWrite rewrites the binary but inserts zero trace points.
>
> With tracing enabled, RetroWrite inserts trace stubs at function entries. In this demo, it instruments 7 functions.
>
> When I set `RETRO_TRACE_PRINT=1`, the program prints `[TRACE]` lines showing the internal call sequence. That gives me function-level visibility without source code.

## Demo 5: AFL blind-seed run

> This final demo shows the fuzzing side.
>
> I start with blind, non-triggering seeds. I do not give AFL the magic strings `FUZZ` or `CRASH`, and I do not give it a long crashing input.
>
> AFL then mutates inputs using coverage feedback. The important part is that it can still discover deeper paths from simple seeds.
>
> In the run I care about, the fuzzer finds all three planted bug classes:
> stack overflow, heap overflow through `FUZZ`, and null dereference through `CRASH`.
>
> The point is not that AFL magically knows the answers. The point is that coverage-guided mutation plus ASan-visible crashes lets it climb toward the interesting paths.

## Closing

> To summarize the project:
>
> RetroWrite gives us a base binary-rewriting framework.
>
> Extension 1 closes a real ASan blind spot around repeated string instructions.
>
> Extension 2 gives us standalone coverage tracking on x86-64 binaries.
>
> Extension 3 gives us internal function call tracing.
>
> Together, these make binary-only analysis more practical without requiring source code.

## Short fallback lines

If you need very short lines on stage, use these:

> Core ASan: RetroWrite makes memory bugs visible in a binary.
>
> Extension 1: rep-based copy and set instructions are now instrumented.
>
> Extension 2: the binary now exposes executed paths through a coverage bitmap.
>
> Extension 3: the binary now exposes function-call order through trace output.
>
> AFL demo: blind seeds are enough when coverage feedback and ASan work together.
