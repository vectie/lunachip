# Phase 5 language, event, and CDC contract

This contract fixes the semantic boundary for Phase 5 before implementation.
It extends the Phase 4 single-clock ground-value model without changing the
meaning, accepted source bytes, or migration behavior of any valid schema-1,
schema-2, or schema-3 artifact. The new claim is a deterministic multi-clock
*digital* model with explicit crossing primitives. It is not an analog
metastability, MTBF, placement, timing-closure, or physical-memory claim.

## Compatibility and schema selection

Canonical IR schema 4 owns explicit domain identity, port timing, reset mode
and polarity, elaboration parameters, aggregate reconstruction metadata, and
first-class CDC primitive declarations. The in-memory representation may
migrate an older artifact into these explicit forms, but public canonical
emission preserves the existing writer policy and selects the lowest current
writable schema that can represent the design:

- schema 1 remains a strict read-only compatibility format whose source is
  checked with the schema-1 canonical writer before the parsed design upgrades
  through the existing schema-2 public writer;
- a newly built design needing at most single-domain synchronous registers
  emits the same schema-2 bytes as before;
- a newly built schema-3 memory artifact, or reset-to-data conversion, remains
  byte-identical schema 3;
- schema 4 is required by multiple distinct domains, asynchronous reset,
  explicit port timing, parameters, aggregate bindings, or CDC primitives.

Every older parser path first proves that the source is canonical under its
declared older schema. Schema-2 and schema-3 could already encode multiple
clocks by repeating clock node references, so those previously canonical
artifacts remain accepted; the in-memory migration derives their domain table
and ordinary public serialization upgrades them to schema 4. A feature that
the declared older schema could not encode is rejected rather than silently
normalized. Schema-4 arrays use canonical order, reject unknown fields, and
participate in the canonical design digest. Node, memory, port, binding, and
primitive IDs use their declared sequential namespaces. During the rising-
edge-only foundation, a domain ID is its clock node ordinal and may therefore
be sparse; this makes independently constructed and migrated domain keys
converge without declaration-order dependence.

## Aggregates and parameterized generators

MoonBit functions are LunaWire parameterized generators. LunaChip does not add
a closure registry, runtime elaboration VM, global generator cache, or second
module system. A generator records its checked, typed parameter values as
canonical elaboration metadata. Parameters never become runtime hardware
nodes unless the generator explicitly builds such nodes.

The public foundational `aggregate` package owns immutable generic `Vec[T]`,
`Bundle[T]`, and recursive `Aggregate[T]` values. It imports no LunaChip
package. A vector has positive length. A bundle has positive length, nonempty
unique UTF-8 field names, and declaration order is semantic. Nested aggregate
flattening is deterministic depth-first traversal: bundle declaration order,
then increasing vector index. Reconstruction requires the exact template and
exact leaf count and preserves every field name, index, and leaf value.

Aggregates are LunaWire/API structure, not new ground RTL types. Each aggregate
leaf lowers to an existing `Clock`, `Reset`, `Bits`, `UInt`, or `SInt` value.
Lowered names use one injective, versioned UTF-8 encoding of the root and every
field/index segment; they never rely on an ambiguous separator convention or
hash-map iteration. Aggregate bindings in canonical IR retain:

- a stable binding kind and root;
- the recursive shape and leaf signal types;
- exact ground node/output endpoints in flatten order;
- typed field/index paths used for source maps and reconstruction.

Validation proves a one-to-one leaf/endpoint mapping, exact endpoint type,
role legality, unique roots, and no duplicate endpoint ownership. Backends and
LunaWave continue to consume only the ground leaves. Debug reconstruction uses
the canonical binding and never guesses structure from emitted names.

## Ready/valid

`ReadyValid[T]` remains an interface convention. Its ready and valid controls
are exact one-bit ground signals and its payload may be an aggregate. A
transfer occurs on an active destination edge only when ready and valid are
known one. Unknown is not a transfer. While valid is known one and no transfer
occurs, valid and the complete payload must remain stable.

