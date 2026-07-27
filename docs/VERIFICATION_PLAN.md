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

## Not yet done

- **Instruction-by-instruction lockstep against a golden model** (e.g. Spike) — would catch the "right answer via the wrong path" class of bug that final-state comparison structurally cannot. Largest single verification upgrade available; not yet implemented.
- **Formal properties / SVA assertions** on the invariants already understood well enough to state in English (trap/MRET mutual exclusion, `x0` never written, frozen-PC stability, forwarding priority, cache FSM legality) — not yet converted into checked properties.
- **Functional coverage** on forwarding-path crosses, predictor outcome crosses, cache FSM transitions, trap causes — not yet measured, so "the directed suite exercises everything that matters" is currently a claim, not a number.
- **Constrained-random testing** against a golden model — would generalize past the blind spots of whoever wrote the directed and even the compliance tests.
- **Synthesis / static timing** — none of the above says anything about whether the design closes timing; see the README's Notes section.
