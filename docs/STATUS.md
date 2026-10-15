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
| 5 — Language foundation and multi-clock events | passed locally | schema-4 language and CDC primitives; atomic rational-clock simulation/replay; unchanged-snapshot 832-test native plus nine-child pinned differential/synthesis/formal aggregate; complete 9-fixture/15-task FIFO formal matrix | no remaining local Phase 5 gate; prior failures retained and physical CDC remains unclaimed |
| 6 — FluxTile-0 simulation proof | in-progress | signed systolic graph, real operand banks and INT32 result SRAM; serial host-memory/queued/fetched-ring baseline; two-slot concurrent host engines, encoding-0.2 queued frontend and fetched concurrent device with one three-client bus; latest-writer dependencies, bounded ordered retirement, observed DMA overlap and runnable demos; independent oracle tests under stalls/faults, exact shapes, failed generations, partial progress, capacity/wrap and reset/flush; stable canonical IR/SV; logical Device ABI 1.0 and checked capability publisher; accepted named differential/synthesis bundles; current native checkpoint1,012/1,012 | close source-bound formal composition, Store/fetched write-path and explicit-fairness completion including the concrete8x8 scope; reconcile the existing named RTL/synthesis artifacts at closure, not an unspecified new matrix |
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

The [LunaWave replay command checkpoint](evidence/lunawave-cli-native-20261006.md)
adds a saved-bundle CLI over the existing public replay/trace APIs. Its clean
snapshot passes the full 853-test native gate, interface generation, formatting,
strict checking and boundaries. Actual executable checks return success 0,
digest mismatch 1 and unreached stop 1, retaining exact trace/VCD outputs.
The 158-file support inventory is retained. This improves simulator usability
without changing replay formats, hardware semantics or Phase 6 proof status.

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

The [2026-10-06 aggregate](evidence/phase5-aggregate-20261006.md) passes on
unchanged commit `58ed2d8`: all 832 native tests and all nine child gates exit
zero. Its complete evidence inventory covers 3,512 files with typed results, witnesses,
counterexamples and logs. HEAD, status and complete input manifests match
before and after execution. Phase 5 is passed locally for its named digital
claims; Phase 6 remains in progress.

The [2026-10-05 aggregate attempts](evidence/phase5-attempt-20261005.md) retain
the original fixture-name failure and its narrow fix. The second unchanged
snapshot passed the 542-test foundation native gate, all three differential
gates, and all three synthesis gates. It stopped when the pinned SBY version
probe crashed during synchronizer formal. An unchanged standalone rerun passed
all synchronizer formal tasks. Those historical child successes alone did not
promote Phase 5; the fresh aggregate above reruns every child on one snapshot.

Standalone toggle formal also passed. The FIFO retry passed its complete
bounded checks, required negatives, and four covers, then stopped before a
later cover during container output-volume initialization. Its failure log
does not identify the underlying cause; no final FIFO gate pass is claimed.
Both previously missing covers now pass in a
[fresh standalone probe](evidence/phase5-cover-probe-20261005.md), with actual
witnesses at global step 31. This adds named task evidence without amending the
incomplete receipt. The subsequent
[complete standalone FIFO formal gate](evidence/phase5-fifo-formal-20261006.md)
passes all nine fixtures and fifteen tasks on unchanged commit `7bcf1a7`,
including the bounded safety result, all six covers and eight exact-label
negative controls. Its complete artifact tree and original receipts are
retained separately from the subsequent passing aggregate.

Canonical IR schema 4 carries sparse explicit domains, port timing, parameters,
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
a completed named bounded task matrix in the passing aggregate, not an
unbounded or physical CDC proof.
The synthesis path now includes a typed alias/cell/memory graph checker,
validated against actual pinned `memory -nomap` output. Its three-profile
gate passed with 25 checks per fixture, exact owned-state and memory topology,
and two-state role equivalence. This is not physical RAM mapping, timing,
four-state equivalence, or analog CDC evidence.

