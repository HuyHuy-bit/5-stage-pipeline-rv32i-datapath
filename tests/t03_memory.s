# t03_memory.s — all five load widths and three store widths
# SW/LW, SH/LH/LHU, SB/LB/LBU

# --- word ---
addi x1,  x0, 42
sw   x1,  0(x0)
lw   x2,  0(x0)        # x2 = 42

# --- halfword ---
addi x3,  x0, -1       # x3 = 0xFFFFFFFF
sh   x3,  4(x0)        # mem[4] lower half = 0xFFFF
lh   x4,  4(x0)        # x4 = sign-ext(0xFFFF) = 0xFFFFFFFF
lhu  x5,  4(x0)        # x5 = zero-ext(0xFFFF) = 0x0000FFFF = 65535

# --- byte ---
addi x6,  x0, -1       # x6 = 0xFFFFFFFF
sb   x6,  8(x0)        # mem[8] byte = 0xFF
lb   x7,  8(x0)        # x7 = sign-ext(0xFF)   = 0xFFFFFFFF
lbu  x8,  8(x0)        # x8 = zero-ext(0xFF)   = 255

# --- non-zero base ---
addi x9,  x0, 100
sw   x9,  12(x0)
lw   x10, 12(x0)       # x10 = 100

tohost          # signal completion (exit code 1 = pass)

halt
