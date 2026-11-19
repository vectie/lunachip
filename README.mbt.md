# LunaChip

> Phases 0 through 5 are implemented and locally gated. LunaChip now has a
> deterministic single-clock construction/simulation foundation, first-class
> synchronous memories, a differentially validated conservative SystemVerilog
> backend, pinned synthesis evidence, and named bounded/unbounded formal
> results. Phase 5's named multi-clock digital gates pass on one unchanged
> snapshot. The separate [PRX100 target build](docs/evidence/prx100-vivado-build-20261015.md)
> passes routed50MHz timing and BRAM mapping in Vivado2025.2. Its
> [physical UART/BRAM smoke test](docs/evidence/prx100-uart-bram-20261016.md)
> passes29 transactions, and its [first signed matrix workloads](docs/evidence/prx100-signed-matrix-20261016.md)
> return−83,255 and0 on the1x1/K2 smoke accelerator. The
> [physical Array8/K16 workload](docs/evidence/prx100-array8-matrix-20261016.md)
> also passes all64 signed INT32 results through UART. The
> [broader board campaign](docs/evidence/prx100-broad-matrix-20261016.md)
> passes40 edge/seeded/repeated cases and a tiled synthetic K1024 projection,
> with separate compute-counter and UART timings. A
> [real W8A8 Qwen projection block](docs/evidence/prx100-qwen-projection-20261016.md)
> also passes24 exact outputs on three real normalized embeddings; this is
> a model-weight arithmetic block, not full-model inference. The later
> [DDR-to-BRAM projection target](docs/evidence/prx100-ddr-projection-20261016.md)
> runs20 verified autonomous jobs with the same unchanged core; full K1024
> jobs initially take median2.369ms. The [target cache/staging optimization](docs/evidence/prx100-ddr-optimization-20261016.md)
> lowers this to1.767ms (25.4%), with20 verified jobs and an unchanged portable
> core; the fresh scalar CPU reference takes183us. The subsequent
> [loading pipeline](docs/evidence/prx100-core-loading-20261016.md) overlaps
> next-tile BRAM staging and removes control bubbles, reaching1.375ms
> (another22.2% reduction) across20 verified jobs with the same core/clocks;
> its scalar CPU reference takes182us. The subsequent
> [descriptor publication pipeline](docs/evidence/prx100-publication-20261017.md)
> reaches1.12750ms (another18.01% reduction), with20 verified jobs and the same
> portable core/bridge/clocks; fresh scalar CPU176us. The subsequent
> [byte-memory port isolation](docs/evidence/prx100-byte-20261017.md) passes
> 20 jobs per image in a fresh A/B campaign, with only1.12747→1.12710ms
> improvement (0.033%) and one additional BRAM tile. The unchanged core's
> serialized byte protocol remained dominant; fresh scalar CPU184us. The subsequent
> [opt-in portable word-read core](docs/evidence/prx100-word-20261017.md) passes
> fresh20-job campaigns per image and lowers median1.12710→0.53526ms
> (52.51%,2.11×). All40 jobs match the CPU;1176 strict native tests pass.
> Core memory requests fall280→76 per tile; arithmetic, bridge and clocks
> retain their behavior, and the legacy byte generator retains its identities.
> Scalar CPU183us remains faster; unbounded proof of the new core is open. The
> [DDR line-staging continuation](docs/evidence/prx100-staging-20261017.md)
> passes another fresh20-job campaign per image:0.53596→0.48102ms median,
> 10.25% lower (1.11× faster), with the exact same portable core and clocks.
> DDR front-end read requests fall36→9 per tile while native bytes stay the
> same;1180 strict native tests and40 CPU-verified board jobs pass.
> Scalar CPU183us remains2.63 times faster; bulk host transfers still dominate.
> The [DDR result-write batching](docs/evidence/prx100-results-20261017.md)
> passes40 fresh A/B jobs and lowers median0.48054→0.45618ms
> (5.07%,1.053×). Writes fall520→130 per full block; the
> portable core/clocks remain exact, and1189 native tests pass. Scalar
> CPU183µs remains faster; host/JTAG throughput still dominates.
> The [DDR stream/descriptor staging continuation](docs/evidence/prx100-stream-20261017.md)
> passes40 fresh A/B jobs: 0.45630→0.41775ms median,
> 8.45% lower (1.092×), exact core/clocks and1196 native tests.
> Front-end reads fall576→128/full block; native traffic remains unchanged.
> Scalar CPU183µs remains faster; host/JTAG still dominates.
> Fabricated silicon
> remains unclaimed; Phase6 and the full Phase7 gate remain open.

