# t09_trap_illegal.s — illegal-instruction trap round-trip.
    auipc x1, 0            # x1 = PC here (=0)
    addi  x1, x1, 24       # handler is 6 instructions ahead (6*4=24)
    csrrw x0, mtvec, x1    # mtvec = handler

    addi  x4, x0, 99       # runs before the fault
    word  0x00000000       # ILLEGAL -> trap to handler
    addi  x4, x0, 7        # wrong-path: squashed by the trap flush

handler:
    addi  x5, x0, 1        # reached handler
    csrrs x6, mcause, x0   # x6 = mcause
    csrrs x7, mepc,   x0   # x7 = mepc
    tohost          # signal completion (exit code 1 = pass)
    halt
