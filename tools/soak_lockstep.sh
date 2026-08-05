#!/usr/bin/env bash
# soak_lockstep.sh [seeds] [instrs] — random programs compared against Spike,
# retirement by retirement.
#
# This is tools/soak.sh's constrained-random generation pointed at a real ISA
# implementation instead of the Python model in tools/rv32i_model.py. That
# swap is the whole point: the model can't interpret branches or jumps, so
# soak.sh has to generate straight-line code only, and "1000/1000 seeds pass"
# has never said anything about control flow. Spike has no such limit, so
# this flow generates branches and jumps too.
#
# It also compares differently. soak.sh checks final register state; this
# compares every retirement's PC, instruction, and register write, so a wrong
# value on a wrong path is caught at the instruction that produced it rather
# than being masked by whatever overwrites it later - the same reason the
# compliance suite got a lockstep flow on top of its signature check.
set -u

SEEDS="${1:-50}"
INSTRS="${2:-60}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIM="${SIM:-$ROOT/obj_dir_lockstep/Vcpu}"
CYCLES="${CYCLES:-4000}"
WORK="${TMPDIR:-/tmp}/rv32i_soak_lockstep"
mkdir -p "$WORK"

if [ ! -x "$SIM" ]; then
    echo "error: $SIM not built - run 'make lockstep-sim' first" >&2
    exit 1
fi

PASS=0; FAIL=0; FAILED=()
for seed in $(seq 1 "$SEEDS"); do
    asm="$WORK/s$seed.S"
    elf="$WORK/s$seed.elf"

    python3 "$ROOT/tools/rand_gen.py" -n "$INSTRS" --seed "$seed" --spike "$asm" 2>/dev/null

    if ! riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany \
            -fvisibility=hidden -nostdlib -nostartfiles \
            -T "$ROOT/compliance/link/spike-lockstep.ld" \
            "$asm" -o "$elf" 2> "$WORK/s$seed.cc.log"; then
        echo "FAIL seed=$seed (compile - see $WORK/s$seed.cc.log)"
        FAIL=$((FAIL+1)); FAILED+=("$seed"); continue
    fi

    python3 "$ROOT/compliance/elf2hex.py" "$elf" \
        "$WORK/s$seed.instr.hex" "$WORK/s$seed.data.hex" > /dev/null || {
        echo "FAIL seed=$seed (elf2hex)"; FAIL=$((FAIL+1)); FAILED+=("$seed"); continue; }

    if python3 "$ROOT/tools/lockstep.py" "$elf" \
           "$WORK/s$seed.instr.hex" "$WORK/s$seed.data.hex" \
           --sim "$SIM" --cycles "$CYCLES" -q > "$WORK/s$seed.log" 2>&1; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1)); FAILED+=("$seed")
        echo "FAIL seed=$seed - reproduce: $asm / $elf, divergence in $WORK/s$seed.log"
        cat "$WORK/s$seed.log"
    fi
done

echo ""
echo "========== $PASS/$((PASS+FAIL)) random seeds match Spike (instrs=$INSTRS) =========="
[ ${#FAILED[@]} -gt 0 ] && echo "Diverged seeds: ${FAILED[*]}"
[ "$FAIL" -eq 0 ]
