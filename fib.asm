LDi r0, 0
LDi r1, 1
LDi r3, 90
$loop:
	MOV r2, r0
	ADD r2, r1
	MOV r0, r1
	MOV r1, r2

	SUBi r3, 1

	PRINTINT r0
	PRINTi.8 10

	CMPi r3, 0
	JGT $loop

DBG
EXIT
