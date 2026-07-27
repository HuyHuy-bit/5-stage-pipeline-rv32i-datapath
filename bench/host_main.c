/* host_main.c - drives a kernel natively so run_bench.sh can derive the
 * expected result instead of hand-maintaining golden values. The kernels are
 * plain unsigned C, so the host and the CPU must agree bit-for-bit. */
#include <stdio.h>

unsigned bench(void);

int main(void) {
    printf("%u\n", bench());
    return 0;
}
