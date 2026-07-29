# t01_rtype.s — all ten R-type operations
# x1=5  x2=3  x20=1(shift amt)  x21=-8
# Expected: x3=8 x4=2 x5=1 x6=7 x7=6 x8=1 x9=1 x10=10 x11=2 x12=0xFFFFFFFC
addi x1,  x0, 5
addi x2,  x0, 3
addi x20, x0, 1
addi x21, x0, -8

add  x3,  x1, x2       # 5+3=8
sub  x4,  x1, x2       # 5-3=2
and  x5,  x1, x2       # 0101&0011=0001=1
or   x6,  x1, x2       # 0101|0011=0111=7
xor  x7,  x1, x2       # 0101^0011=0110=6
slt  x8,  x2, x1       # 3<5 signed  -> 1
sltu x9,  x2, x1       # 3<5 unsigned-> 1
sll  x10, x1, x20      # 5<<1=10
srl  x11, x1, x20      # 5>>1=2  (logical)
sra  x12, x21, x20     # -8>>1=-4=0xFFFFFFFC (arithmetic)

tohost                 # signal completion (exit code 1 = pass)

halt                  # park here so we never fetch past the program