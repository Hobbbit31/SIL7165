"""
Extension 2: Basic Block Coverage Pass for x86-64
=================================================

NSS Course Project - Extension 2
Authors: [our team]

WHAT THIS DOES:
    RetroWrite originally had no standalone coverage pass for x86-64 binaries.
    This extension adds one. It instruments every basic block (entry point of
    a straight-line code sequence) with a tiny trampoline that increments a
    counter in a shared bitmap.

HOW IT WORKS:
    We use the same edge-hashing scheme as AFL (American Fuzzy Lop):
        bitmap[cur_block_id XOR prev_block_id] += 1
        prev_block_id = cur_block_id >> 1
    This tracks which *edges* (transitions between blocks) were taken, not just
    which blocks were visited. Edge coverage is better because it can distinguish
    A->B->C from A->C->B even if both visit the same blocks.

WHY WE BUILT THIS:
    The paper mentions AFL instrumentation but it's tightly coupled to the fuzzer.
    A standalone coverage pass is useful for just measuring how much of a binary
    gets exercised by a test suite — without needing AFL at all.

RUNTIME:
    We allocate the bitmap via raw mmap syscall in a .init_array constructor,
    so there's no libc dependency for the allocation itself.

Usage:
    python3 retrowrite -m coverage <binary> <output.s>
    clang -o <output> <output.s>

    Set DISABLE_COVERAGE=1 to turn this off for demo comparison.
"""

import os
import random
from collections import defaultdict

from librw_x64.container import (DataCell, InstrumentedInstruction, DataSection,
                                 Function)


# 64KB bitmap — same size as AFL uses. Each byte is a counter for one edge.
# We use a power of 2 so we can do (id & (MAP_SIZE-1)) for fast modulo.
MAP_SIZE = (1 << 16)

# These are arbitrary high addresses used as unique IDs for the new sections
# and functions we inject. RetroWrite's container system needs unique addresses
# to tell our injected code apart from the original binary's code.
COV_SECTION_NAME = ".cov_payload"
COV_SECTION_BASE = 0x4000000000000000
COV_INIT_FN = "coverage.module_ctor"
COV_INIT_LOC = 0x5000000000000000

# Compiler-generated functions that we skip — instrumenting these would just
# add noise and could break the init/fini sequence.
SKIP_FUNCTIONS = [
    "call_weak_fn", "__libc_csu_init", "_init", "_fini",
    "register_tm_clones", "deregister_tm_clones",
    "__do_global_dtors_aux", "frame_dummy",
    "_start",
]


