# Phase 5 CDC primitive implementation design

This document refines the accepted Phase 5 contract into reviewable vertical
slices. It does not broaden LunaChip's physical claim: LunaWave models
deterministic digital sampling and latency, while metastability probability,
MTBF, placement, routing, and timing closure remain external implementation
concerns.

## Design rules

1. A primitive is checked canonical IR, not a comment, name pattern, or lint
   waiver.
2. The primitive record names every structural node that receives an
   exemption. The ordinary graph remains visible to simulation, emission,
   synthesis, and formal tooling.
3. The CDC pass is the only authority that changes provenance across a
   primitive boundary. Backends do not independently recognize structures.
4. Primitive IDs are sequential in declaration order. All referenced nodes,
   domains, endpoint roles, types, stage counts, and fanout constraints are
   validated before the record is admitted.
5. Schema 4's existing `PRIMITIVES` table is extended in place. Designs with
   no primitives retain their exact bytes, and schemas 1 through 3 remain
   byte-stable.
6. Each primitive lands as a complete IR-to-evidence vertical slice. A record
   is not public while any simulator, emitter, CDC, replay, or formal sink can
   misinterpret it.

## Bit synchronizer slice

The first primitive accepts one ground one-bit value and transfers it into one
distinct destination domain through two to four destination-domain register
stages.

Canonical metadata owns:

- primitive ID and stable debug name;
- source node and its declared source class (`Asynchronous` or one exact
  source domain);
- destination domain;
- ordered stage-register node IDs;
- exact destination reset contract; and
- the final stage as the sole typed synchronized output.

Validation requires every stage to be a one-bit register in the destination
domain with no enable. Stage zero samples only the declared source; every later
stage samples only its predecessor. All stages use the same supported reset
contract. Intermediate stages may feed only the next stage; the final stage is
the only primitive output. Source and destination domains must differ when the
source is timed. An ordinary two-flop chain without this exact checked record
remains an unsafe crossing.

The initial reset subset is active-high synchronous destination reset. Async
assert/synchronous release becomes a separate checked reset primitive only
after its event ordering and emitted structure have their own gate. There is no
implicit reset conversion.

LunaWave needs no special state machine: the registered structure already
provides deterministic destination-edge latency. The CDC pass exempts only the
declared first-stage input and assigns destination provenance only to the final
stage. SystemVerilog emits the ordinary register chain plus stable preservation
attributes only when the selected backend contract explicitly supports them;
attributes never substitute for structural validation.

Required tests include stage counts 2, 3, and 4; sparse domain IDs; coincident
source/destination edges; unknown source values; reset/enable/type/fanout
tampering; wrong or equal domains; per-bit reconvergence; generic two-flop
rejection; schema round trips and malformed records; simulation/RTL
differential latency; synthesis shape; and named formal properties.

## Toggle-handshake slice

The handshake is a one-item ready/valid channel, not independently
synchronized payload bits. Canonical metadata binds the source and destination
domains, request and acknowledgement synchronizers, held source payload,
destination capture, ready/valid controls, and every externally visible
endpoint.

The source accepts only when idle, then holds request state and the complete
payload until acknowledgement. The destination captures a payload only after
the synchronized request changes and holds its valid response and payload
under backpressure. A new source item cannot overwrite an outstanding item.

Initial support requires coordinated idle reset. Unilateral reset while an
item is outstanding is an explicit flush/loss outcome and cannot be reported
as lossless delivery. CDC validation permits the stable payload bus to cross
only inside its owning checked handshake and rejects hidden fanout.

Evidence covers one-item capacity, payload stability, simultaneous consume and
refill boundaries, unknown controls, reset at every idle phase, documented
mid-flight loss behavior, randomized rational clock ratios, an emitted-RTL
differential oracle, and bounded data-integrity/formal safety properties.

## Asynchronous-FIFO slice

The FIFO owns private dual-domain storage; LunaChip's generic memory remains
single-domain. Depth is a power of two of at least four. Data width and depth
are bounded by declared resource limits, and pointer synchronization uses two
to four stages.

Each side owns a binary pointer for addressing and a Gray-coded pointer for
crossing. Only synchronized Gray pointers enter the opposite domain. Full and
empty are conservative local decisions derived from synchronized remote
pointers. Storage writes occur only on a known source transfer, reads become
visible only under the declared destination contract, and ready/valid payload
stability is preserved under backpressure.

The primitive record binds both domains, both endpoint bundles, private
storage, binary/Gray pointer nodes, synchronizer chains, depth, width, and
reset policy. Validation checks cardinality, type, fanout, Gray-conversion
structure, pointer widths, address bounds, and ownership. No generic memory or
free-form node subgraph may claim the FIFO exemption.

Initial support again requires coordinated idle reset. Later independent reset
support needs a separately versioned flush protocol and cannot silently inherit
the initial claim.

Evidence covers every wrap boundary, full/empty transitions, simultaneous
enqueue/dequeue, long asymmetric clock gaps, coincidences, backpressure,
unknown controls, randomized clock ratios/phases, ordered watched-token data
integrity, emitted-RTL differential behavior, synthesis shape, and the exact
bounded/conditional formal claims in the Phase 5 contract.

## Admission and migration

The canonical IR decoder remains a lossless structural boundary so older
artifacts can be inspected and migrated. Construction completion and every
operational sink run the one CDC validator. Thus decoding success never means
that a design is safe to simulate, emit, or prove.

There is no public unchecked execution API. Private white-box tests may call a
kernel entry point only to test atomic event machinery with deliberately raw
cross-coupled state; that symbol is not exported by the package interface.

## Commit and gate order

1. primitive IR types, invariants, schema-4 codec, and negative fixtures;
2. LunaWire bit-synchronizer construction and CDC provenance roles;
3. simulator/RTL differential, synthesis, and named formal evidence for the
   bit synchronizer;
4. handshake IR, construction, execution, emission, and evidence;
5. asynchronous-FIFO IR, construction, execution, emission, and evidence;
6. one unchanged-snapshot Phase 5 aggregate gate.

Every numbered item is reviewed, warning-strict tested, and committed before
the next begins.

## Research anchors

- Clifford Cummings, [*Clock Domain Crossing (CDC) Design & Verification
  Techniques Using SystemVerilog*](https://www.paradigm-works.com/technical-library?term=clock+domain+crossing+(cdc)+design+%26+verification+techniques+using+systemverilog),
  SNUG Boston 2008. The design follows its separation between single-bit
  synchronization, closed-loop transfer, and FIFO-style multi-bit transfer,
  without claiming analog verification.
- CHIPS Alliance Rocket Chip
  [`AsyncQueue.scala`](https://github.com/chipsalliance/rocket-chip/blob/master/src/main/scala/util/AsyncQueue.scala).
  Its explicit per-domain source/sink structure, Gray indices, minimum
  synchronizer depth, and reset coordination reinforce keeping an asynchronous
  queue as a first-class component rather than a generic memory mode.
- CIRCT [`seq` dialect documentation](https://circt.llvm.org/docs/Dialects/Seq/)
  and
  [rationale](https://circt.llvm.org/docs/Dialects/Seq/RationaleSeq/). Its
  explicit clocked state operations reinforce retaining visible sequential
  structure instead of hiding behavior in backend annotations.

These sources inform the architecture; LunaChip's exact semantics and claim
boundary are defined by its own checked contracts and tests.