Ready/valid combinators elaborate ordinary LunaWire nodes. A one-entry elastic
buffer is the first reusable aggregate component. Protocol checkers are named
properties; they are not hidden simulator behavior. Reset, backpressure,
empty-to-full, full-to-empty, simultaneous refill, payload stability, and
unknown controls receive direct reference and differential tests.

## Explicit clock domains and port timing

A module owns an ordered table of distinct rising-edge clock domains. A stable
domain ID is assigned by canonical semantic key `(clock node ordinal, edge
tag)`, not by the order in which a generator happened to request a domain.
Repeated requests for the same key intern one domain. Phase 5 supports rising
edges only; representing a domain table does not imply falling-edge, gated-
clock, or generated-clock support.

Registers, synchronous memories, properties, timed ports, and CDC primitives
reference a domain ID. A schema-4 multi-clock module classifies each data input
as asynchronous or sampled in one exact domain and classifies timed outputs by
their producing domain. Clock and Reset retain dedicated ground types. Legacy
single-domain inputs migrate to the sole domain only where the older contract
made that interpretation unambiguous. No multi-clock validator infers a data
port's timing from its consumers.

Generic synchronous memory remains single-domain. Phase 5 does not broaden it
into an arbitrary dual-clock memory. The asynchronous FIFO owns its dedicated
dual-domain storage contract.

## Timestamp events and coincident edges

Simulation time is an unsigned integer number of normalized design ticks. The
semantic action is one atomic timestamp event containing:

- one strictly monotonic timestamp;
- a canonical set of unique named input drives;
- a canonical set of unique active domain IDs.

There is at most one state-changing event at a timestamp. Schedulers merge
same-time drives and edges before execution. Empty state events are rejected;
trace-only markers remain separate metadata. Duplicate drives, duplicate
domains, unknown domains, time regression, and arithmetic overflow are typed
failures.

The exact micro-order at a timestamp is:

1. apply all external drives atomically in canonical input-name order;
2. settle combinational logic over old committed state;
3. evaluate every asynchronous reset and commit all selected reset effects
   simultaneously;
4. settle again if asynchronous state changed;
5. visit active domains in increasing domain ID for deterministic candidate
   and diagnostic order, while computing every candidate from the same
   post-asynchronous-reset, pre-clock state;
6. commit all selected-domain register, memory, and CDC updates once globally;
7. settle once, observe properties, and record one trace frame.

Cross-coupled state in coincident domains therefore observes only pre-commit
state. Reversing the caller's edge-list order cannot change the result. The
legacy `rising_edge(clock)` API is a one-domain convenience over one atomic
event; it is not used to model coincident edges. Runtime state records current
time, global event ordinal, and a separate edge count per domain. A single
global cycle count is not used as multi-clock time.

## Exact rational schedules

A clock schedule uses a positive reduced rational period and a non-negative
reduced rational phase (with zero canonically represented as `0/1`). The
scheduler computes a common integer tick lattice with checked gcd/lcm
arithmetic, checked `UInt64` bounds, and a declared event/resource limit. It
never uses floating-point time. Events at one normalized tick are coalesced
before simulation. Replay stores the normalized timebase and event batches, so
execution does not regenerate or reinterpret the schedule.

Randomized conformance uses seeded, reduced, co-prime and non-co-prime ratios,
varied phases, deliberate coincidences, and permutation metamorphic tests.

## Reset mode and polarity

Schema 4 represents reset mode (`Synchronous` or `Asynchronous`) and polarity
(`ActiveHigh` or `ActiveLow`) explicitly. Existing constructors mean
synchronous active-high. The complete additive vertical slice and its gate are
specified in [`PHASE5_ASYNC_RESET.md`](PHASE5_ASYNC_RESET.md).

