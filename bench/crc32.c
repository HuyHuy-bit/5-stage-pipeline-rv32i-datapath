/* crc32.c - bitwise CRC-32 over a 1KB buffer.
 *
 * Table-free on purpose: a lookup table would land in .rodata (instr_mem),
 * which loads can't reach on this Harvard split. The bitwise form is also
 * the better I-cache benchmark - a tiny inner loop, 8192 iterations, near
 * total instruction locality with a purely sequential data stream.
 */
#define BUFLEN 1024

static unsigned char buf[BUFLEN];

unsigned bench(void) {
    unsigned i, k, crc = 0xFFFFFFFFu, seed = 0xACE1u;

    for (i = 0; i < BUFLEN; i++) {
        seed ^= seed << 13;
        seed ^= seed >> 17;
        seed ^= seed << 5;
        buf[i] = (unsigned char)(seed >> 16);
    }

    for (i = 0; i < BUFLEN; i++) {
        crc ^= buf[i];
        for (k = 0; k < 8; k++)
            crc = (crc & 1u) ? (crc >> 1) ^ 0xEDB88320u : (crc >> 1);
    }

    return crc ^ 0xFFFFFFFFu;
}
