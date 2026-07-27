#!/usr/bin/env bash
# run_bench.sh [latency] [icache_bytes] [block_words] [ways]
#
# Builds and runs the benchmark kernels and prints a CPI table.
#
# Expected results are not stored anywhere. Each kernel is also compiled for
# the host and executed there, and the CPU's x10 is checked against that.
# The kernels are plain unsigned C, so any disagreement is a CPU bug.
#
# `latency` (default 1) is the backing-memory access cost in cycles, applied to
# both memories. icache_bytes 0 (the default) bypasses the cache entirely.
# All of these are RTL parameters, so each combination needs its own simulator
# build; builds are cached per-configuration under obj_dir_<cfg>.
set -u

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$BENCH_DIR")"
LD="$ROOT/compliance/link/rv32i-pipeline.ld"
ELF2HEX="$ROOT/compliance/elf2hex.py"
WORK="${TMPDIR:-/tmp}/rv32i_bench"
CYCLES=600000         # testbench timeout multiplier, not a cycle budget

LATENCY="${1:-1}"
IC_BYTES="${2:-0}"
IC_BLOCK="${3:-4}"
IC_WAYS="${4:-1}"

KERNELS=(crc32 matmul sort llist interp)
mkdir -p "$WORK"

if [ "$LATENCY" -le 1 ] && [ "$IC_BYTES" -eq 0 ]; then
    SIM="$ROOT/obj_dir/Vcpu"          # the plain build the Makefile already makes
    if [ ! -x "$SIM" ]; then
        echo "error: $SIM not built - run 'make sim' first" >&2
        exit 1
    fi
else
    OBJ="$ROOT/obj_dir_L${LATENCY}_ic${IC_BYTES}_b${IC_BLOCK}_w${IC_WAYS}"
    SIM="$OBJ/Vcpu"
    if [ ! -x "$SIM" ]; then
        echo "building simulator: latency=$LATENCY icache=${IC_BYTES}B/${IC_BLOCK}w/${IC_WAYS}way ..." >&2
        verilator --cc --exe --build --trace -j 0 --top-module cpu \
            -GIMEM_LATENCY="$LATENCY" -GDMEM_LATENCY="$LATENCY" \
            -GICACHE_BYTES="$IC_BYTES" -GICACHE_BLOCK_WORDS="$IC_BLOCK" \
            -GICACHE_WAYS="$IC_WAYS" \
            --Mdir "$OBJ" \
            "$ROOT"/rtl/rv32i_pkg.sv $(ls "$ROOT"/rtl/*.sv | grep -v rv32i_pkg.sv) "$ROOT/cpu_tb.cpp" \
            > "$WORK/build.log" 2>&1 || { cat "$WORK/build.log" >&2; exit 1; }
    fi
fi

if [ "$IC_BYTES" -eq 0 ]; then
    echo "memory latency: $LATENCY cycle(s), I-cache: none"
else
    echo "memory latency: $LATENCY cycle(s), I-cache: ${IC_BYTES}B ${IC_BLOCK}-word blocks ${IC_WAYS}-way"
fi

printf '%-10s %10s %10s %7s %8s %10s %9s %9s\n' \
       kernel cycles instret CPI flushes memstall bpred-acc ic-hitrate
printf '%.0s-' {1..80}; echo

FAIL=0
for k in "${KERNELS[@]}"; do
    src="$BENCH_DIR/$k.c"

    # --- expected result, from the same C compiled natively ---
    if ! cc -O2 -o "$WORK/$k.host" "$BENCH_DIR/host_main.c" "$src" 2> "$WORK/$k.host.log"; then
        echo "$k: host build failed - see $WORK/$k.host.log" >&2
        FAIL=1; continue
    fi
    expected=$("$WORK/$k.host")

    # --- target build ---
    if ! riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -O2 -static -mcmodel=medany \
            -nostdlib -nostartfiles -ffreestanding -fno-builtin -fno-jump-tables \
            -T "$LD" "$BENCH_DIR/crt0.S" "$src" -o "$WORK/$k.elf" -lgcc \
            2> "$WORK/$k.build.log"; then
        echo "$k: target build failed - see $WORK/$k.build.log" >&2
        FAIL=1; continue
    fi

    # .rodata is linked into instr_mem, but loads read data_mem. Anything
    # landing there would read back garbage on the CPU while working fine on
    # the host - exactly the kind of mismatch that wastes an afternoon.
    rodata=$(riscv64-unknown-elf-size -A "$WORK/$k.elf" | awk '/^\.rodata/{print $2}')
    if [ -n "${rodata:-}" ] && [ "$rodata" -gt 0 ]; then
        echo "$k: $rodata bytes in .rodata - unreachable by loads on this Harvard split" >&2
        FAIL=1; continue
    fi

    python3 "$ELF2HEX" "$WORK/$k.elf" "$WORK/$k.instr.hex" "$WORK/$k.data.hex" > /dev/null || {
        echo "$k: elf2hex failed" >&2; FAIL=1; continue; }

    echo "x10=$expected" > "$WORK/$k.ref"

    "$SIM" +MEMFILE="$WORK/$k.instr.hex" +DATAFILE="$WORK/$k.data.hex" \
           +REFFILE="$WORK/$k.ref" +CYCLES=$CYCLES +VCD= > "$WORK/$k.run.log" 2>&1
    rc=$?

    perf=$(grep -m1 'perf: cycles=' "$WORK/$k.run.log")
    bp=$(grep -m1 'bpred: branches=' "$WORK/$k.run.log")
    ic=$(grep -m1 'icache: hits=' "$WORK/$k.run.log")
    get() { sed -n "s/.*$1=\([0-9.]*\).*/\1/p" <<< "$2"; }

    if [ -z "$perf" ]; then
        printf '%-10s %s\n' "$k" "no perf output - see $WORK/$k.run.log"
        FAIL=1; continue
    fi

    if [ "$IC_BYTES" -eq 0 ]; then ichr="-"; else ichr="$(get hitrate "$ic")%"; fi
    printf '%-10s %10s %10s %7s %8s %10s %8s%% %9s' \
        "$k" "$(get cycles "$perf")" "$(get instret "$perf")" "$(get CPI "$perf")" \
        "$(get flushes "$perf")" "$(get memstall "$perf")" \
        "$(get accuracy "$bp")" "$ichr"

    if [ $rc -ne 0 ]; then
        got=$(sed -n 's/.*x10  got=0x\([0-9a-f]*\).*/\1/p' "$WORK/$k.run.log")
        printf '   WRONG RESULT (got 0x%s, expected %u)' "${got:-?}" "$expected"
        FAIL=1
    fi
    echo
done

echo
[ $FAIL -eq 0 ] && echo "all kernels produced the expected result" \
                || echo "one or more kernels failed - logs in $WORK"
exit $FAIL