The locked runner boundary remains phase-neutral and the complete
warning-strict foundation native phase gate passed 542 tests; the fresh
aggregate passes the expanded 832-test suite. Earlier runs
retained incomplete receipts when Docker was unavailable; the later pinned
child receipts superseded only those unexecuted checks. The fresh aggregate
closes the local Phase 5 gate without creating any physical CDC claim.

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
allocation or pinned tool setting has been changed. The supporting-assertion native
checkpoint at `84d61eb` passes 798 tests, interface generation, formatting, strict checking
with warning73, default CLI smoke and dependency/source-size boundaries.
The Boolean helper refinement separately passes97 targeted tests. No full-product proof
is claimed.
The [local generation transfer slice](PHASE6_GENERATION_LEMMA.md) now discovers
the exact eighteen production register roots and materializes their reset,
enable and hold transfers in a separate combinational module. Discovery/transfer
tests and five decoder tests pass. The independent generation reference and separate proof-input
exporter now pass [pinned reset/step SAT](evidence/phase6-generation-sat-20261005.md)
for the banks, local fault/reject and halted alias, with three actual sensitivity
counterexamples. The strengthened
[decoder-complete local reset/step obligations](evidence/phase6-generation-decoder-sat-20261005.md)
also pass, with seven exact private production projections and independently
reviewed complete controls. Full-device composition remains unfinished.
The [full-harness supporting assertion experiment](evidence/phase6-generation-support-20261006.md)
retains all original checks and assumptions, but times out after 601s while
checking assumptions at global step 62 of 256. Actual preparation retains 28 assertions,
four assumptions and unchanged DUT state/memory choices; no trace or typed
proof receipt exists. All 46 ordinary fixture artifacts remain byte-identical.
The [exact sequential generation bridge](evidence/phase6-generation-bridge-20261006.md)
subsequently passes actual k-induction with four assertions and only the first
joint-reset assumption, plus a complete selected negative-control trace.
This proves the local binary generation clock/reset relation, not full-device safety.
The [compute identity checkpoint](evidence/phase6-compute-identity-20261006.md)
at `5d53a55` retains nine actual controller registers/80 bits and passes its
complete native suite, 808/808, plus 84/84 formal-package tests, strict checking,
interface generation, formatting, CLI smoke and dependency/source-size boundaries.
Isolated boundary tests and three unchanged full-device regressions have distinct
documented scopes. All thirteen generation and 46 ordinary artifacts remain
byte-identical. No new engine ran and saved authorization is not yet proved.
The [joint extraction checkpoint](evidence/phase6-compute-composition-20261006.md)
at `7892771` subsequently retains 27 actual registers/416 bits with nineteen
inputs/341 bits and no generation-state shadows. Three focused transition tests,
87/87 formal-package tests and its complete native suite, 811/811, pass,
along with strict checking, interface generation, formatting, CLI smoke and
dependency/source-size boundaries. All 59 existing artifacts remain byte-identical.
This is native extraction evidence; no new formal engine or authorization/owner
proof result is claimed at that extraction checkpoint.
The subsequent [joint proof checkpoint](evidence/phase6-compute-proof-20261006.md)
at `94f620d` passes its complete native suite, 816/816, formal-package
tests 91/91, CLI tests 9/9 and all thirteen pointwise Boolean helper checks with
their negative control. All 59 existing artifacts remain byte-identical. Actual
pinned base checking and k-induction pass for six local conclusions with only
the first joint-reset assumption. The comparison-only reduction mutation fails
the exact saved-authorization assertion at global step11 after a legal outer
acceptance and real inner handshake; all four counterexample formats are retained.
Prepared-model and PRE-phase trace audits preserve the distinction between this
binary local relation and the unfinished full-device safety/composition gate.
Production RTL and ordinary formal bundle bytes
are unchanged; one purpose-specific artifact-export function is added publicly.
The [fetched writer rejection/recovery checkpoint](evidence/phase6-writer-fault-20261006.md)
at `1926677` passes the latest complete native suite, 819/819, and fixture CLI
tests 10/10. Strict pinned lint/build/execute and typed audit agree across
2,887 cycles and all 30 outputs. The malformed version preserves prior writer
intent; syntax-valid stride rejection forbids stale operand/result fallback;
unrelated result storage and fresh recovery computation succeed. Seventeen
ordered completions, 552 actual request/ACK pairs, a 32-edge held completion,
five safe refills and all-byte oracle checks are recorded. All 55 artifacts
from the five earlier replay fixtures remain byte-identical. The initial
external helper sorting failure and corrected resume are retained separately;
no hardware, runner or replay-input changes were needed. This does not close
the remaining Phase 6 workload, synthesis or full-device formal gates.
The [fetched DMA protocol-owner checkpoint](evidence/phase6-dma-poison-20261006.md)
at `4fab038` passes the full native suite, 822/822, and fixture CLI tests 11/11.
Pinned lint/build/execute and typed audit agree across 21,072 cycles and all 30
outputs. Both actual owned status 2 responses advance accepted compute on their
discovery edges. Owner fault 10, sibling fault 15, held Fence stability, exact
admitted-prefix retirement, 78 Run/64 capture-edge drainage and four joint resets
are observed. All 66 older fixture artifacts remain byte-identical and all 16,384
host bytes match independent expectations. Two compiler OOM attempts are
retained; the unchanged build passes with 8 GiB VM RAM plus 4 GiB guest swap.
The subsequent [matching remote failure checkpoint](evidence/phase6-remote-fault-20261006.md)
at `5477490` passes 825/825 native tests and 12/12 fixture CLI tests.
Pinned lint/build/execute and typed audit agree across 2,822 cycles and all
30 outputs. A genuine two-byte partial host write precedes matching status 1;
same-generation retry succeeds without reset. Failed reload generations reject
stale compute/store, unrelated C1 persists and fresh recomputation recovers.
All sixteen ordered completions, 537 request/ACK pairs and every host byte pass;
all 77 older artifacts remain byte-identical.
The [capacity/origin-wrap checkpoint](evidence/phase6-capacity-wrap-20261006.md)
at `87b9583` passes 828/828 native tests and 13/13 fixture CLI tests.
Pinned lint/build/execute and typed audit agree across 1,371 cycles and all
30 outputs. Origin `fffffffe`, publications zero/two/four/six, five admitted
and six fetched commands at consumer three/producer four/queue two, a 32-edge
stable host-owned slot and eight ordered retirements are observed. All 256
descriptor reads/ACKs, zero operand/write/compute activity and every host byte
pass; all 88 older artifacts remain byte-identical. Internal ticket wrap,
invalid publication and remaining Phase 6 workload/synthesis/formal coverage
remain unfinished.
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
The [direct queue observation checkpoint](evidence/phase6-queue-seam-20261006.md)
at `58ed2d8` passes all 832 native tests, three focused seam tests and the checked
public example. Its 115 exact typed references add no hardware nodes or ABI
ports; ordinary canonical IR/SV and the old 48-reference dependency view remain
unchanged. Six actual packets with duplicate IDs exercise lane/head/entry/engine
ownership and ordered retirement, including sixteen consecutive held quiet
edges. This validates construction and bounded native replay, not a formal
task. Actual structural conservation, saved packet identity, engine ownership,
leases, fairness and the complete Phase 6 gate remain unfinished.
The [queue-task and descriptor-replay native checkpoint](evidence/phase6-queue-descriptor-native-20261006.md)
passes 838/838 native tests and the native CLI build. The structural exporter
preserves all 93 older formal artifacts; its exact 19-helper binary SAT and
negated-miter control pass. The new descriptor replay checks 86 ordered
completions over 14,464 cycles, all host bytes and exact rejection/recovery
oracles; all 99 older replay artifacts remain unchanged. Reference generation
and self-audit do not establish independent RTL agreement or device formal
safety. The subsequent
[independent descriptor-rejection RTL checkpoint](evidence/phase6-descriptor-rejection-20261006.md)
passes strict pinned lint/build/execute and typed audit on clean `011a048`.
All 433,920 observations match over 14,464 cycles; the complete 451-file support
inventory is retained. This closes the fixed replay's independent agreement,
not the queue formal tasks or the complete Phase 6 gate. Its original
obligations remain required.
The [retirement-record native checkpoint](evidence/phase6-retirement-record-native-20261006.md)
passes842/842 native tests and the CLI build on its documented source contexts.
All113 earlier formal artifacts remain byte-identical, and the only generated
public API additions are two fixture enum cases. Real-DUT duplicate-ID,
younger-collector, held-record/release and later-reset checks pass. The new
six-assertion safety, adjacent cover and held-payload negative remain separate
unexecuted obligations at this native checkpoint, not inferred proof results.
The subsequent
[retirement-record formal execution](evidence/phase6-retirement-record-formal-20261006.md)
accepts the exact p10 sensitivity counterexample, including the held-record
release edge. Full six-assertion safety times out after 601 seconds. The p11
cover also times out during export after discovering the predicate at step 23;
its partial VCD is not a complete witness. No typed safety or cover result is
produced. The complete 142-file support inventory retains both failures and
the negative's original typed receipt; positive retirement safety stays open.
The [dynamic-shape reload checkpoint](evidence/phase6-shape-reload-20261006.md)
passes 15/15 affected native tests on clean `aad4b60` and preserves all 121
older replay artifacts. On the existing 8x8/capacity17 device, 3x5/K17 then
8x8/K1 reuse mixed source slots and preserve both C0/C1 results through exact
shape reloads. All 4096 host bytes and 79 result words match the independent
oracle. Strict pinned lint/build/execute and typed audit pass; all 117510
public observations match over 3917 cycles. The complete 530-file inventory
retains reference generation and independently executed RTL separately. A
failed ordinary evidence copy is preserved outside the accepted copy; the
successful copy-on-write clone verifies byte-for-byte. This closes that fixed
workload's differential agreement, not any remaining full-device formal gate.
The [public packet provenance native checkpoint](evidence/phase6-packet-provenance-native-20261006.md)
at clean `51f3fb5` passes 113/113 affected tests and preserves all 133 older
formal artifacts. One independent watch saves 256 public lane bits through
FIFO response, captured head, reservation and ordinal retirement. Real-DUT
duplicate-ID replay requires full pop/refill, simultaneous watched admission
and older retirement, held completion and reset cancellation. Production IR,
RTL, ABI and runner remain unchanged. The 415-file support inventory retains
the corrected test's original input-API failure as well as successful checks.
At that native checkpoint the solver tasks were unexecuted; neither generation
nor its finite replay completes a formal obligation. The subsequent
[packet-provenance formal execution](evidence/phase6-packet-provenance-formal-20261006.md)
accepts the exact p12 sensitivity counterexample and complete p13 same-watch
transfer witness, with original typed results and receipts. All-seven safety
with 20 nested DUT memory assertions times out after 601 seconds, last checking
assertions at global step 33, without a trace or typed safety result. The
148-file retained inventory preserves all three outcomes. Positive safety and
the remaining full-device obligations stay open.
The [actual structural queue pilot](evidence/phase6-queue-formal-20261006.md)
retains a complete p7 full/refill capture witness and exact p5 population
sensitivity counterexample, with unchanged inputs and complete typed receipts.
Its three-assertion safety task times out after601 seconds at the original
256-global-step bound, with no trace or typed safety result. Neither successful
control substitutes for that unfinished proof or the complete Phase6 gate.
The [ring-control recovery checkpoint](evidence/phase6-ring-control-20261006.md)
passes 845/845 native tests and preserves all 110 older replay artifacts. Strict
pinned lint/build/execute and typed audit pass on clean `77db8bb`; all 213,210
observations match over 7,107 cycles. Seven epochs exercise runtime configuration
and invalid publication, actual packet-admission overlap, admitted-work drainage,
held completion and stale-slot reset/fresh recovery. The 486-file retained
inventory includes failed native attempts and all actual RTL outputs. This
closes the fixed replay's independent agreement, not the original safety,
retirement-record or complete Phase 6 formal obligations.
The [fixed queue assertion partition measurement](evidence/phase6-queue-partition-20261006.md)
also times out after 601 seconds at the unchanged 256-step bound. Its exact 11
assertions/four assumptions and canonical selection-boundary preservation pass
independent review, but reaching assumption checking at 97 versus 96 is not a
safety pass or useful measured improvement. The original timeout remains
unchanged; no typed conjunction is produced. Remaining partition/control
invocations and a permanent collection framework are not pursued on this
hypothesis. The 543-file support inventory retains all unsuccessful attempts.
Deterministic digital sampling does not measure metastability, MTBF, placement,
routing, recovery/removal timing, or timing closure.

