# Phase 5 asynchronous FIFO implementation readiness

This note turns the accepted asynchronous-FIFO contract in
`PHASE5_CONTRACT.md` and `PHASE5_CDC_PRIMITIVES.md` into an implementation
sequence. It does not change that contract and it does not claim analog CDC
safety, MTBF, placement, routing, physical RAM inference, timing closure, or
unconditional delivery.

## Decision summary

The FIFO is one first-class `CdcPrimitive` with primitive-private storage. It
is not a two-clock mode of `MemorySpec`: generic LunaChip memory remains
single-domain. Binary pointers, Gray conversions, synchronized Gray-pointer
pipelines, full/empty state, ready/valid controls, and output masking remain
ordinary canonical nodes. The only new node cut-point is a primitive-owned
storage read, because no existing node can name private storage without
misrepresenting it as a generic synchronous memory.

This split keeps one source of behavioral truth:

- ordinary operations and registers continue to use the shared IR, LunaWave,
  and SystemVerilog semantics;
- the FIFO primitive owns only its storage array, its source-edge write, and
  the authorization for the two Gray-pointer crossings;
- the canonical CDC pass remains the only authority that changes provenance;
- the simulator and emitter consume the already-validated primitive record and
  do not rediscover or regenerate pointer logic.

## Initial semantic profile

The first profile is intentionally narrow and versionable:

- distinct rising-edge source and destination domains;
- power-of-two depth from 4 through 1,048,576;
- two through four pointer-synchronizer stages in each direction;
- aggregate ready/valid payload with a total flattened width from 1 through 64
  bits; every leaf remains an existing ground data type;
- active-high synchronous source and destination resets, both with reset value
  zero and the explicit `coordinated_idle` reset policy;
- first-word-fall-through destination data, masked to the exact zero value of
  every payload leaf whenever destination valid is known zero;
- uninitialized private storage; storage is architecturally observable only
  while destination valid is known one;
- no externally supplied initial pointer, flag, synchronizer, or storage
  state.

The depth ceiling matches the existing reference-simulator per-state-object
ceiling. Preparation must also enforce one combined allocation budget across
generic memory cells and FIFO lane cells. The aggregate width ceiling is the
current `LogicValue` limit, not a permanent hardware-language limit.

`coordinated_idle` means both sides are idle, both resets are asserted, and
each domain observes at least one active edge before either side resumes
traffic. A unilateral or mid-flight reset still has deterministic digital
state transitions, but delivery across that boundary is explicitly flushed or
lost and must never be reported as lossless. A later independent-reset or
flush protocol needs a new reset-policy spelling and its own evidence.

## Public LunaWire surface

Reuse the existing directional ready/valid handles instead of adding a second
interface convention. The additive API should have this shape:

```text
pub struct AsyncFifo
pub fn AsyncFifo::source(Self) -> ReadyValidBackward
pub fn AsyncFifo::destination(Self) -> ReadyValidForward

pub fn ModuleBuilder::asynchronous_fifo(
  Self,
  name : String,
  source_domain : ClockDomain,
  destination_domain : ClockDomain,
  source : ReadyValidForward,
  destination : ReadyValidBackward,
  source_reset : SynchronousReset,
  destination_reset : SynchronousReset,
  depth : Int,
  synchronizer_stages? : Int = 2,
) -> AsyncFifo raise
```

The builder checks ownership before appending a node. It rejects equal domains,
non-power-of-two or out-of-range depth, stage counts outside two through four,
empty/non-data/over-wide payloads, nonzero reset values, non-synchronous or
non-active-high resets, and reset timing that does not match the side using it.
It records `depth`, `synchronizer_stages`, and total payload width as canonical
parameters only if that is already the generator's chosen public metadata;
the primitive record itself remains authoritative.

Supporting aggregate lanes directly avoids a temporary one-leaf API and avoids
packing away field paths. Storage uses one private lane per flattened payload
leaf. All lanes share one address and write enable and therefore form one FIFO
item. The canonical primitive stores the recursive shape plus source/raw-read/
visible node identities in flatten order.

The returned source `ready` is produced in the source domain. The returned
destination `valid` and every destination payload leaf are produced in the
destination domain. Callers may bind them to scalar or aggregate outputs using
the existing APIs.

