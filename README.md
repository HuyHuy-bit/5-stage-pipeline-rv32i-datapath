# RV32I Pipelined CPU

A 5-stage pipelined RISC-V (RV32I) processor, written in SystemVerilog and verified against the official RISC-V architectural compliance suite.

[![RTL Tests](https://github.com/HuyHuy-bit/rv32i-pipeline/actions/workflows/rtl-tests.yml/badge.svg)](https://github.com/HuyHuy-bit/rv32i-pipeline/actions/workflows/rtl-tests.yml)

## What it does

Every cycle, up to five instructions are in flight at once, moving through **IF → ID → EX → MEM → WB**. The core implements the full RV32I base instruction set plus enough of the privileged spec to handle exceptions correctly:

- **Pipelining** — pipeline registers between every stage, with forwarding (EX/MEM and MEM/WB → EX) resolving most data hazards for free, and a hazard-detection unit stalling the one case forwarding can't fix (load-use).
- **Branch prediction** — a 64-entry BTB paired with 2-bit saturating counters (Smith 1982), predicting taken branches in the fetch stage and redirecting speculatively. Correctly-predicted taken branches cost zero cycles instead of the usual 2-cycle flush penalty; measured 80%+ accuracy on loop-heavy code.
- **Precise exceptions** — a single commit point in the MEM stage resolves all traps, so an exception always leaves architectural state exactly as if every older instruction completed and every younger one never ran. Covers illegal instructions, misaligned loads/stores, `ECALL`/`EBREAK`, and `MRET`, backed by a minimal M-mode CSR file (`mtvec`, `mepc`, `mcause`).
- **Performance counters** — cycle count, instructions retired, stall/flush counts, and branch-predictor accuracy, all exposed live so the pipeline's behavior is measurable, not just "it passes."

## Verification

- **11 hand-written directed tests** covering every instruction class, plus specific hazard, prediction, and exception-round-trip scenarios (each one written to catch a specific failure mode, not just exercise the happy path).
- **The official RISC-V `riscv-arch-test` compliance suite** (`rv32i_m/I`, base integer): **38/38 passing**, each result diffed word-for-word against the golden reference signature.
- CI runs the full directed-test suite on every push, and the compliance sweep whenever the RTL changes.

## Architecture

| Module | Role |
|---|---|
| `pc.sv`, `instr_mem.sv` | Fetch |
| `control.sv`, `reg_file.sv`, `imm_gen.sv` | Decode |
| `alu.sv`, `branch_unit.sv`, `forwarding_unit.sv`, `branch_predictor.sv` | Execute |
| `data_mem.sv` | Memory |
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
cd compliance && ./run_compliance.sh   # run the official compliance suite
```

## What I learned

- **A clean single-cycle design pays for itself later.** Pipelining, forwarding, prediction, and exceptions were all added *around* the original ALU/control/decode logic without rewriting it — good early modularity compounds.
- **Forwarding and stalling solve different problems.** It's tempting to think of them as one "hazard handling" feature; they're not interchangeable, and conflating them is an easy way to miss the load-use case specifically.
- **The narrowest bugs are the easiest to miss and the most worth finding.** A same-cycle register-file write/read race, a CSR value that wasn't threaded through forwarding correctly, `FENCE` silently trapping as illegal — none of these fit the "adjacent instruction" mental model that motivates most hazard logic, and none of my own directed tests caught them until I specifically went looking.
- **Precise exceptions are a control-flow discipline, not a checklist.** Getting `mepc`/`mcause` right is easy; making sure a trap can't corrupt or duplicate architectural state under speculation (a mispredicted branch, an in-flight load) is the actual work.
- **Passing your own tests and being *correct* are different claims.** The compliance suite exists because directed tests, however careful, reflect the blind spots of whoever wrote them. Running against an external, independently-generated reference is what turns "I believe this works" into "this is verified."

## Notes

This is a learning project — a real, working pipelined core with genuine hazard/prediction/exception logic, verified against the actual RISC-V spec, but not synthesized, not power/timing-aware, and not carrying a randomized/formal verification methodology beyond the directed and compliance test suites described above.