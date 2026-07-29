# t02_itype.s — all nine I-type arithmetic/logic operations
# x1=12=0b1100
# Expected: x2=7 x3=8 x4=15 x5=6 x6=1 x7=0 x8=1 x9=48 x10=3 x11=0xFFFFFFFD
addi x1,  x0, 12

addi  x2,  x1, -5      # 12-5=7
andi  x3,  x1, 10      # 1100&1010=1000=8
ori   x4,  x1, 3       # 1100|0011=1111=15
xori  x5,  x1, 10      # 1100^1010=0110=6
slti  x6,  x1, 15      # 12<15 signed  -> 1
slti  x7,  x1, 10      # 12<10 signed  -> 0
sltiu x8,  x1, 15      # 12<15 unsigned-> 1
slli  x9,  x1, 2       # 12<<2=48
srli  x10, x1, 2       # 12>>2=3  (logical)
addi  x21, x0, -12     # x21=-12=0xFFFFFFF4
srai  x11, x21, 2      # -12>>2=-3=0xFFFFFFFD (arithmetic)

tohost                 # signal completion (exit code 1 = pass)

halt                  # park here so we never fetch past the program