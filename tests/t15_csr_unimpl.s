# t15_csr_unimpl.s — a read of an unimplemented CSR must trap illegal.
    auipc x1, 0
    addi  x1, x1, 24       # handler is 6 instructions ahead (6*4=24)
    csrrw x0, mtvec, x1    # mtvec = handler

    addi  x4, x0, 99       # marker: reached before the fault
    csrrs x2, 0x7c0, x0    # read of an unimplemented CSR -> illegal -> trap
    addi  x4, x0, 7        # wrong-path: squashed

handler:
    addi  x5, x0, 1        # reached handler
    csrrs x6, mcause, x0   # x6 = mcause (should be 2 = illegal instruction)
    halt
