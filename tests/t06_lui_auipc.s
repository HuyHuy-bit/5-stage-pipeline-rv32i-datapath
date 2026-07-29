# t06_lui_auipc.s — LUI and AUIPC
#
# Layout (byte addresses):
#   0x00  lui   x1, 1            x1=0x00001000
#   0x04  lui   x2, 0xABCDE      x2=0xABCDE000
#   0x08  lui   x3, 0xFFFFF      x3=0xFFFFF000
#   0x0C  auipc x4, 0             x4=0x0000000C
#   0x10  auipc x5, 1             x5=0x00001010
#   0x14  sub   x6, x5, x4       x6=0x00001010-0x0C=0x00001004
#   0x18  nop
lui   x1, 1
lui   x2, 0xABCDE
lui   x3, 0xFFFFF
auipc x4, 0
auipc x5, 1
sub   x6, x5, x4

tohost          # signal completion (exit code 1 = pass)

halt