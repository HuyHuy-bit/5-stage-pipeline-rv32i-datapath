# Verification plan

What's tested, by what mechanism, and what's explicitly not tested yet.

## Directed tests (`tests/`, run via `make all`)

11 hand-assembled programs, one per hazard/instruction-class scenario (R-type, I-type, memory, branch, jump, LUI/AUIPC, load-use stall, loop, illegal-instruction trap, misaligned trap, MRET). Each checks final register state against a `.ref` file. Runs on every push, across the 6-configuration cache matrix in `.github/workflows/rtl-tests.yml` — the pass/fail result must be identical in all 6, since cache configuration is not supposed to be architecturally visible.

**Catches:** instruction decode/execute bugs, the specific hazard each test targets, exception entry/exit for the cases named above.
**Doesn't catch:** anything the test author didn't think to write a scenario for. Final-register-state comparison also can't distinguish "got the right answer via the wrong path" from "got the right answer" — a bug that's masked rather than avoided passes silently.

## Compliance suite (`compliance/`, run via `run_compliance.sh`)

The official `riscv-arch-test` `rv32i_m/I` suite: 38 programs, independently written, each producing a signature dumped to memory and diffed word-for-word against a golden reference. Currently 38/38 passing. Runs in CI whenever `rtl/**` changes.

**Catches:** ISA-conformance bugs the directed suite's author (same person as the RTL author) wouldn't think to target — this is the point of using an external, independently-generated suite.
**Doesn't catch:** anything outside the base integer ISA (no M/C/Zicsr-suite coverage), and like the directed tests, it's a final-state signature comparison, not an instruction-by-instruction trace check.

## C benchmark kernels (`bench/`)

Five kernels (`crc32`, `matmul`, `sort`, `llist`, `interp`), each also compiled and run on the host; the RTL's result is compared against the host's. Not part of CI pass/fail today — used for performance measurement (see the README's Performance section), but a wrong answer does fail the run rather than silently skewing the CPI numbers.

**Catches:** correctness bugs exercised by realistic, longer-running code paths that the short directed tests don't reach.
**Doesn't catch:** anything not exercised by these five specific access/control-flow patterns.

## SVA assertions (`rtl/cpu.sv`, `rtl/reg_file.sv`)

13 concurrent assertions, built into every simulator binary via `verilator --assert` and checked on every cycle of every test, directed and benchmark alike: trap/MRET mutual exclusion, frozen-PC stability under a memory stall, next-PC redirect priority (trap vs. mispredict), no request reaching memory with a pending exception, stall boundedness (scoped to exclude the testbench's own debug cache-flush hook, which is legitimately long-running), `x0` immutability, no bubble retiring, no register write on a trap, and forwarding priority/no-forward-through-x0.

**Catches:** any RTL change that violates one of these invariants, in any test, immediately — including tests that would otherwise pass on final-state comparison alone. Two were found to be mis-specified during authoring (not RTL bugs): an x0-write check that didn't match how `reg_file.sv` actually guards the write, and a stall-bound check that didn't account for the debug flush path; both were corrected against the RTL's actual behavior, not the other way around.
**Doesn't catch:** anything not already expressed as a property. The set above is representative, not exhaustive — CSR-specific and interrupt invariants are natural additions once Phase 8 lands interrupts.

## Functional coverage (`make coverage`, `docs/coverage.md`)

Verilator doesn't support SystemVerilog covergroups; `cover property` is the supported equivalent and feeds the same `--coverage` database. 38 cover points across forwarding-path crosses, predictor-outcome crosses, control-flow type, trap causes, and the full D-cache FSM (every state, every legal transition, hit/miss/dirty-evict crossed with load/store). Currently **25/38 (65.8%)** hit by the directed suite alone against a cache-enabled build.

**Catches:** silently-untested scenarios — "the directed suite exercises everything that matters" is now a number, not a claim.
**Doesn't catch:** anything a cover point wasn't written for. The unhit list in `docs/coverage.md` is the actual to-do list: `ecall`/`ebreak` traps, a misaligned-load trap, a genuine predictor target mismatch, and a few D-cache transitions (idle→writeback, writeback→fill, flush→idle) aren't exercised by the 11 directed tests as they stand today — closing those is directed-test work, not infrastructure work.

## Constrained-random regression (`make soak`, `tools/rand_gen.py`)

Spike-based lockstep (the plan's original ask here) is blocked in this sandbox on installing Spike's build dependencies without root — see above. `tools/rv32i_model.py` is the pragmatic substitute: a ~90-line Python interpreter for the subset `tools/rand_gen.py` generates (R-type/I-type ALU ops, word loads/stores against a small aligned scratch region, no branches/jumps/traps/CSRs). `tools/rand_gen.py` emits raw instruction words plus a `.ref` computed by running the same words through the model, so a generated program plugs directly into the existing `+MEMFILE=`/`+REFFILE=` comparison the directed tests already use — no new comparison logic. Generation is biased toward dependency distance 1-2 (60% chance a source register is one of the last two destinations), since that's where forwarding and load-use bugs live.

`make soak SEEDS=1000` (default 100) runs that many programs seed-by-seed; a failing seed prints the seed number and the paths to its program/expected/log for reproduction. 1000 seeds at 80 instructions each pass clean against both the cacheless default build and a cache-enabled one (4-way write-back D$, 4-way I$) in about 20 seconds.

**Catches:** forwarding and load-use bugs in the ALU/load-store subset, independent of the directed suite's own blind spots — the same class of value the compliance suite provides, generalized past a fixed instruction list.
**Doesn't catch:** anything involving branches, jumps, traps, interrupts, or CSRs (out of the model's scope — those stay covered by the directed suite, compliance suite, and assertions instead). This is real scope, not decoration: don't read "1000/1000 passed" as "the random suite verifies control flow," because it doesn't.

## Not yet done

- **Instruction-by-instruction lockstep against a golden model** (e.g. Spike) — would catch the "right answer via the wrong path" class of bug that final-state comparison structurally cannot, and would extend constrained-random coverage to the full ISA including control flow and traps. Largest single verification upgrade available; blocked in this environment on installing Spike's build dependencies (needs root).
- **Synthesis / static timing** — none of the above says anything about whether the design closes timing; see the README's Notes section.
- **mstatus / interrupts** — see the README's Notes section; no `mie`/`mip`/timer, so there's nothing here to test yet.
