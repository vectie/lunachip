# LunaChip

> Phases 0 through 4 are implemented and locally gated. LunaChip now has a
> deterministic single-clock construction/simulation foundation, first-class
> synchronous memories, a differentially validated conservative SystemVerilog
> backend, pinned synthesis evidence, and named bounded/unbounded formal
> results. Phase 5 language and multi-clock work is in progress but not yet
> evidence-gated. LunaChip does not yet claim FPGA execution, timing closure,
> physical RAM mapping, physical design, or fabricated silicon.

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
- deterministic schema-v3 IR serialization for memories and reset-to-data
  conversion, byte-stable schema-1/2 compatibility, and fixed digests;
- deterministic LunaWire construction with explicit arithmetic, comparisons,
  shifts, slices, concatenation, casts, registers, and cycle diagnostics;
- shared `0/1/X` semantics and a no-duplicate-logic LunaWave interpreter;
- exhaustive small-width and deterministic seeded conformance tests;
- explicit rising-edge domains, active-high synchronous reset, enable/hold,
  unreset X state, simultaneous commit, and deterministic snapshots;
- cycle-stamped assertions and cover points with explicit X behavior;
- canonical changed-only traces, deterministic VCD and source maps, plus
  executable replay bundles with preserved result digests;
- counter, maximal-length LFSR, pipeline, and ready/valid elastic fixtures;
- deterministic conservative SystemVerilog-2017 emission with a canonical
  all-node name manifest and fail-closed unsupported-feature diagnostics;
- a normalized identity-first differential comparator and deterministic
  mismatch reducer;
- a digest-pinned Verilator 5.050 OCI gate whose six representative fixtures
  agree with LunaWave for 102,000 post-reset cycles;
- synchronous memories with exact one-cycle read latency, explicit masks,
  bounds, disabled-read, read/write collision, and deterministic multi-write
  policies across canonical IR, LunaWire, LunaWave, and SystemVerilog;
- reusable FIFO and banked-memory components that elaborate only through the
  public LunaWire API;
- a second pinned Verilator memory gate whose eight positive fixtures agree
  for 104,000 cycles and whose enabled out-of-bounds and dynamic Reject
  fixtures fail on their exact emitted assertion labels;
- a digest-pinned Yosys 0.68 synthesis matrix covering nine emitted memory,
  FIFO, and banked-memory forms without claiming physical RAM or timing;
- canonical assertion/assumption/cover export with typed task/result/evidence
  manifests, retained counterexamples, a bounded FIFO safety pass, a cover
  witness, and a separately selected four-property k-induction proof;
- one fail-closed Phase 4 aggregate command that binds all seven contract
  claims and rejects any repository-input drift;
- in-progress schema-4 parameters, aggregate reconstruction, port timing, and
  checked CDC primitive metadata with exact older-schema compatibility;
- deterministic atomic rational-clock simulation, schema-2 trace/VCD/replay,
  fail-closed CDC provenance, and a public two-through-four-stage one-bit
  synchronizer construction API;
- a reproducible prepared-loop allocation probe with every current allocation
  source measured and scheduled for removal;
- black-box MoonBit tests and generated public interfaces;
- supply-chain-pinned native CI and an external-tool lock-manifest format;
- research-grounded product, semantic, architecture, and implementation plans.

Phase 5's synchronizer tool evidence, asynchronous reset, toggle handshake,
asynchronous FIFO, and aggregate receipt remain incomplete. FluxTile hardware,
FPGA execution, and physical design remain explicit later gates.

See [docs/STATUS.md](docs/STATUS.md) for the evidence-backed phase ledger.

## Target repository map

~~~text
ir/                 canonical public hardware IR
ir/codec/           versioned deterministic canonical serialization
diagnostics/        stable codes, source spans, paths, and corrections
semantics/          shared digital value and operation semantics
wire/               LunaWire construction API and elaboration validation
wave/               LunaWave simulation, properties, traces, snapshots, replay
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
moon check --target native --deny-warn --warn-list +73
moon test --target native --deny-warn
moon run --target native cmd/lunachip
~~~

The Phase 3 Verilator and Phase 4 Yosys/SymbiYosys toolchains are pinned by
platform and manifest digest and executed in isolated OCI containers. The
complete Phase 4 reproduction entry point is `scripts/phase4-gate.sh`. Host-
global Verilator, Yosys, CIRCT, OpenROAD, and PDK installations are not
assumed.
