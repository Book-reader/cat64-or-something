# 88e8 00000000000000ff 01 8988 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800a
# Prints "Hello, World!\n" assuming it is as 0xff in memory
# LDi.64 r1, 0xff;
LDi r2, 10
$start:
	LDi r1, 0xff # Should be equivalent
	#LDi r1, 0xff; NOP; LDi r1, 0xff # Semicolon test
	# Comment
	$loop:
		LD.8 r0, r1
		PRINT.8 r0
	#	DBG
		ADDi r1, 1
	#	DBG
		CMPi.8 r0, 0
		JNE $loop

# DBG
SUBi r2, 1
# DBG
CMPi r2, 0
JNE $start

DBG
EXIT
# idx: db.8 0xff
