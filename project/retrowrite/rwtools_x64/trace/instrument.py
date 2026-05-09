"""
Extension 3: Function Call Tracing for x86-64
==============================================

NSS Course Project - Extension 3
Authors: [our team]

WHAT THIS DOES:
    Instruments every function entry in a binary so that at runtime, we can
    see exactly which functions were called and in what order. This is useful
    for debugging binary-only software where you don't have source code.

HOW IT WORKS:
    At each function entry, we inject a trampoline that:
      1. Saves all caller-saved registers (we can't clobber anything!)
      2. Calls our __trace_log_entry function with the function name as argument
      3. Restores everything

    The log function stores the name pointer in a circular buffer (64K entries).
    If RETRO_TRACE_PRINT=1 is set in the environment, it also prints each
    function name to stderr in real time.

WHY RAW SYSCALLS:
    We initially tried using dprintf/printf for printing, but it kept segfaulting
    because of stack alignment issues — printf has internal state that requires
    16-byte aligned stack. Using the raw write() syscall (syscall #1) avoids
    all of that since it has no alignment requirements.

Usage:
    python3 retrowrite -m trace <binary> <output.s>
    clang -o <output> <output.s>
    RETRO_TRACE_PRINT=1 ./<output>      # shows [TRACE] lines on stderr

    Set DISABLE_TRACE=1 to turn this off for demo comparison.
"""

import os
from collections import defaultdict

from librw_x64.container import (DataCell, InstrumentedInstruction, DataSection,
                                 Function)


# Arbitrary high addresses used as unique IDs for our injected sections/functions.
# RetroWrite needs these to be unique so they don't collide with the original binary.
TRACE_SECTION_NAME = ".trace_payload"
TRACE_SECTION_BASE = 0x6000000000000000
TRACE_INIT_FN = "trace.module_ctor"
TRACE_INIT_LOC = 0x7000000000000000
TRACE_LOG_FN = "__trace_log_entry"
TRACE_LOG_LOC = 0x7100000000000000

# Circular buffer size — 64K entries, each storing an 8-byte pointer = 512KB total.
# Power of 2 so we can use & (TRACE_BUFFER_SIZE - 1) as a fast modulo for wrapping.
TRACE_BUFFER_SIZE = 65536

# Compiler-generated functions — tracing these would just add noise
SKIP_FUNCTIONS = [
    "call_weak_fn", "__libc_csu_init", "_init", "_fini",
    "register_tm_clones", "deregister_tm_clones",
    "__do_global_dtors_aux", "frame_dummy",
    "_start",
]


