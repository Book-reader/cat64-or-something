mov.64 r1, 0xff
mov.8 r0, [r1]
printc.8
; This wont work because I have not implemented labels yet
; Does your assembler support labels with spaces? thought not
jmp exit\ program

str: "hello"

exit\ program:
    exit
