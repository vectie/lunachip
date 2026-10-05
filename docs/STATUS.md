# LunaChip implementation status

This ledger records what current repository evidence proves. It is deliberately
stricter than a feature checklist: a phase remains in progress until every gate
in `PLAN.md` has direct evidence.

## Phase ledger

| Phase | Status | Current evidence | Remaining gate |
|---|---|---|---|
| 0 — Repository and semantic skeleton | passed locally | versioned canonical codec; byte-stable round trips; fixed construction-order digest; stable diagnostics and source metadata; pinned CI definition and external-tool manifest schema; full native gate | remote CI execution begins when a remote is configured, but is not substituted for the completed local gate |
| 1 — Combinational LunaWire and LunaWave | passed locally | exact typed builders and IR nodes; shortest stable cycle paths; shared known-mask semantics; exhaustive and seeded tests; measured prepared-loop allocation profile with every source identified and removal scheduled | zero-allocation optimization remains scheduled performance work, not a prerequisite under the phase's explicit alternative evidence gate |
| 2 — Sequential semantics, trace, and replay | passed locally | explicit domain/reset/enable IR and builders; exhaustive known/X priority; simultaneous commit; properties; snapshots; canonical trace/VCD/source map; executable digest-checked replay; all required fixtures; pinned independent viewer load | remote/alternate-host reproduction may add evidence but is not substituted for or required by the completed local gate |
| 3 — SystemVerilog and differential validation | passed locally | deterministic conservative SV2017 emission; canonical name/harness manifests; strict digest-pinned Verilator 5.050 OCI lint/build/run; normalized identity-first comparison; 6 fixtures and 102,000 post-reset cycles agree | remote/alternate-host reproduction may add evidence but is not substituted for or required by the completed local gate |
| 4 — Memories and formal properties | passed locally | schema-3 synchronous memory IR; public LunaWire builders; sparse LunaWave and RTL lowering; FIFO/banked-memory components; 8-fixture/104,000-cycle differential agreement; 2 exact external assertion failures; 9-fixture pinned-Yosys synthesis matrix; bounded FIFO pass, cover witness, selected unbounded proof, and 3 retained negative counterexamples | remote/alternate-host reproduction may add evidence but is not substituted for or required by the completed local gate; physical RAM and timing remain unclaimed |
| 5 — Language foundation and multi-clock events | in-progress | schema-4 language and CDC primitives; atomic rational-clock simulation/replay; 542-test foundation native gate; pinned synchronizer/handshake/FIFO differential and synthesis gates, including actual FIFO pre-map typed-graph checks; standalone synchronizer/toggle formal passes and both remaining FIFO cover witnesses | reproduce the complete FIFO formal gate and successful unchanged-snapshot aggregate; prior process-startup failures remain retained |
| 6 — FluxTile-0 simulation proof | in-progress | signed systolic graph, real operand banks and INT32 result SRAM; serial host-memory/queued/fetched-ring baseline; two-slot concurrent host engines, encoding-0.2 queued frontend and fetched concurrent device with one three-client bus; latest-writer dependencies, bounded ordered retirement, observed DMA overlap and runnable demos; independent oracle tests under stalls/faults, exact shapes, failed generations, partial progress, capacity/wrap and reset/flush; stable canonical IR/SV; logical Device ABI 1.0 and checked capability publisher | complete pinned-RTL/synthesis/formal gate |
| 7–8 | not-started | gates documented in `PLAN.md` | all deliverables and evidence in `PLAN.md` |

## Phase 0 evidence

The repository phase gate runs:

```sh
moon info
moon fmt
moon check --target native --deny-warn --warn-list +73
moon test --target native --deny-warn
moon run --target native cmd/lunachip
scripts/check-boundaries.sh
```

Canonical codec tests prove:

- schema version rejection and strict canonical parsing;
- parse/serialize/parse byte stability;
- deterministic module and output ordering;
- a reviewed fixed digest fixture;
- UTF-8 names and every current canonical node operation;
- strict schema-1 register compatibility and schema-2 explicit sequential
  controls without silent normalization;
