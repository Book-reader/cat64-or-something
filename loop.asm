# 88e8 00000000000000ff 01 8988 01 00 8006 88e4 0000000000000001 01 8582 00 00 9083 000000000000000b 800a
# Prints "Hello, World!\n" assuming it is as 0xff in memory
mov.64 r1, 0xff;
mov.64 r2, 100
# Comment
loop:
  mov.8 r0, [r1];
  printc.8
  add.64 r1, 1;
  cmp.8 r0, 0
  jif 01, loop
dbg

# sub.64 r2, 1
# cmp.64 r2, 0
jmp 0x0000000000
# jif 01, 12

exit
# idx: db.8 0xff