## Canonical structure

For depth `2^A`, pointer width is `P = A + 1`. Each side contains:

- a `P`-bit binary pointer register;
- its `P`-bit binary next value;
- a `P`-bit Gray pointer register;
- its exact Gray next value, `binary_next xor (binary_next >> 1)`;
- a two-through-four-stage `P`-bit destination-domain register pipeline that
  samples only the remote Gray pointer;
- one local registered status flag.

The source transfer control is the ordinary bitwise conjunction of source
valid and source ready. Source ready is `not full`. The binary write pointer
increments modulo `2^P` on a possible transfer and otherwise holds. Full-next
is the equality of write-Gray-next with the synchronized read Gray pointer
whose top two bits are inverted. Depth is at least four, so this expression
always has a nonempty lower slice.

The destination transfer control is destination valid and destination ready.
Destination valid is a registered `nonempty` flag. The binary read pointer
increments on a possible transfer and otherwise holds. Nonempty-next is the
inverse equality of read-Gray-next and the synchronized write Gray pointer.
Using `nonempty` rather than an `empty` bit lets every internal register use
the same zero-valued reset contract.

An unknown ready or valid never counts as a known transfer observation. The
ordinary four-state mux graph still conservatively merges hold and advance
possibilities, so unknown control can make pointer and flag state unknown. A
private-storage write occurs only when the source transfer control is known
one and its address is fully known. This matches a synthesizable procedural
`if (enqueue)` and does not invent a known transfer.

Private storage has one source-domain write and combinational read at the
current destination address. Each visible destination payload leaf is
`mux(destination_valid, raw_storage_read, zero)`. Thus invalid payload is
deterministic, payload is stable while valid is one under backpressure, and a
Verilator comparison never depends on an arbitrary uninitialized cell.

At a coincident source/destination timestamp, every register candidate and the
source storage write are computed from the shared pre-commit state. Registers
and storage commit once, then the raw and visible reads settle. A consumed item
is the pre-edge valid/payload pair; post-event outputs may already present the
next item.

## Canonical primitive record

Add `AsyncFifoPrimitive` as a variant of the existing schema-4
`CdcPrimitive` table. Its checked value names at least:

- primitive ID and name;
- source and destination domains;
- depth, pointer width, pointer synchronizer stage count, and reset policy;
- exact source and destination reset specs;
- source valid, source ready, source transfer, and source payload leaves;
- destination ready, destination valid, destination transfer, raw storage-read
  leaves, and visible destination payload leaves;
- write/read binary current and next nodes;
- write/read Gray current and next nodes;
- ordered read-Gray-in-source and write-Gray-in-destination synchronizer stages;
- current and next full/nonempty flags;
- exact write and read address nodes.

Use the primitive ID as the private-storage identity. A second storage-ID table
would add a namespace with no independent lifecycle. The new cut-point can be
`NodeKind::AsyncFifoRead(primitive, leaf)`. It is validated after the metadata
table exists, is a combinational-cycle cut-point like `MemoryRead`, and forces
schema 4. It must not be constructible through a generic public wire method.

The codec extends the existing `PRIMITIVES` discriminated table in place, as
the Phase 5 contract requires. It records every list length and ordinal,
payload shape, node identity, reset policy, and exact reset fields. Old
schema-1/2/3 goldens and schema-4 artifacts with zero or bit-synchronizer-only
primitive tables remain byte-identical. Unknown primitive tags, fields,
policies, reordered ordinals, extra tokens, and truncated records fail closed.

## Structural validation invariants

The IR validator proves all of the following before CDC admission:

1. Primitive IDs and names are canonical and unique; every exclusive state or
   storage-read node belongs to exactly one primitive role.
2. Both domains exist and differ. Every ordinary register has the exact side's
   domain, type, reset, and no unrecorded enable.
3. Depth is a supported power of two, pointer width is exactly
   `log2(depth) + 1`, and address nodes are exact `UInt(log2(depth))` slices of
   the corresponding binary pointer.
4. Binary-next, Gray-next, full-next, and nonempty-next have the exact operation
   topology described above. No implicit cast, truncation, alternative compare,
   or inferred arithmetic is accepted.
