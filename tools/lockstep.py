#!/usr/bin/env python3
"""lockstep.py — run a program on Spike and on the RTL, compare retirement traces.

Both machines execute the *same ELF*, linked by compliance/link/spike-lockstep.ld
at 0x80000000 (Spike reserves low memory, so the normal 0x0-based image can't be
loaded into it). The RTL's memories decode only their low address bits, so that
image aliases back to word 0 exactly as the 0x0-linked one does; the only
adjustment needed is the reset vector, via cpu.sv's RESET_PC parameter.

Comparison is per-retirement: PC, instruction word, destination register, and
written value. On the first divergence it prints the preceding retirements from
both sides and stops — a mismatch reported 400 instructions later is nearly
useless, so failing at the divergence point is the entire value of doing this.

Usage: lockstep.py <program.elf> <instr.hex> <data.hex> [--sim PATH] [--cycles N]
"""
import argparse
import os
import re
import subprocess
import sys

RESET_PC = 0x80000000

# expanduser is applied to the environment value too, not just the default:
# a "~/..." path passed through a CI env block arrives as a literal tilde,
# which no shell has expanded and Python will not resolve on its own.
SPIKE = os.path.expanduser(
    os.environ.get("SPIKE", "~/projects/riscv-isa-sim/build/spike"))

# A Spike commit line looks like:
#   core   0: 3 0x80000000 (0x00500093) x1  0x00000005
#   core   0: 3 0x8000000c (0x0182a283) x5  0x80000000 mem 0x00001018
# The leading privilege digit is what distinguishes a commit from the
# disassembly line Spike prints for the same instruction.
COMMIT = re.compile(r"^core\s+\d+:\s+\d+\s+0x([0-9a-f]+)\s+\(0x([0-9a-f]+)\)(.*)$")
REGWR = re.compile(r"\bx\s*(\d+)\s+0x([0-9a-f]+)")


def spike_trace(elf, limit):
    """Retirements from Spike, starting at the program entry point.

    Spike enters through a small boot ROM at 0x1000 that jumps to the ELF
    entry; those instructions aren't part of the program under test and the
    RTL never executes them, so they're skipped.
    """
    # Streamed, not captured wholesale: these programs end by parking in a
    # self-loop (the RTL's end-of-test convention), so Spike never terminates
    # on its own. Read until we have enough retirements, then kill it.
    if not os.path.exists(SPIKE):
        sys.exit(f"error: spike not found at {SPIKE!r} "
                 f"(set $SPIKE to its absolute path)")
    proc = subprocess.Popen([SPIKE, "--isa=rv32i", "-l", "--log-commits", elf],
                            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
                            text=True)
    trace, started = [], False
    for line in proc.stderr:
        m = COMMIT.match(line)
        if not m:
            continue
        pc, insn, tail = int(m.group(1), 16), int(m.group(2), 16), m.group(3)
        if not started:
            if pc != RESET_PC:
                continue
            started = True
        rd, wdata = 0, 0
        w = REGWR.search(tail)
        if w:
            rd, wdata = int(w.group(1)), int(w.group(2), 16)
        trace.append((pc, insn, rd, wdata))
        if len(trace) >= limit:
            break

    proc.kill()
    proc.wait()
    return trace


def rtl_trace(sim, instr_hex, data_hex, cycles, tracefile):
    subprocess.run(
        [sim, f"+MEMFILE={instr_hex}", f"+DATAFILE={data_hex}",
         f"+CYCLES={cycles}", "+VCD=", f"+RVFI_TRACE={tracefile}"],
        capture_output=True, text=True, timeout=300)
    trace = []
    with open(tracefile) as f:
        for line in f:
            pc, insn, rd, wdata = line.split()
            trace.append((int(pc, 16), int(insn, 16), int(rd), int(wdata, 16)))
    return trace


def fmt(entry):
    pc, insn, rd, wdata = entry
    wr = f"x{rd}=0x{wdata:08x}" if rd else "-"
    return f"pc=0x{pc:08x} insn=0x{insn:08x} {wr}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("elf")
    ap.add_argument("instr_hex")
    ap.add_argument("data_hex")
    ap.add_argument("--sim", default="obj_dir_lockstep/Vcpu")
    ap.add_argument("--cycles", type=int, default=2000)
    ap.add_argument("--context", type=int, default=8)
    ap.add_argument("-q", "--quiet", action="store_true")
    args = ap.parse_args()

    rtl = rtl_trace(args.sim, args.instr_hex, args.data_hex, args.cycles,
                    "/tmp/_rvfi.trace")
    ref = spike_trace(args.elf, limit=len(rtl) + 16)

    # The RTL stops when its PC parks in a self-loop; Spike keeps going. Only
    # the overlap is meaningful, so compare that and report how far it got.
    n = min(len(rtl), len(ref))
    if n == 0:
        print(f"FAIL {os.path.basename(args.elf)}: no retirements "
              f"(rtl={len(rtl)}, spike={len(ref)})")
        return 1

    for i in range(n):
        if rtl[i] != ref[i]:
            print(f"FAIL {os.path.basename(args.elf)}: diverged at retirement {i}")
            lo = max(0, i - args.context)
            print(f"  --- last {i - lo} matching ---")
            for j in range(lo, i):
                print(f"    {j:5d}  {fmt(rtl[j])}")
            print(f"  --- divergence ---")
            print(f"    {i:5d}  RTL   {fmt(rtl[i])}")
            print(f"    {i:5d}  SPIKE {fmt(ref[i])}")
            return 1

    if not args.quiet:
        print(f"PASS {os.path.basename(args.elf)}: {n} retirements match")
    return 0


if __name__ == "__main__":
    sys.exit(main())