The [exact queue control extraction](PHASE6_QUEUE_CONTROL_LEMMA.md) at clean
`670ca8c` passes interface generation, formatting, strict native checking with
warning 73 enabled and 108/108 formal-package tests. Sixteen existing production
registers/37 bits retain the original lane, head and retirement transitions;
eight explicit boundary cuts abstract terminal timing, not engine identity.
Four new tests cover extraction and representative control sequences. The
preceding family-owned induction-selection fix preserves all 36 contemporary
FIFO artifact bytes. No new engine ran, the full native matrix was not rerun,
and local induction plus whole-device composition remain unfinished.

The subsequent [local queue-control proof](evidence/phase6-queue-control-proof-20261006.md)
at clean `47736b1` passes actual base case and k-induction for six control
conclusions (two-second SBY wall time). The negative fails only its intended
population assertion at global step 9 from genuine PRE step 8 reservation
(four-second SBY wall time). Clean targeted tests pass 125/125; all 172 prior
exported artifact bytes are unchanged. Four exact Boolean comparison helpers
pass equivalence plus the selected negative control. This establishes the
scoped binary control theorem, not a speedup measurement or whole-device gate.
The larger queue/retirement/packet safety timeouts and composition, ownership,
memory, fairness and full 8×8 requirements remain open. The complete native
test matrix was not rerun.

The [actual-device queue assertion composition](evidence/phase6-queue-control-composition-20261007.md)
at clean `0b7fc71` carries the proved relation into existing `p6`, without new
state, cuts, premises or production changes. Clean targeted tests pass 132/132;
142 preceding artifacts remain byte-identical and 36 have exactly the intended
harness/hash changes. All nineteen full-DUT Boolean helpers pass pointwise
equivalence and the negated control. The original full safety task retains
23 assertions/four premises and times out after 601 seconds, last checking
assumptions at step 82 versus the retained baseline 96. No trace, typed safety
result, useful solver improvement or completed composition is claimed. The
next supporting proof must retain the original 35 monitor bits on the exact
37-bit controller projection; the larger Phase 6 gates remain unfinished.

The [original queue-monitor supporting proof](evidence/phase6-queue-monitor-proof-20261007.md)
at clean `6e5ee3b` establishes the original three conclusions by base case plus
k-induction (three-second SBY wall time), retaining all 35 monitor bits on the
unchanged 37-bit projection. Original R+1 sensitivity fails only p5 at global
step 11 with genuine prior admission/reservation PRE history (four seconds).
Clean targeted tests pass 137/137; all 178 preceding artifacts are byte-identical.
The initial collector rejects a Yosys-trimmed trace width; the narrow one-role
repair qualifies the unchanged actual trace read-only, retaining the original
rejection and both complete engine outputs. No engine rerun, full-device pass,
measured speedup or completed Phase 6 gate is claimed. All larger composition,
ownership, provenance, memory, fairness and full 8x8 obligations remain open.

The [engine/live-entry ownership discovery and native checkpoint](evidence/phase6-queue-owner-native-20261007.md)
at clean `4573cb1` passes 143/143 targeted tests and preserves all 184 preceding
artifact bytes. The private candidate-only probe retains 30 original registers/
304 bits and 59 derived events, with 82 inspected foreign leaves and no accepted
projection or public API change. Actual PRE/POST checks require real Store/
compute overlap, younger collection, held ordered retirement, reuse,
simultaneous reserve/ACK and reset/fresh-epoch recovery. No formal engine runs,
unbounded ownership result, physical ticket-wrap witness, full native matrix
rerun or complete Phase 6 gate is claimed. Exact sequential materialization
and induction are the next ownership implementation steps.

The [accepted ownership projection and proof-input checkpoint](evidence/phase6-queue-owner-inputs-20261007.md)
at clean `ea27f7e` passes 151/151 targeted tests and preserves all 184 preceding
artifact bytes. The private plan freezes the full reviewed inventory and exact
closure; 30 original registers/304 bits and 59 derived events are compared at
actual PRE/POST edges with all 82 foreign LogicValues mirrored. Six supporting
inputs retain nine conclusions, one startup-reset premise and a checked-ticket
only negative. The original filename-order comparison failure is retained;
read-only exact-membership qualification succeeds without re-export. No helper
qualification, engine run, ownership theorem, full native matrix rerun or
completed Phase 6 gate is claimed. Induction and causal sensitivity are next.

The [original engine/live-entry ownership proof](evidence/phase6-queue-owner-proof-20261007.md)
at unchanged clean `ea27f7e` passes actual base case and k-induction (27 SBY
clock seconds). The checked-ticket-only negative fails solely engine identity
at global step 13 (49 seconds), with independently qualified PRE reservation,
committed loader acceptance and original raw owner versus checked-mask mismatch.
Prepared models preserve 30 original registers/304 bits, all 82 cuts/1,069 bits,
nine assertions and the sole startup-reset premise. All nineteen exact Boolean
helpers reuse prior source-bound qualification without identical solver reruns.
The 237-file sealed inventory retains actual engine outputs, initial script
compiler failures and subsequent successful read-only collector qualification;
no engine is rerun after repair. Prior 151 targeted native tests and 184-artifact
compatibility are reused, not rerun. This establishes scoped binary ownership,
not packet-content provenance, completed composition, the full native matrix,
solver speedup or the complete Phase 6 gate. Larger storage, generation, Store,
DMA/memory, fairness, fetched transport and full 8x8 obligations remain open.

The [original two-client DMA arbiter discovery](evidence/phase6-dma-arbiter-native-20261007.md)
at clean `aa9425a` passes 155/155 targeted tests and preserves all 190 preceding
artifact bytes. Independent inspection accepts eleven original registers/172
bits, seventeen derived events and the exact 81-node combinational closure;
fifteen nonconstant candidates and seven distinct original constants preserve
raw client boundaries without cutting grant, acceptance, routing or poison.
The 540-file sealed support retains unsuccessful drafts and read-only collector
repair. No sequential projection, PRE/POST correspondence, proof inputs,
arbiter theorem, full native matrix rerun or completed Phase 6 gate is claimed.
Exact materialization and native correspondence precede the local proof.

