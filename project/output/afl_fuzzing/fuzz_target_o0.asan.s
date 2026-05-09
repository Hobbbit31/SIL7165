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
.LC4020:
	.byte 0x0
.LC4021:
	.byte 0x0
.LC4022:
	.byte 0x0
.LC4023:
	.byte 0x0
.LC4024:
	.byte 0x0
.LC4025:
	.byte 0x0
.LC4026:
	.byte 0x0
.LC4027:
	.byte 0x0
.LC4028:
	.quad .LC4028
.section .bss
.align 1
.type	completed.0_4030,@object
.globl completed.0_4030
completed.0_4030: # 4030 -- 4031
.LC4030:
	.byte 0x0
.LC4031:
	.byte 0x0
.LC4032:
	.byte 0x0
.LC4033:
	.byte 0x0
.LC4034:
	.byte 0x0
.LC4035:
	.byte 0x0
.LC4036:
	.byte 0x0
.LC4037:
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
.L1170:
.LC1170:
	pushq %rbp
.LC1171:
	movq %rsp, %rbp
.LC1174:
	subq $0x40, %rsp
.LC1178:
.LC_ASAN_ENTER_1178: # 1178: movq %rdi, -8(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -8(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	cmpb $0, 2147450880(%rsi)
	je .LC_ASAN_EX_4472
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4472:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movq %rdi, -8(%rbp)
.LC117c:
.LC_ASAN_ENTER_117c: # 117c: movl %esi, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4476
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4476
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4476:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movl %esi, -0xc(%rbp)
.LC117f:
.LC_ASAN_ENTER_117f: # 117f: cmpl $0, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4479
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4479
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4479:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $0, -0xc(%rbp)
.LC1183:
	jle .LC1221
.LC1189:
.LC_ASAN_ENTER_1189: # 1189: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4489
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4489:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC118d:
.LC_ASAN_ENTER_118d: # 118d: movsbl (%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq (%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4493
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4493
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4493:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl (%rax), %eax
.LC1190:
	cmpl $0x46, %eax
.LC1193:
	jne .LC1221
.LC1199:
.LC_ASAN_ENTER_1199: # 1199: cmpl $1, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4505
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4505
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4505:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $1, -0xc(%rbp)
.LC119d:
	jle .LC121c
.LC11a3:
.LC_ASAN_ENTER_11a3: # 11a3: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4515
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4515:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC11a7:
.LC_ASAN_ENTER_11a7: # 11a7: movsbl 1(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 1(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4519
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4519
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4519:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 1(%rax), %eax
.LC11ab:
	cmpl $0x55, %eax
.LC11ae:
	jne .LC121c
.LC11b4:
.LC_ASAN_ENTER_11b4: # 11b4: cmpl $2, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4532
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4532
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4532:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $2, -0xc(%rbp)
.LC11b8:
	jle .LC1217
.LC11be:
.LC_ASAN_ENTER_11be: # 11be: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4542
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4542:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC11c2:
.LC_ASAN_ENTER_11c2: # 11c2: movsbl 2(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 2(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4546
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4546
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4546:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 2(%rax), %eax
.LC11c6:
	cmpl $0x5a, %eax
.LC11c9:
	jne .LC1217
.LC11cf:
.LC_ASAN_ENTER_11cf: # 11cf: cmpl $3, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4559
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4559
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4559:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $3, -0xc(%rbp)
.LC11d3:
	jle .LC1212
.LC11d9:
.LC_ASAN_ENTER_11d9: # 11d9: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4569
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4569:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC11dd:
.LC_ASAN_ENTER_11dd: # 11dd: movsbl 3(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 3(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4573
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4573
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4573:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 3(%rax), %eax
.LC11e1:
	cmpl $0x5a, %eax
.LC11e4:
	jne .LC1212
.LC11ea:
	movl $8, %edi
.LC11ef:
	callq malloc@PLT
.LC11f4:
.LC_ASAN_ENTER_11f4: # 11f4: movq %rax, -0x38(%rbp): ['rdi', 'rsi', 'rdx']
		leaq  -0x38(%rbp), %rsi
	movq %rsi, %rdi
	shrq $3, %rdi
	cmpb $0, 2147450880(%rdi)
	je .LC_ASAN_EX_4596
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4596:
	movq %rax, -0x38(%rbp)
.LC11f8:
.LC_ASAN_ENTER_11f8: # 11f8: movq -0x38(%rbp), %rdi: ['rdi', 'rsi', 'rdx']
		leaq -0x38(%rbp), %rsi
	movq %rsi, %rdi
	shrq $3, %rdi
	cmpb $0, 2147450880(%rdi)
	je .LC_ASAN_EX_4600
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4600:
	movq -0x38(%rbp), %rdi
.LC11fc:
.LC_ASAN_ENTER_11fc: # 11fc: movq -8(%rbp), %rsi: ['rsi', 'rdx']
		leaq -8(%rbp), %rdx
	movq %rdx, %rsi
	shrq $3, %rsi
	cmpb $0, 2147450880(%rsi)
	je .LC_ASAN_EX_4604
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4604:
	movq -8(%rbp), %rsi
