.section .fini_array
	.quad asan.module_dtor
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
.section .init_array
.align 8
	.quad asan.module_ctor
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
.LC_ASAN_ENTER_1145: # 1145: cmpb $0x43, (%rdi): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  (%rdi), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4421
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4421
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4421:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpb $0x43, (%rdi)
.LC1148:
	jne .LC1154
.LC114a:
.LC_ASAN_ENTER_114a: # 114a: cmpb $0x52, 1(%rdi): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  1(%rdi), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4426
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4426
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4426:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpb $0x52, 1(%rdi)
.LC114e:
	jne .LC1154
.LC1150:
.LC_ASAN_ENTER_1150: # 1150: cmpb $0x41, 2(%rdi): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  2(%rdi), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4432
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4432
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4432:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
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
.LC_ASAN_ENTER_1167: # 1167: movq stdin@GOTPCREL(%rip), %rax: ['rdi', 'rsi', 'rcx', 'rdx', 'rax']
		leaq stdin@GOTPCREL(%rip), %rsi
	movq %rsi, %rdi
	shrq $3, %rdi
	cmpb $0, 2147450880(%rdi)
	je .LC_ASAN_EX_4455
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4455:
	movq stdin@GOTPCREL(%rip), %rax
.LC116e:
.LC_ASAN_ENTER_116e: # 116e: movq (%rax), %rcx: ['rdi', 'rsi', 'rcx', 'rdx']
		leaq (%rax), %rsi
	movq %rsi, %rdi
	shrq $3, %rdi
	cmpb $0, 2147450880(%rdi)
	je .LC_ASAN_EX_4462
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4462:
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
	.text
	.align 2
	.p2align 4,,15
	.local asan.module_ctor
	.type asan.module_ctor, @function
asan.module_ctor:
	.cfi_startproc
    .align    16, 0x90
# BB#0:
    pushq    %rax
.Ltmp11:
    callq    __asan_init@PLT
    popq    %rax
    retq
	.cfi_endproc
	.size asan.module_ctor,.-asan.module_ctor
	.text
	.align 2
	.p2align 4,,15
	.local asan.module_dtor
	.type asan.module_dtor, @function
asan.module_dtor:
	.cfi_startproc
    .align    16, 0x90
# BB#0:
    pushq    %rax
.Ltmp12:
    popq    %rax
    retq
	.cfi_endproc
	.size asan.module_dtor,.-asan.module_dtor
