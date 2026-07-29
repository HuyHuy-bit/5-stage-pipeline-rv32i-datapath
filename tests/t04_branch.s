# t04_branch.s — all six branch types, each taken (poison instruction skipped)
# x1..x6 must remain 0; x7=99 proves execution reached the end

# BEQ taken: 5==5
addi x10, x0, 5
addi x11, x0, 5
beq  x10, x11, beq_t
addi x1,  x0, 1        # POISON
beq_t:

# BNE taken: 3!=7
addi x12, x0, 3
addi x13, x0, 7
bne  x12, x13, bne_t
addi x2,  x0, 1        # POISON
bne_t:

# BLT taken (signed): -1 < 1
addi x14, x0, -1
addi x15, x0, 1
blt  x14, x15, blt_t
addi x3,  x0, 1        # POISON
blt_t:

# BGE taken: 5 >= 3
addi x16, x0, 5
addi x17, x0, 3
bge  x16, x17, bge_t
addi x4,  x0, 1        # POISON
bge_t:

# BLTU taken (unsigned): 3 < 0xFFFFFFFF
addi x18, x0, 3
addi x19, x0, -1       # 0xFFFFFFFF
bltu x18, x19, bltu_t
addi x5,  x0, 1        # POISON
bltu_t:

# BGEU taken (unsigned): 0xFFFFFFFF >= 3
bgeu x19, x18, bgeu_t
addi x6,  x0, 1        # POISON
bgeu_t:

addi x7, x0, 99        # success marker

tohost          # signal completion (exit code 1 = pass)

halt