class Instrument():
    def __init__(self, rewriter):
        self.rewriter = rewriter
        self.bb_count = 0
        self.coverage_stats = defaultdict(int)

    def _get_trampoline(self, block_id, instruction):
        """Generate the assembly trampoline injected at each basic block entry.

        This is the core of the coverage pass. The trampoline does:
          1. Save registers (rax, rcx) and CPU flags — we can't clobber anything
          2. Load the bitmap pointer from our global __cov_area_ptr
          3. XOR current block ID with previous block ID (edge hashing)
          4. Increment the byte at bitmap[xor_result]
          5. Update prev_loc = cur_id >> 1 (the shift prevents A->A from being invisible)
          6. Restore everything

        We use .format() instead of % for string formatting because the assembly
        contains %rax, %rcx etc. and Python's % formatting would choke on those
        (it tries to interpret %r as a format specifier and crashes).
        """
        label = "COV_BB_%x" % instruction.address
        exit_label = ".LCOV_EXIT_%x" % instruction.address
        code = (
            "\tpushq %rax\n"
            "\tlahf\n"
            "\tseto %al\n"
            "\tpushq %rax\n"
            "\tpushq %rcx\n"
            "\tleaq __cov_area_ptr(%rip), %rax\n"
            "\tmovq (%rax), %rax\n"
            "\ttestq %rax, %rax\n"
            "\tjz {exit_label}\n"
            "\tleaq __cov_prev_loc(%rip), %rcx\n"
            "\txorq ${block_id}, (%rcx)\n"
            "\tmovq (%rcx), %rcx\n"
            "\tincb (%rax, %rcx)\n"
            "\tleaq __cov_prev_loc(%rip), %rcx\n"
            "\tmovq ${block_id_shifted}, (%rcx)\n"
            "{exit_label}:\n"
            "\tpopq %rcx\n"
            "\tpopq %rax\n"
            "\tadd $0x7f, %al\n"
            "\tsahf\n"
            "\tpopq %rax"
        ).format(
            block_id=block_id,
            block_id_shifted=block_id >> 1,
            exit_label=exit_label
        )

        comment = "coverage: bb %d @ %x" % (block_id, instruction.address)
        return InstrumentedInstruction(code, label, comment)

    def instrument_basic_blocks(self):
        """Walk every function in the binary and inject coverage at each basic block.

        A "basic block" is a straight-line code sequence with one entry and one exit.
        RetroWrite already identifies basic block boundaries for us (stored in fn.bbstarts),
        so we just iterate and inject our trampoline at each entry point.

        Each block gets a random ID (0 to MAP_SIZE-1). Random is fine because
        collisions are rare with 64K possible IDs and typically a few hundred blocks.
        """
        for addr, fn in self.rewriter.container.functions.items():
            if fn.name in SKIP_FUNCTIONS:
                continue
            if fn.instrumented:
                continue

            for idx, instruction in enumerate(fn.cache):
                if isinstance(instruction, InstrumentedInstruction):
                    continue

                # A basic block starts at index 0 (function entry) or at any
                # address that RetroWrite identified as a jump target
                is_bb_entry = (idx == 0) or (instruction.address in fn.bbstarts)
                if not is_bb_entry:
                    continue

                block_id = random.randint(0, MAP_SIZE - 1)
                iinstr = self._get_trampoline(block_id, instruction)
                instruction.instrument_before(iinstr)

                self.bb_count += 1
                self.coverage_stats[fn.name] += 1

    def instrument_coverage_runtime(self):
        """Inject the coverage runtime into the binary.

        This creates:
          1. A data section with globals: __cov_area_ptr (bitmap pointer), __cov_prev_loc
          2. A constructor function (added to .init_array) that allocates the bitmap

        The constructor runs before main() because it's in .init_array. It uses a raw
        mmap syscall (syscall #9) to allocate memory — we can't use malloc because
        the C runtime might not be fully initialized yet when .init_array runs.
        """
        # Add coverage data section with area pointer and prev_loc
        ds = DataSection(COV_SECTION_NAME, COV_SECTION_BASE, 0, None)
        ds.cache.append(DataCell.instrumented(
            ".section .data.coverage, \"aw\", @progbits", 0))
        ds.cache.append(DataCell.instrumented(
            ".globl __cov_area_ptr", 0))
        ds.cache.append(DataCell.instrumented(
            "__cov_area_ptr: .quad 0", 8))
        ds.cache.append(DataCell.instrumented(
            ".globl __cov_prev_loc", 0))
        ds.cache.append(DataCell.instrumented(
            "__cov_prev_loc: .quad 0", 8))
        ds.cache.append(DataCell.instrumented(
            ".globl __cov_map_size", 0))
        ds.cache.append(DataCell.instrumented(
            "__cov_map_size: .quad %d" % MAP_SIZE, 8))
        self.rewriter.container.add_section(ds)

        # Add init function that allocates the bitmap via mmap
        section = self.rewriter.container.sections[".init_array"]
        constructor = DataCell.instrumented(
            ".quad %s" % COV_INIT_FN, 8)
        section.cache.append(constructor)

        initfn = Function(COV_INIT_FN, COV_INIT_LOC, 0, "")
        initfn.set_instrumented()
        init_code = (
            "\t.align 16, 0x90\n"
            "\tpushq %rax\n"
            "\tpushq %rdi\n"
            "\tpushq %rsi\n"
            "\tpushq %rdx\n"
            "\tpushq %r10\n"
            "\tpushq %r8\n"
            "\tpushq %r9\n"
            "\t# mmap(NULL, MAP_SIZE, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0)\n"
            "\txorq %rdi, %rdi\n"
            "\tmovq ${map_size}, %rsi\n"
            "\tmovq $3, %rdx\n"
            "\tmovq $0x22, %r10\n"
            "\tmovq $-1, %r8\n"
            "\txorq %r9, %r9\n"
            "\tmovq $9, %rax\n"
            "\tsyscall\n"
            "\tleaq __cov_area_ptr(%rip), %rdi\n"
            "\tmovq %rax, (%rdi)\n"
            "\tpopq %r9\n"
            "\tpopq %r8\n"
            "\tpopq %r10\n"
            "\tpopq %rdx\n"
            "\tpopq %rsi\n"
            "\tpopq %rdi\n"
            "\tpopq %rax\n"
            "\tretq"
        ).format(map_size=MAP_SIZE)

        initcode = InstrumentedInstruction(init_code, None, None)
        initfn.cache.append(initcode)
        self.rewriter.container.add_function(initfn)

    def do_instrument(self):
        if os.environ.get("DISABLE_COVERAGE") == "1":
            print("[!] DISABLE_COVERAGE=1: Coverage instrumentation DISABLED (Extension 2 OFF)")
            print("[!] Binary will be rewritten but WITHOUT coverage tracking.")
            return
        self.instrument_basic_blocks()
        self.instrument_coverage_runtime()
        self.dump_stats()

    def dump_stats(self):
        print("[*] Coverage: Instrumented %d basic blocks across %d functions" %
              (self.bb_count, len(self.coverage_stats)))
        top_fns = sorted(self.coverage_stats.items(), key=lambda x: -x[1])[:10]
        for fn_name, count in top_fns:
            print("    %s: %d blocks" % (fn_name, count))
