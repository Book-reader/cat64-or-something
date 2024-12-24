;mov.64 r1, 0xff
;; mov.8 r6, 1e1999 ; Too large number test
;mov.8 r2, [r1]
;mov.8 r0, 'A'
;printc.8
;; This wont work because I have not implemented labels yet
;; Does your assembler support labels with spaces? thought not
;;jmp exit\ program

;;str: "hello"

;;exit\ program:
;    exit

; 84e8 00000000000000ff 01 8588 01 00 8006 84e4 0000000000000001 01 8382 00 00 8083 000000000000000b 900a
; 84e8 0009000000000000 00 8588 00 00 8006 84e4 0009000000000000 00 8682 00 00 8283 0000

mov.64 r1, 0xff

mov.8, r0, [r1]

printc.8

add.64, r1, 1

cmp.8, [r0], 0

jif 01, 0xb

exit

