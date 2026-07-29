#!/usr/bin/env bash
set -u

ARCH_TEST="${ARCH_TEST:-$HOME/riscv-arch-test}"
# A "~/..." value arriving from a CI env block is a literal tilde that
# no shell has expanded; do it here so the path resolves either way.
ARCH_TEST="${ARCH_TEST/#\~/$HOME}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel)}"
COMPLIANCE="$REPO_ROOT/compliance"
SIM="$REPO_ROOT/obj_dir/Vcpu"
CYCLES=2000

SRC_DIR="$ARCH_TEST/riscv-test-suite/rv32i_m/I/src"
REF_DIR="$ARCH_TEST/riscv-test-suite/rv32i_m/I/references"
WORK_DIR="/tmp/compliance_run"
mkdir -p "$WORK_DIR"

PASS=0
FAIL=0
FAILED_TESTS=()

for src in "$SRC_DIR"/*.S; do
    name=$(basename "$src" .S)
    elf="$WORK_DIR/$name.elf"
    instr_hex="$WORK_DIR/$name.instr.hex"
    data_hex="$WORK_DIR/$name.data.hex"
    sig_out="$WORK_DIR/$name.sig.output"
    ref="$REF_DIR/$name.reference_output"

    if [ ! -f "$ref" ]; then
        echo "SKIP  $name (no reference file)"
        continue
    fi

    riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -static -mcmodel=medany \
        -fvisibility=hidden -nostdlib -nostartfiles \
        -T "$COMPLIANCE/link/rv32i-pipeline.ld" \
        -I "$COMPLIANCE/riscv-target/rv32i-pipeline" \
        -I "$ARCH_TEST/riscv-test-env" \
        -I "$ARCH_TEST/riscv-test-env/p" \
        -DXLEN=32 \
        "$src" -o "$elf" 2> "$WORK_DIR/$name.compile.log"
    if [ $? -ne 0 ]; then
        echo "FAIL  $name (compile error - see $WORK_DIR/$name.compile.log)"
        FAIL=$((FAIL+1)); FAILED_TESTS+=("$name (compile)")
        continue
    fi

    python3 "$COMPLIANCE/elf2hex.py" "$elf" "$instr_hex" "$data_hex" > /dev/null
    if [ $? -ne 0 ]; then
        echo "FAIL  $name (elf2hex error)"
        FAIL=$((FAIL+1)); FAILED_TESTS+=("$name (elf2hex)")
        continue
    fi

    begin_addr=$(riscv64-unknown-elf-nm "$elf" | awk '/ begin_signature$/{print $1}')
    end_addr=$(riscv64-unknown-elf-nm "$elf" | awk '/ end_signature$/{print $1}')
    begin_word=$(( (0x$begin_addr & 0xFFFF) / 4 ))
    end_word=$(( (0x$end_addr & 0xFFFF) / 4 ))

    "$SIM" +MEMFILE="$instr_hex" +DATAFILE="$data_hex" +REFFILE= +CYCLES=$CYCLES \
           +SIGSTART=$begin_word +SIGEND=$end_word +SIGFILE="$sig_out" \
           +VCD=/tmp/_compliance.vcd > "$WORK_DIR/$name.run.log" 2>&1

    if [ ! -f "$sig_out" ]; then
        echo "FAIL  $name (simulation produced no signature - check $WORK_DIR/$name.run.log)"
        FAIL=$((FAIL+1)); FAILED_TESTS+=("$name (no sig)")
        continue
    fi

    if diff -q "$sig_out" "$ref" > /dev/null; then
        echo "PASS  $name"
        PASS=$((PASS+1))
    else
        n_diff=$(diff "$sig_out" "$ref" | grep -c '^<')
        echo "FAIL  $name ($n_diff/$(wc -l < "$ref") words differ)"
        FAIL=$((FAIL+1)); FAILED_TESTS+=("$name")
    fi
done

echo ""
echo "========== $PASS/$((PASS+FAIL)) compliance tests passed =========="
if [ ${#FAILED_TESTS[@]} -gt 0 ]; then
    echo "Failed: ${FAILED_TESTS[*]}"
fi
