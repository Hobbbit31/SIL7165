.section .rodata
.align 4
.type	_IO_stdin_used_2000,@object
.globl _IO_stdin_used_2000
_IO_stdin_used_2000: # 2000 -- 2004
.LC2000:
	.byte 0x1
.LC2001:
	.byte 0x0
.LC2002:
	.byte 0x2
.LC2003:
	.byte 0x0

.section .data
.align 8
.LC4008:
	.byte 0x0
.LC4009:
	.byte 0x0
.LC400a:
	.byte 0x0
.LC400b:
	.byte 0x0
.LC400c:
	.byte 0x0
.LC400d:
	.byte 0x0
.LC400e:
	.byte 0x0
.LC400f:
	.byte 0x0
.LC4010:
	.quad .LC4010
.section .bss
.align 1
.type	completed.0_4018,@object
.globl completed.0_4018
completed.0_4018: # 4018 -- 4019
.LC4018:
	.byte 0x0
.LC4019:
	.byte 0x0
.LC401a:
	.byte 0x0
.LC401b:
	.byte 0x0
.LC401c:
	.byte 0x0
.LC401d:
	.byte 0x0
.LC401e:
	.byte 0x0
.LC401f:
	.byte 0x0
.section .text
.align 16
.section .note.GNU-stack,"",%progbits
	.text
	.align 2
	.p2align 4,,15
	.globl process_input
	.type process_input, @function
process_input:
	.cfi_startproc
.L1140:
.LC1140:
	cmpl $5, %esi
.LC1143:
	jl .LC1154
.LC1145:
	cmpb $0x43, (%rdi)
.LC1148:
	jne .LC1154
.LC114a:
	cmpb $0x52, 1(%rdi)
.LC114e:
	jne .LC1154
.LC1150:
	cmpb $0x41, 2(%rdi)
.L1154:
.LC1154:

	retq 
	.cfi_endproc
	.size process_input,.-process_input
	.text
	.align 2
	.p2align 4,,15
	.globl main
	.type main, @function
main:
	.cfi_startproc
.L1160:
.LC1160:
	subq $0x108, %rsp
.LC1167:
	movq stdin@GOTPCREL(%rip), %rax
.LC116e:
	movq (%rax), %rcx
.LC1171:
	movq %rsp, %rdi
.LC1174:
	movl $1, %esi
.LC1179:
	movl $0x100, %edx
.LC117e:
	callq fread@PLT
.LC1183:
	xorl %eax, %eax
.LC1185:
	addq $0x108, %rsp
.LC118c:

	retq 
	.cfi_endproc
	.size main,.-main
