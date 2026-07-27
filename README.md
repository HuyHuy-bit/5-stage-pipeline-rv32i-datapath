# RV32I Pipelined CPU

A 5-stage pipelined RISC-V (RV32I) processor, written in SystemVerilog and verified against the official RISC-V architectural compliance suite.

[![RTL Tests](https://github.com/HuyHuy-bit/rv32i-pipeline/actions/workflows/rtl-tests.yml/badge.svg)](https://github.com/HuyHuy-bit/rv32i-pipeline/actions/workflows/rtl-tests.yml)

## What it does

Every cycle, up to five instructions are in flight at once, moving through **IF → ID → EX → MEM → WB**. The core implements the full RV32I base instruction set plus enough of the privileged spec to handle exceptions correctly:

- **Pipelining** — pipeline registers between every stage, with forwarding (EX/MEM and MEM/WB → EX) resolving most data hazards for free, and a hazard-detection unit stalling the one case forwarding can't fix (load-use).
- **Branch prediction** — a 64-entry BTB paired with 2-bit saturating counters (Smith 1982), predicting taken branches in the fetch stage and redirecting speculatively. Correctly-predicted taken branches cost zero cycles instead of the usual 2-cycle flush penalty; measured 80%+ accuracy on loop-heavy code.
- **Precise exceptions** — a single commit point in the MEM stage resolves all traps, so an exception always leaves architectural state exactly as if every older instruction completed and every younger one never ran. Covers illegal instructions, misaligned loads/stores, `ECALL`/`EBREAK`, and `MRET`, backed by a minimal M-mode CSR file (`mtvec`, `mepc`, `mcause`).
- **Memory hierarchy** — a parameterised instruction cache and data cache in front of a backing memory with configurable access latency. The D-cache supports write-through/no-allocate and write-back/write-allocate as a build-time choice, so the two can be measured against each other rather than argued about. Both caches sweep on capacity, block size, and associativity.
- **Performance counters** — cycle count, instructions retired, stall/flush counts, memory-stall cycles, branch-predictor accuracy, and per-cache access/miss counts, all exposed live so the pipeline's behavior is measurable, not just "it passes."

## Verification

- **11 hand-written directed tests** covering every instruction class, plus specific hazard, prediction, and exception-round-trip scenarios (each one written to catch a specific failure mode, not just exercise the happy path).
- **The official RISC-V `riscv-arch-test` compliance suite** (`rv32i_m/I`, base integer): **37/38 passing**, each result diffed word-for-word against the golden reference signature.
- CI runs the full directed-test suite on every push, and the compliance sweep whenever the RTL changes.

## Architecture

| Module | Role |
|---|---|
| `pc.sv`, `instr_mem.sv` | Fetch |
| `control.sv`, `reg_file.sv`, `imm_gen.sv` | Decode |
| `alu.sv`, `branch_unit.sv`, `forwarding_unit.sv`, `branch_predictor.sv` | Execute |
| `lsu.sv`, `dcache.sv`, `data_mem.sv` | Memory |
| `icache.sv` | Instruction cache (fetch path) |
| `mem_timing.sv` | Backing-memory access-cost model |
| `csr.sv` | Exception/CSR commit point |
| `hazard_detect.sv` | Load-use stall detection |
| `if_id_reg.sv` / `id_ex_reg.sv` / `ex_mem_reg.sv` / `mem_wb_reg.sv` | Pipeline registers |
| `rv32i_pkg.sv` | Shared opcode/ALU-op constants |

Every pipeline register carries a `valid` bit end-to-end, so a flushed bubble is always distinguishable from a genuinely-retired instruction — this is what makes the performance counters and precise exceptions trustworthy rather than approximate.

## Building and running

Requires **Verilator**. For the compliance suite, also **the RISC-V GNU toolchain**.

```bash
make lint    # syntax/structure check, no build
make all     # build the simulator, run all directed tests
make bench   # run the C benchmark kernels, print a CPI table
```

```bash
cd compliance && ./run_compliance.sh
```

Cache and latency settings are RTL parameters, so each configuration is its own simulator build. The benchmark runner handles that and caches builds per configuration:

```bash
./bench/run_bench.sh 10 1024 4 1
```

```bash
DC_BYTES=4096 DC_WB=1 ./bench/run_bench.sh 10 1024 4 1
```

```bash
./bench/sweep.sh 10
```

```bash
./bench/sweep_dcache.sh 10
```

## Performance

Five C kernels, compiled with the same toolchain the compliance suite uses. Nothing is hand-checked: each kernel is also compiled for the host and run there, and the CPU's result is compared against that, so a wrong answer fails the run rather than quietly skewing a number.

`crc32` is a tight bitwise loop, `matmul` a 16x16 integer multiply, `sort` a data-dependent bubble sort, `llist` a deliberately cache-hostile scattered pointer chase, and `interp` a stack-machine interpreter whose dispatch chain gives the I-cache a real instruction footprint to miss on.

CPI against a 10-cycle backing memory:

| kernel | no caches | +1KB I-cache | +4KB write-back D-cache | ideal 1-cycle memory |
|---|---|---|---|---|
| crc32  | 11.36 | 1.51 | **1.18** | 1.17 |
| matmul | 11.39 | 1.47 | **1.18** | 1.18 |
| sort   | 12.48 | 4.22 | **1.25** | 1.25 |
| llist  | 10.00 | 4.36 | **1.03** | 1.00 |
| interp | 11.88 | 2.60 | **1.19** | 1.19 |

The last column is the same core with a one-cycle memory — a machine that can never stall on an access. The cached configuration lands within 0.1–3% of it while actually paying 10 cycles per backing-memory access, so the hierarchy recovers essentially the whole latency penalty.

Three results from the sweeps that are worth more than the headline:

**Bigger blocks are not better blocks.** On `interp` with a 512B I-cache, sweeping block size inverts the two metrics against each other: 8-word blocks give the highest hit rate (96.8%) and the *worst* CPI (3.48), while 1-word blocks give the lowest hit rate (93.3%) and the *best* CPI (3.02). Refill cost outruns the locality it buys, and a cache tuned on hit rate alone would have picked the slowest configuration on the board. Measuring this at all requires the backing memory to model burst transfers; charge full latency per word and every block size above one loses for a reason that is an artifact of the model rather than a property of caches.

**Write-back is not a free upgrade.** It wins big where stores dominate — `sort` goes 2.25 to 1.25 CPI at 1KB — but *loses* to write-through on `matmul` at 256B and 1KB (1.54 vs 1.48, 1.32 vs 1.26). Write-allocate fetches a block before overwriting it, which is wasted work for a kernel that streams writes into memory it never reads back. The two policies cross over at 4KB.

**The hostile kernel behaves hostilely, until it doesn't.** `llist` chases 4KB of scattered pointers. With 1-word blocks it hits 0.17% of the time — the control case confirming the cache isn't quietly succeeding for the wrong reason. With 4-word blocks it reaches 74%, and at 4KB, where the pool finally fits, 99.3%. Non-monotonic in block size too: 8-word blocks are *worse* than 4-word (62.8% vs 74.2%), because a fixed capacity split into fewer, larger blocks thrashes harder on a scattered access pattern.

## What I learned

- **A clean single-cycle design pays for itself later.** Pipelining, forwarding, prediction, and exceptions were all added *around* the original ALU/control/decode logic without rewriting it — good early modularity compounds.
- **Forwarding and stalling solve different problems.** It's tempting to think of them as one "hazard handling" feature; they're not interchangeable, and conflating them is an easy way to miss the load-use case specifically.
- **The narrowest bugs are the easiest to miss and the most worth finding.** A same-cycle register-file write/read race, a CSR value that wasn't threaded through forwarding correctly, `FENCE` silently trapping as illegal — none of these fit the "adjacent instruction" mental model that motivates most hazard logic, and none of my own directed tests caught them until I specifically went looking.
- **Precise exceptions are a control-flow discipline, not a checklist.** Getting `mepc`/`mcause` right is easy; making sure a trap can't corrupt or duplicate architectural state under speculation (a mispredicted branch, an in-flight load) is the actual work.
- **Passing your own tests and being *correct* are different claims.** The compliance suite exists because directed tests, however careful, reflect the blind spots of whoever wrote them. Running against an external, independently-generated reference is what turns "I believe this works" into "this is verified."

## Notes

This is a learning project — a real, working pipelined core with genuine hazard/prediction/exception logic and a measured memory hierarchy, verified against the actual RISC-V spec, but not synthesized, not power/timing-aware, and not carrying a randomized/formal verification methodology beyond the directed and compliance test suites described above.

Two limitations worth stating plainly, because they bound what the numbers above mean:

- **Cycles only, no clock.** Every result here is CPI at a fixed cycle count. A cache lowers CPI and lengthens the critical path, and without synthesis only the first half of that trade is visible. Treat the speedups as upper bounds until there is an fmax number beside them.
- **The pipeline freezes globally on a memory stall** rather than letting the back end drain through an instruction-fetch miss. It costs overlap a real design would recover, and it inflates the cached and uncached numbers alike, so it doesn't manufacture a speedup — but a decoupled front end with a fetch buffer would make the I-cache look slightly less essential than it does here.