An asynchronous reset is level-sensitive in the digital reference model.
Polarity is normalized before evaluation. Known asserted selects the reset
value; known deasserted retains state until an edge; unknown merges reset and
retained values bit by bit. At a coincident timestamp, asynchronous reset
assertion or deassertion is processed before clock sampling. At an active edge,
reset still has priority over enable and next state. All asynchronous reset
effects at one timestamp commit together.

This ordering says nothing about recovery/removal timing or physical reset
release. CDC components that accept asynchronous assertion use a checked
per-domain reset-release synchronizer. Raw asynchronous deassertion is never
treated as a safe ordinary state control.

## First-class CDC primitives

The reviewable vertical-slice design is specified in
[`PHASE5_CDC_PRIMITIVES.md`](PHASE5_CDC_PRIMITIVES.md).

CDC safety is explicit intent, not pattern recognition. An arbitrary two-flop
chain cannot declare itself safe, and a free-form annotation cannot suppress a
crossing diagnostic. Canonical IR owns checked primitive declarations and
typed primitive output roles. The emitted structural implementation remains
visible to synthesis and formal tools.

The Phase 5 primitives are:

1. **Bit synchronizer.** Exactly one bit, distinct source/destination domains,
   two through four destination stages, and an explicit destination reset
   contract. It does not accept a multi-bit bus or independently synchronized
   bits that later reconverge.
2. **Toggle handshake.** One item in flight with source ready/valid/payload and
   destination ready/valid/payload. Request and acknowledge cross through
   checked bit synchronizers. The source holds payload while outstanding; the
   destination captures only after synchronized request and holds under
   backpressure. Initial support requires coordinated idle reset. A unilateral
   mid-flight reset is a documented flush/loss event, never called lossless.
3. **Asynchronous FIFO.** Power-of-two depth of at least four, data width within
   the supported reference limit, binary plus Gray pointers, two through four
   pointer-synchronizer stages, explicit source/destination domains, and
   ready/valid endpoints. Its dual-clock storage is private to this primitive.
   The generic memory API remains single-domain.

LunaWave models deterministic digital sampling and latency only. It does not
invent analog metastable values or probabilistic resolution.

## Fail-closed CDC provenance lint

The public CDC pass propagates a provenance lattice through the canonical
graph: neutral constant, asynchronous external, one domain, or a mixed set of
domains. Combinational nodes union operand provenance. A state, memory,
property, or timed-output sink may consume only neutral values and its declared
domain. Any foreign, asynchronous, or mixed dependency is a typed error with
source domain, destination domain, sink role, and a stable minimal path.

Only exact primitive input roles may consume their declared foreign or
asynchronous sources. Primitive outputs acquire their declared destination
domain. Handshake payload and asynchronous-FIFO storage/pointer paths are
allowed only inside the owning checked primitive and must satisfy exact fanout,
role, type, and cardinality rules. Reset crossings and property observation
domains are checked separately.

The same canonical pass runs at public construction completion and every
operational admission point: LunaWave preparation, replay execution,
SystemVerilog emission, and formal integration. The canonical IR decoder is a
lossless structural and migration boundary, not an authorization to execute;
it preserves older canonical artifacts so they can be inspected and upgraded.
No public operation may simulate, emit, or prove a decoded design before the
canonical CDC pass accepts it. These sinks do not carry divergent copies of
CDC logic.

Required negative fixtures include raw register crossings, generic two-flop
chains, multi-bit synchronizers, per-bit reconvergence, mixed-domain muxes,
foreign enables/resets/memory controls, direct asynchronous inputs, wrong
property domains, duplicate domain aliases, illegal primitive roles, and
hidden payload fanout.

## Replay, trace, and VCD

Replay schema 2 stores a timebase and atomic timestamp events with sorted input
drives and domain IDs. Schema 1 remains strict and byte stable; migration maps
each old edge to a distinct timestamp and does not pretend the old artifact
represented coincidence. Stop conditions include time, boundary, per-domain
edge count, and output equality.