LunaChip is a MoonBit-native hardware construction and simulation product:

- **LunaWire** builds typed, clocked hardware graphs.
- **LunaWave** simulates those graphs deterministically.

The first reference design is FluxTile-0, a small host-driven tensor
accelerator intended to prove the complete language-to-simulation-to-RTL flow.

Detailed documents are under docs/.

The [PBlaze3 2 GiB port](docs/PBLAZE3_PORT.md) adds a PCIe/XDMA target for
the existing Qwen reference layer. Its [arrival runbook](docs/PBLAZE3_BRINGUP.md)
covers the prepared DDR diagnostics, high-address workloads and complete-layer
campaign. Physical board qualification is pending; the PRX100 results remain
the measured performance reference. The [software preparation follow-up](docs/PBLAZE3_SOFTWARE_PREPARATION.md)
tracks checks and host tooling that can be completed before the card arrives.

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
- schema-4 parameters, aggregate reconstruction, port timing, and
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

The [Phase 5 aggregate](docs/evidence/phase5-aggregate-20261006.md) passes the
full 832-test native gate and all nine child tool gates on one unchanged
snapshot. Run them with
`moon run --deny-warn scripts/phase5-gate.mbtx -- /absolute/empty-run-root`.
The [complete standalone FIFO formal gate](docs/evidence/phase5-fifo-formal-20261006.md)
passes all fifteen logical tasks, also rerun within the aggregate. These
bounded digital results do not establish analog CDC
behavior or unbounded device safety.
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
readiness and response-delay streams. A sixth [writer rejection/recovery replay](docs/evidence/phase6-writer-fault-20261006.md)
passes all 30 outputs for 2,887 cycles, distinguishing syntax rejection from
failed writer generations and requiring fresh recovery computation.
A seventh [DMA protocol-owner replay](docs/evidence/phase6-dma-poison-20261006.md)
passes all 30 outputs for 21,072 cycles, including both owned malformed responses,
compute drainage, exact admitted-prefix retirement and stale-slot reset recovery.
A matching [remote failure and partial-write replay](docs/evidence/phase6-remote-fault-20261006.md)
passes all 30 outputs for 2,822 cycles, including an actual two-byte partial
host write, retry without reset, failed generations and fresh recovery.
A [capacity/origin-wrap replay](docs/evidence/phase6-capacity-wrap-20261006.md)
passes all 30 outputs for 1,371 cycles, including the actual UInt32 reader-origin
wrap, five admitted/six fetched saturation and a 32-edge host-owned slot hold.
The [direct queue observation seam](docs/evidence/phase6-queue-seam-20261006.md)
adds 115 exact existing-node references without changing ordinary IR or RTL.
Its directed replay checks duplicate caller IDs and held ordered retirement;
it is not a formal result. The
[queue-task and descriptor-replay native checkpoint](docs/evidence/phase6-queue-descriptor-native-20261006.md)
passes 838 tests, strict checking, CLI smoke and dependency/source-size
boundaries, with all 93 older formal and 99 older replay artifacts unchanged.
The [retirement-record native checkpoint](docs/evidence/phase6-retirement-record-native-20261006.md)
passes842 tests and preserves113 earlier formal artifacts, with real-device
hold/release/reset checks; its generated tasks are not formal proof results.
The additive [public packet provenance check](docs/PHASE6_QUEUE_PACKET_PROVENANCE.md)
saves all four accepted lanes independently and links response, captured head,
reservation and ordinal retirement. It adds no production hardware or ABI port;
its generated safety/cover/sensitivity tasks still require actual formal results.
The subsequent [descriptor-rejection RTL replay](docs/evidence/phase6-descriptor-rejection-20261006.md)
passes strict pinned lint/build/execute and typed audit across 14,464 cycles,
including 86 ordered completions, rejection priority and recovery without reset.
The [ring-control recovery checkpoint](docs/evidence/phase6-ring-control-20261006.md)
passes 845 native tests and preserves 110 earlier replay artifacts. Pinned RTL
agrees on all 30 outputs over 7,107 cycles, including invalid publication during
packet admission, admitted-work drainage and reset/fresh recovery. These finite
replays do not complete the unfinished Phase 6 formal gate.
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
native transition tests. The subsequent [joint generation/compute proof](docs/evidence/phase6-compute-proof-20261006.md)
passes actual induction for the local binary relation, saved Issue authorization
and accepted compute-owner identity, with a genuine handshake negative control.
Its eighteen environment cuts remain free; this is not the full-device gate.
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
cmd/lunawave/       saved simulation replay CLI
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

