# Verification plan

What's tested, by what mechanism, and what's explicitly not tested yet.

| Mechanism | Scale | What it uniquely catches |
|---|---|---|
| Directed tests | 19 programs × 6 cache configs | The specific hazard/trap each was written for |
| Compliance suite | 38/38 `rv32i_m/I` | ISA conformance the author wouldn't think to target |
| Spike lockstep | 38 programs, instruction-by-instruction | Right answer reached by the *wrong path* |
| SVA assertions | 25 properties, every cycle | Invariant violations, in any test, immediately |
| Functional coverage | 33/38 points (86.8%) | Scenarios nothing exercises |
| Constrained-random | 1000 seeds vs. a reference model | Blind spots of whoever wrote the directed tests |

## Directed tests (`tests/`, run via `make all`)

19 hand-assembled programs, one per hazard/instruction-class/trap scenario: R-type, I-type, memory, branch, jump, LUI/AUIPC, load-use stall, loop, illegal instruction, misaligned load/store/fetch, MRET, CSR read/write, CSR permission traps, timer interrupt, MRET-from-interrupt, ECALL/EBREAK, and D-cache dirty eviction. Each checks final register state against a `.ref` file, across the 6-configuration cache matrix — the result must be identical in all 6, since cache configuration is not architecturally visible.

Every test ends by storing to a reserved address (`tohost`, the riscv-tests convention); the run stops there and the stored value is the exit code. This replaced a `same_pc >= 6` heuristic that inferred completion from the PC not moving — which cannot distinguish "finished" from "spinning on a lock", "stalled on slow memory", or "stuck", and made every legitimately-looping test a guess. Completion is detected where the store *commits* rather than by watching memory, so it behaves identically with a write-back cache holding the value dirty.

Tests name their trap handler via a `la` pseudo-instruction rather than a hardcoded byte offset. That is not cosmetic: adding the `tohost` sequence shifted every handler label and broke eight tests at once, because they computed `mtvec` by counting instructions.

**Catches:** decode/execute bugs, the specific hazard each test targets, trap entry/exit.
**Doesn't catch:** anything the author didn't think to write. Final-state comparison also can't distinguish "right answer via the wrong path" from "right answer" — which is what lockstep below is for.

## Compliance suite (`compliance/`)

The official `riscv-arch-test` `rv32i_m/I` suite: 38 independently-written programs, each dumping a signature diffed word-for-word against a golden reference. **38/38 passing.** Runs in CI whenever `rtl/**` changes.

**Catches:** ISA-conformance bugs the directed suite's author (same person as the RTL author) wouldn't target.
**Doesn't catch:** anything outside base RV32I, and it is still a final-state comparison.

## Spike lockstep (`make lockstep`)

The same 38 compliance programs, re-linked for Spike's memory map and compared **retirement by retirement** — PC, instruction word, destination register, and written value. **38/38 match instruction-for-instruction** (`add-01` alone is 3,212 retirements).

The RTL exposes an RVFI-style trace at WB (`rvfi_*` in `backend.sv`), simulation-only, so no pipeline register is widened to serve a debug consumer. `tools/lockstep.py` streams Spike's commit log and stops at the *first* divergence, printing both sides and the preceding retirements — a mismatch reported 400 instructions later is nearly useless.

Both machines run the *same ELF*. Spike reserves low memory, so `compliance/link/spike-lockstep.ld` relocates to `0x80000000`; the RTL's memories decode only their low address bits, so that image aliases back to the same words, and only the reset vector needs adjusting (`RESET_PC`).

**Catches:** the "right answer via the wrong path" class — wrong forwarding masked by a dead value, a flush that squashes one instruction too many, a stale CSR read nobody observes. This is what made the Phase 7 refactor safe to attempt.
**Doesn't catch:** anything outside the 38 programs; it is not yet wired to random stimulus.

## SVA assertions

**25 concurrent properties**, built into every simulator binary via `--assert`, checked on every cycle of every test and benchmark. Placed beside the logic they constrain: next-PC redirect priority in `frontend.sv`, forwarding/trap/interrupt invariants in `backend.sv`, `x0` immutability in `reg_file.sv`, stall-boundedness at the top level.

The interrupt properties are the sharpest: an interrupt resumes at `pc+4` while a trap re-runs the faulting instruction, so `a_irq_mepc_is_next` and `a_trap_mepc_is_faulting` pin down both directions — getting them backwards silently drops or repeats work.

**Catches:** any change violating an invariant, immediately, in any test.
**Doesn't catch:** anything not expressed as a property. Three were found mis-specified during authoring (not RTL bugs) and corrected against the RTL's actual behaviour, not the reverse.

## Functional coverage (`make coverage`, `docs/coverage.md`)

Verilator doesn't support covergroups; `cover property` is the supported equivalent. 38 points across forwarding crosses, predictor-outcome crosses, control-flow type, trap causes, and the full D-cache FSM. **33/38 (86.8%)** from the directed suite alone.

Each of the five remaining holes is annotated in `docs/coverage.md` with *why* it is still open — none is dead logic. They need either a BTB tag collision, a load-use/mispredict coincidence, or an indirect-jump target mismatch, all of which random stimulus reaches more naturally than a directed test.

## Constrained-random (`make soak`)

`tools/rand_gen.py` emits random ALU/load-store programs; `tools/rv32i_model.py` is a small Python reference model that computes the expected result. **1000 seeds pass clean** against both cacheless and cache-enabled builds.

**Doesn't catch:** branches, jumps, traps, interrupts, or CSRs — out of the model's scope. Don't read "1000/1000 passed" as "random testing verifies control flow". Pointing the generator at Spike instead of the Python model would remove this limit entirely and is the obvious next step.

## Not yet done

- **Random stimulus through lockstep.** The generator and the Spike harness both exist but aren't connected; joining them would extend random coverage to the full ISA including control flow and traps.
- **Interrupt testing under random stimulus.** Interrupts are covered by directed tests only.
- **Formal.** The RVFI port makes a formal flow (e.g. riscv-formal) bindable, but none is set up.
- **Timing closure.** Nothing here says whether the design meets timing; see the synthesis section of `docs/MICROARCHITECTURE.md`.