The [exact original DMA arbiter materialization](evidence/phase6-dma-arbiter-materialization-20261007.md)
at clean `ae84d15` passes 157/157 targeted tests and preserves all 190 preceding
artifact bytes. The private checked module retains 108 nodes, eleven original
registers/172 bits, sixteen inputs and twenty-eight aliases. Independent tests
compare every original operation/specification and retain startup X, with seven
constant boundaries unchanged. The 479-file sealed support retains the original
type-error draft and exact-equality correction. No actual-device correspondence,
observer premise, proof inputs, arbiter theorem, full matrix rerun or completed
Phase 6 gate is claimed. Finite PRE/POST scenarios precede the supporting proof.

The [actual-device DMA arbiter correspondence](evidence/phase6-dma-arbiter-correspondence-20261007.md)
at clean `3f4b408` passes 159/159 targeted tests. All fifteen full LogicValue
boundaries, eleven retained roots and seventeen derived events agree at PRE
and POST without state injection. Actual witnesses require a tied grant, three
contested Store Offer stalls, consumed malformed response, four poison edges
and later reset/fresh matching recovery. This test-only checkpoint reuses the
prior exact 190-artifact comparison through a read-only sealed-inventory check;
no re-export is claimed. The 109-file support retains the effect-error draft
and exact payload-loop correction. Remote/reserved status, nonrising events,
symbolic peer safety, local induction and the full Phase 6 gate remain open.

The [original DMA arbiter proof input checkpoint](evidence/phase6-dma-arbiter-inputs-20261007.md)
at clean `f1493e0` passes 171/171 targeted tests and freshly compares all 190
prior artifacts byte-for-byte. Actual native remote/reserved fault and active
Offer/Wait reset scenarios pass. Six deterministic inputs retain eleven
original registers/172 bits and all fifteen raw cuts; an export-only direct
raw-data observation makes the otherwise unused input reachable without
altering the native component or emitter rule. Eight conclusions use one
startup-reset premise and an isolated stalled-payload comparison negative.
The sealed 533-file support retains failed drafts and complete clean-source
validation. Helper qualification, prepared-model review, local induction,
causal negative qualification and the full Phase 6 gate remain open.

The [original two-client DMA arbiter proof](evidence/phase6-dma-arbiter-proof-20261007.md)
at clean source `f1493e0` passes explicit base case and unbounded induction.
Actual prepared-model review accepts eleven original registers/172 bits,
fifteen free cuts/233 bits, eight assertions and the sole startup-reset premise.
The isolated negative fails only payload at global step seven after real
grant and committed stall; independent low-PRE review qualifies unchanged raw
owner/payload and exactly checked data-bit-zero mismatch. Three complete
binary helper pairs reuse the retained 19-helper result with unchanged
remaining RTL. The sealed 190-file proof support retains actual models,
logs and counterexample formats; native validation and prior-artifact
compatibility are reused. This is local binary arbiter safety. DMA bounds,
Store leases, storage/provenance composition, fetched transport, fairness
and the full Phase 6 gate remain open.

The [original Store observation and finite preservation checkpoint](evidence/phase6-store-observation-20261007.md)
at clean `336fc56` passes 345/345 targeted native tests and freshly preserves
all 196 preceding artifact files byte-for-byte. The metadata-only fixture
exposes 48 original registers/515 bits, 33 existing events and both complete
C-memory read references without changing production hardware or the older
115/48 inventories. A genuine loader pregrant delay overlaps six opposite-slot
captures, including final capture; actual Store offers and both matrices match
their native oracles. The sealed 485-file support retains the initial strict
trait-declaration failure and clean validation. No projection, formal engine
run, independent RTL replay, full native matrix rerun or completed Phase 6 gate
is claimed. Storage-aware candidate discovery precedes a Store supporting proof;
larger storage/provenance, DMA/memory, fairness and full 8x8 obligations remain open.

The [original storage discovery and FIFO-to-head native prefix](evidence/phase6-storage-discovery-20261007.md)
at clean `933939d` passes the full native gate, 940/940 tests, and freshly
preserves all 196 preceding artifacts byte-for-byte. Store candidate discovery
retains 48 roots/515 bits, both original C memories and complete provenance;
it is not yet an accepted Store projection. The exact FIFO prefix retains
28 original registers/309 bits, all four q3 Bits64 memories/read states and
59 shared raw boundaries. Independent native correspondence agrees across
100 PRE/POST pairs, 23 captures, 17 changed full refills, pointer wraps and
later reset retaining all twelve cells. The 579-file sealed support preserves
failed drafts and clean-source results. No new symbolic proof, RTL replay or
completed Phase 6 gate is claimed. FIFO/Store proof and full provenance,
fetched transport/DMA bounds, fairness and 8x8 formal closure remain open.
The [Phase 7 board plan](PHASE7_FPGA_TARGET.md) provisionally recommends the
Arty A7-100T; no hardware purchase, fit or timing result is implied.

The [original FIFO storage-to-head supporting proof](evidence/phase6-fifo-prefix-proof-20261007.md)
at unchanged clean `0feff5e` passes actual base case and temporal induction,
watched-transfer cover and the sole selected watched-response negative.
Independent inspection retains 309 original register bits, 768 actual SRAM
bits and 256 registered-read bits, all sixteen positive assertions and the
sole startup-reset premise. Cover and negative have genuine admission/pop/
response/capture PRE histories; complete traces are exported. Seventeen exact
helper pairs reuse the accepted whole nineteen-helper result. The 561-file
sealed support retains unsuccessful preparation drafts and clean 192-test
native validation. This closes the scoped binary FIFO-to-head prefix, not
full retirement provenance, Store preservation, completion fairness or Phase 6.

Direct q3 completion inputs are now implemented at `f00a76e`, with CLI export
and canonical registry regeneration at `c50261e`. The three fixtures distinguish
the proposed 252-edge arbitrary-admission obligation, a separate useful Store
cover with repeated caller ID 73, and a deadline-one monitor sensitivity check.
They use explicit public-host legal/fairness premises; response availability
bounds offers, never DUT readiness. Working targeted tests pass 23/23. No
completion engine result is recorded; supporting composition, Store/DMA and
fetched/8x8 scope closure still precede a completed Phase 6 gate. See
[the completion proposal](PHASE6_FORMAL_COMPLETION.md).

Clean completion source `c50261e` additionally passes the full serial native
gate, 955/955 tests. A fresh CLI exports all three input sets; independent
review accepts their emitted bindings, public-only premises, ordinal identity
and isolated deadline-negative expression as inputs, not solver outcomes.
The [sealed 252-file input checkpoint](evidence/phase6-direct-completion-inputs-20261007.md)
records this distinction. No completion engine has run for that checkpoint.

The [Store storage/correspondence checkpoint](evidence/phase6-store-storage-correspondence-20261007.md)
at `b3907c0` / `eb3cb93` passes clean strict check, four structural tests and
the real 426-PRE/426-POST overlap/reset workload. Exact original control,
six memories/read states and only four arithmetic-production cuts are retained.
Actual Loader contention, opposite-C1 final capture, three held offers and eight
acknowledged writes match both signed matrix oracles; reset preserves all twenty
cells and six read states. Independently reviewed, sealed 200/143-file evidence
does not constitute the required Store formal preservation result.

