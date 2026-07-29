#!/usr/bin/env bash
# run_lockstep.sh — run the compliance suite through Spike co-simulation.
#
# Same programs the signature-based flow uses (compliance/run_compliance.sh),
# but linked for Spike's memory map and compared instruction-by-instruction
# instead of only at the final signature. That difference is the point: a
# program can reach the right final state via the wrong path, and only a
# retirement-by-retirement comparison sees it.
set -u

ARCH_TEST="${ARCH_TEST:-$HOME/riscv-arch-test}"
# A "~/..." value arriving from a CI env block is a literal tilde that
# no shell has expanded; do it here so the path resolves either way.
ARCH_TEST="${ARCH_TEST/#\~/$HOME}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
SIM="${SIM:-$REPO_ROOT/obj_dir_lockstep/Vcpu}"
CYCLES="${CYCLES:-4000}"
WORK="${TMPDIR:-/tmp}/rv32i_lockstep"

SRC_DIR="$ARCH_TEST/riscv-test-suite/rv32i_m/I/src"
mkdir -p "$WORK"

if [ ! -x "$SIM" ]; then
    echo "error: $SIM not built — run 'make lockstep-sim' first" >&2
    exit 1
fi

PASS=0; FAIL=0; FAILED=()
for src in "$SRC_DIR"/*.S; do
    name=$(basename "$src" .S)
    elf="$WORK/$name.elf"

    if ! riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany \
            -fvisibility=hidden -nostdlib -nostartfiles \
            -T "$REPO_ROOT/compliance/link/spike-lockstep.ld" \
            -I "$REPO_ROOT/compliance/riscv-target/rv32i-pipeline" \
            -I "$ARCH_TEST/riscv-test-env" -I "$ARCH_TEST/riscv-test-env/p" \
            -DXLEN=32 "$src" -o "$elf" 2> "$WORK/$name.cc.log"; then
        echo "FAIL  $name (compile — see $WORK/$name.cc.log)"
        FAIL=$((FAIL+1)); FAILED+=("$name"); continue
    fi

    python3 "$REPO_ROOT/compliance/elf2hex.py" "$elf" \
        "$WORK/$name.instr.hex" "$WORK/$name.data.hex" > /dev/null || {
        echo "FAIL  $name (elf2hex)"; FAIL=$((FAIL+1)); FAILED+=("$name"); continue; }

    if python3 "$REPO_ROOT/tools/lockstep.py" "$elf" \
           "$WORK/$name.instr.hex" "$WORK/$name.data.hex" \
           --sim "$SIM" --cycles "$CYCLES" -q; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1)); FAILED+=("$name")
    fi
done

echo ""
echo "========== $PASS/$((PASS+FAIL)) programs match Spike instruction-for-instruction =========="
[ ${#FAILED[@]} -gt 0 ] && echo "Diverged: ${FAILED[*]}"
[ "$FAIL" -eq 0 ]
