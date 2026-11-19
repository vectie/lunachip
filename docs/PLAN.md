# LunaChip implementation plan

## Method

Development is semantics-first and evidence-driven. Each phase produces a
small executable vertical slice, records independent evidence, and removes
experiments that do not become part of the selected architecture. The project
does not claim a later physical stage because an earlier software stage passed.

The phase matrix uses four statuses: `not-started`, `in-progress`, `passed`, and
`blocked`. Only reproducible gate evidence permits `passed`.

The current evidence ledger is maintained in [`STATUS.md`](STATUS.md). The
plan remains normative; implementation progress does not silently weaken a
gate.

## Phase 0 — Repository and semantic skeleton

Deliver:

- focused MoonBit packages for public `ir`, `wire`, `semantics`, and `wave`;
- checked diagnostic model with stable codes and source spans;
- exact-width types and stable IDs;
- immutable canonical design/module/value skeleton;
- deterministic textual or JSON serialization with schema version;
- CI and pinned external-tool manifest format.

Gate:

- `moon info`, `moon fmt`, native deny-warning check, and native tests pass;
- serialize/parse/serialize is byte stable;
- construction order fixtures have stable IDs and digests;
- invalid width and invalid reference fixtures return checked diagnostics.

Claim after passing: LunaChip has a canonical IR skeleton. No simulator or RTL
claim is allowed.

## Phase 1 — Combinational LunaWire and LunaWave

Deliver:

- module, input, output, literal, bitwise, arithmetic, comparison, slice,
  concatenation, cast, and mux builders;
- exact-width and signedness rules from `SEMANTICS.md`;
- single-driver and missing-driver checks;
- combinational dependency graph and cycle diagnostics;
- topological Simulation IR;
- two-state execution plus known-mask representation;
- adder, ALU, mux, and combinational-loop fixtures.

Gate:

- exhaustive tests for small widths where feasible;
- randomized operation tests against a simple mathematical oracle;
- cycle diagnostics include a stable minimal cycle path;
- no allocations in a prepared steady-state evaluation loop, or a recorded
  profile identifies and schedules the remaining work.

Claim: combinational designs run under LunaWave reference semantics.

## Phase 2 — Sequential semantics, trace, and replay

Deliver:

- one explicit rising-edge domain;
- registers, enable, synchronous reset, and unreset unknown state;
- deterministic event/step API;
- assertions and cover points;
- native trace schema, VCD export, snapshots, and replay bundles;
- counter, LFSR, pipeline, and ready/valid fixtures.

Gate:

- simultaneous register-commit tests catch ordered-update bugs;
- reset/enable priority exhaustively tested;
- replay of each failure produces the same event and trace digest;
- VCD renders in a common viewer and signal names map back to source metadata.

Claim: single-clock sequential designs are deterministically simulated.

## Phase 3 — SystemVerilog and independent differential validation

Deliver:

- conservative synthesizable SystemVerilog emitter;
- emitted-name and source-map manifest;
- pinned Verilator environment and harness generator;
- deterministic stimulus bridge and normalized result comparison;
- lint and unsupported-feature diagnostics.

Gate:

- at least 100,000 randomized cycles across representative designs agree
  between LunaWave and a pinned Verilator build;
- mismatch reducer emits a minimal replay fixture;
- all emitted RTL passes the selected Verilator lint policy;
- backend output is stable for identical semantic input.

Claim: the named subset is differentially validated against generated
SystemVerilog. This is still a simulation claim.

## Phase 4 — Memories and formal properties

Deliver:

- synchronous memory with explicit ports, latency, masks, and collision rules;
- FIFO and banked-memory library components;
- assertion/assumption/cover export;
- pinned Yosys and SymbiYosys tasks;
- proof manifests recording bounds, engines, assumptions, and artifact digest.

Gate:

- LunaWave/Verilator agreement for each memory policy;
- Yosys synthesis succeeds for supported memory forms;
- FIFO safety properties pass both bounded and selected unbounded tasks;
- intentionally broken fixtures fail with expected counterexamples;
- no report uses “proved” for a bounded-only result.

Claim: named properties passed named formal tasks and supported RTL synthesizes
through the pinned flow.

## Phase 5 — Language foundation and multi-clock events

Deliver:

- parameterized module generators, `Vec`, `Bundle`, and ready/valid library;
- deterministic aggregate lowering and debug reconstruction metadata;
- asynchronous reset only after its ordering is completely tested;
- multiple explicit clocks and deterministic coincident-edge semantics;
- explicit synchronizer, handshake, and asynchronous FIFO primitives;
- CDC lint and formal fixtures.

Gate:

- aggregate flatten/reconstruct round trips preserve names and values;
- randomized rational clock schedules replay identically;
- synchronizer/async-FIFO properties pass their declared formal tasks;
- no implicit domain crossings pass validation.

Claim: the documented multi-clock digital model is supported. No analog
metastability claim is allowed.

## Phase 6 — FluxTile-0 simulation proof

Deliver:

- versioned device ABI and capability manifest;
- bounded command ring, descriptor frontend, scoreboard, completion/fault path;
- decoupled load, execute, and store controllers;
- banked scratchpad, accumulator storage, and simple memory model;
- 8×8 signed INT8 systolic array with INT32 accumulation;
- `LoadTile`, `MatMul`, `StoreTile`, and `Fence` commands;
- MoonBit functional matrix oracle and performance counters.