The [Store input/model-qualified experiment](evidence/phase6-store-preservation-experiment-20261007.md)
at clean `3c9f244` passes its private four-test proof-input and one-test export
checkpoints and exact nineteen-helper source reuse. Actual positive base case
global 0–31 passes, but induction, coherent overlap cover and selected negative
each time out after 601 seconds with no trace. The sealed 1,377-file support
retains all three actual work directories and qualified prepared models.
No Store theorem, required bounded gate, witness or sensitivity result is
accepted. Optional unbounded induction work is paused; named bounded and
compositional obligations remain unchanged. Phase 6 stays in progress.

The [packet storage/native correspondence checkpoint](evidence/phase6-packet-composition-native-20261007.md)
at clean `8739f77` passes its three targeted tests, comparing all retained
state, actual FIFO storage/read results and ordinary outputs across 109 and
100 PRE/POST pairs. Its sealed 333-file support records full refill, pointer
wrap, repeated caller IDs, held completion and later reset. The private
response-data alias repair at `ffa5dbd` preserves ordinary hardware and makes
the original public response-stability premise exportable. Repaired projection
and proof inputs pass fourteen targeted tests at `c77e159`; the clean exporter
passes its actual one-test collector at `ad22f65`. The 201-output projection
has new report/IR pins distinct from the native checkpoint. These are input
and finite correspondence checks, not a packet solver result or Phase 6 pass.

The [packet composition experiment](evidence/phase6-packet-composition-experiment-20261007.md)
at unchanged clean `ad22f65` qualifies the original same-watch FIFO-to-head,
reservation/live-record and ordinal-retirement cover at step 13, and the
sole selected checked-packet negative at step 7. The cover is genuine local
rejection, not useful Store execution. Positive base checks 0–19 pass, but
induction reports p12 failure and times out during incomplete trace export;
neither a packet theorem nor a reachable hardware bug is accepted. All
actual models, complete cover/negative formats and unsuccessful history are
retained in sealed 1,423-file support. The checked predecessor-history
refinement at `5f4c4b9` passes working/clean strict checks and four targeted
tests, with no solver outcome yet. Phase 6 remains in progress.

The separate refined-history experiment now has independently qualified
cover PASS at step 13 and selected negative FAIL at step 7. Its cover is a
fault-15 local-error retirement, not successful Store. Positive `prove20`
still times out with incomplete induction trace. A full `bmc256` attempt
under the unchanged seventeen conclusions/four premises also times out,
finishing step 60 and starting 61. The complete refined support is sealed
and mirrored; see the appended actual-results section in the
[packet experiment](evidence/phase6-packet-composition-experiment-20261007.md).

The complete native regression at clean `e32ebef` now passes 1,012/1,012
tests with empty stderr. Native info, formatting and strict checking also
pass without source changes. Actual command/exit/source records are retained
under `/private/tmp/lunachip-composition-drafts-native-20261007.muObbm/`
in `current-source-native-{info,format,check,regression}`. This validates the
current native source checkpoint; it does not substitute for the still-open
formal Phase 6 gate or establish FPGA execution.
Disjoint conclusion groups retain the full declared bound; they are not
accepted results until every required group completes. Phase 6 remains open.

The additional [Store BMC256 attempt](evidence/phase6-store-preservation-experiment-20261007.md)
also times out, completing step54 and starting55. Actual models are
byte-identical to the prior independently qualified 3,771-bit model; its
complete support is sealed separately. This is not a Store safety result.

Source checkpoints `73d0b50`, `81cc3b6`, `74e0e89` and `6801d94` add native
dependency-union correspondence and private proof inputs, fresh three-client
fetched transport correspondence, and distinct public fetched-useful/direct8
task identities. Strict native check and all26 targeted native tests pass.
The dependency union retains79 registers/1,202 bits plus the original four
reads/arrays, totaling2,226 original state bits. The fetched component retains
the actual26 registers/666 bits; native correspondence exercises96 descriptor
bytes, producer wrap, held offers and later reset, not all-client symbolic
contention. Full source/report mapping inventories are collected for review.

The fetched useful fixture keeps the uncut R1/H1/C1 device and explicitly
directed public host, with safety/Store-write-ACK-retirement tasks at1,024
global steps. The distinct direct8 8x8/K16/R2/H2/C2 fixture uses deadline11,718
and23,552 global steps, never reinterpreting the original direct1 deadline252
or640-step tasks. All three original direct1 harness hashes remain unchanged.
The actual task/registry/CLI native tests pass, but no engine outcomes for
these newly exported families are recorded. The private fetched component
proof refused export until its complete actual source pins were accepted.

At `e32ebef`, those independently reviewed component-source pins are bound;
strict native check and four targeted tests pass. A new 115-cycle native
Store trajectory exercises genuine pending-read contention, opposite-bank
intermediate/final captures, three held offers and four successful writes.
Its input and causal traces are collected separately from six fetched
component proof inputs. These are finite native/source checkpoints, not
formal Store witnesses, fetched proofs or a Phase 6 pass. Guided input
constraints may be used only for an explicit existential scenario, never
to narrow universal safety unnoticed.

That separate guided Store experiment now has independently qualified
existential and sensitivity results: the unchanged original coherent cover
reaches229 with all four successful C0 writes/ACKs and progress16/fault0;
the sole checked payload mutation fails151 during the genuine held overlap.
Both preserve original storage and input-only scenario constraints. Native
full PRE/POST snapshot equivalence and universal Store safety remain unclaimed.
See the [Store experiment](evidence/phase6-store-preservation-experiment-20261007.md).

The packet controller group now has an independently qualified unbounded
supporting proof: original eleven conclusions plus one checked FIFO-shape
conclusion pass base0–19 and induction in22s under the same four premises.
The remaining packet groups and dependency, Store, fetched-device and
fair-completion/8x8 obligations are still open. Actual outcomes and the
immutable support/correction are recorded in the
[packet experiment](evidence/phase6-packet-composition-experiment-20261007.md).

The original fetched-reader/three-client component conclusions now also have
an independently qualified unbounded supporting proof. All twelve original
conclusions plus four checked history/prefix relations pass base 0–19 and
induction under the unchanged sole startup joint-reset premise. The original
26 registers/666 bits and 21 raw component boundaries remain intact; no
supporting relation is assumed. The complete 961-file sealed support is mirrored
at `.phase6-fetched-support-evidence-20261008` with all checksums and bytes
verified. Prior tag, aperture and unwritten-prefix induction failures remain
recorded separately. See [formal checkpoint](PHASE6_FORMAL.md).
This does not close full-device fetched write-path safety, packet/dependency
composition, universal Store safety or explicit-fairness completion at the
declared 8x8 scope. Phase 6 remains open; native source stays at clean `e32ebef`
with 1,012/1,012 tests passing.

## Validation resumption — 2026-10-13

The [resumption checkpoint](evidence/phase6-validation-resume-20261013.md)
restores one small user-authorized validation VM and the unchanged pinned tools.
Native strict checking, interface/format checks, nine focused source tests and
the standalone partition test pass. The one-test fresh Store collector matches
all eight retained source-qualified inputs byte-for-byte. The attempted full
native regression was interrupted; no fresh full-matrix pass is claimed.

