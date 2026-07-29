# t08_loop.s — a counted loop, so the loop-back branch is seen many times
# and the 2-bit predictor can warm up.
addi x1, x0, 10       # counter = 10
addi x2, x0, 0        # acc = 0

loop:
    add  x2, x2, x1    # acc += counter
    addi x1, x1, -1    # counter -= 1
    bne  x1, x0, loop  # if counter != 0, loop back

addi x7, x0, 42       # sentinel: reached after loop exit

tohost          # signal completion (exit code 1 = pass)

halt