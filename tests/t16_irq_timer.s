# t16_irq_timer.s — a timer interrupt fires during a loop and returns correctly.
# Proves: mtimecmp arms MTIP, mstatus.MIE gates it, the handler runs, MRET
# resumes the interrupted code, and mcause carries the interrupt bit.
    auipc x1, 0
    addi  x1, x1, 48        # handler is 12 instructions ahead (12*4=48)
    csrrw x0, mtvec, x1

    addi  x2, x0, 20        # arm the timer a short way out
    csrrw x0, mtimecmp, x2

    addi  x3, x0, 128       # mie.MTIE (bit 7)
    csrrw x0, mie, x3
    addi  x4, x0, 8         # mstatus.MIE (bit 3)
    csrrw x0, mstatus, x4

    addi  x5, x0, 0         # loop counter, incremented until the IRQ lands
loop:
    addi  x5, x5, 1
    jal   x0, loop

handler:
    addi  x6, x0, 1         # marker: handler entered
    csrrs x7, mcause, x0    # x7 = mcause: interrupt bit set + cause 7
    addi  x8, x0, -1        # disarm: mtimecmp = huge so MTIP drops
    srli  x8, x8, 1
    csrrw x0, mtimecmp, x8
    csrrs x9, mstatus, x0   # x9 = mstatus inside handler: MIE must be 0
    halt