- malformed, noncanonical, truncated, and IR-invalid input rejection.

Diagnostic tests prove stable-code uniqueness, checked source coordinates,
immutable semantic paths, related spans, corrections, and adapters for IR and
LunaWire failures.

## Phase 1 evidence and restraint

The implemented combinational surface is subtraction, low/full multiply,
equality, ordered comparison, logical and arithmetic shifts, inclusive slice,
MSB-first concatenation, zero/sign extension, truncation, reinterpretation,
bitwise logic, add, and mux. Width and signedness changes are explicit.

LunaWave delegates those operations to the shared `semantics` package rather
than retaining a second implementation. Tests exhaustively cover small known
values, exercise signed behavior and overshifts, cover representative unknown
propagation, and run a deterministic seeded oracle stream.

The release-mode prepared benchmark measures a 724-node representative graph
for 20,000 settlements after warmup. It records 629 allocations and 20,116
requested bytes per settlement. Return-address aggregation accounts for every
call: three iterator objects, two boxed constants, and 624 boxed operation
results. [PERFORMANCE.md](PERFORMANCE.md) records the environment, artifact
hashes, timings, exact sites, and the scheduled shared-scalar-kernel/preallocated
schedule remediation. This satisfies Phase 1's explicit alternative gate while
forbidding an allocation-free claim until the zero-allocation counter passes.

## Phase 2 evidence and restraint

Canonical IR schema 2 represents an immutable rising-edge domain plus explicit
per-register synchronous reset, enable, next state, and optional initial value.
Schema 1 remains a strict compatibility reader and new artifacts always emit
schema 2. LunaWire exposes explicit domain/reset values and retains only
clock-explicit convenience wrappers.

LunaWave tests prove simultaneous register commit, feedback through later
next-state logic, snapshot/restore determinism, and all nine combinations of
known-zero, known-one, and unknown reset/enable controls. Unknown controls use
bitwise mux merging, retaining bits equal on every possible path. Sequential
fixtures cover a wrapping counter, a 255-state nonzero LFSR, a two-stage
pipeline, and a one-entry ready/valid elastic buffer.

The property package emits cycle-stamped assertion and cover observations with
stable failure codes and fail-closed unknown assertions. Trace artifacts are
strict, canonical, changed-only, and retain empty event boundaries. VCD output
uses stable identifiers and lowercase `x`. Replay bundles carry canonical IR,
semantic options, ordered stimuli, stop conditions, taps, and an expected trace
digest; execution records an initial frame, applies simultaneous drives and
edges, and preserves the actual trace/digest on mismatch. Repeating a failure
fixture produces identical events and digest.

The separate canonical trace source-map artifact binds every signal index and
stable VCD `sN` identifier to a validated semantic path and optional exact
`SourceSpan`; keeping it separate preserves existing trace, replay, and VCD
bytes. Its parser rejects missing, duplicate, reordered, malformed, or
mismatched entries.

The checked golden VCD was independently loaded by the pinned ARM64 Surfer
0.7.0 Homebrew bottle, verified by SHA-256 and run from `/private/tmp` without
host installation. [VCD_VALIDATION.md](VCD_VALIDATION.md) records the viewer,
digest, commands, runtime headers, and revalidation rule. This closes the final
Phase 2 gate locally.

## Phase 3 evidence and restraint

The SystemVerilog backend covers every current canonical combinational node
and the schema-2 single-clock register contract. It emits explicit widths,
casts, four-state helper logic, and reset/enable/hold priority. Explicit
register initialization and unreachable canonical nodes fail closed instead of
silently changing the portable synthesis or manifest contract.

The differential layer binds every result to the semantic version, canonical
design SHA-256, and exact stimulus SHA-256 before value comparison. Its
canonical normalized values preserve width and known-mask planes, its first
mismatch ordering is stable, and its reducer retains only candidates that
reproduce the same structured mismatch identity.

