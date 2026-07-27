/* sort.c - bubble sort over 256 unsigned words.
 *
 * ~32K inner iterations whose branch outcome depends entirely on unsorted
 * data, so the 2-bit bimodal predictor has nothing to learn. This is the
 * kernel where a predictor upgrade shows up, and where the current one
 * should look worst.
 */
#define N 256

static unsigned arr[N];

static unsigned rnd(unsigned *s) {
    unsigned x = *s;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    *s = x;
    return x;
}

unsigned bench(void) {
    unsigned i, j, sum = 0, seed = 0xC0FFEEu;

    for (i = 0; i < N; i++)
        arr[i] = rnd(&seed);

    for (i = 0; i + 1 < N; i++)
        for (j = 0; j + 1 < N - i; j++)
            if (arr[j] > arr[j + 1]) {
                unsigned t = arr[j];
                arr[j]     = arr[j + 1];
                arr[j + 1] = t;
            }

    for (i = 0; i < N; i++)
        sum = sum * 31u + arr[i];

    return sum;
}
