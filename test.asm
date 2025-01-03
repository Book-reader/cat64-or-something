mov.64 r1, 0xff;
# Comment
loop:
  mov.8 r0, [r1];
  printc.8
  add.64 r1, 1;
  cmp.8 [r0], 0
  jif 01, loop

exit