The authoritative local gate used the locked ARM64 OCI platform digest for
Verilator 5.050 with networking disabled and warnings fatal. Combinational
logic, arithmetic, controlled-counter, pipeline, LFSR, and ready/valid fixtures
each contributed 17,000 post-reset cycles. All 102,000 LunaWave observations
matched the independently compiled Verilator model. The durable evidence and
reproduction protocol are in [PHASE3_VALIDATION.md](PHASE3_VALIDATION.md).

## Phase 4 evidence and restraint

Canonical IR schema 3 adds synchronous memories with exact address width,
one-cycle read latency, optional enables, whole or granular masks, explicit
bounds behavior, disabled-read behavior, read/write collision policy, and
lower-port-ID per-granule write priority. Existing schema-1 and schema-2
artifacts remain byte stable; reset-to-data reinterpretation is explicitly
versioned instead of silently broadening an older schema. LunaWave performs
sparse addressed-word commits and preflights its documented reference-memory
capacity before allocation. The RTL backend likewise avoids depth-wide
combinational copies and clocked commit loops.

The authoritative clean-tree run used commit
`056c881ff1028ae4b3c10a798d00109ec9de3bab`. Its single aggregate gate ran 18
focused codec tests, the full warning-strict 241-test native gate, both external
tool boundary self-tests, eight pinned-Verilator positive fixtures for 104,000
post-reset cycles, two expected-failure Verilator fixtures, nine pinned-Yosys
synthesis fixtures, and six formal tasks. The source-input manifest was
identical before and after the run.

The two external negative simulations reached the exact emitted labels
`lc_mem0_read0_bounds` and `lc_mem0_write0_write1_collision`. The synthesis
matrix retained the required pre-map memory cells for seven inference-eligible
forms and observed two multiwrite forms without claiming physical RAM,
technology mapping, or timing. Formal evidence retains counterexamples for
broken bounds, FIFO data ordering, and response protocol fixtures; the valid
FIFO passed five safety properties through depth 16, produced a cover witness,
and separately proved four selected structural/control properties with
12-step k-induction. The non-inductive data-order property remains in BMC and
is deliberately absent from the selected unbounded claim.

The checked-in receipt is
[evidence/phase4-evidence.txt](evidence/phase4-evidence.txt), whose SHA-256 is
`b07069231893f2402025250b9775a71db60dcc865a12abc45d8d6bc88030a481`.
It binds child evidence digests and the full retained artifact manifest. The
reproduction and claim boundary are fixed in
[PHASE4_CONTRACT.md](PHASE4_CONTRACT.md), with tool details in
[PHASE4_TOOLCHAIN.md](PHASE4_TOOLCHAIN.md) and
[PHASE4_SYNTHESIS.md](PHASE4_SYNTHESIS.md).

## Phase 5 evidence and restraint

The [2026-10-05 aggregate attempts](evidence/phase5-attempt-20261005.md) retain
the original fixture-name failure and its narrow fix. The second unchanged
snapshot passed the 542-test foundation native gate, all three differential
gates, and all three synthesis gates. It stopped when the pinned SBY version
probe crashed during synchronizer formal. An unchanged standalone rerun passed
all synchronizer formal tasks. The remaining formal runs and a successful
unchanged-snapshot aggregate are still required; child successes alone do not
promote Phase 5 to passed.

Standalone toggle formal also passed. The FIFO retry passed its complete
bounded checks, required negatives, and four covers, then stopped before a
later cover during container output-volume initialization. Its failure log
does not identify the underlying cause; no final FIFO gate pass is claimed.
Both previously missing covers now pass in a
[fresh standalone probe](evidence/phase5-cover-probe-20261005.md), with actual
witnesses at global step 31. This adds named task evidence without amending the
incomplete receipt. A fresh complete FIFO gate and aggregate remain required.

