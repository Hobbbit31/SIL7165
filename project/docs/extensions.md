# Possible Extensions

## Extension 1: Fix `rep movs`/`rep stos` ASan Instrumentation

**Difficulty:** Medium | **Impact:** High

The paper says ASan-retrowrite misses overflows from `rep movsb`/`rep stosb` (used by memcpy/memset). The code has a literal `pass # XXX: THIS IS A TODO` at `rwtools_x64/asan/instrument.py:320`.

**Fix:** Add shadow memory checks for both start and end of the `rep` region before these instructions.

**Files:** `rwtools_x64/asan/instrument.py:243-320`, `rwtools_x64/asan/snippets.py`

---

## Extension 2: Basic Block Coverage Pass (Easiest)

**Difficulty:** Easy | **Impact:** Medium

Create a standalone AFL-style coverage pass for x64 (the ARM64 version exists but x64 doesn't).

**What to do:** Create `rwtools_x64/coverage/instrument.py` (~60 lines). At each basic block entry, inject `inc byte [bitmap + BLOCK_ID]`.

---

## Extension 3: Stack Canary Insertion

**Difficulty:** Medium | **Impact:** Medium

Add stack canaries to binaries compiled without `-fstack-protector`. At function entry: push canary. Before every `ret`: verify canary is intact.

**Files:** Create `rwtools_x64/canary/instrument.py` (~100 lines)

---

## Extension 4: Function Call Tracing

**Difficulty:** Easy | **Impact:** Low

Add function entry/exit logging for debugging binary-only software.

**Files:** Create `rwtools_x64/trace/instrument.py` (~50 lines)

---

## Extension 5: Forward-Edge CFI

**Difficulty:** Hard | **Impact:** High

Before every indirect `call *%rax`, check if the target is a valid function entry point. Prevents code-reuse attacks (ROP/JOP).

**Files:** Create `rwtools_x64/cfi/instrument.py` (~200 lines)

---

## Quick Comparison

| Extension          | Difficulty | Lines | Addresses Paper Limitation? |
|--------------------|-----------|-------|----------------------------|
| 1. Rep prefix fix  | Medium    | ~150  | Yes (explicitly mentioned)  |
| 2. Coverage pass   | Easy      | ~60   | Missing for x64             |
| 3. Stack canary    | Medium    | ~100  | No                          |
| 4. Function trace  | Easy      | ~50   | No                          |
| 5. Forward-edge CFI| Hard      | ~200  | No                          |