Gate:

- random legal matrices and edge values match the functional oracle;
- LunaWave and Verilator agree cycle-for-cycle at the device boundary;
- formal checks cover command bounds, no illegal issue, FIFO safety, dependency
  ordering, and eventual completion under explicit fairness assumptions;
- injected invalid descriptors produce exact documented faults;
- backpressure and memory latency are randomized;
- Yosys reports and generated RTL are archived by digest.

Claim: FluxTile-0 is a simulated, differentially validated, synthesizable
reference accelerator. Do not call it a chip or FPGA accelerator yet.

## Phase 7 — FPGA demonstration

Deliver:

- one named development-board target;
- target-specific clock/reset, memory, and host transport shells kept outside
  the portable core;
- bitstream build recipe and version lock;
- host diagnostic tool and external LunaFlux adapter experiment;
- on-board self-test, workload capture, and measured counters.

Gate:

- place-and-route timing closes for the declared clock constraint;
- bitstream runs on the named physical board;
- transfer, matmul, reset, cancellation/fault, and soak tests pass;
- on-board outputs match the software oracle;
- logs identify board, FPGA part, tool versions, bitstream digest, clock, and
  workload;
- power numbers, if reported, name the instrument and measurement conditions.

Claim: demonstrated on the named FPGA board. This is not ASIC evidence.

## Phase 8 — Accelerator utility

The [recorded LunaTile hardware direction](LUNATILE_HETEROGENEOUS_TILES.md)
describes a proposed external backend and heterogeneous matrix/vector tile
experiment, with numerical, storage and event contracts preceding replication.
It records future work; existing phase prerequisites and evidence gates remain
unchanged.

Deliver only after Phase 7:

- design-space parameters for array shape, banks, and capacities;
- vector lane for normalization/RoPE candidates;
- BF16 functional semantics followed by separately verified synthesizable
  arithmetic;
- compiler/runtime scheduling experiment in an external LunaFlux adapter;
- performance model separating compute, scratchpad, host-link, and memory
  bottlenecks.

Gate:

- every configuration carries capability and evidence manifests;
- numerical error bounds are specified and tested;
- performance comparisons use identical end-to-end conditions;
- added hardware improves a declared workload rather than a microbenchmark
  alone.

Claim: only the exact measured configuration and workload.

## Phase 9 — RTL-to-GDS research proof

Deliver:

- a small, frozen core or test vehicle, not the full performance target;
- target PDK/library selection and license/provenance record;
- synthesis constraints, floorplan, power grid, placement, routing, extraction,
  timing, DRC, and LVS artifacts using a pinned flow;
- post-synthesis and post-layout simulation where supported;
- explicit list of checks that are tool-level versus foundry-qualified.

Gate:

- OpenROAD Flow or another named flow completes reproducibly;
- timing results name clocks, corners, extraction, and derates;
- DRC/LVS results name decks and waivers;
- generated GDS, netlist, constraints, and reports are content-addressed;
- reviewers agree the language is “GDS produced,” not “taped out” or
  “fabricated.”

Claim: GDS generated and listed checks passed under the named research flow.

## Phase 10 — Optional fabrication and silicon validation

This phase requires an external foundry/shuttle decision, budget, package,
board, test plan, and risk review. It is not implied by Phase 9.

Gate for “fabricated”:

- foundry accepted the submission and manufactured dies;
- received-die evidence and lot/shuttle identity are recorded.

Additional gate for “silicon validated”:

- packaged device and board are identified;
- bring-up, scan/test where applicable, command, memory, compute, frequency,
  voltage, temperature, and power procedures are recorded;
- measured results and failures are published without substituting simulated
  values.

## Continuous quality gates

At each completed MoonBit phase:

```sh
moon info
moon fmt
moon check --target native --deny-warn
moon test --target native --deny-warn
```

Additional permanent gates:

- black-box public API tests and checked documentation examples;
- stable IR golden fixtures with reviewed migrations;
- property-based and metamorphic tests for width/value operations;
- differential simulation on every supported construct;
- seeded randomized tests with replay artifacts;
- fuzz limits and denial-of-service resource bounds;
- source files preferably below 500 lines, ADR required above 800;
- public interface diff review through generated `.mbti` files;
- benchmarks report hardware, OS, compiler, warmup, repetitions, variance, and
  artifact digest.

## First 12 implementation issues

1. Define diagnostic codes, source spans, stable IDs, and resource limits.
2. Define `Bits`, `UInt`, `SInt`, width validation, and known-mask values.
3. Define immutable Design/Module/Port/Value canonical IR types.
4. Implement deterministic canonical serialization and digest fixtures.
5. Implement LunaWire module builder with scope and single-driver checks.
6. Implement literal, logic, add, compare, slice, concat, cast, and mux.
7. Implement dependency graph, topological order, and cycle diagnostics.
8. Implement prepared combinational LunaWave execution.
9. Add registers, one clock domain, synchronous reset, and simultaneous commit.
10. Add assertions, deterministic stimulus, native trace, VCD, and replay.
11. Emit conservative SystemVerilog for the completed subset.
12. Run randomized differential validation under a pinned Verilator container.

The first external toolchain should be a pinned Linux container; host-global
tool installations are not a reproducible project contract.
