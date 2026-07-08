.section .text.init
.globl _start
_start:
    la   t0, mydata
    lw   t1, 0(t0)
    addi t1, t1, 1
    sw   t1, 0(t0)
1:  j 1b

.section .data
mydata:
    .word 41
