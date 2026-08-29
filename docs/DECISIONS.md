# LunaChip architecture decisions

This file is the initial architecture decision log. Decisions are immutable in
meaning: a replacement adds a new entry and marks the old entry superseded.

## ADR-001: One product with two version-locked components

**Status:** Accepted

**Decision:** LunaWire and LunaWave live in one LunaChip repository and release.

**Reason:** They share one semantics and canonical IR; releasing them
independently would create an immediate compatibility matrix and allow language
changes without a matching reference execution.

## ADR-002: LunaWire is an embedded MoonBit construction library

**Status:** Accepted

**Decision:** The first frontend is a MoonBit API, not a standalone HDL parser.

**Reason:** Host-language execution provides parameterization, abstraction,
packages, testing, and tooling while preserving a static hardware graph after
elaboration. Chisel and Amaranth validate the broad approach.

**Consequence:** Hardware and host values require visibly distinct types and
operations. Generator code is trusted build-time executable code.

## ADR-003: MoonBit-owned canonical Core RTL IR

**Status:** Accepted

**Decision:** A small, versioned, deterministic Core RTL IR is the semantic
source of truth. SystemVerilog and CIRCT are backends.

**Reason:** This keeps LunaWire and LunaWave stable and testable without making
an external compiler version or broad HDL syntax authoritative.

## ADR-004: Strict explicit semantics

**Status:** Accepted

**Decision:** Exactly one driver; no implicit widths, casts, clocks, resets, or
memory collision behavior; combinational cycles are rejected.

**Reason:** Convenient ambiguity becomes backend divergence and simulation/
synthesis mismatch. Explicitness improves diagnostics, formal reasoning, and
deterministic lowering.

## ADR-005: Known-mask values, no internal Z initially

**Status:** Accepted

**Decision:** Reference values contain bits plus a known mask, representing
`0`, `1`, and `X`. Internal `Z` and analog resolution are excluded initially.

**Reason:** Unknown-state behavior is necessary for reset and uninitialized
state correctness. Full four-state/strength semantics would greatly expand
scope. Physical bidirectional IO can use explicit input/output/enable signals.

## ADR-006: Reference simulation owns semantics

**Status:** Accepted

**Decision:** LunaWave begins as a clear deterministic MoonBit reference
engine. Compiled simulation is a later conforming optimization.

**Reason:** Debuggability and an executable oracle matter before maximum speed.
Multiple engines without a reference would allow silent semantic drift.

## ADR-007: Deterministic event queue, not wall-clock concurrency

**Status:** Accepted

**Decision:** Hardware time is integer simulated time and stable event order.
MoonBit async scheduling may support UI or file IO but never defines simulated
ordering.

**Reason:** Reproducible hardware behavior, snapshots, and differential tests
require independence from host scheduling and timing.

## ADR-008: Conservative SystemVerilog interoperability

**Status:** Accepted

**Decision:** Emit a small explicit synthesizable SystemVerilog subset and use
pinned Verilator and Yosys as independent tools. Do not implement arbitrary
SystemVerilog parsing.

**Reason:** Standard RTL unlocks verification, synthesis, FPGA, and ASIC flows
without turning LunaChip into a full standards implementation.

## ADR-009: External tools are pinned evidence producers

**Status:** Accepted

**Decision:** Verilator, Yosys, SymbiYosys, CIRCT, FPGA tools, and OpenROAD are
external, version-pinned, isolated tools. Results include artifact digests,
versions, commands/configuration, and reports.

**Reason:** Reproducibility and independent checking are more valuable than
hidden host-global integrations. LunaChip does not claim ownership of their
capabilities.

## ADR-010: Host-attached FluxTile-0 before CPU/SoC integration

**Status:** Accepted

**Decision:** The first accelerator uses a memory command ring and abstract
memory port, not a custom CPU instruction interface.

**Reason:** This isolates the tensor architecture and device ABI from a CPU,
ISA, cache hierarchy, and SoC generator. It also gives an external LunaFlux
adapter a portable contract.

## ADR-011: INT8/INT32 systolic array first

**Status:** Accepted

**Decision:** FluxTile-0 begins with an 8×8 signed INT8 array and INT32
accumulation. BF16 begins only as a later functional model.

**Reason:** Integer arithmetic reduces datapath and numerical-verification
scope while proving elaboration, simulation, memories, control, RTL, and
synthesis. It is a toolchain proof, not the final LunaFlux performance target.

## ADR-012: Radically separate evidence levels

**Status:** Accepted

**Decision:** Constructed, simulated, differentially simulated, formally
checked, synthesized, FPGA demonstrated, GDS produced, fabricated, and silicon
validated are distinct project states.

**Reason:** Hardware projects commonly overstate downstream maturity. Precise
claims protect technical decisions, users, and future investment.

## ADR-013: LunaFlux adapter remains external

**Status:** Accepted

**Decision:** LunaChip publishes a generic device ABI. LunaFlux owns any
compiler/runtime adapter; LunaNexa observes only LunaFlux's generic hardware
capability.

**Reason:** Hardware construction and simulation must not couple to model
serving or fleet control. This preserves independent release and permits other
software stacks to target LunaChip devices.

## ADR-014: No silent target fallback

**Status:** Accepted

**Decision:** If a backend cannot preserve a requested clock, memory,
arithmetic, or property semantic, capability validation fails with a checked
diagnostic.

**Reason:** Silent rewrites are a direct path to simulation/synthesis mismatch.
Users may explicitly select a documented transformation, whose effect then
enters the artifact digest.

## ADR-015: One canonical implementation per concept

**Status:** Accepted

**Decision:** Experiments are either promoted and old paths removed, or kept in
clearly experimental packages outside stable artifacts. Permanent parallel
“v1/v2” elaborators, IRs, and simulators are prohibited.

**Reason:** Compatibility branches and global option interactions are the main
technical-debt pattern LunaChip is designed to avoid.

## Open decisions

These require implementation evidence before acceptance:

- binary versus canonical textual IR serialization format;
- digest algorithm and long-term canonicalization rules;
- exact MoonBit API shape for builders and typed signals;
- whether four-state precision is bit-precise or word-conservative in Phase 2;
- native compiled-simulator strategy versus CIRCT Arc;
- first FPGA board and host transport;
- first physical-design target, if Phase 9 is authorized;
- stable foreign-module contract;
- exact ready/valid combinator library and CDC primitive set.

Each open decision must be resolved by a focused experiment, conformance
fixtures, and a new ADR—not by an undocumented implementation accident.

