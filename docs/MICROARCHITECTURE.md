# Microarchitecture specification

## Overview and design goals

A 5-stage in-order RV32I pipeline optimized for **measurable trade-offs over raw performance**: every major design choice below has a cheaper or faster alternative that was deliberately not taken, and the point of the project is to state what it cost. It is not optimized for area, power, or clock frequency (no synthesis run exists yet — see Limitations), and it deliberately does not implement interrupts, `FENCE.I`, or any extension beyond base RV32I.

## Pipeline organization

IF → ID → EX → MEM → WB, one instruction wide, in order. See the datapath diagram in the [README](../README.md#datapath) for the full block diagram, including both forwarding paths, the load-use stall path, and the next-PC priority mux.

- **IF**: PC → optional I-cache → `instr_mem`. Branch prediction (BTB + 2-bit counters) looks up in parallel with fetch and can redirect the *next* fetch speculatively.
- **ID**: decode (`control.sv`), register read (`reg_file.sv`, with a same-cycle write/read bypass), immediate generation.
- **EX**: ALU, branch/jump resolution, forwarding mux (EX/MEM and MEM/WB → EX).
- **MEM**: optional D-cache → `data_mem`; also the single commit point for traps, MRET, and CSR writes.
- **WB**: register file write-back.

Every pipeline register carries a `valid` bit end-to-end, so a flushed bubble is distinguishable from a genuinely-retired instruction at every stage — this is what makes the performance counters and precise exceptions exact rather than approximate.

## Major trade-offs, with their cost

Each entry: what was chosen, the alternative, what it costs, and the evidence.

### EX-resolve branches, not ID-resolve
**Chosen:** branches and jumps resolve in EX. **Alternative:** resolve in ID, which would cut the mispredict penalty from 2 cycles to 1. **Cost:** an ID-stage comparator on what's likely close to the critical path already, plus a second forwarding network feeding it (EX/MEM and MEM/WB values would need to reach ID, not just EX). **Evidence:** none measured — this would need the fmax numbers Phase 6 of the improvement plan calls for, which this pass didn't produce (see Limitations). The 2-cycle penalty itself is directly measured: `bpred: mispredicts=N` in every test's perf counters, and the branch-predictor accuracy figures in the README's Performance section (80%+ on loop-heavy code) are the reason it doesn't dominate.

### Global pipeline freeze, not a decoupled front end
**Chosen:** any memory stall (`pipe_stall`) freezes the *entire* pipeline — PC, all four pipeline registers, the predictor, the CSR file, and the counters — for the cycle. **Alternative:** a fetch buffer between IF and ID would let the back end drain through an instruction-fetch miss instead of stalling on it. **Cost:** this is the single biggest structural limiter in the design (see `cpu.sv`'s `ponytail:` comment at the freeze mux). It inflates both the cached and uncached CPI numbers in the README's Performance section equally, so it doesn't fabricate a cache speedup, but it does mean the I-cache's measured benefit is somewhat inflated relative to what a decoupled front end would show — a D-cache miss currently stalls fetch too, which a real design would avoid. **Not implemented this pass**: a correct fetch-buffer redesign touches the freeze/flush/redirect priority logic this whole codebase's precise-exception and forwarding guarantees are built on, and validating it needs the lockstep golden model (blocked — see Limitations) as a regression net. Attempting it without one risks introducing exactly the kind of subtle pipeline bug the verification work in this pass was aimed at catching.

### Blocking caches, not hit-under-miss
**Chosen:** both caches are blocking — one outstanding miss stalls everything behind it. **Alternative:** a single MSHR would let independent hits proceed under a miss. **Cost:** simplicity (`dcache.sv`'s FSM is 4 states) against throughput lost to serialization; not quantified here for the same reason as above — it's downstream of the decoupled-front-end work.

### Write-through vs. write-back, both implemented and measured
**Chosen:** the D-cache supports both as a build-time parameter (`DCACHE_WRITE_BACK`), rather than picking one. **Cost:** none architecturally — this is the one trade-off in this list that's fully measured rather than argued about. The README's Performance section has the actual numbers: write-back wins on `sort` (2.25 → 1.25 CPI at 1KB) but *loses* to write-through on `matmul` at 256B/1KB, crossing over at 4KB. The comparison is somewhat unfair to write-through as implemented (no write buffer — every store pays full backing-memory latency), which the improvement plan flags as a natural next measurement; not done this pass.

### FIFO victim selection, not LRU
**Chosen:** both caches use a simple round-robin/FIFO victim pointer per set (`ponytail:` comments in `icache.sv` and `dcache.sv`). **Alternative:** true LRU. **Cost:** for the associativities actually swept in this project (1-4 way), the plan predicts the difference is usually small for a 2-way cache — that's a real, cheap-to-run finding this pass didn't get to. Not measured here.

### Single MEM commit point for precise exceptions
**Chosen:** every control-flow-changing exceptional event (trap, MRET, CSR write) resolves at one point, in MEM, in program order. **Alternative:** none seriously — this is what makes the exception model precise "for free" (see `cpu.sv`'s commit-point comment) rather than needing a reorder buffer. **Cost:** none beyond what precise exceptions cost anywhere: the offending and every younger instruction must be flushable, which is why `valid` is threaded through every pipeline register. This is the foundation the 13 SVA assertions and the directed exception tests (`t09`–`t15`) check.

### BTB-gated prediction (never predicts taken until a first taken hit)
**Chosen:** a branch is only ever predicted taken after the BTB has already recorded a taken outcome for it — the first execution of any branch is always predicted not-taken. **Cost:** every branch pays a guaranteed misprediction on its first taken occurrence; measured indirectly in the `bpred: accuracy=` figures already reported per test/kernel.

### A structural read-only-CSR convention, not a hand-maintained permission table
**Chosen:** CSR write permission is derived from address bits `[11:10] == 2'b11` (the standard RISC-V convention), rather than a per-CSR read/write flag. **Cost:** none found — this is a case where following the spec's own structural convention was strictly simpler than the alternative, not a trade-off with a real downside.

## Hazard and exception model

- **Data hazards**: EX/MEM and MEM/WB forwarding cover same-register producer/consumer pairs at distance 1 and 2; load-use (distance-1 dependency on a load, which forwarding can't fix because the value doesn't exist yet at EX) is caught by `hazard_detect.sv` and resolved with a one-cycle stall. See the load-use timing diagram in the README.
- **Control hazards**: predicted speculatively in IF; resolved in EX. A misprediction squashes IF/ID and ID/EX (the two younger in-flight instructions) — see the mispredict timing diagram in the README.
- **Exceptions**: illegal instruction, misaligned load/store, misaligned fetch (taken branch/JAL to a non-4-byte-aligned target), `ECALL`/`EBREAK`, and illegal CSR access (unimplemented address, or a write to a structurally read-only one) are all detected in EX and committed at the MEM commit point — see the trap timing diagram in the README. `mepc`/`mcause`/`mtval` are set on entry; `MRET` restores `mepc` as the redirect target. There is no `mstatus.MIE`/`MPIE`/`MPP` stack — see Limitations.
- **Priority** (next-PC mux, highest to lowest): memory-stall freeze > trap/MRET commit > EX misprediction recovery > load-use stall > front-end predicted-taken redirect > sequential.

## Memory hierarchy

![Memory hierarchy](mem_hierarchy.svg)

`lsu.sv` handles RV32I subword load/store semantics (sign/zero extension, byte-enable generation); `dcache.sv`/`icache.sv` hold geometry and policy; `mem_timing.sv` is the backing-memory access-cost model everything above scales against. The burst-refill discount it models (full `LATENCY` for the first word of a block, 1 cycle per sequential word after) is what makes the block-size sweep in the README's Performance section mean anything — without it, every block size above one word would look strictly worse, which would be an artifact of the model, not a property of caches.

![D-cache FSM](cache_fsm.svg)

## Performance results

See the README's [Performance](../README.md#performance) section for the full CPI table and the three sweep findings (block-size/hit-rate inversion, write-back's non-uniform win, and `llist`'s non-monotonic block-size behavior). No fmax numbers exist for this design — see Limitations.

## Verification summary

See [`docs/VERIFICATION_PLAN.md`](VERIFICATION_PLAN.md) for the full breakdown. In one line each:

- 15 directed tests + 38/38 compliance tests, both run across a 6-configuration cache/latency CI matrix (66+114 test executions per push).
- 13 SVA properties, checked on every cycle of every test and benchmark run.
- 38 functional cover points (`cover property`, the supported stand-in for covergroups on this toolchain); 25/38 (65.8%) hit by the directed suite alone.
- Constrained-random regression (`make soak`) against a small Python golden model, 1000/1000 seeds clean on both cacheless and cache-enabled builds — scoped to the ALU/load-store subset (see Limitations).

## Known limitations and future work

Kept in the same honest tone as the README's Notes section, because a list like this is worth more than it costs to write:

- **No synthesis.** No fmax, area, or critical-path numbers exist for this design. Every trade-off above that says "not quantified here" is waiting on this. Blocked in the environment this pass ran in: no Vivado/Yosys/nextpnr installed, and no root to install one.
- **No Spike lockstep.** The largest single verification upgrade available (instruction-by-instruction comparison against an independent reference, catching "right answer via the wrong path" bugs that final-state comparison structurally can't) is blocked the same way — Spike needs a build toolchain (device-tree-compiler, boost) this sandbox has no root to install. The constrained-random regression's Python golden model is a partial, ALU/load-store-only substitute.
- **No decoupled front end, no non-blocking caches, no store buffer.** All three are real, well-understood next steps (10b/10c in the improvement plan) but each is a significant redesign of the freeze/flush/redirect logic this pass's verification work was built to protect; none were attempted without the lockstep regression net to validate them against.
- **No interrupts.** `mie`/`mip`/`mtime`/`mtimecmp` and `mstatus.MIE`/`MPIE`/`MPP` don't exist. Synchronous exceptions are precise and fully tested; nothing asynchronous is implemented.
- **No `FENCE.I`.** Decodes as a no-op. Self-modifying or dynamically-loaded code can observe stale instructions after a store to code space.
- **No AXI wrapper.** The bespoke `req`/`burst`/`ready` memory-port protocol works but isn't the industry-standard interface an SoC integration would expect.