The original nineteen Store conclusions are partitioned into disjoint
control4/data2/storage13 groups without changing DUT expressions, premises,
depth256 or timeout600. Prepared-model qualification and actual group outcomes
are still required. The corrected control4 run times out after601s, completing
assertion steps0–50 and starting assumptions51, without a trace or counterexample.
It retains the four expected conclusions, sole premise and six original unknown
arrays. No depth256 pass or speedup is claimed. New support stays under
`artifacts/`, with one reused native cache and no copied builds. Phase6 remains
in progress.

The disjoint storage13 attempt also times out after602s, completing assertions
0–87 and starting assumptions88. Its actual model retains all thirteen selected
checks, sole premise and six original unknown arrays. Data2 also times out
after601s, completing assertions0–72 and starting assertions73. No run returns
a trace or counterexample, and none completes depth256. The full storage/reset
observation cones remain present. Complete309-file support is sealed under
`artifacts/phase6-store-partition-20261013/`, without compiler caches.

The new private fetched-supported collector now reproduces all three exact
accepted theorem inputs: the unchanged Boolean DUT, sixteen-conclusion wrapper
and actual prove config. Five focused native tests, strict check, interface and
format checks pass. The four additional relations remain checked assertions,
not assumptions; no production hardware or legacy six-artifact export changes.
This makes the existing component proof source-reproducible, not a fresh solver
result or full-device Phase6 pass. The idle VM is stopped and QEMU-only.

## Clock/reset and lease checkpoint — 2026-10-13

Three parallel source/review agents and serial QEMU-only tool runs complete
eight source-bound supporting k-induction proofs (eighteen conclusions): all
twelve memory-port reset enables, all162 register reset values, reset retention
of all SRAM/read state, nonrising register/memory hold, exact lease release and
Issue ownership with checked paired-state support, old-PRE admission exclusion,
and pending-read protection through ACK. Six focused native tests, strict
checking, interface/format checks and the runner test pass.

The original Issue conjunction passes its20-step base case but fails induction;
trace export then times out, with incomplete diagnostics retained. A single
additional checked state-phase assertion closes the fresh supported task without
a DUT change or new assumption. All successful and unsuccessful work is sealed
under two `artifacts/` roots, with no compiler caches. The idle VM is stopped.
See the [actual result ledger](evidence/phase6-validation-resume-20261013.md).

These are supporting component proofs, not automatic composition into the
original Store conjunction. Capture ownership/shape, publication, payload,
complete reset ghosts/events and memory bounds remain required alongside the
other packet/fetched and explicit-fairness8x8 obligations. Phase6 remains open.

## Capture/publication and Store payload checkpoint — 2026-10-13

Three parallel agents and serial pinned QEMU runs complete eleven scoped
k-induction tasks. Joint checked support closes the original capture/lease p2
and produced-storage p3 predicates for the2x2/K2 original projection: legal
capture/cursor/lease, same-commit metadata publication, current-generation
rectangle coverage, captured cells and real synchronous reads. Pending/DMA
transport and a joint independent-raw-origin public Store write relation also
pass, with the latter explicitly captured-read-basis guarded.

One smaller captured-slot1 task has an engine crash before status; its error
is preserved, while the stronger read-slot1 task independently proves the
same six cell conclusions plus read behavior. Six focused native tests,
strict checking, interface/format checks and the runner test pass. All inputs,
models, logs and failures are sealed in two `artifacts/` roots without compiler
caches; the dedicated VM is stopped. See the
[actual ledger](evidence/phase6-validation-resume-20261013.md).

Original p4 still needs the checked generation-basis link, whole reservation
and full13-bit Store cursor/shape/fault/address composition. Remaining Store
control/reset/bounds, packet/fetched and explicit-fairness8x8 obligations are
not closed. Hardware/ABI are unchanged; Phase6 remains in progress.

## Original Store p4 composition checkpoint — 2026-10-13

The [audited p4 ledger](evidence/phase6-store-p4-composition-20261013.md) closes
exact original p1/p3/p4 together for the unchanged binary2x2/K2 projection.
Three pinned QEMU k-induction tasks pass; the joint task checks85 assertions
including old-PRE reservation, complete-generation eligibility, full13-bit
cursor/fault/physical-address composition, pending independently produced word,
unconditional genuine-grant basis and original DMA/public write identity.
All support is asserted, never assumed from prior results.

One narrower cursor task remains TIMEOUT with a retained partial induction
trace. Its missing generation/physical-metadata link is checked by original p3
inside the stronger83/85 passing tasks; every cursor relation passes there.
Five focused native tests and strict/interface/format/runner checks pass.
The339-file evidence inventory verifies, contains no compiler cache, and the
dedicated VM is stopped. Production hardware/ABI/API remain unchanged.

Original p5/p6, full Store conjunction, memory bounds, BMC256 and selected
overlap/sensitivity results remain required alongside packet/fetched and
explicit-fairness8x8 obligations. This does not close Phase6 or establish
numerical MatMul, full8x8 safety, FPGA execution or physical performance.

## Full original Store safety checkpoint — 2026-10-13

The [audited full Store ledger](evidence/phase6-store-full-composition-20261013.md)
closes all nineteen original positive safety conclusions together for the
unchanged binary2x2/K2/host1024/q3 projection. Four pinned QEMU k-induction tasks
pass: original p5, complete p6/global hold, all twelve physical memory-port
bounds, and the full109-assertion conjunction (original19 plus90 checked
supports). Original predicates/labels remain intact; only the overlap cover
is removed. Exactly one startup-reset premise remains, with arbitrary later
reset and unknown memory initialization.

P5/p6 reuse original observers; eight real depth3 FIFO pointer ranges supply
the remaining memory support. All162 registers,20 cells/six held read states
and four arbitrary32-bit producers are retained in the accepted full model.
Seven focused native tests and strict/interface/format/runner checks pass.
All338 evidence files are sealed without compiler caches; the dedicated VM is
stopped. Changes are private validation only; hardware/ABI/API are unchanged.

This closes the original unbounded positive Store conjunction, not the whole
Phase6 gate. Packet/fetched and
explicit-fairness8x8 composition and aggregate validation remain open. No
numerical MatMul, host/full-device bounds, FPGA or physical-performance claim
is added.

## Store bounded check and evidence reconciliation — 2026-10-13

The [current Store ledger](evidence/phase6-store-bounded-20261013.md) credits
the previously accepted original input-guided overlap cover and selected
payload sensitivity. Complete1,076-file archive hashes, original bridge identity,
input-only guidance and complete230/152-frame causal traces verify. The cover
includes Loader-owned pregrant contention, opposite C1 intermediate/final
captures, four C0 writes/matching ACKs and successful full rectangle completion.
The negative fails only checked p4 after a guarded bit0 payload mutation.
These existential/sensitivity obligations are no longer pending. Historical
timeouts and native full-snapshot limitations are unchanged.

The new full109 BMC256 task uses exactly the accepted unbounded proof source.
Actual QEMU execution times out after601s, finishing assertion checks0–45 and
starting assumptions46, with no counterexample or trace. Prepared JNY/RTLIL
and final SMT match the accepted full proof after complete task-filename
normalization. This is not a BMC256 PASS; no unchanged retry is scheduled.
On2026-10-13 the user explicitly accepts the sealed unbounded full19 theorem
as the safety gate for this exact Store projection. It establishes safety
beyond256 global steps with all supports checked, not assumed. The Store
projection's safety/overlap/selected-sensitivity obligations are accepted;
the separate BMC256 PASS is no longer an additional requirement. All actual
bounded timeouts remain recorded unchanged, and no other Phase6 gate is waived.