class Instrument():
    def __init__(self, rewriter):
        self.rewriter = rewriter
        self.traced_count = 0

    def _get_entry_trampoline(self, fn_name, instruction):
        """Generate the assembly trampoline injected at each function's first instruction.

        This is the trickiest part of the extension. We need to:
          1. Align the stack to 16 bytes (required by x86-64 ABI before any callq)
             - When a function is called, the return address is pushed (8 bytes)
             - We push 9 registers + 1 flags save = 10 pushes = 80 bytes
             - 8 (ret addr) + 80 = 88, which is NOT 16-byte aligned
             - So we do subq $8 first to make it 96 = 16-byte aligned
          2. Save ALL caller-saved registers — we don't know what the function uses
          3. Save CPU flags (lahf/seto trick — same approach as ASan uses)
          4. Load the function name string address and call __trace_log_entry
          5. Restore everything in exact reverse order
        """
        label = "TRACE_ENTER_%x" % instruction.address
        code = (
            "\tsubq $8, %rsp\n"
            "\tpushq %rdi\n"
            "\tpushq %rsi\n"
            "\tpushq %rax\n"
            "\tpushq %rcx\n"
            "\tpushq %rdx\n"
            "\tpushq %r8\n"
            "\tpushq %r9\n"
            "\tpushq %r10\n"
            "\tpushq %r11\n"
            "\tlahf\n"
            "\tseto %al\n"
            "\tpushq %rax\n"
            "\tleaq .LTRACE_NAME_{addr:x}(%rip), %rdi\n"
            "\tcallq {log_fn}\n"
            "\tpopq %rax\n"
            "\tadd $0x7f, %al\n"
            "\tsahf\n"
            "\tpopq %r11\n"
            "\tpopq %r10\n"
            "\tpopq %r9\n"
            "\tpopq %r8\n"
            "\tpopq %rdx\n"
            "\tpopq %rcx\n"
            "\tpopq %rax\n"
            "\tpopq %rsi\n"
            "\tpopq %rdi\n"
            "\taddq $8, %rsp"
        ).format(addr=instruction.address, log_fn=TRACE_LOG_FN)

        comment = "trace entry: %s @ %x" % (fn_name, instruction.address)
        return InstrumentedInstruction(code, label, comment)

    def instrument_function_entries(self):
        """Walk all functions in the binary and inject tracing at each entry.

        We only instrument the first instruction of each function.
        RetroWrite gives us the function boundaries, so we just iterate.
        """
        for addr, fn in self.rewriter.container.functions.items():
            if fn.name in SKIP_FUNCTIONS:
                continue
            if fn.instrumented:
                continue
            if not fn.cache:
                continue

            first_instr = fn.cache[0]
            if isinstance(first_instr, InstrumentedInstruction):
                continue

            iinstr = self._get_entry_trampoline(fn.name, first_instr)
            first_instr.instrument_before(iinstr)
            self.traced_count += 1

    def instrument_trace_runtime(self):
        """Inject the trace runtime into the binary.

        This creates 3 things:
          1. A data section with globals (buffer pointer, index, print flag, strings)
          2. A constructor (.init_array) that allocates the buffer via mmap and
             checks if RETRO_TRACE_PRINT env var is set
          3. The __trace_log_entry function that trampolines call into

        The log function does two things:
          - Always: stores the function name pointer in a circular buffer
          - If printing enabled: writes "[TRACE] <name>\n" to stderr via raw syscall

        We use the write syscall (syscall #1, fd=2 for stderr) instead of printf
        because printf requires proper stack alignment and internal state that
        can break when called from injected instrumentation code.
        """
        # Data section for trace state
        ds = DataSection(TRACE_SECTION_NAME, TRACE_SECTION_BASE, 0, None)
        ds.cache.append(DataCell.instrumented(
            ".section .data.trace, \"aw\", @progbits", 0))
        ds.cache.append(DataCell.instrumented(
            ".globl __trace_buffer_ptr", 0))
        ds.cache.append(DataCell.instrumented(
            "__trace_buffer_ptr: .quad 0", 8))
        ds.cache.append(DataCell.instrumented(
            ".globl __trace_buffer_idx", 0))
        ds.cache.append(DataCell.instrumented(
            "__trace_buffer_idx: .quad 0", 8))
        ds.cache.append(DataCell.instrumented(
            ".globl __trace_print_enabled", 0))
        ds.cache.append(DataCell.instrumented(
            "__trace_print_enabled: .quad 0", 8))
        ds.cache.append(DataCell.instrumented(
            ".globl __trace_fmt_str", 0))
        ds.cache.append(DataCell.instrumented(
            '__trace_fmt_str: .asciz "[TRACE] %s\\n"', 0))
        ds.cache.append(DataCell.instrumented(
            '__trace_prefix: .asciz "[TRACE] "', 0))
        ds.cache.append(DataCell.instrumented(
            '__trace_newline: .asciz "\\n"', 0))

        # Add function name strings
        for addr, fn in self.rewriter.container.functions.items():
            if fn.name in SKIP_FUNCTIONS or fn.instrumented or not fn.cache:
                continue
            first_instr = fn.cache[0]
            if isinstance(first_instr, InstrumentedInstruction):
                continue
            ds.cache.append(DataCell.instrumented(
                '.LTRACE_NAME_%x: .asciz "%s"' % (first_instr.address, fn.name), 0))

        self.rewriter.container.add_section(ds)

        # Add init constructor to .init_array
        section = self.rewriter.container.sections[".init_array"]
        constructor = DataCell.instrumented(
            ".quad %s" % TRACE_INIT_FN, 8)
        section.cache.append(constructor)

        # Init function — runs before main() because it's in .init_array.
        # Allocates the trace buffer via mmap and checks RETRO_TRACE_PRINT env var.
        initfn = Function(TRACE_INIT_FN, TRACE_INIT_LOC, 0, "")
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
            "\t# mmap trace buffer\n"
            "\txorq %rdi, %rdi\n"
            "\tmovq ${buf_size}, %rsi\n"
            "\tmovq $3, %rdx\n"
            "\tmovq $0x22, %r10\n"
            "\tmovq $-1, %r8\n"
            "\txorq %r9, %r9\n"
            "\tmovq $9, %rax\n"
            "\tsyscall\n"
            "\tleaq __trace_buffer_ptr(%rip), %rdi\n"
            "\tmovq %rax, (%rdi)\n"
            "\t# Check RETRO_TRACE_PRINT env var\n"
            "\tleaq .Ltrace_env_name(%rip), %rdi\n"
            "\tcallq getenv@PLT\n"
            "\ttestq %rax, %rax\n"
            "\tjz .Ltrace_init_done\n"
            "\tleaq __trace_print_enabled(%rip), %rdi\n"
            "\tmovq $1, (%rdi)\n"
            ".Ltrace_init_done:\n"
            "\tpopq %r9\n"
            "\tpopq %r8\n"
            "\tpopq %r10\n"
            "\tpopq %rdx\n"
            "\tpopq %rsi\n"
            "\tpopq %rdi\n"
            "\tpopq %rax\n"
            "\tretq\n"
            ".Ltrace_env_name:\n"
            '\t.asciz "RETRO_TRACE_PRINT"'
        ).format(buf_size=TRACE_BUFFER_SIZE * 8)

        initcode = InstrumentedInstruction(init_code, None, None)
        initfn.cache.append(initcode)
        self.rewriter.container.add_function(initfn)

        # The actual logging function. Called from every function entry trampoline.
        # %rdi = pointer to the function name string (set by the trampoline)
        # It stores the pointer in a circular buffer and optionally prints to stderr.
        logfn = Function(TRACE_LOG_FN, TRACE_LOG_LOC, 0, "")
        logfn.set_instrumented()
        log_code = (
            "\t.align 16, 0x90\n"
            "\t# rdi = pointer to function name string\n"
            "\tpushq %rax\n"
            "\tpushq %rcx\n"
            "\tpushq %rdx\n"
            "\t# Store name pointer in circular buffer\n"
            "\tleaq __trace_buffer_ptr(%rip), %rax\n"
            "\tmovq (%rax), %rax\n"
            "\ttestq %rax, %rax\n"
            "\tjz .Ltrace_log_done\n"
            "\tleaq __trace_buffer_idx(%rip), %rcx\n"
            "\tmovq (%rcx), %rdx\n"
            "\tmovq %rdi, (%rax, %rdx, 8)\n"
            "\tincq %rdx\n"
            "\tandq ${buf_mask}, %rdx\n"
            "\tmovq %rdx, (%rcx)\n"
            "\t# Check if printing is enabled\n"
            "\tleaq __trace_print_enabled(%rip), %rax\n"
            "\tmovq (%rax), %rax\n"
            "\ttestq %rax, %rax\n"
            "\tjz .Ltrace_log_done\n"
            "\t# Print function name to stderr using write syscall\n"
            "\t# First write '[TRACE] '\n"
            "\tpushq %rdi\n"
            "\tpushq %rsi\n"
            "\tpushq %r11\n"
            "\tmovq $1, %rax\n"
            "\tmovq $2, %rdi\n"
            "\tleaq __trace_prefix(%rip), %rsi\n"
            "\tmovq $8, %rdx\n"
            "\tsyscall\n"
            "\t# Now write the function name (need strlen)\n"
            "\tmovq 16(%rsp), %rsi\n"
            "\txorq %rdx, %rdx\n"
            ".Ltrace_strlen:\n"
            "\tcmpb $0, (%rsi, %rdx)\n"
            "\tje .Ltrace_strlen_done\n"
            "\tincq %rdx\n"
            "\tjmp .Ltrace_strlen\n"
            ".Ltrace_strlen_done:\n"
            "\tmovq $1, %rax\n"
            "\tmovq $2, %rdi\n"
            "\tsyscall\n"
            "\t# Write newline\n"
            "\tmovq $1, %rax\n"
            "\tmovq $2, %rdi\n"
            "\tleaq __trace_newline(%rip), %rsi\n"
            "\tmovq $1, %rdx\n"
            "\tsyscall\n"
            "\tpopq %r11\n"
            "\tpopq %rsi\n"
            "\tpopq %rdi\n"
            ".Ltrace_log_done:\n"
            "\tpopq %rdx\n"
            "\tpopq %rcx\n"
            "\tpopq %rax\n"
            "\tretq"
        ).format(buf_mask=TRACE_BUFFER_SIZE - 1)

        logcode = InstrumentedInstruction(log_code, None, None)
        logfn.cache.append(logcode)
        self.rewriter.container.add_function(logfn)

    def do_instrument(self):
        if os.environ.get("DISABLE_TRACE") == "1":
            print("[!] DISABLE_TRACE=1: Function tracing DISABLED (Extension 3 OFF)")
            print("[!] Binary will be rewritten but WITHOUT function call tracing.")
            return
        self.instrument_function_entries()
        self.instrument_trace_runtime()
        self.dump_stats()

    def dump_stats(self):
        print("[*] Trace: Instrumented %d function entries" % self.traced_count)
        print("[*] Trace buffer: %d entries (%d KB)" %
              (TRACE_BUFFER_SIZE, TRACE_BUFFER_SIZE * 8 // 1024))
