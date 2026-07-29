# t11_mret.s — full trap round-trip WITH return via MRET.
    la    x1, handler      # mtvec = handler (label, not a byte count)
    csrrw x0, mtvec, x1    # mtvec = handler

    addi  x4, x0, 11       # before fault
    word  0x00000000       # ILLEGAL -> trap (mepc points here)
    addi  x4, x0, 55       # AFTER return: this must execute post-MRET
    tohost                 # signal completion (exit code 1 = pass)
    halt                   # main program parks here

handler:
    addi  x5, x0, 1        # handler ran
    csrrs x6, mcause, x0   # x6 = mcause
    csrrs x2, mepc, x0     # x2 = faulting PC
    addi  x2, x2, 4        # advance past the faulting instruction
    csrrw x0, mepc, x2     # write mepc back (so MRET returns to fault+4)
    mret                   # return to mepc -> the 'addi x4,x0,55'