Three focused native tests, strict checks, interface/format review and the
runner test pass. All93 new evidence files are sealed without compiler caches;
the VM is stopped and owned containers/volumes are cleared. Hardware/ABI/API
and user codec are unchanged. Packet/fetched, explicit-fairness8x8 and the
remaining Phase6 matrix/aggregate stay open; Phase6 is not complete.

## Original packet safety composition accepted — 2026-10-13

The [packet retirement and ownership ledger](evidence/phase6-packet-retirement-20261013.md)
accepts the complete original seventeen-conclusion safety conjunction for the
unchanged direct1x1/K2/host1024/q3 binary projection. This includes independent
public packet provenance, terminal-record/held-completion immutability,
oldest-terminal selection, structural conservation, all eight enabled FIFO
bounds and global nonrising hold. Three additional ownership/events/FIFO
relations are checked, not assumed; all original DUT/observer equations,
four public-peer premises and arbitrary foreign payloads remain intact.

Retirement18 passes actual basecase and k-induction in53 wall seconds; full20
passes in51s. Complete source/JNY/RTLIL/SMT review retains original labels,
all54 register and four held-read bindings, four unknown-initialized q3/Bits64
arrays and the1,900-bit physical observation. The same-source original p13
same-watch cover and p12 checked-bit128 sensitivity archive verifies and remains
accepted. Its cover retires a local fault, not a useful Store. Earlier timeouts
are neither retried unchanged nor relabeled as passes by the new theorem.

Four focused native tests plus the runner test and strict/interface/format
checks pass. The176-file qualified archive and eight-file refused-native draft
are sealed without caches; the dedicated QEMU VM is stopped. Hardware/ABI/API
and user codec are unchanged. MoonBit and repository-documentation skills keep
the new code private and evidence in the existing project ledger.

Packet projection safety/cover/sensitivity and the accepted exact Store gates
are now closed at their stated scopes. Full dependency/fetched/address
composition, explicit-fairness8x8 completion, remaining matrix and aggregate
validation remain open. Phase6 is still in progress; no FPGA or physical claim
is added.

## Full fetched useful Store checkpoint — 2026-10-13

The [fetched useful Store ledger](evidence/phase6-fetched-useful-20261013.md)
records an exact full-device native witness at PRE edge418 under the existing
directed R1/H1/C1 host. All128 descriptor-byte and four operand-byte reads have
distinct matching ACKs. The real four-byte write at address768 carries−29 at
edge414, its owned ACK occurs at415, and the fourth repeated-ID ordinal
retirement occurs at417. This fits the existing512-DUT-edge search budget;
it is a native trajectory, not an independent RTL or formal pass.

Two actual runner preflight rejections expose and repair export integration:
the job schema/validator now accept descriptive names through128 characters,
and the fetched source-set declares its existing binary address semantics.
Seven real name-policy cases, five targeted native tests, both real typed-task
verifiers, strict/interface/format checks pass. Hardware, public APIs, host
premises, DUT/harness bytes and1024-step bound are unchanged.

The corrected ordinary pinned cover task actually times out after601 wall
seconds, child exit8. It completes reachability checks0–319 and starts320,
with no witness or counterexample. Prepared models retain eight host premises,
one nonconstant cover, ten unknown-initialized memories and no safety
assertions in cover mode. Complete helper-body reuse and the historical961-file
seal verify. The two preflight archives and actual timeout archive are sealed,
about29MiB total, without compiler caches; owned tool resources are cleared
and the QEMU-only VM is stopped.

The next search is separately identified input-only guidance over the recorded
native PRE trajectory, not an unchanged retry or a safety assumption. Full
fetched/dependency/address safety, explicit-fairness8×8 completion and the
remaining matrix/aggregate are still open. Phase6 remains in progress.

## Input-guided fetched Store cover — 2026-10-13

The [input-guided cover ledger](evidence/phase6-fetched-input-cover-20261013.md)
records source-bound guidance over419 native PRE frames and twelve public
inputs, plus a focused QEMU-only runner. Four real native guidance tests and
two runner tests pass. No DUT, harness, original host premise, unknown memory
initialization, public API or user codec changes.

Two separately committed runs retain the full initialized prefix and existing
bound1024/time600. Skip832 ends in actual `ERROR 16 803` after590 wall seconds:
the VM kernel confirms Bitwuzla's global OOM kill at the first query. Skip839
ends in `TIMEOUT 8 85` after601s, building through552 before reaching its first
query. Both actual prepared-model audits pass with byte-identical original
models, eight premises and ten unknown-initialized memories. Neither produces
a witness or counterexample; the useful formal cover is not yet accepted.

All new evidence is sealed, about39MiB without compiler caches. Owned tool
resources are cleared and the dedicated VM is stopped. Next candidate is a
separately qualified memory-mapped SMT encoding; no memory-saving or semantic
claim has been established for it. Full fetched safety, fairness8×8 and the
remaining matrix/aggregate remain open. Phase6 is still in progress.

## Fetched Store SMT representation checkpoint — 2026-10-14

The [lower-memory encoding ledger](evidence/phase6-fetched-nomem-20261014.md)
qualifies exact memory mapping, one generated decoder fold and packed-state
serialization without changing the fetched DUT, address guards or initialization.
All 640 physical memory bits retain unconstrained initial values. All 264 original
initialization clauses, eight premises and the original sampled cover remain
intact; the packed model preserves all 10,009 functional definitions and maps
566 storage declarations to disjoint width-correct fields.

The original mapped SBY task hits an SMT exporter internal error before solver
execution. Folding just the new empty-address decoder permits export; its
standalone unrolled cover times out at state824 before query839. Packed state
builds the full initialized prefix in 4s and queries839, but Bitwuzla is then
killed for global OOM at about 7.44GiB RSS after about 411s. Child exit1 is an
engine error, not a safety failure or unreachability result. No witness exists.

Four focused runner tests and three audit parser tests pass. Eight stepwise
commits record the plan, methods, qualifications and outcomes. All new evidence
is sealed, about 81MiB without caches; owned resources are cleared and the
QEMU-only VM is stopped. Hardware, API and user codec are unchanged. Next is
field-split SMT with only existing public input literals, retaining complete
initialization and address semantics under the 8GiB limit. It is a proposal,
not an implemented or accepted result. Phase6 remains in progress.

## Fetched Store field split and recurrence checkpoint — 2026-10-14

The [encoding ledger](evidence/phase6-fetched-nomem-20261014.md) now records
implemented, independently qualified field-split and recurrence formulations
for the original first late query839. Both retain840 full initialized states,
839 transitions, original model/initialization/address/hierarchy equations,
eight host premises and unchanged useful cover. Only the existing twelve
public inputs at0..837 are guided; the tail remains free.

The field split reconstructs all9716 bits from565 complete disjoint typed
leaves. Recurrence derives461 next fields from their exact original update
expressions and retains every original transition assertion. It removes386779
fresh declarations, leaving77765, without a state cut or private native pins.
Every original state0 declaration,18 unknown memory words640bits and11
undefined slices166bits remains unchanged.

Actual pinned QEMU-only8GiB runs both end with fresh kernel-confirmed solver
OOM, child137 and no host timeout: field split about322s/7.47GiB anonymous RSS,
recurrence about451s/7.48GiB. No SAT/UNSAT, certificate or cover acceptance
returns. Recurrence reaches the check839 marker in7.331s, but variable-count
reduction and query-entry timing are not solve-time or peak-memory benefits.