Phase 5 is in progress and has no aggregate evidence receipt yet. Canonical IR
schema 4 now carries sparse explicit domains, port timing, parameters,
aggregate reconstruction bindings, and structurally checked CDC primitive
records while retaining exact schema-1 through schema-3 compatibility.
LunaWire lowers nested aggregates to injectively named ground values, supplies
aggregate ready/valid buffering, and admits public modules through the one CDC
validator.

LunaWave executes exact normalized rational clock schedules with atomic
coincident-edge sampling and commit. Schema-2 replay stores that canonical
event table and produces schema-2 traces and VCD at the original normalized
times without regenerating schedules. The first CDC primitive is a checked
two-through-four-stage, one-bit synchronizer. Its ordinary destination-domain
registers remain visible to every backend; only its declared first-stage
dependency receives a CDC exemption, and only when actual source provenance
exactly matches the primitive declaration. Generic two-flop patterns remain
unsafe. Schema 4 also represents synchronous or asynchronous reset with
active-high or active-low polarity. LunaWave applies every asynchronous reset
effect at a timestamp atomically before computing coincident clock candidates
from the shared post-reset state.

Native evidence now includes atomic Verilator-v2 fixture generation and gate
self-tests, exact pre-map synchronizer structure checking, toggle-handshake
fixtures, and the complete asynchronous-FIFO path through canonical IR,
LunaWire, CDC admission, LunaWave storage/snapshots/replay, and conservative
SystemVerilog. The FIFO differential generator fixes three timing profiles,
559 exact-time events, 104 coincident edges, scalar and 64-bit aggregate
payloads, pointer wraps, full/empty boundaries, coordinated reset, and isolated
negative controls. The second aggregate attempt passed the corresponding
pinned differential gate and retained its receipt.

The asynchronous-FIFO formal registry now deterministically produces nine
fixtures and fifteen tasks with seven assumptions, twenty-two independent
assertions, six cover tasks, and eight exact negative-control labels. This is
a generated proof obligation matrix, not a proof result until its tasks run.
The synthesis path now includes a typed alias/cell/memory graph checker,
validated against actual pinned `memory -nomap` output. Its three-profile
gate passed with 25 checks per fixture, exact owned-state and memory topology,
and two-state role equivalence. This is not physical RAM mapping, timing,
four-state equivalence, or analog CDC evidence.

The locked runner boundary remains phase-neutral and the complete
warning-strict foundation native phase gate passes 542 tests. Earlier runs
retained incomplete receipts when Docker was unavailable; the later pinned
child receipts supersede only those unexecuted checks, not the aggregate gate.
Until the remaining pinned formal executions and one
unchanged-snapshot aggregate gate pass, Phase 5 supports no completed-phase or
physical CDC claim.

## Phase 6 local slices and restraint

The serial host-memory path, queued frontend, fetched host-ring integration,
standalone two-slot storage, serial selected-slot host transfers, independent
concurrent host engines, the slotted queued frontend and fetched concurrent
device, capability contract, four independent-tool fixtures and synthesis/formal
exporters pass the warning-strict native slice gate: 754/754 tests, public interface
generation, formatting, native check with warning 73 enabled, CLI smoke, and
dependency/source-size boundaries on the isolated integration checkout. The
FluxTile package passes 153 tests, including 11 standalone reader tests,
five legacy and six three-client arbiter tests, six legacy composed device
tests and six fetched concurrent behavior tests. Existing execute,
stored-execute, portable, and queued canonical goldens remain unchanged.
The original descriptor codec has 10 tests including its checked example; the
separate draft-0.2 slotted codec has 12. The CLI has eight tests including the
serial fetched-ring, queued-concurrent and fetched-concurrent matrix demos.

