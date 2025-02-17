@define input r0

$print_int:
#	PUSH input
#	PUSH r1
	ICMPi input, 0
	JGT $print_int_1
	PRINTi 0x2d # '-'
	LDi r1, 0
	ISUB r1, input
	MOV input, r1
$print_int_1:
	MOV r1, input
	DIVi input, 10
	MODi r1, 10
	ADDi r1, 0x30 # '0'
	PRINT r1
	CMPi r0, 0
	JNE $print_int
#	POP r1
#	POP input
#	RET
	EXIT

@undefine input