5. Both pointer pipelines have the declared count. Stage zero samples only the
   remote Gray pointer; later stages sample only their predecessor; every stage
   has exact local-domain reset and no enable.
6. Intermediate synchronizer stages feed only the next stage. The final stage
   feeds only the owning flag computation. Raw storage-read nodes feed only
   their visible valid-masking mux. Internal pointers, flags, addresses, and
   transfer nodes have only their enumerated owning consumers.
7. Payload shape is nonempty and homogeneous where `Vec` requires it; flattened
   source, raw-read, and visible lists have equal cardinality, exact leaf types,
   exact ordinals, and total width within the declared limit.
8. Each raw-read node is `AsyncFifoRead(this primitive, this leaf)`. Each visible
   leaf is the exact destination-valid/zero mask. The source payload has no
   storage bypass into the destination graph.
9. Source payload and controls have only neutral/source provenance; destination
   ready has only neutral/destination provenance. Resets have exact side-local
   provenance. Outputs declare the matching produced domain.
10. No generic memory port, ordinary register, property, output, or other CDC
    primitive consumes a private crossing role. No free-form subgraph can claim
    the FIFO exemption.

Source payload may still fan out to source-domain logic; destination visible
payload may fan out to destination-domain logic. The forbidden fanout is the
private cross-domain path, not legitimate local reuse.

## CDC provenance changes

Extend provenance with an `AsyncFifoReadState` origin carrying primitive, leaf,
and destination domain. During analysis, a validated raw storage read acquires
the destination domain. The visible mask and downstream nodes then propagate
normally.

The CDC pass receives exactly three primitive-specific exemptions:

- the first read-Gray synchronizer stage may sample the write Gray register;
- the first write-Gray synchronizer stage may sample the read Gray register;
- the private storage write may consume the source payload and source transfer.

Every exemption first checks the primitive's declared role and the exact actual
provenance. No per-bit pointer synchronizer is admitted and reconvergence of
ordinary bit synchronizers remains illegal. Add typed sink roles for FIFO
payload write, pointer stage zero, and private read so diagnostics retain the
primitive ID, side, leaf or stage, domains, and the minimal witness.

`ModuleBuilder::finish`, `Simulator::prepare`, replay, SystemVerilog emission,
and formal integration continue to call the same public CDC validator.

## LunaWave execution and snapshots

Preparation builds an indexed descriptor for each FIFO and an indexed binding
for each raw-read node; settlement must not scan every primitive per node. It
allocates one unknown-initialized cell array per payload lane and enforces the
combined generic-memory/FIFO resource budget before allocation.

On an active source edge, LunaWave stages at most one whole-item write from the
pre-state address and source leaves. It stages a write only for known-one
transfer and a fully known in-range address. Canonical pointer structure makes
out-of-range known addresses impossible; a violation is an internal invariant
error with replay data, not silent modulo repair. The destination side has no
storage mutation.

FIFO writes join register and generic-memory changes in the existing atomic
timestamp transaction. Rollback retains one undo entry per written FIFO lane;
it never copies an entire FIFO. `SimulatorSnapshot` includes every private
lane, and restore checks the exact canonical module as it does today.

Direct debugger inspection, if exposed at all, is read-only and names the FIFO,
leaf path, and element index. There is no public mutation or unchecked prepare
path.

Targeted simulator tests cover:

- reset, empty, first enqueue visibility, last dequeue, and invalid-data zero;
- every wrap boundary for depth 4 and depth 8;
- full assertion and conservative deassertion after the synchronized read
  pointer arrives;
- empty assertion and conservative deassertion after the synchronized write
  pointer arrives;
- simultaneous source/destination edges and edge-list permutation;
- long one-sided clock gaps, sustained backpressure, and continuous traffic;
- unknown source valid, destination ready, and reset controls;
- storage/address corruption through package-private negative fixtures;
- snapshot/restore and replay digest identity across wrapped pointers.

## SystemVerilog emission

Emit one unpacked logic array per payload leaf, with deterministic identifiers
derived from primitive and leaf ordinals. Emit exactly one source-clocked write
process guarded by the recorded transfer and one continuous raw read per leaf.
All pointer, Gray, flag, synchronizer, and visible payload logic is already
emitted from ordinary nodes. No backend may regenerate those equations from
depth or infer a different latency.

