# t17_irq_mret.s — MRET returns from an interrupt and restores mstatus.MIE.
# The interrupted loop must resume (it spins until the handler sets x6), and
# mstatus.MIE must be 1 again afterwards - the pop half of the enable stack
# that t16 only checks the push half of.
    auipc x1, 0
    addi  x1, x1, 56        # handler is 14 instructions ahead
    csrrw x0, mtvec, x1

    addi  x2, x0, 30
    csrrw x0, mtimecmp, x2
    addi  x3, x0, 128       # mie.MTIE
    csrrw x0, mie, x3
    addi  x4, x0, 8         # mstatus.MIE
    csrrw x0, mstatus, x4

    addi  x5, x0, 0
loop:
    addi  x5, x5, 1
    beq   x6, x0, loop      # spin until the handler sets x6 - proves we resumed
    csrrs x9, mstatus, x0   # MIE must be back to 1 here
    halt

handler:
    addi  x6, x0, 1         # break the spin
    addi  x8, x0, -1
    srli  x8, x8, 1
    csrrw x0, mtimecmp, x8  # disarm so it fires exactly once
    mret
