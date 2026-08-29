# LunaChip

> Phase 0 is implemented and locally gated. Phase 1's combinational language
> and reference execution are implemented; prepared-schedule allocation
> profiling remains before the phase is declared passed. LunaChip does not yet
> claim SystemVerilog compatibility, FPGA execution, physical design, or
> fabricated silicon.

LunaChip is a MoonBit-native hardware construction and simulation product:

- **LunaWire** builds typed, clocked hardware graphs.
- **LunaWave** simulates those graphs deterministically.

The first reference design is FluxTile-0, a small host-driven tensor
accelerator intended to prove the complete language-to-simulation-to-RTL flow.

Detailed documents are under docs/.

## System placement

~~~mermaid
flowchart LR
    N["LunaNexa<br/>fleet and deployment"] --> F["LunaFlux<br/>serving and execution plans"]
    F --> A["External LunaChip device adapter"]
    A --> C["FluxTile accelerator"]
    W["LunaWire"] --> I["Canonical Luna IR"]
    I --> S["LunaWave"]
    I --> V["SystemVerilog / CIRCT"]
    V --> E["Verilator / Yosys / FPGA / ASIC"]
~~~

LunaChip does not import LunaFlux or LunaNexa. A LunaFlux-owned adapter may
consume LunaChip's published command, register, and capability contracts.

## Current milestone

The current implementation includes:

- stable diagnostics with source spans and semantic paths;
- checked canonical bit-vector and graph vocabulary;
- deterministic schema-v1 IR serialization, strict parsing, and fixed digests;
- deterministic LunaWire construction with explicit arithmetic, comparisons,
  shifts, slices, concatenation, casts, registers, and cycle diagnostics;
- shared `0/1/X` semantics and a no-duplicate-logic LunaWave interpreter;
- exhaustive small-width and deterministic seeded conformance tests;
- black-box MoonBit tests and generated public interfaces;
- supply-chain-pinned native CI and an external-tool lock-manifest format;
- research-grounded product, semantic, architecture, and implementation plans.

SystemVerilog emission, external differential testing, synthesis, formal
verification, FluxTile hardware, FPGA execution, and physical design remain
explicit later gates.

See [docs/STATUS.md](docs/STATUS.md) for the evidence-backed phase ledger.

## Target repository map

~~~text
ir/                 canonical public hardware IR
ir/codec/           versioned deterministic canonical serialization
diagnostics/        stable codes, source spans, paths, and corrections
semantics/          shared digital value and operation semantics
wire/               LunaWire construction API and elaboration validation
wave/               LunaWave values, scheduling, simulation, and traces
emit/systemverilog/ standard RTL backend
emit/circt/         optional CIRCT textual backend
formal/             property export and formal evidence
designs/flux_tile/  first host-driven tensor accelerator
cmd/lunachip/       inspection and simulation CLI
docs/               product, semantics, architecture, research, and plan
~~~

Packages are created only when their vertical phase begins. Empty architectural
directories are not treated as implementation.

## Bootstrap validation

~~~sh
moon info
moon fmt
moon check --target native --deny-warn
moon test --target native --deny-warn
moon run --target native cmd/lunachip
~~~

The external hardware toolchain will be pinned separately. Host-global
Verilator, Yosys, CIRCT, OpenROAD, and PDK installations are not assumed.
