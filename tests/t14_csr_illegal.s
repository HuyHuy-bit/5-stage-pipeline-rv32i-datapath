# t14_csr_illegal.s — a write attempt to a read-only CSR must trap illegal.
    auipc x1, 0
    addi  x1, x1, 24       # handler is 6 instructions ahead (6*4=24)
    csrrw x0, mtvec, x1    # mtvec = handler

    addi  x4, x0, 99       # marker: reached before the fault
    csrrwi x0, mhartid, 1  # write attempt to read-only CSR -> illegal -> trap
    addi  x4, x0, 7        # wrong-path: squashed

handler:
    addi  x5, x0, 1        # reached handler
    csrrs x6, mcause, x0   # x6 = mcause (should be 2 = illegal instruction)
    halt
