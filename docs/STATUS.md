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
| 5 — Language foundation and multi-clock events | in-progress | schema-4 domains, port timing, parameters, aggregates, resets, and CDC records; aggregate LunaWire lowering and ready/valid buffering; atomic rational-clock simulation, trace, VCD, and replay; synchronous/asynchronous reset modes and polarities; fail-closed CDC provenance; checked synchronizer, toggle-handshake, and asynchronous-FIFO construction; asynchronous-FIFO simulation, replay, SystemVerilog, native differential/formal fixture generation, and canonical synthesis role inventory; 483-test native gate | implement the typed asynchronous-FIFO pre-map Yosys graph checker from actual pinned output; execute the pinned synchronizer, toggle, and FIFO tool gates on an available locked container runtime; produce one unchanged-snapshot aggregate Phase 5 evidence receipt |
| 6 — FluxTile-0 simulation proof | in-progress | independent checked INT8 matrix oracle; parameterized 1..8-row/column output-stationary signed INT8 × INT8 / INT32 systolic graph; every-cycle LunaWave schedule checks, pauses, clear/reset reuse, qualifier gating, modular accumulation, and deterministic IR/SV | hardware execute controller, scratchpad and memory transport, load/execute/store commands, device ABI/frontend, dependency scoreboard, counters, and complete pinned-RTL/synthesis/formal gate |
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
negative controls. Those are deterministic native artifacts and expectations;
they are not a Verilator agreement result until the pinned gate runs.

The asynchronous-FIFO formal registry now deterministically produces nine
fixtures and fifteen tasks with seven assumptions, twenty-two independent
assertions, six cover tasks, and eight exact negative-control labels. This is
a generated proof obligation matrix, not a proof result. The synthesis
foundation emits a canonical three-profile IR role inventory and explicitly
sets `pre_map_rtlil_topology=false`; the rejected grep/count checker and
synthetic RTLIL substitutes were removed. A typed alias/cell/memory graph
checker must be validated against actual locked `memory -nomap` output before
any exact FIFO topology result can be claimed.

The locked runner boundary remains phase-neutral and the complete
warning-strict native phase gate passes 483 tests. The pinned FIFO differential
and formal attempts both completed their native checks and bundle generation,
then retained incomplete receipts when the Docker daemon was unavailable. No
pinned FIFO differential, synthesis-topology, or formal pass and no aggregate
receipt is claimed. Until the remaining pinned executions and one
unchanged-snapshot aggregate gate pass, Phase 5 supports no completed-phase or
physical CDC claim.
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