.LC1200:
.LC_ASAN_ENTER_1200: # 1200: movslq -0xc(%rbp), %rdx: ['rdx']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -0xc(%rbp), %rdi
	movq %rdi, %rdx
	shrq $3, %rdx
	movb 2147450880(%rdx), %dl
	testb %dl, %dl
	je .LC_ASAN_EX_4608
	andl $7, %edi
	addl $3, %edi
	movsbl %dl, %edx
	cmpl %edx, %edi
	jl .LC_ASAN_EX_4608
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4608:
leaq -8(%rsp), %rsp
	popq %rdi
	movslq -0xc(%rbp), %rdx
.LC1204:
	callq memcpy@PLT
.LC1209:
.LC_ASAN_ENTER_1209: # 1209: movq -0x38(%rbp), %rdi: ['rdi']
		pushq %rsi
leaq 8(%rsp), %rsp
	leaq -0x38(%rbp), %rsi
	movq %rsi, %rdi
	shrq $3, %rdi
	cmpb $0, 2147450880(%rdi)
	je .LC_ASAN_EX_4617
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4617:
leaq -8(%rsp), %rsp
	popq %rsi
	movq -0x38(%rbp), %rdi
.LC120d:
	callq free@PLT
.L1212:
.LC1212:
	jmp .LC1217
.L1217:
.LC1217:
	jmp .LC121c
.L121c:
.LC121c:
	jmp .LC1221
.L1221:
.LC1221:
.LC_ASAN_ENTER_1221: # 1221: cmpl $4, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4641
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4641
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4641:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $4, -0xc(%rbp)
.LC1225:
	jle .LC1294
.LC122b:
.LC_ASAN_ENTER_122b: # 122b: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4651
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4651:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC122f:
.LC_ASAN_ENTER_122f: # 122f: movsbl (%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq (%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4655
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4655
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4655:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl (%rax), %eax
.LC1232:
	cmpl $0x43, %eax
.LC1235:
	jne .LC1294
.LC123b:
.LC_ASAN_ENTER_123b: # 123b: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4667
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4667:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC123f:
.LC_ASAN_ENTER_123f: # 123f: movsbl 1(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 1(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4671
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4671
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4671:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 1(%rax), %eax
.LC1243:
	cmpl $0x52, %eax
.LC1246:
	jne .LC1294
.LC124c:
.LC_ASAN_ENTER_124c: # 124c: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4684
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4684:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC1250:
.LC_ASAN_ENTER_1250: # 1250: movsbl 2(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 2(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4688
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4688
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4688:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 2(%rax), %eax
.LC1254:
	cmpl $0x41, %eax
.LC1257:
	jne .LC1294
.LC125d:
.LC_ASAN_ENTER_125d: # 125d: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4701
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4701:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC1261:
.LC_ASAN_ENTER_1261: # 1261: movsbl 3(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 3(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4705
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4705
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4705:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 3(%rax), %eax
.LC1265:
	cmpl $0x53, %eax
.LC1268:
	jne .LC1294
.LC126e:
.LC_ASAN_ENTER_126e: # 126e: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4718
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4718:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC1272:
.LC_ASAN_ENTER_1272: # 1272: movsbl 4(%rax), %eax: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 4(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4722
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4722
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4722:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movsbl 4(%rax), %eax
.LC1276:
	cmpl $0x48, %eax
.LC1279:
	jne .LC1294
.LC127f:
.LC_ASAN_ENTER_127f: # 127f: movq $0, -0x40(%rbp): ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq  -0x40(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4735
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4735:
leaq -8(%rsp), %rsp
	popq %rdi
	movq $0, -0x40(%rbp)
.LC1287:
.LC_ASAN_ENTER_1287: # 1287: movq -8(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -8(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4743
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4743:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -8(%rbp), %rax
.LC128b:
.LC_ASAN_ENTER_128b: # 128b: movb 5(%rax), %cl: []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq 5(%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4747
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4747
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4747:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movb 5(%rax), %cl
.LC128e:
.LC_ASAN_ENTER_128e: # 128e: movq -0x40(%rbp), %rax: ['rax']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -0x40(%rbp), %rdi
	movq %rdi, %rax
	shrq $3, %rax
	cmpb $0, 2147450880(%rax)
	je .LC_ASAN_EX_4750
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4750:
leaq -8(%rsp), %rsp
	popq %rdi
	movq -0x40(%rbp), %rax
.LC1292:
.LC_ASAN_ENTER_1292: # 1292: movb %cl, (%rax): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  (%rax), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4754
	andl $7, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4754
	callq __asan_report_load1@PLT
.LC_ASAN_EX_4754:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movb %cl, (%rax)
.L1294:
.LC1294:
.LC_ASAN_ENTER_1294: # 1294: cmpl $2, -0xc(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0xc(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4756
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4756
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4756:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $2, -0xc(%rbp)
.LC1298:
	jle .LC12af
