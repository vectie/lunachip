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
- a provisional FluxTile-0 signed INT8 systolic array (1..8 rows/columns),
  INT32 accumulators, pause/clear/reset controls, and an independent matrix
  oracle with cycle-by-cycle LunaWave tests;
- a real synchronous-bank execute slice with checked loaded prefixes,
  one accepted wavefront step per ready clock edge, held completion, and
  per-command cycle/stall counters;
- a real INT32 result SRAM, active-cell capture before success completion,
  and a serialized one-edge read channel with stable backpressured responses;
- a provisional serial LoadA/LoadB/MatMul/StoreC/Fence engine with a tagged,
  acknowledged host-memory port, wide address validation, exact slot shapes,
  partial-transfer faults, and independent end-to-end byte-memory tests;
- a pure provisional 32-byte descriptor codec and real bounded four-lane
  hardware queue with atomic acceptance, ordered held completions, strict
  syntax checks, and explicit transport-fault cancellation of queued entries;
- a real host descriptor-ring reader and composed device shell with one shared,
  globally tagged memory bus, bounded backpressure, and explicit fault ownership;
- a standalone two-slot execute/storage generator with separate A/B banks and
  persistent C SRAMs around one array, permitting unrelated loads and result
  reads during computation and capture;
- a host-connected two-slot variant sharing the serial transfer controller,
  with latched selectors, exact complete-load shapes, isolated failed reloads,
  and selected result stores;
- three concurrent host engines around that same two-slot storage, with real
  DMA overlap during computation/capture and independent held completions;
- a separate draft-0.2 slotted packet codec and queued concurrent frontend,
  with strict dispatch, failed-generation dependencies, bounded ordered
  retirement and a runnable `concurrent-demo`;
- a fetched draft-0.2 concurrent device that connects the reader, loader and
  storer through one three-client memory arbiter around the same two-slot core;
- supply-chain-pinned native CI and an external-tool lock-manifest format;
- research-grounded product, semantic, architecture, and implementation plans.