Run `moon run --target native cmd/lunawave -- replay INPUT_REPLAY NEW_OUTPUT`
to execute a saved replay bundle and retain its canonical trace and VCD.
The [LunaWave command](cmd/lunawave/README.md) succeeds only when both the
declared stop condition and expected trace digest match. Failed outcomes retain
their actual artifacts; an existing output path is never reused.

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

A separate [BF16 / FP32 PRX100 experiment](docs/evidence/prx100-fp-20261017.md) passes55 CPU-exact board jobs at25MHz using1 DSP and2006 LUTs. It is constructed in MoonBit, uses BRAM staging, and preserves the integer portable core. One K1024 dot takes163.84µs; this first scalar FP profile prioritizes numerical correctness and fit.

The [FP DDR3 target](docs/evidence/prx100-fpd-20261017.md) connects the unchanged eight-lane BF16/FP32 core to DDR3 with resident weights, burst JTAG transfers and autonomous batches. All848 output words match the CPU reference. The same three-vector upload takes0.362s, and one48-job batch amortizes host completion to1.288ms per projection. Integer and existing FP cores remain unchanged; this is selected-projection evidence, with full-model inference still open.

The [eight-lane FP pipeline](docs/evidence/prx100-fpp-20261017.md) now runs the same eight-channel Qwen block in 102.48 µs at 50 MHz, 12.79× faster than the scalar FPGA engine total. All 320 results from 40 board jobs match the CPU reference; 1,203 native tests pass. The integer core remains unchanged. This BRAM experiment still needs bulk transfers and model integration.

The separate [FP banked loader](docs/evidence/prx100-fpl-20261017.md) reduces BRAM-to-core loading from163.86 µs to20.50 µs. The same Qwen block completes in163.773 µs warm hardware time versus307.123 µs in a fresh DDR baseline, a1.875× improvement. All848 outputs from106 projections match the CPU reference;1,212 native tests pass. Integer and existing FP profiles remain unchanged. JTAG still dominates host time; full-model inference remains open.

The separate [four-stage FP accumulator](docs/evidence/prx100-fpa-20261017.md) reduces arithmetic from 102.48 µs to 82.00 µs while preserving FP32 rounding and accumulation order. The same Qwen block completes in 143.313 µs warm hardware time versus 163.760 µs in a fresh banked-loader baseline, a 1.143× improvement. All 848 outputs from 106 projections match the CPU reference; 1,218 native tests pass. Integer and existing FP profiles remain unchanged; JTAG overhead and full-model inference remain open.

