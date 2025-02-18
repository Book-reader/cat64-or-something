@define input r0
@define idx r2

$print_int:
#	PUSH input
#	PUSH r1
#	PUSH r2
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
	LDi r3, $data
	ADDi r3, r2
	SDi
	PRINT r1
	CMPi r0, 0
	JNE $print_int_1
	PRINTi 0x0a
#	POP r2
#	POP r1
#	POP input
#	RET
	EXIT

# Define a bunch of empty bytes :)
$data:
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
	NOP.8
@undefine input
