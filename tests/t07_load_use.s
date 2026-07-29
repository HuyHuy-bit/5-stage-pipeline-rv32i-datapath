addi x1, x0, 42
sw   x1, 0(x0)
lw   x2, 0(x0)
addi x2, x2, 1
addi x3, x0, 100
sw   x3, 4(x0)
lw   x4, 4(x0)
add  x5, x4, x4
addi x6, x0, 5
addi x7, x0, 200
sw   x7, 8(x0)
lw   x8, 8(x0)
add  x8, x8, x6

tohost          # signal completion (exit code 1 = pass)

halt
