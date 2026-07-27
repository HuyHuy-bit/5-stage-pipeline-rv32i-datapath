# t12_misaligned_fetch.s — JAL to a target not 4-byte aligned must trap.
    auipc x1, 0
    addi  x1, x1, 24       # handler is 6 instructions ahead (6*4=24)
    csrrw x0, mtvec, x1    # mtvec = handler

    addi  x4, x0, 99       # marker: reached before the fault
    jal   x6, 2            # JAL to pc+2 -> MISALIGNED (bit1 set) -> trap
    addi  x4, x0, 7        # wrong-path: squashed

handler:
    addi  x5, x0, 1        # reached handler
    csrrs x6, mcause, x0   # x6 = mcause (should be 0 = misaligned fetch)
    csrrs x7, mepc,   x0   # x7 = mepc (faulting PC, the jal instruction)
    halt