The separate [FP DDR/loading overlap target](docs/evidence/prx100-fpo-20261017.md) prepares the next operands while the current job computes. A 48-job batch averages 83.313 µs per projection versus 143.289 µs in a fresh baseline, a 1.720× throughput improvement; single-job latency remains about 143.5 µs. All 848 outputs from 106 projections match the CPU reference; 1,225 native tests pass. Arithmetic, integer and existing FP profiles remain unchanged. Double buffering adds eight BRAM36 equivalents; JTAG overhead and full-model inference remain open.

The [JTAG host-transfer update](docs/evidence/prx100-fpt-20261017.md) uses 30 MHz, reusable transactions and coalesced configuration with the same FPDDR1.3 bitstream. Three interleaved campaigns per profile pass 318 projections / 2,544 CPU-exact outputs. Median 22 KiB upload falls from 367.261 to 96.768 ms, and complete 48-job host time falls from 77.948 to 25.423 ms (3.066×). All 1,225 native tests pass; integer and FP hardware remain unchanged. A retained 257.711 ms single-job host outlier limits tail-latency claims; full-model inference remains open.

The [16-entry JTAG AXI target](docs/evidence/prx100-fpq-20261018.md) batches DDR transfers at the same 30 MHz. Fresh depth1 serial, depth16 serial and depth16 queued profiles each pass 318 projections / 2,544 CPU-exact outputs. Median application time, including actual upload, both input readbacks and 106 projections, falls from 637.402 to 485.841 ms (1.312×); upload improves 2.345×. Resident 48-job timings overlap, so no meaningful resident-batch speedup is established. All 1,225 native tests and fresh routed timing pass; integer and first-party FP RTL remain unchanged. The queues add 3,236 LUTs and 3.5 BRAM36 equivalents; full-model inference remains open.

The [JTAG control/diagnostic update](docs/evidence/prx100-fpc-20261018.md) coalesces status/error reads and reuses unchanged descriptors on the same FPDDR1.3Q bitstream. Five interleaved campaigns per profile pass 530 projections / 4,240 CPU-exact outputs. Median resident 48-job completion falls 30.250→21.425 ms (1.412×), and repeated three-job batches fall 5.535→4.057 ms per projection. One paired run regresses and ranges overlap; these are measured median gains. All integer and FP hardware remains unchanged; this is still a selected-projection experiment.

The [polling/diagnostic update](docs/evidence/prx100-fps-20261018.md) reuses completed-counter cache evidence and tests bounded post-START pacing on the same bitstream. Five interleaved campaigns per compact/cache-only/paced profile each pass 530 projections / 4,240 CPU-exact outputs. Median resident 48-job time falls 22.428→19.370 ms (1.158×); application time falls 435.145→403.664 ms. Cache-only warm repeated jobs improve 24.7%; pacing adds only a small, unestablished incremental benefit. All results, counters and error checks remain; integer and FP hardware are unchanged. Ranges overlap and full-model inference remains open.

The [result-readback update](docs/evidence/prx100-fpr-20261018.md) combines full DDR outputs and all 34 counters in one completed-read command on the same bitstream. Five interleaved campaigns per prior/queued/list profile each pass 530 projections / 4,240 CPU-exact outputs. Selected sequential-list dispatch reduces median 48-job readback 10.099→7.950 ms (1.270×) and complete resident time 20.597→16.567 ms (1.243×), with identical payloads. Sixty matched Linux/Mac audit pairs plus four final qualification pairs agree; all integer/FP hardware is unchanged. Application-wide and tail improvements remain unestablished; full-model inference remains open.

