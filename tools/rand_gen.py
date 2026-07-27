#!/usr/bin/env python3
"""Random RV32I program generator — straight-line ALU + load/store subset.

Emits raw instruction words directly (no assembler pass) plus a matching
.ref computed by tools/rv32i_model.py, so a generated program plugs straight
into the existing +MEMFILE=/+REFFILE= testbench comparison — no new
comparison logic needed.

Scope, deliberately: no branches/jumps/traps/CSRs (the model doesn't
interpret them; see its docstring), no negative load/store offsets (keeps
both the model's and the RTL's address truncation trivially in agreement).
Biased toward dependency distance 1-2, since that's where forwarding and
load-use bugs live.
"""
import random
import sys

REGS = list(range(1, 11))          # x1..x10: scratch
MEM_WORDS = 64                      # word-addressed scratch region, base 0

R_OPS = [  # (funct3, funct7)
    (0x0, 0x00), (0x0, 0x20), (0x1, 0x00), (0x2, 0x00), (0x3, 0x00),
    (0x4, 0x00), (0x5, 0x00), (0x5, 0x20), (0x6, 0x00), (0x7, 0x00),
]
I_OPS = [0x0, 0x2, 0x3, 0x4, 0x6, 0x7, 0x1, 0x5]  # funct3; shifts handled specially


def r_type(rd, rs1, rs2, f3, f7):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0x33


def i_type(rd, rs1, imm12, f3, op=0x13):
    return ((imm12 & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def s_type(rs1, rs2, imm12, f3):
    imm12 &= 0xFFF
    return ((imm12 >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm12 & 0x1F) << 7) | 0x23


def gen(n, seed):
    rnd = random.Random(seed)
    words = []
    recent_rd = []  # last few destination registers, for dependency bias

    def pick_src():
        # 60%: reuse a recent destination (distance 1-2), biased toward the
        # most recent. 40%: a fresh random register.
        if recent_rd and rnd.random() < 0.6:
            idx = 0 if (len(recent_rd) == 1 or rnd.random() < 0.7) else 1
            return recent_rd[idx]
        return rnd.choice(REGS)

    for _ in range(n):
        kind = rnd.choices(["r", "i", "load", "store"], weights=[35, 35, 15, 15])[0]
        rd = rnd.choice(REGS)
        if kind == "r":
            rs1, rs2 = pick_src(), pick_src()
            f3, f7 = rnd.choice(R_OPS)
            words.append(r_type(rd, rs1, rs2, f3, f7))
        elif kind == "i":
            rs1 = pick_src()
            f3 = rnd.choice(I_OPS)
            if f3 in (0x1, 0x5):        # SLLI / SRLI / SRAI: shamt in [0,31]
                shamt = rnd.randint(0, 31)
                f7 = 0x20 if (f3 == 0x5 and rnd.random() < 0.5) else 0x00
                imm = (f7 << 5) | shamt
            else:
                imm = rnd.randint(-2048, 2047)
            words.append(i_type(rd, rs1, imm, f3))
        elif kind == "load":
            off = rnd.randrange(0, MEM_WORDS) * 4
            words.append(i_type(rd, 0, off, 0x2, op=0x03))  # lw rd, off(x0)
        else:  # store
            off = rnd.randrange(0, MEM_WORDS) * 4
            rs2 = pick_src()
            words.append(s_type(0, rs2, off, 0x2))          # sw rs2, off(x0)

        if kind != "store":
            recent_rd = [rd] + recent_rd[:1]

    words.append(0x0000006F)  # halt: jal x0, 0
    return words


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("-n", type=int, default=40, help="instruction count (excluding halt)")
    ap.add_argument("--seed", type=int, required=True)
    ap.add_argument("hexfile")
    ap.add_argument("reffile")
    args = ap.parse_args()

    words = gen(args.n, args.seed)
    with open(args.hexfile, "w") as f:
        for w in words:
            f.write(f"{w:08x}\n")

    sys.path.insert(0, sys.path[0])
    from rv32i_model import run
    regs = run(words, mem_words=MEM_WORDS)
    with open(args.reffile, "w") as f:
        f.write(f"cycles={args.n * 4 + 50}\n")
        for i in range(1, 32):
            if regs[i]:
                f.write(f"x{i}=0x{regs[i]:x}\n")

    print(f"seed={args.seed} n={args.n} -> {args.hexfile}", file=sys.stderr)