Six focused compiler/runner tests and three independent parser tests pass;
formatting, interface generation and diff checks pass. Three agents and seven
stepwise commits record this continuation. The two archives are sealed,
about115MiB without caches; owned resources are cleared and the dedicated VM
is stopped. Hardware, public APIs, accepted Store/packet gates and user codec
are unchanged.

The next proposed formulation derives44 DUT inputs through exact hierarchy
aliases and263 initialized state0 fields from original constants. It retains
all264 initialization clauses and avoids same-step alias cycles. This is
reviewed as feasible, not implemented or engine-qualified. Useful formal cover,
full fetched safety, fairness8×8 and remaining matrix/aggregate stay open.
Phase6 remains in progress.

## Fetched Store original-equation aliases and initialization — 2026-10-14

The [alias/initialization ledger](evidence/phase6-fetched-alias-init-20261014.md)
records implementation and independent qualification of44 child input aliases
and263 specified initial constants derived solely from the original equations.
It replaces36960 input declarations and263 state0 declarations, leaving40542
fresh fields. All840 initialized-prefix states,839 transitions,264 original
initialization clauses and original cover839 remain. Unknown memory640bits,
undefined slices166bits, invalid-read anyseq and old held-read samples352bits
remain free where originally unspecified; address semantics are unchanged.

The pinned QEMU-only8GiB run reaches query839 in6.819s, then hits the unchanged
600-second host deadline without SAT/UNSAT or state values. Docker reports
`OOMKilled=false`; exit137 follows the explicit timeout stop, not a solver
OOM. The1.013GiB early sample is not a peak-memory measurement. No witness,
useful-cover pass, safety result or SBY/typed receipt is accepted.

Four compiler tests and two independent audit tests pass; native checking,
formatting and interface generation pass. Three agents separate implementation,
equation audit and outcome review. The dedicated VM is stopped; hardware,
public APIs, user codec and accepted Store/packet gates are unchanged.
Four stepwise commits record this continuation; the independently reviewed
132-file archive is sealed, about66MiB without native compiled caches; six small
formatting metadata entries32KiB are retained and disclosed in the ledger.

Next candidate is exact elimination of30 output shadows via original hierarchy
equations and a separately constructed full child state. No native output pins,
state cut or resource increase follows. Useful cover, full fetched safety,
fairness8×8 and the remaining matrix/aggregate remain open. Phase6 is in progress.

## Fetched Store exact output shadows and partial SAT certificate — 2026-10-14

The [output-shadow ledger](evidence/phase6-fetched-output-shadow-20261014.md)
implements and independently qualifies30 original output mappings over840
complete acyclic7857-bit child recompositions. All25200 replaced shadows are
exact original calls;15342 fields remain fresh. Unknown memory, held reads,
undefined slices, invalid-read sources and address/read/write equations remain
unchanged, as do the full initialized prefix, original premises and cover839.

The actual pinned QEMU-only8GiB run returns SAT after467.461 seconds, then
times out at the600-second deadline while emitting state values. Only79 complete
states0..78 are retained, with no final cover response. Docker exit137 follows
explicit timeout stop; `OOMKilled=false` and kernel snapshots show no OOM event.
SAT is retained honestly, but no complete witness, ground/causal validation,
useful-cover pass or original typed receipt is accepted.

Nine targeted native deny-warning tests pass across compiler, equation audit,
certificate preparation/refusal and outcome classification. Three agents and
stepwise commits separate implementation, qualification and actual outcome.
The dedicated VM is stopped; public APIs, hardware, user codec and accepted
Store/packet gates are unchanged. Full fetched safety, explicit-fairness8×8 and
remaining matrix/aggregate still require their own gates.

Next is separately qualified certificate-request batching, preserving the same
841 terms and all search constraints. No missing state may be filled from native
outputs or a zero-memory assumption. Phase6 remains in progress.
The157-file evidence archive is sealed, about79MiB without caches, with its
inventory and predecessor verified. Four stepwise commits record this slice;
small unsealed formatting metadata was moved recoverably to the shared build
area before sealing, with exact paths retained in the ledger.

## Fetched Store batched certificate requests — 2026-10-15

The [batch-certificate ledger](evidence/phase6-fetched-batch-certificate-20261015.md)
records one request containing the same841 original terms. A separate mechanical
audit verifies every search byte through `check-sat`, original exit suffix,
all13417 assertions,15342 fresh fields and original model/layout/guidance bytes.
Unknown memory, address slices, held reads, invalid-read sources, bounds and
read/write semantics are unchanged. Three parser/batching tests and one outcome
rejection test pass natively; a pinned two-state format probe also passes.

The actual QEMU-only8GiB run returns SAT after410.840 seconds but reaches the
600-second deadline during extraction:77 complete states0..76, a state77 fragment,
no closed batch and no cover response. Explicit stop produces runtime137 without
Docker/kernel OOM. The extractor refuses the partial certificate; no ground or
causal validation, accepted cover or original typed receipt is claimed. Actual
source freeze and owned cleanup verify; the dedicated VM is stopped.

Next candidate is one lossless packed expression for all840states and original
cover bit, with unchanged search bytes and independently checked boundaries.
Current batching remains implemented but did not meet the extraction budget.
The157-file archive is sealed, about79MiB without caches; both its inventory and
predecessor verify. Four stepwise commits record this continuation.
Hardware, public APIs, user codec and prior Store/packet proofs are unchanged;
full fetched safety, explicit-fairness8×8 and matrix/aggregate remain open.
Phase6 remains in progress.

## Fetched Store single-expression certificate — 2026-10-15

The [packed-certificate ledger](evidence/phase6-fetched-packed-certificate-20261015.md)
qualifies one lossless8161441-bit expression containing840 complete states and
the original cover bit. Independent grammar/interval checking verifies all
boundaries and every search byte through `check-sat` unchanged. Unknown memory,
held reads, anyseq and full-width address semantics remain intact. Three focused
native tests and targeted checks pass; pinned tiny and full-width synthetic
probes pass, including actual strict decoding and every-bit reconstruction.

The actual fetched job reaches600seconds without SAT/UNSAT or certificate data.
Explicit stop produces runtime137 with no observed Docker/kernel OOM. The runner
also rejects its full-checkout freeze: HEAD is unchanged, but ten unrelated
untracked PRX100 files appear during execution. All seven actual solver input
hashes independently reverify unchanged; no freeze waiver or accepted run is
claimed. Retrieval performance remains unmeasured because search never returns.

Our owned resources are removed and the VM is stopped, then restarted by another
job; read-only handover records confirm a foreign runtime and our resources
absent. That job is left untouched. The222-file archive is sealed, about94MiB
without caches; its inventory and predecessor are reverified. Four stepwise
commits retain plan, implementation, qualification and actual outcome. Useful
fetched cover, full fetched safety, explicit-fairness8×8 and matrix/aggregate
remain open. Prior accepted Store/packet scopes, hardware, public APIs and the
user codec remain unchanged; Phase6 is still in progress.

## Claim boundary

Completed-phase evidence supports “canonical LunaChip IR,” “the named combinational
and single-clock sequential subset executes deterministically in LunaWave,”
“the named memory subset is differentially validated against emitted
conservative SystemVerilog,” “the nine named RTL forms synthesize through the
pinned generic Yosys flow,” and “the named formal properties produced their
recorded bounded, witness, counterexample, or selected unbounded results.” It
does not support synthesis equivalence, FPGA execution, physical RAM mapping,
timing closure, GDS, fabrication, or silicon performance.
