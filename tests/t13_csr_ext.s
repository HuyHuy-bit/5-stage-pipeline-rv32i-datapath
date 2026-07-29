# t13_csr_ext.s — mscratch round-trip, misa/mhartid fixed reads, mcycle live read.
    addi   x1, x0, 123
    csrrw  x0, mscratch, x1   # mscratch = 123
    csrrs  x2, mscratch, x0   # x2 = mscratch (123)

    csrrs  x3, misa, x0       # x3 = misa (0x40000100)
    csrrs  x4, mhartid, x0    # x4 = mhartid (0)

    # x5 = live cycle counter; exercises the mcycle read path. Its value is
    # timing-dependent (varies with memory latency/cache config), so it's
    # read but deliberately not checked against a fixed expected value in
    # the .ref file — the CI matrix requires results invariant to config.
    csrrs  x5, mcycle, x0
    tohost          # signal completion (exit code 1 = pass)
    halt
