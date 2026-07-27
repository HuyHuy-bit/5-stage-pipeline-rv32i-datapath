# Functional coverage report

**25/38 cover points hit (65.8%)**, from the directed test suite run against a cache-enabled build (`make coverage`).

| Cover point | Hits |
|---|---|
| `cpu.c_branch_nottaken` | 1 |
| `cpu.c_branch_taken` | 60 |
| `cpu.c_cause_ebreak` | 0 **(unhit)** |
| `cpu.c_cause_ecall` | 0 **(unhit)** |
| `cpu.c_cause_illegal` | 2 |
| `cpu.c_cause_mis_load` | 0 **(unhit)** |
| `cpu.c_cause_mis_store` | 1 |
| `cpu.c_false_predict` | 0 **(unhit)** |
| `cpu.c_jal` | 2964 |
| `cpu.c_jalr` | 1 |
| `cpu.c_load_use_and_mispredict` | 0 **(unhit)** |
| `cpu.c_mret` | 1 |
| `cpu.c_pred_nn` | 0 **(unhit)** |
| `cpu.c_pred_nt` | 101 |
| `cpu.c_pred_tn` | 1 |
| `cpu.c_pred_tt_match` | 2924 |
| `cpu.c_pred_tt_mismatch` | 0 **(unhit)** |
| `cpu.c_trap_pending_and_stall` | 0 **(unhit)** |
| `cpu.g_dcache.u_dcache.c_dirty_evict` | 0 **(unhit)** |
| `cpu.g_dcache.u_dcache.c_hit_load` | 27 |
| `cpu.g_dcache.u_dcache.c_hit_store` | 16 |
| `cpu.g_dcache.u_dcache.c_miss_load` | 0 **(unhit)** |
| `cpu.g_dcache.u_dcache.c_miss_store_alloc` | 2 |
| `cpu.g_dcache.u_dcache.c_state_fill` | 32 |
| `cpu.g_dcache.u_dcache.c_state_flush` | 2829 |
| `cpu.g_dcache.u_dcache.c_state_idle` | 768 |
| `cpu.g_dcache.u_dcache.c_state_wb` | 32 |
| `cpu.g_dcache.u_dcache.c_trans_fill_to_idle` | 2 |
| `cpu.g_dcache.u_dcache.c_trans_flush_to_idle` | 0 **(unhit)** |
| `cpu.g_dcache.u_dcache.c_trans_flush_to_wb` | 2 |
| `cpu.g_dcache.u_dcache.c_trans_idle_to_fill` | 2 |
| `cpu.g_dcache.u_dcache.c_trans_idle_to_flush` | 11 |
| `cpu.g_dcache.u_dcache.c_trans_idle_to_wb` | 0 **(unhit)** |
| `cpu.g_dcache.u_dcache.c_trans_wb_to_fill` | 0 **(unhit)** |
| `cpu.g_dcache.u_dcache.c_trans_wb_to_flush` | 2 |
| `cpu.g_fwd_a[*].g_fwd_b[0]` | 3550 |
| `cpu.g_fwd_a[*].g_fwd_b[1]` | 70 |
| `cpu.g_fwd_a[*].g_fwd_b[2]` | 41 |

## Unhit points

- `cpu.c_cause_ebreak`
- `cpu.c_cause_ecall`
- `cpu.c_cause_mis_load`
- `cpu.c_false_predict`
- `cpu.c_load_use_and_mispredict`
- `cpu.c_pred_nn`
- `cpu.c_pred_tt_mismatch`
- `cpu.c_trap_pending_and_stall`
- `cpu.g_dcache.u_dcache.c_dirty_evict`
- `cpu.g_dcache.u_dcache.c_miss_load`
- `cpu.g_dcache.u_dcache.c_trans_flush_to_idle`
- `cpu.g_dcache.u_dcache.c_trans_idle_to_wb`
- `cpu.g_dcache.u_dcache.c_trans_wb_to_fill`
