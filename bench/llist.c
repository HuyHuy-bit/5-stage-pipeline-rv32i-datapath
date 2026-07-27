/* llist.c - pointer chase through a 4KB node pool in scattered order.
 *
 * The cache-hostile one. Nodes are linked p -> (p + 269) mod 512, and 269 is
 * coprime with 512, so the chain visits every node exactly once in an order
 * with no spatial locality worth exploiting. The pool is deliberately larger
 * than the D-cache sizes worth building here, so the hit rate should stay
 * poor no matter how the cache is configured - the control case that stops
 * "the cache helped" from looking like a universal law.
 */
#define NODES  512
#define STRIDE 269
#define PASSES 32

struct node {
    struct node *next;
    unsigned     val;
};

static struct node pool[NODES];

unsigned bench(void) {
    unsigned i, p = 0, sum = 0;
    struct node *n;

    for (i = 0; i < NODES; i++)
        pool[i].val = i * 7u + 1u;

    for (i = 0; i < NODES; i++) {
        unsigned q = (p + STRIDE) % NODES;
        pool[p].next = &pool[q];
        p = q;
    }

    n = &pool[0];
    for (i = 0; i < NODES * PASSES; i++) {
        sum += n->val;
        n = n->next;
    }

    return sum;
}