[PHASE6_FRONTEND.md](PHASE6_FRONTEND.md) records the atomic packet boundary,
queue capacity, ordered faults/completions, cancellation after protocol fault,
and joint reset/transport flush. [PHASE6_DEMO.md](PHASE6_DEMO.md) provides a
runnable byte-memory load/matmul/store example with actual transport stalls.
Its `ring-demo` publishes five encoded descriptors, checks ordered successful
completions, and compares all host bytes with the independent result oracle.
It observes 181 acknowledged transactions: 175 bytes read, including the 160
descriptor bytes, and 24 bytes written. These are functional simulation counts,
not physical performance or independent RTL evidence.
[PHASE6_RING.md](PHASE6_RING.md) records publication and slot consumption;
[PHASE6_HOST_RING.md](PHASE6_HOST_RING.md) records the single shared memory bus,
global tag validation, fault ownership, and progress-preserving cancellation.
[PHASE6_SLOTS.md](PHASE6_SLOTS.md) records the standalone two-slot engine:
separate operand banks and C SRAMs surround exactly one array. Ten independent
behavioral tests exercise mixed source selections, persistent results,
ownership and pre-edge conflicts, and reset. Fresh unrelated C reads and
operand writes accept during Run/capture while the corresponding compute or
capture counter advances. An artifact test checks deterministic round trips,
local SV, memory topology, and exactly one array's multiply nodes. The existing
canonical execute/stored/portable/queued artifacts remain unchanged.
The [serial selected-slot host integration](PHASE6_SLOTTED_PORTABLE.md) adds
six independent behavioral tests and a deterministic artifact check. Its
requests use the same acknowledged transfer controller, while selected
complete-load shape metadata prevents stale prefixes from authorizing failed
reloads. Tests cover mixed slots and two persistent results, selector latching
under stalls, selected partial failures and retries, and reset during actual
load/compute/capture/completion/store states. Public interface generation
exposes only the new generator, not its private construction hooks.
The [concurrent host-engine integration](PHASE6_CONCURRENT.md) adds eleven
independent behavioral tests, a deterministic artifact test and a checked
public example. Tests observe all eight read/write request/response classes
on edges where Run or capture advances, with independent final-host-byte
oracle comparisons. Whole-store leases, early compute source reservations,
pre-edge conflicts, held completions, local failures/retries, both poison
owners with compute draining, and joint reset/actual transport flush pass.
One array and two storage sets remain authoritative; narrow shared transfer
helpers preserve legacy canonical goldens. Counters reset at inner core issue,
not outer acceptance; registered Issue overhead is excluded.
The [queued concurrent integration](PHASE6_QUEUED_CONCURRENT.md) adds nine
independent behavioral tests, two artifact/limit tests and a checked example.
Actual DMA overlaps Run/capture, while younger commands finish before the
oldest command and retire in packet order. Duplicate caller IDs use internal
tickets; held oldest retirement permits engine reuse and Fence progress.
General-depth retirement/FIFO/head saturation and position wrap, aligned
collectors, failed-intent stale-data exclusion, syntax-failure non-writers,
generation recovery and delayed older completion exclusion pass. Both DMA
poison owners, committed sibling progress, compute draining and joint reset
with actual transport flush pass. Ticket wrap is structurally bounded, not
tested by four billion simulated commands.
`concurrent-demo` checks all 1024 host bytes, both result matrices and padding.
It observes seven accepted read and five write edges during advancing compute
or capture, ten ordered successes with caller ID 42, and twelve later-store
bytes committed while oldest retirement is held for 24 clocks. Its 277
transactions read 207 bytes and write 280 bytes; those are modeled simulation
counts, not physical performance. Public graph composition exports only
signal views, not writable state; the direct concurrent canonical digest is
unchanged by extraction.
The [fetched concurrent device](PHASE6_RING_CONCURRENT.md) connects that packet
frontend and the same engines to the raw host reader through one three-client
bus. Six standalone arbiter tests and eight fetched integration/artifact tests
pass. Integration observes all twelve actual reader/loader/storer accepted
request and response-ACK classes during advancing Run/capture, with signed
oracle results, ordered duplicate IDs, younger store finish and engine reuse
under held oldest retirement. Ring depths 2/4/8/16 saturate the depth-2 frontend
without early consumer advancement, including real UInt32 origin/counter wrap.
Partial reader remote fault 4 creates no fabricated completion and accepted
commands drain normally. All three protocol owners preserve committed sibling
DMA progress and accepted compute drains through 78 Run and 64 capture edges.
Held terminal records remain immutable; a public-observation replay verifies
packet admission on the exact poison discovery edge. Joint reset flushes an
actual pending fetch. Both direct and queued canonical digests remain unchanged
after extracting private, read-only engine/queue composition seams.
`ring-concurrent-demo` fetches eight draft-0.2 descriptors and retires eight
successes with duplicate caller ID 42. It checks both signed 8x8 K=16 results
and all 1024 host bytes, observes four operand-read, five store-write and five
descriptor-read acceptance edges during advancing compute/capture, and reuses
ring slots only after consumer advancement. Its 768 transactions read 640
bytes and write 512 bytes. These are simulation counts, not physical performance.
The legacy fetched-ring device remains serial/single-slot, and direct concurrent
channels still have independent completions; ordered retirement belongs to the
packet frontend. No complete Phase 6 gate claim follows from these local tests.
Local deterministic RTL emission alone is not independent RTL differential evidence.
The first [pinned fetched-device replay](evidence/phase6-differential-20261005.md)
now passes strict lint/build/execute and the typed audit for a small 1x1/K2
pipeline: all 30 public outputs agree across 1,114 cycles. Its five completions,
ring-slot reuse, held completion, signed result -637 and all host bytes are
checked. A narrowly scoped emitter annotation handles explicit partial-bit
consumers without changing canonical IR, public ports or strict runner flags;
all nine earlier synthesis bundles remain byte-identical. This scoped replay
does not cover the larger concurrency/fault matrix or complete Phase 6.
The [measured concurrency replay](evidence/phase6-concurrent-20261005.md)
additionally agrees across 9,041 cycles and all 30 outputs. It checks ten
ordered successes, both operand/result slots, all 4096 host bytes and real
descriptor/load/store acceptance during advancing compute. The oldest record
holds for 64 edges while the loader accepts 13 reads. All eleven original
fixture artifacts remain byte-identical.
The [reader-poison/reset replay](evidence/phase6-fault-reset-20261005.md) agrees
across 1,261 cycles and all 30 outputs. It corrupts an owned reader response
while compute advances, retains committed loader progress under ordered
cancellation, drains compute under held retirement, and resets with a real
pending response before host flush. Recovery rejects invalidated old slots.
The [first fetched-device synthesis slice](evidence/phase6-synthesis-20261005.md)
passes the unchanged locked Yosys flow for the replay-identical 1x1/K512 graph,
retaining ten pre-map memory cells. The replay-identical 8x8/K16 graph also
passes [pinned generic synthesis](evidence/phase6-synthesis8-20261005.md),
retaining 38 exact pre-map memory cells without legacy declarations. Neither
result establishes synthesis equivalence, physical RAM mapping, area or timing.
The [signed 8x8 replay](evidence/phase6-array8-20261005.md) agrees across 6,935
cycles and all 30 outputs, checking both persistent result slots, all 4096 host
bytes, safe ring refills, varied response delay and younger bus progress under
held retirement. It does not measure Run/capture overlap. All three earlier
fixture bundles remain byte-identical. The
[seeded 8x8 replay](evidence/phase6-seeded-20261005.md) agrees across 7,488
cycles and all 30 outputs with separate random matrix, readiness and delay
streams; both result slots and all 4096 host bytes match. All four earlier
replay bundles remain byte-identical. The public transport formal generator
passes 50 targeted native/exporter tests. The first
[actual formal pilot result](evidence/phase6-formal-pilot-20261005.md) retains
the exact expected bounds-monitor counterexample plus held-request and
owned-response witnesses, not production safety. Valid safety and the
first-terminal reachability result remain
unrecorded. Additional workload coverage, independent capacity/wrap,
remaining fault owners, the complete synthesis matrix and named formal tasks
remain unfinished.
The [dependency pilot](evidence/phase6-dependency-20261005.md) now also retains
the exact observed-Failed-as-Success monitor counterexample with independent
trace inspection and complete typed evidence validation. Its initial strict
preprocessing error remains separate. The
[Boolean adapter and fresh priority cover](evidence/phase6-boolean-20261005.md)
retain pinned pointwise equivalence for19 helpers and a completed positive
witness, plus the exact selected priority-monitor sensitivity counterexample;
both independently inspected and fully typed-evidence verified. Actual
DUT symbolic helper defaults fall from4268 to16 with state/memory counts
unchanged; production IR/RTL and the original three pilot bundles are unchanged.
Positive dependency safety, four covers and the inner-identity negative remain
unrecorded. The fresh all-seven-assertion safety task timed out after601s,
last checking global step69 of256, without a trace or typed proof receipt.
The previous priority-cover export timeout remains incomplete and
separate from this PASS. Scoped kernel logs correlate
both directed fetched Fence solver EOFs with global test-VM OOM kills. No VM
allocation or pinned tool setting has been changed. The latest complete native
checkpoint at `c2a14f2` passes 785 tests, interface generation, formatting, strict checking
with warning73, default CLI smoke and dependency/source-size boundaries.
The Boolean helper refinement separately passes97 targeted tests. No full-product proof
is claimed.
The [local generation transfer slice](PHASE6_GENERATION_LEMMA.md) now discovers
the exact eighteen production register roots and materializes their reset,
enable and hold transfers in a separate combinational module. Ten focused
tests pass; its independent ghost equivalence, SAT and composition remain
unfinished. Production RTL, public interfaces and formal bundle bytes are unchanged.
The [standalone trace projection probe](evidence/phase6-trace-projection-20261005.md)
passes naming/connectivity preservation for1,942 wires and four artifact
corruption controls. The runner remains unchanged. A separate
[projected witness experiment](evidence/phase6-projected-witness-20261005.md)
completes the cover and same-model replay; older-model replay fails on generated
witness identity, and JSON import loses 112 signed net metadata fields.
Direct-preparation integration, selected negative and typed binding validation
remain required. No cross-model replay or safety result is claimed.
The [logical Device ABI 1.0](PHASE6_DEVICE_ABI.md) now binds the existing fetched
concurrent behavior and unchanged descriptor encoding 0.2. Its pure
[checked capability publisher](PHASE6_CAPABILITIES.md) rejects invalid
elaboration parameters, publishes deterministic JSON and imports no hardware
or simulator. The configuration bridge produces byte-identical canonical IR
to the existing constructor. Targeted tests bind the complete 13-input/30-output
signal contract and show that descriptor bytes 1/0 still fault while 0/2 succeeds.
The manifest distinguishes compute counters from retirement records and
descriptor-slot reuse from host-buffer reuse. It carries no verification or
performance claim. The complete independent tool gate remains required before
Phase 6 can pass. FPGA execution, frequency, physical RAM mapping, and silicon remain
unclaimed.
Deterministic digital sampling does not measure metastability, MTBF, placement,
routing, recovery/removal timing, or timing closure.

## Claim boundary

Completed-phase evidence supports “canonical LunaChip IR,” “the named combinational
and single-clock sequential subset executes deterministically in LunaWave,”
“the named memory subset is differentially validated against emitted
conservative SystemVerilog,” “the nine named RTL forms synthesize through the
pinned generic Yosys flow,” and “the named formal properties produced their
recorded bounded, witness, counterexample, or selected unbounded results.” It
does not support synthesis equivalence, FPGA execution, physical RAM mapping,
timing closure, GDS, fabrication, or silicon performance.