The source map/name manifest gains explicit FIFO-storage-lane identities. The
backend reachability roots include every FIFO write dependency and private read
even when no generic memory exists. The emitter still rejects explicit register
initials and runs canonical CDC admission first.

SystemVerilog tests assert exact declaration, address, write guard, read, and
visible-mask text; sparse domain IDs; deterministic names; and rejection of a
tampered primitive. The format version changes only for modules containing an
asynchronous FIFO. There is no block-RAM or technology-mapping claim.

## Independent differential evidence

Create an isolated `validation/phase5_fifo` package and fixture command rather
than adding FIFO branches to `validation/phase5_sync`. Reuse the atomic
Verilator-v2 event table and locked runner boundary unchanged.

Minimum positive fixtures are:

1. depth 4, 8-bit scalar payload, two-stage pointers, coprime clocks;
2. depth 8, aggregate payload totaling 64 bits, three-stage pointers,
   non-coprime clocks and deliberate coincidences;
3. depth 4, four-stage pointers, zero/offset phases, long asymmetric gaps,
   full backpressure, wraparound, and simultaneous enqueue/dequeue.

The generator derives both LunaWave expected output rows and a watched-token
ledger directly from one normalized event table. The ledger samples transfer
valid/ready/payload before active edges; ordinary output comparison samples
after the atomic event. Require every fixture to hit reset release, empty and
full transitions, at least two wraps on each pointer, enqueue-only,
dequeue-only, simultaneous transfer, coincidence, and backpressure coverage.

External stimulus remains two-state. X-focused semantics stay in native tests.
The visible invalid-payload zero rule keeps all compared public outputs defined.
Include one frozen sequential-edge negative oracle whose first mismatch identity
is exact, proving that coincident edges were not raised and evaluated one at a
time.

The gate snapshots start/end HEAD and all inputs, checks exact bundle/result
digests, reuses the pinned Verilator lock without fallback, and records every
command and artifact. Container unavailability is a fail-closed incomplete
result, never a host-tool substitution.

## Synthesis evidence

Extend the phase-neutral synthesis bundle registry with FIFO-specific expected
shape JSON and a separate checker/gate. The pre-map RTLIL checker proves:

- exact binary/Gray/flag register counts, widths, domains, and resets;
- exact two-through-four-stage pointer pipelines with no bypass or extra state;
- one source-clock write path per lane and no destination write path;
- exact write/read address widths and payload lane widths;
- no direct source payload path to a destination output;
- no missing, duplicate, or extra primitive-owned state.

Provide negative RTLIL fixtures for wrong clock, missing stage, synchronizer
bypass, binary rather than Gray crossing, wrong pointer width, reversed full
compare bit, payload bypass, second writer, and extra private state. Run the
same digest-pinned Yosys image and network-disabled boundary. Passing proves
the named structural pre-map shape only, not CDC analog safety, RAM inference,
technology mapping, placement, routing, or timing.

## Formal evidence

Register FIFO bundles through the phase-neutral formal artifact registry; do
not add fixture-family conditionals to the locked runner. Use a small depth-4,
8-bit, two-stage instance and the existing explicit global formal timestep,
legal clock-transition, bounded-gap fairness, and atomic-coincidence model.

Named assertions cover:

- source and destination transfer guards;
- binary pointer hold/increment rules;
- Gray pointer hold/one-bit-transition rules;
- both synchronized-pointer pipelines;
- exact full and nonempty equations;
- write and read addresses within bounds;
- no write while full and no consume while empty;
- destination payload stability under valid/backpressure;
- watched-token ordering and data integrity.

Delivery or convergence claims are conditional on the source protocol,
coordinated-idle reset, bounded clock gaps, and eventual destination ready.
Keep data ordering bounded unless an independently reviewed induction succeeds.
Cover coincidence, full, wrap, simultaneous transfer, and watched-token
consumption.

Each deliberately broken bundle changes one behavior and expects one exact
stable label. At minimum retain separate counterexamples for broken Gray
conversion, broken full detection, broken address selection, and reordered
storage data. Wrong label, missing counterexample/witness, inconclusive,
timeout, unsupported, or tool error is non-pass.

