#!/usr/bin/env bash
# sweep_dcache.sh [latency] - D-cache geometry and write-policy sweep.
#
# The I-cache is pinned at 1KB/4-word/1-way throughout, since its own sweep
# showed everything at or above 256B saturating on these kernels. Holding it
# fixed keeps the numbers here attributable to the data side.
set -u

BENCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATENCY="${1:-10}"
KERNELS=(crc32 matmul sort llist interp)

# label:bytes:block:ways:writeback   (bytes 0 = no D-cache)
CONFIGS=(
    "none          :0:4:1:0"
    "256B b4 1w wt :256:4:1:0"
    "1KB  b4 1w wt :1024:4:1:0"
    "4KB  b4 1w wt :4096:4:1:0"
    "256B b4 1w wb :256:4:1:1"
    "1KB  b4 1w wb :1024:4:1:1"
    "4KB  b4 1w wb :4096:4:1:1"
    "1KB  b1 1w wb :1024:1:1:1"
    "1KB  b8 1w wb :1024:8:1:1"
    "1KB  b4 2w wb :1024:4:2:1"
    "4KB  b4 2w wb :4096:4:2:1"
)

echo "D-cache sweep, memory latency = $LATENCY cycles, I-cache fixed at 1KB/4w/1-way"
echo

printf '%-15s' "config"; for k in "${KERNELS[@]}"; do printf '%18s' "$k"; done; echo
printf '%-15s' "";       for k in "${KERNELS[@]}"; do printf '%18s' 'CPI / hit%'; done; echo
printf '%.0s-' $(seq 1 $((15 + 18 * ${#KERNELS[@]}))); echo

for cfg in "${CONFIGS[@]}"; do
    label="${cfg%%:*}"; rest="${cfg#*:}"
    bytes="${rest%%:*}"; rest="${rest#*:}"
    block="${rest%%:*}"; rest="${rest#*:}"
    ways="${rest%%:*}";  wb="${rest#*:}"

    out=$(DC_BYTES="$bytes" DC_BLOCK="$block" DC_WAYS="$ways" DC_WB="$wb" \
          "$BENCH_DIR/run_bench.sh" "$LATENCY" 1024 4 1 2>/dev/null)
    if ! grep -q "all kernels produced the expected result" <<< "$out"; then
        printf '%-15s  FAILED (DC_BYTES=%s DC_BLOCK=%s DC_WAYS=%s DC_WB=%s)\n' \
               "$label" "$bytes" "$block" "$ways" "$wb"
        continue
    fi

    printf '%-15s' "$label"
    for k in "${KERNELS[@]}"; do
        line=$(awk -v k="$k" '$1==k' <<< "$out")
        printf '%18s' "$(printf '%.2f / %s' "$(awk '{print $4}' <<< "$line")" \
                                            "$(awk '{print $NF}' <<< "$line")")"
    done
    echo
done
