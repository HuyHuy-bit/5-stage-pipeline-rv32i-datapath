# t18_trap_causes.s — ECALL, EBREAK and a misaligned LOAD, each returning via
# MRET. Closes the ecall/ebreak/misaligned-load trap-cause coverage that the
# earlier directed tests left unhit (t10 covers the misaligned *store* only).
# x6 accumulates each mcause, so a single value proves all three fired:
# 11 (ECALL) + 3 (EBREAK) + 4 (misaligned load) = 18.
    auipc x1, 0
    addi  x1, x1, 32        # handler is 8 instructions ahead
    csrrw x0, mtvec, x1

    ecall                   # cause 11
    ebreak                  # cause 3
    lh    x4, 1(x0)         # addr 1 is odd -> misaligned load -> cause 4
    addi  x9, x0, 99        # marker: all three traps returned here
    halt

handler:
    csrrs x5, mcause, x0
    add   x6, x6, x5        # accumulate causes
    csrrs x7, mepc, x0
    addi  x7, x7, 4         # skip the faulting instruction
    csrrw x0, mepc, x7
    mret
