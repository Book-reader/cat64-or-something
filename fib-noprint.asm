$forever:
LDi r0, 0
LDi r1, 1
LDi r3, 90
LDi r4, 0xff
$loop:
	MOV r2, r0
	ADD r2, r1
	MOV r0, r1
	MOV r1, r2

	SUBi r3, 1

	SD r4, r0
	ADDi r4, 8

	CMPi r3, 0
	JGT $loop

JMP $forever

EXIT