The [launch/poll dispatch update](docs/evidence/prx100-fpu-20261018.md) combines changed descriptors, START and short-batch status reads in sequential commands on the same bitstream. Five fresh interleaved runs per profile check530 projections /4,240 CPU-exact outputs. Median application time falls439.951→401.976 ms (8.6%) and summed complete resident batches214.936→193.829 ms (9.8%), with101→76–77 API calls. Warm repeated-job gains are small, one application pair regresses and ranges overlap. All integer and FP hardware remains unchanged; full-model inference remains open.

The [warm-request coalescing update](docs/evidence/prx100-fpv-20261018.md) executes six already available identical warm three-job requests as one18-job physical batch, retaining every logical result. Five fresh interleaved runs per profile pass530 projections /4,240 CPU-exact outputs. Complete warm-sequence time falls57.238→13.358 ms (4.285×), with12→2 JTAG commands; application time falls400.200→362.511 ms (9.4%). First-result-ready time slightly increases, and one application pair regresses. All integer/FP hardware is unchanged; batching improves aggregate throughput rather than isolated-request latency. Full-model inference remains open.

The [bulk host-data update](docs/evidence/prx100-fpw-20261018.md) batches read-property fetches and trace writes while omitting redundant write-object echoes and dummy read-request fields. Every actual DDR word and CPU result remains checked. Five fresh interleaved runs per selected profile reduce upload49.853→33.044 ms, both actual input readbacks133.537→118.584 ms, and complete application353.897→326.303 ms (7.8%). All8,480 compared output words match the CPU;154 Linux/Mac audit pairs agree across exploration and qualification. One application pair regresses, resident timing does not improve, and ranges overlap. Integer/FP hardware and physical JTAG/DDR payloads are unchanged; full-model inference remains open.

PRX100 BF16/FP32 readback decoding: fixed-width actual DATA slicing and batched
completion properties retain all payloads/checks. Fresh five-pair medians:
total readback 185.047→176.291 ms, full 106-projection application 348.876→323.771 ms;
all 8,480 compared outputs exact. Queued-read finish median regresses; one paired
application regresses. Integer/FP hardware unchanged. See [measurement report](docs/evidence/prx100-fpx-20261018.md).

PRX100 queued-read finish profiling identifies per-word Tcl decoding as the
dominant software cost. Validated fixed-width scan decoding retains all actual
reads and CPU/counter checks. Both the initial five pairs and five opposite-order
follow-up pairs remain in the combined report; integer/FP hardware is unchanged.
See [measurement report](docs/evidence/prx100-fpz-20261018.md).

PRX100 BF16/FP32 launch/completion experiment: five fresh interleaved pairs,
all12,720 successful-campaign output words CPU-exact,integer/FP hardware unchanged.
Selected dispatch "serial";complete ranges,pairs and failed attempt retained.
See [measurement report](docs/evidence/prx100-fqa-20261018.md).

PRX100 now runs one complete Qwen3-0.6B layer in MoonBit-constructed BF16/FP32
hardware, including normalization, RoPE, attention/softmax, SiLU and cached
decode. All 656,960 readback words pass the CPU reference. Four-token kernel
time is 15.36 s; warm application median is 22.16 s; scalar CPU is 2.75 s.
The integer core is unchanged. See the [layer report](docs/evidence/prx100-layer-20261018.md).

The complete-layer four-lane FP32 pipeline improves the same PRX100 workload:
kernel15.36→3.46 s and warm diagnostic end-to-end22.18→10.04 s. All656,960
readback words are bit-identical to the scalar FPGA;1,235 native tests pass;
the integer core remains unchanged. The optimized CPU reference takes93 ms;
the earlier2.75 s CPU figure used a debug build. See the [parallel-layer report](docs/evidence/prx100-layer-parallel-20261018.md).

The [LunaFlux / PBlaze3 adapter preparation](docs/LUNAFLUX_PBLAZE3_CONTRACT.md)
publishes the 2 GiB device contract, validates a complete Qwen3-0.6B memory
placement and runs a LunaFlux-generated LunaTile program in LunaWave. Full-model
lowering and physical inference remain open.
