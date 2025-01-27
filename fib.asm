mov.64 r0, 0
mov.64 r1, 1
# dbg
loop:
#    mov.64 r2, r0
    mov.64 r0, r1
    dbg
    add.64 r1, r0
    add.64 r2, 1
    dbg
    printint.64
#    jmp loop
    cmp.64 r2, 20
    jif 02, loop
exit