Phase 5 remains in progress until the combined native and nine child tool
gates pass on one unchanged snapshot. Run them with
`moon run --deny-warn scripts/phase5-gate.mbtx -- /absolute/empty-run-root`.
FluxTile's compute, result storage, and first serial host-memory load/store
path, a queued register-packet frontend, fetched host-ring integration, and
standalone and host-connected two-slot storage are implemented. A separate
concurrent-engine variant overlaps load, compute and store; its contract is in
[PHASE6_CONCURRENT.md](docs/PHASE6_CONCURRENT.md). The legacy host-ring device remains
serial and single-slot. A separate packet frontend supplies slot-bearing queued
dispatch, latest-writer dependencies and ordered retirement; see
[its implementation contract](docs/PHASE6_QUEUED_CONCURRENT.md). The new fetched
concurrent shell is specified in
[its integration contract](docs/PHASE6_RING_CONCURRENT.md). The fetched concurrent
profile now publishes [logical Device ABI 1.0](docs/PHASE6_DEVICE_ABI.md) and
[checked capabilities](device/capabilities/README.mbt.md), retaining descriptor
encoding 0.2 unchanged. The complete independent RTL/synthesis/formal gate
remains incomplete; publishing this contract is not a gate pass.
The first [independent fetched-device RTL replay](docs/PHASE6_DIFFERENTIAL.md)
passes pinned Verilator across all 30 outputs for 1,114 cycles. This is one
small successful pipeline, not the complete Phase 6 gate.
A second [measured concurrency replay](docs/evidence/phase6-concurrent-20261005.md)
passes all 30 outputs for 9,041 cycles, including actual descriptor/load/store
handshakes during advancing compute and loader progress under held retirement.
A third [reader-poison/reset replay](docs/evidence/phase6-fault-reset-20261005.md)
passes all 30 outputs for 1,261 cycles, including compute drainage and reset
with a real pending host response. The same concurrency design also passes
[pinned generic synthesis](docs/evidence/phase6-synthesis-20261005.md), retaining
ten pre-map memory cells. A fourth [signed 8x8 replay](docs/evidence/phase6-array8-20261005.md)
passes all 30 outputs for 6,935 cycles and checks both result slots plus all
host bytes. A fifth [seeded 8x8 replay](docs/evidence/phase6-seeded-20261005.md)
passes all 30 outputs for 7,488 cycles with independent random matrix,
readiness and response-delay streams. The latest full native checkpoint passes 811
tests, strict checking, CLI smoke and dependency/source-size boundaries.
The replay-identical 8x8 graph also passes [pinned generic synthesis](docs/evidence/phase6-synthesis8-20261005.md),
retaining all 38 expected pre-map memory cells. The
[dependency formal pilot](docs/evidence/phase6-dependency-20261005.md) retains
two exact monitor-sensitivity counterexamples and
[one complete priority-cover witness](docs/evidence/phase6-boolean-20261005.md),
not production safety.
The [full-harness generation-support experiment](docs/evidence/phase6-generation-support-20261006.md)
preserves the ordinary bundles and assumptions but also times out; no full-device
proof or solver speedup is claimed.
The [exact sequential generation bridge](docs/evidence/phase6-generation-bridge-20261006.md)
passes actual k-induction with a complete selected negative-control trace;
this is a local binary clock/reset relation, not the full device gate.
The [exact compute identity checkpoint](docs/evidence/phase6-compute-identity-20261006.md)
adds private controller extraction and native identity/reset regressions while
preserving all 59 existing generation and ordinary artifacts; saved-authorization
composition is not yet proved.
The [joint generation/compute extraction](docs/evidence/phase6-compute-composition-20261006.md)
retains 27 actual registers, removes generation-state input shadows and passes
native transition tests. Its independent authorization/owner proof is still pending.
The remaining fault/workload matrix, synthesis coverage and named formal
tasks remain unfinished; generic synthesis is not physical RAM or timing evidence.
See [the execute contract](docs/PHASE6_EXECUTE.md).
Result storage is described in [the stored-result contract](docs/PHASE6_RESULT.md).
The end-to-end baseline is specified in [the portable contract](docs/PHASE6_PORTABLE.md).
The provisional packet format and queue are specified in
[the frontend contract](docs/PHASE6_FRONTEND.md).
Host publication and shared transport are specified in
[the host-ring contract](docs/PHASE6_HOST_RING.md).
The standalone storage/ownership contract is specified in
[the two-slot contract](docs/PHASE6_SLOTS.md).
Direct host command slot selection is specified in
[the slotted portable contract](docs/PHASE6_SLOTTED_PORTABLE.md).
See [the Phase 6 slices](docs/PHASE6_IMPLEMENTATION.md) for the build order.
FPGA execution and physical design remain explicit later gates.

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
device/             pure descriptor and capability contracts
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

Run `moon run --target native cmd/lunachip -- matmul-demo` for a signed
matrix workload executed by the banked hardware graph, checked against the
independent oracle. [The demo](docs/PHASE6_DEMO.md) reports modeled cycles,
not physical throughput.

Run `moon run --target native cmd/lunachip -- portable-demo` for the complete
serial LoadA/LoadB/MatMul/StoreC/Fence path. A separate byte-memory environment
answers observed requests with backpressure and delayed responses; final host
words match the oracle and untouched bytes remain unchanged. This demonstrates
the provisional transport, not a frozen device ABI or independent RTL gate.

Run `moon run --target native cmd/lunachip -- ring-demo` for the fetched
host-ring path through one shared memory bus. It publishes encoded descriptors,
checks five ordered completions, and verifies the final host matrix and all
untouched bytes. Descriptor fetching and computation are real hardware graphs;
the demo remains simulation-only with a provisional device ABI.

The Phase 3 Verilator and Phase 4 Yosys/SymbiYosys toolchains are pinned by
platform and manifest digest and executed in isolated OCI containers. The
complete Phase 4 reproduction entry point is `scripts/phase4-gate.sh`. Host-
global Verilator, Yosys, CIRCT, OpenROAD, and PDK installations are not
assumed.
