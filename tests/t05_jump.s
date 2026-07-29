# t05_jump.s — JAL and JALR
#
# Layout (byte addresses):
#   0x00  addi x2,  x0, 0
#   0x04  jal  x1,  jal_t      x1=0x08, PC->0x0C
#   0x08  addi x2,  x0, 99     POISON
# jal_t:
#   0x0C  auipc x3, 0           x3=0x0C
#   0x10  addi  x4, x3, 16     x4=0x1C
#   0x14  jalr  x5, x4, 0      x5=0x18, PC->0x1C
#   0x18  addi  x6, x0, 99     POISON
# jalr_t:
#   0x1C  addi  x7, x0, 77
#   0x20  nop
#
# Expected: x1=8 x2=0 x3=12 x4=28 x5=24 x6=0 x7=77
addi  x2,  x0, 0
jal   x1,  jal_t
addi  x2,  x0, 99
jal_t:
auipc x3,  0
addi  x4,  x3, 16
jalr  x5,  x4, 0
addi  x6,  x0, 99
jalr_t:
addi  x7,  x0, 77

tohost          # signal completion (exit code 1 = pass)

halt