Trace schema 2 binds semantic version, canonical IR digest, timebase, and a
domain table. A frame stores actual time, boundary, event drive names, active
domain IDs, and changed values. Empty-change event frames remain meaningful.
VCD timestamps use normalized design time rather than frame index; comments
retain event boundary, drives, domains, and per-domain counts. Ground signal
IDs and source mappings remain stable when their semantic inputs are stable.

The Verilator harness performs coincident edges atomically: it applies all
drives, evaluates, raises every active clock in one update, evaluates once,
then samples. A fixture whose result changes under sequential clock raising is
mandatory, so the harness cannot accidentally validate the wrong ordering.

## Formal and synthesis claim boundary

The exact Phase 4 Yosys/SymbiYosys/Bitwuzla image remains the Phase 5 formal
tool boundary. Multiclock tasks declare their global formal timestep, legal
clock-transition assumptions, fairness assumptions, modes, bounds, and
selected properties in the task manifest.

Named formal claims are limited to:

- synchronizer pipeline/reset structure, destination-edge-only output change,
  and stable-input convergence in destination edges;
- handshake one-item capacity, stable outstanding payload, stable destination
  response under backpressure, no duplicate acknowledge/consume, and watched-
  transaction data integrity;
- asynchronous-FIFO local transfer guards, pointer-update rules, Gray
  transitions, synchronized-pointer pipelines, conservative full/empty logic,
  bounded addresses, and watched-token ordering/data integrity.

Any completion/delivery statement is bounded or conditional on explicit
bounded-clock-gap, eventual-ready, and source-protocol assumptions. No result
claims metastability probability, MTBF, placement, routing skew, arbitrary
near-edge capture latency, unconditional liveness, block-RAM inference, timing
closure, or hardware execution.

Each deliberately broken primitive has its own fixture, exact expected
property label, and retained counterexample. Inconclusive, timeout,
unsupported, tool-error, wrong-label, or missing-witness results are non-pass.

## Stepwise implementation and phase gate

Phase 5 is committed and validated in these reviewable steps:

1. freeze this domain/aggregate/CDC contract;
2. add the independent aggregate package and exhaustive flatten/reconstruct
   tests;
3. add schema-4 domains, resets, port timing, parameters, and aggregate
   metadata while preserving all older bytes;
4. add LunaWire aggregate/parameter/ready-valid APIs and reusable elastic
   buffering;
5. add atomic timestamp execution, exact rational schedules, replay schema 2,
   trace schema 2, and actual-time VCD;
6. enable asynchronous reset only after exhaustive event-order tests;
7. add the one-bit synchronizer and fail-closed provenance lint;
8. add the toggle handshake with differential and formal evidence;
9. add the asynchronous FIFO with wrap/full/empty, differential, synthesis,
   and formal evidence;
10. run one aggregate Phase 5 gate on one unchanged repository snapshot, then
    record the evidence and bounded claim language.

The aggregate Phase 5 gate passes only when:

- nested Unicode aggregate flatten/reconstruct round trips preserve exact
  names, types, values, and endpoint mappings;
- all schema-1/2/3 goldens remain byte identical and schema 4 rejects malformed
  domain, timing, reset, aggregate, parameter, and CDC records;
- exhaustive coincident-edge tests prove global pre-state sampling and caller-
  order independence;
- seeded randomized rational schedules replay with identical trace digests;
- no implicit crossing passes the canonical lint at any public sink;
- synchronizer, handshake, and asynchronous-FIFO LunaWave observations agree
  with the pinned emitted-RTL harness for their declared defined outputs;
- named synthesis and formal tasks produce only their exact required result
  classes, properties, counterexamples, and witnesses;
- the full warning-strict native gate and dependency boundaries pass; and
- start/end HEAD plus complete repository-input manifests are identical, with
  every child input, output, comparison, report, witness, and log content-
  digested.

Until that single gate passes, Phase 5 remains in progress and none of its CDC
or multi-clock claims are promoted to the product status ledger.