## Commit sequence and file ownership

The handshake slice currently touches the same primitive enum and error files.
Finish and commit it before starting FIFO core edits. Do not develop handshake
and FIFO IR in parallel in one worktree.

Use these reviewable commits:

1. **Canonical contract.** Add primitive/reset-policy/payload-lane types,
   storage-read node kind, validation errors, checked topology, and exhaustive
   IR negative tests. Primary files: `ir/cdc_primitive.mbt`, a cohesive
   `ir/async_fifo.mbt`, `ir/cdc_validation.mbt`, `ir/types.mbt`,
   `ir/module.mbt`, cycle/dependency tests, diagnostics adapter, and generated
   interfaces.
2. **Schema-4 codec.** Extend metadata/node encoding and decoding, format docs,
   malformed fixtures, and byte-compatibility goldens. Primary files:
   `ir/codec/{encode_metadata,decode_metadata,encode,decode,FORMAT}.mbt*` and a
   focused `async_fifo_codec_test.mbt`.
3. **LunaWire construction.** Add `AsyncFifo`, builder-owned private
   declarations, exact ordinary node graph, ownership failures, aggregate
   paths, and public black-box tests. Primary files: `wire/types.mbt`,
   `wire/builder.mbt`, new `wire/async_fifo.mbt`, tests, and interfaces.
4. **CDC admission.** Add primitive roles, provenance origin, exact exemptions,
   output-domain behavior, fanout negatives, and admission tests. Primary files:
   `passes/cdc/{types,provenance,validate}.mbt` and focused tests. Rerun all
   simulator/emitter/replay/formal sink boundary tests in this commit.
5. **Reference execution.** Add prepared descriptors, private storage, atomic
   staging/commit/undo, settlement, snapshots, and exhaustive native behavior
   tests. Primary files: `wave/sim/{types,simulator}.mbt`, a cohesive
   `wave/sim/async_fifo.mbt`, replay/snapshot tests, and interfaces.
6. **SystemVerilog.** Add private lane declarations/write/read emission,
   reachability/name mappings, exact text tests, and format documentation.
   Primary files: `emit/systemverilog/{emit,capabilities,names,types}.mbt`, a
   cohesive `async_fifo.mbt`, tests, and interfaces.
7. **Differential fixtures and gate.** Own only new
   `validation/phase5_fifo`, `cmd/phase5-fifo-fixtures`, and FIFO gate scripts;
   reuse Verilator lock/runner files unchanged.
8. **Synthesis fixtures and gate.** Extend the phase-neutral synthesis registry
   and add FIFO shape schema/checker/negative fixtures/gate. Keep the locked
   Yosys runner generic.
9. **Formal fixtures and gate.** Extend the phase-neutral formal registry and
   add FIFO bundles, properties, negatives, and gate. Keep the locked runner
   generic.
10. **Documentation/status.** Update the Phase 5 contract ledger only with
    evidence actually produced. The aggregate unchanged-snapshot Phase 5 gate
    remains a later commit after handshake and FIFO gates both pass.

Core commits 1 through 6 are sequential because their exhaustive enum matches
and generated interfaces overlap. After commit 6 freezes the artifact
contract, differential, synthesis, and formal fixture work can proceed in
parallel in isolated packages. The root integrator reviews, runs targeted
tests, commits each slice, and promotes it before the next shared-core slice.

## Validation cadence

For each core commit run `moon info`, `moon fmt`, targeted native checks/tests,
and `scripts/check-boundaries.sh`. Review every generated interface change.
After commits 1 through 6 run the full warning-strict native phase gate.

Before any schema or operational-sink commit is accepted, additionally prove:

- all older codec golden bytes are unchanged;
- decoding does not authorize execution;
- every public operational sink rejects a tampered FIFO through the same CDC
  error identity;
- event-order permutation, snapshot/restore, replay, emission, and formal
  integration agree on the same canonical primitive;
- no repository boundary imports LunaFlux, LunaNexa, or another MoonSuite
  product.

Pinned Verilator, Yosys, and formal gates run only after their native bundle and
boundary self-tests pass. Their evidence may be promoted only when all three
execute successfully against one unchanged repository snapshot.
