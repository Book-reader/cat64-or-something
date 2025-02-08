# 88e8 00000000000000ff 01 8988 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800a
# Prints "Hello, World!\n" assuming it is as 0xff in memory
# LDi.64 r1, 0xff;
LDi r1, 0xff # Should be equivalent
# Comment
$loop:
  LD.8 r0, r1
#  mov.8 r0, [r1];
#  printc.8
  PRINT.8 r0
#  add.64 r1, 1;
  ADDi.64 r1, 1
#  cmp.8 r0, 0
  CMPi.8 r0, 0
#  jif 01, $loop
  JNE $loop
DBG
EXIT
# idx: db.8 0xff