.LC129e:
	leaq -0x30(%rbp), %rdi
.LC12a2:
.LC_ASAN_ENTER_12a2: # 12a2: movq -8(%rbp), %rsi: ['rsi', 'rdx']
		leaq -8(%rbp), %rdx
	movq %rdx, %rsi
	shrq $3, %rsi
	cmpb $0, 2147450880(%rsi)
	je .LC_ASAN_EX_4770
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4770:
	movq -8(%rbp), %rsi
.LC12a6:
.LC_ASAN_ENTER_12a6: # 12a6: movslq -0xc(%rbp), %rdx: ['rdx']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -0xc(%rbp), %rdi
	movq %rdi, %rdx
	shrq $3, %rdx
	movb 2147450880(%rdx), %dl
	testb %dl, %dl
	je .LC_ASAN_EX_4774
	andl $7, %edi
	addl $3, %edi
	movsbl %dl, %edx
	cmpl %edx, %edi
	jl .LC_ASAN_EX_4774
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4774:
leaq -8(%rsp), %rsp
	popq %rdi
	movslq -0xc(%rbp), %rdx
.LC12aa:
	callq memcpy@PLT
.L12af:
.LC12af:
	addq $0x40, %rsp
.LC12b3:
	popq %rbp
.LC12b4:

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
.L12c0:
.LC12c0:
	pushq %rbp
.LC12c1:
	movq %rsp, %rbp
.LC12c4:
	subq $0x120, %rsp
.LC12cb:
.LC_ASAN_ENTER_12cb: # 12cb: movl $0, -4(%rbp): ['rdi', 'rsi', 'rcx', 'rdx', 'rax']
		leaq  -4(%rbp), %rsi
	movq %rsi, %rdi
	shrq $3, %rdi
	movb 2147450880(%rdi), %dil
	testb %dil, %dil
	je .LC_ASAN_EX_4811
	andl $7, %esi
	addl $3, %esi
	movsbl %dil, %edi
	cmpl %edi, %esi
	jl .LC_ASAN_EX_4811
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4811:
	movl $0, -4(%rbp)
.LC12d2:
	leaq -0x110(%rbp), %rdi
.LC12d9:
.LC_ASAN_ENTER_12d9: # 12d9: movq stdin@GOTPCREL(%rip), %rax: ['rsi', 'rcx', 'rdx', 'rax']
		leaq stdin@GOTPCREL(%rip), %rcx
	movq %rcx, %rsi
	shrq $3, %rsi
	cmpb $0, 2147450880(%rsi)
	je .LC_ASAN_EX_4825
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4825:
	movq stdin@GOTPCREL(%rip), %rax
.LC12e0:
.LC_ASAN_ENTER_12e0: # 12e0: movq (%rax), %rcx: ['rsi', 'rcx', 'rdx']
		leaq (%rax), %rcx
	movq %rcx, %rsi
	shrq $3, %rsi
	cmpb $0, 2147450880(%rsi)
	je .LC_ASAN_EX_4832
	callq __asan_report_load8@PLT
.LC_ASAN_EX_4832:
	movq (%rax), %rcx
.LC12e3:
	movl $1, %esi
.LC12e8:
	movl $0x100, %edx
.LC12ed:
	callq fread@PLT
.LC12f2:
.LC_ASAN_ENTER_12f2: # 12f2: movl %eax, -0x114(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0x114(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4850
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4850
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4850:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	movl %eax, -0x114(%rbp)
.LC12f8:
.LC_ASAN_ENTER_12f8: # 12f8: cmpl $0, -0x114(%rbp): []
		pushq %rdi
	pushq %rsi
leaq 16(%rsp), %rsp
	leaq  -0x114(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4856
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4856
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4856:
leaq -16(%rsp), %rsp
	popq %rsi
	popq %rdi
	cmpl $0, -0x114(%rbp)
.LC12ff:
	jle .LC1317
.LC1305:
	leaq -0x110(%rbp), %rdi
.LC130c:
.LC_ASAN_ENTER_130c: # 130c: movl -0x114(%rbp), %esi: ['rsi']
		pushq %rdi
leaq 8(%rsp), %rsp
	leaq -0x114(%rbp), %rdi
	movq %rdi, %rsi
	shrq $3, %rsi
	movb 2147450880(%rsi), %sil
	testb %sil, %sil
	je .LC_ASAN_EX_4876
	andl $7, %edi
	addl $3, %edi
	movsbl %sil, %esi
	cmpl %esi, %edi
	jl .LC_ASAN_EX_4876
	callq __asan_report_load4@PLT
.LC_ASAN_EX_4876:
leaq -8(%rsp), %rsp
	popq %rdi
	movl -0x114(%rbp), %esi
.LC1312:
	callq .LC1170
.L1317:
.LC1317:
	xorl %eax, %eax
.LC1319:
	addq $0x120, %rsp
.LC1320:
	popq %rbp
.LC1321:

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
