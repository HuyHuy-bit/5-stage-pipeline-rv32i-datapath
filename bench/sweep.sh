#!/usr/bin/env bash
# sweep.sh [latency] - run the kernels across a range of I-cache geometries and
# print CPI and hit rate as a matrix.
#
# The point of a parameterised cache is the curve, not any one configuration.
# Three questions get asked here, each holding everything else fixed:
#   capacity      - how small can it get before the working set stops fitting
#   block size    - spatial locality traded against refill cost
#   associativity - how much of what's left is conflict rather than capacity
set -u

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATENCY="${1:-10}"
KERNELS=(crc32 matmul sort llist interp)

# label:bytes:block:ways   (bytes 0 = no cache)
CONFIGS=(
    "none:0:4:1"
    "128B b4 1w:128:4:1"
    "256B b4 1w:256:4:1"
    "512B b4 1w:512:4:1"
    "1KB  b4 1w:1024:4:1"
    "512B b1 1w:512:1:1"
    "512B b2 1w:512:2:1"
    "512B b8 1w:512:8:1"
    "512B b4 2w:512:4:2"
    "1KB  b4 2w:1024:4:2"
)

echo "I-cache sweep, backing memory latency = $LATENCY cycles"
echo

hdr=$(printf '%-12s' "config")
for k in "${KERNELS[@]}"; do hdr+=$(printf '%18s' "$k"); done
echo "$hdr"
echo "$(printf '%-12s' '')$(for k in "${KERNELS[@]}"; do printf '%18s' 'CPI / hit%'; done)"
printf '%.0s-' $(seq 1 $((12 + 18 * ${#KERNELS[@]}))); echo

for cfg in "${CONFIGS[@]}"; do
    label="${cfg%%:*}"; rest="${cfg#*:}"
    bytes="${rest%%:*}"; rest="${rest#*:}"
    block="${rest%%:*}"; ways="${rest#*:}"

    out=$("$BENCH_DIR/run_bench.sh" "$LATENCY" "$bytes" "$block" "$ways" 2>/dev/null)
    if ! grep -q "all kernels produced the expected result" <<< "$out"; then
        printf '%-12s  BUILD/RUN FAILED (rerun run_bench.sh %s %s %s %s)\n' \
               "$label" "$LATENCY" "$bytes" "$block" "$ways"
        continue
    fi

    row=$(printf '%-12s' "$label")
    for k in "${KERNELS[@]}"; do
        line=$(awk -v k="$k" '$1==k' <<< "$out")
        cpi=$(awk '{print $4}' <<< "$line")
        hr=$(awk '{print $NF}' <<< "$line")
        row+=$(printf '%18s' "$(printf '%.2f / %s' "$cpi" "$hr")")
    done
    echo "$row"
done
