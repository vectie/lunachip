# Toggle-handshake implementation and evidence design

This document fixes the concrete digital state machine and evidence boundary
for the Phase 5 toggle handshake. It refines, but does not broaden,
`PHASE5_CONTRACT.md` and `PHASE5_CDC_PRIMITIVES.md`. The handshake transfers a
complete payload without independently synchronizing its bits. It does not
claim metastability resolution, MTBF, placement, routing, recovery/removal,
timing closure, or lossless operation across an uncoordinated reset.

## Exact state machine

The initial primitive is a one-item toggle transport feeding a one-entry
destination response buffer. A request is acknowledged when the destination
captures it, not when the downstream consumer later accepts it. This choice is
necessary for the declared simultaneous destination consume/refill behavior.
It permits at most one item in the CDC transport while the independently
registered destination response may hold the preceding item.

All control registers and synchronizer stages reset to known zero. Every
source payload-hold and destination payload register resets to its declared
canonical zero value. The source and destination each use a synchronous,
active-high reset in their own domain for the initial slice.

Source-domain state consists of:

- `request_toggle`;
- one payload-hold register for every flattened payload leaf; and
- the ordered acknowledgement synchronizer stages.

Destination-domain state consists of:

- the ordered request synchronizer stages;
- `acknowledgement_toggle`;
- `destination_valid`; and
- one destination payload register for every flattened payload leaf.

The final acknowledgement synchronizer stage is `acknowledgement_seen`. The
source interface is ready exactly when
`request_toggle == acknowledgement_seen`. On a known source ready/valid
transfer, all payload leaves are captured from one source pre-state and
`request_toggle` changes polarity. No source payload-hold register changes
while that request is outstanding.

The final request synchronizer stage is `request_seen`. A destination request
is pending exactly when
`request_seen != acknowledgement_toggle`. A destination response is consumed
on a known destination ready/valid transfer. The destination may capture a
pending request when its response register is empty or is consumed on the same
edge. Capture atomically writes every destination payload leaf from the stable
source payload-hold bus, leaves `destination_valid` asserted, and assigns
`acknowledgement_toggle = request_seen`. Consumption without replacement
clears `destination_valid`. Backpressure changes none of the destination
response state.

These rules give the following destination-edge priority table:

| pending request | current valid | ready | action |
| --- | --- | --- | --- |
| 0 | 0 | any | remain empty |
| 0 | 1 | known 1 | consume and become empty |
| 0 | 1 | otherwise | hold response |
| 1 | 0 | any | capture and acknowledge |
| 1 | 1 | known 1 | consume old, capture new, remain valid, acknowledge |
| 1 | 1 | otherwise | hold response and defer acknowledgement |

The table is evaluated from one destination pre-state. At a coincident source
and destination event, both domains likewise sample one global pre-state; a
new source request cannot advance a destination synchronizer stage in that
same atomic event.

Unknown ready or valid does not count as a protocol transfer and may produce a
strict protocol diagnostic. The four-state structural circuit may still merge
state when an unknown control selects distinct next values. Tests must not
silently strengthen the contract to “unknown holds every register,” and the
two-state Verilator oracle must not accept an external unknown value.

## Coordinated reset boundary

Normal operation begins only after both domains have sampled asserted reset,
both domains have sampled deasserted reset, and both synchronizer chains have
settled to the common idle phase before source valid is admitted. The same
sequence is required when resetting from either idle toggle polarity. Traffic
and delivery observations during the coordinated reset window are excluded.

A unilateral reset while a request or destination response is outstanding is
a flush/loss operation. Its deterministic digital state is still compared
between LunaWave and emitted RTL, but the evidence class must say
`expected-reset-flush-loss`; it must never be counted as a delivered or
lossless transaction. Independent-reset recovery is a future, separately
versioned protocol.

## Canonical structural admission

The primitive record must identify every state node and endpoint explicitly:
both domains, both resets, source valid/ready, destination valid/ready, the
ordered source and destination payload leaves, both ordered two-through-four
stage synchronizer chains, both toggle registers, and the destination-valid
register. Aggregate leaf paths remain in canonical flatten order.

Admission checks the exact transition structure above. In particular:

- request and acknowledgement chains use the declared opposite-domain toggle
  as stage-zero input and have no enable;
- every later synchronizer stage samples only its predecessor;
- payload-hold registers are source-domain state enabled only by source
  acceptance;
- destination payload registers, destination valid, and acknowledgement are
  destination-domain state controlled only by the capture/consume table;
- the unsynchronized source payload bus may feed only the matching destination
  capture data inputs inside this primitive;
- payload leaf types and order match at the source hold, destination capture,
  and external destination endpoint;
- intermediate synchronizer stages and private toggles have no external or
  hidden fanout; and
- source and destination domains differ and all nodes belong to one module.

The CDC pass grants the stable payload-bus exemption only to the declared
destination capture inputs. The source ready endpoint obtains source-domain
provenance and destination valid/payload endpoints obtain destination-domain
provenance. No backend recognizes names or topology as an alternative waiver.

Codec tests require one exact schema-4 golden, a parse/serialize round trip,
lowest-schema preservation for designs without the primitive, and focused
rejections for missing, duplicated, reordered, wrong-domain, wrong-type,
wrong-stage-count, wrong-reset, wrong-fanout, and mismatched-payload records.

## LunaWave, replay, trace, and VCD evidence

LunaWave executes only the ordinary registered structure after the canonical
CDC pass accepts it. There is no primitive-specific simulator state machine.
One shared normalized `TimestampEvent` array is the source of truth for direct
simulation, schema-2 replay, trace recording, and Verilator stimulus. A test
must not regenerate clock schedules independently for those paths.

Directed native tests cover:

1. coordinated reset from idle phase zero and idle phase one;
2. one source acceptance, request-chain latency, destination capture, and
   acknowledgement-chain latency for synchronizer depths two, three, and four;
3. source ready deassertion and complete payload stability while outstanding;
4. destination valid and complete payload stability during long backpressure;
5. consumption without refill and consumption with same-edge refill;
6. a new source item waiting behind a full destination response without
   overwriting either payload;
7. coincident source/destination edges and both permutations of the caller's
   drive and domain arrays;
8. known-zero controls, unknown controls as non-transfers/diagnostics, and
   mixed known/unknown payload bits in the native four-state model;
9. coordinated reset while idle and unilateral reset at each mid-flight phase,
   with the latter classified as expected flush/loss; and
10. seeded reduced rational schedules with coprime and non-coprime periods,
    varied phases, long asymmetric gaps, and deliberate coincidences.

At least one payload fixture is multi-leaf, for example a Unicode-named record
containing a tag and a vector, so the evidence checks complete aggregate hold,
capture, endpoint ordering, and trace source mapping rather than only a scalar
bus.

Schema-2 replay tests bind the canonical IR digest, normalized timebase,
sparse domain table, exact atomic events, and endpoint taps. Execution must
produce the same changed-value frames and final trace digest as the direct
simulation. Reversing drive/domain input order must reserialize to the same
canonical replay bytes and trace digest. Stop conditions must be exercised for
time, boundary, each domain's edge count, source-ready equality, and
destination-valid/payload equality.

Trace tests require one frame for every timestamp event, including events with
no changed endpoint. Each frame retains exact time, boundary, sorted drive
names, sorted sparse domain IDs, and changed values. VCD timestamps use the
normalized event time and its comments retain boundary, drives, active
domains, and per-domain edge counts. No trace or VCD path invents a global
multi-clock cycle meaning.

## SystemVerilog evidence

The production emitter lowers the visible registers and combinational logic;
it does not emit a behavioral handshake black box. Unit tests bind every
register to its declared clock and synchronous reset, confirm that the source
payload bus reaches only destination capture data inputs, and confirm that
external destination payload is driven only from destination registers.

No CDC attribute substitutes for structural validation. If preservation
attributes are added later, they require a separately versioned backend
capability and exact emission tests.

The Verilator-v2 bridge must be made phase-neutral before adding handshake
fixtures. The current synchronizer-local C++ generator only accepts one-bit
drives and masks every output to one bit. Copying it would duplicate atomic
edge semantics and truncate handshake payloads. Move the generator and
manifest writer into `validation/verilator`, make drive/result conversion
width-aware through 64 bits, use each `StimulusDomain.clock_port` directly,
and preserve the current synchronizer bundle bytes exactly as the extraction
regression.

Every C++ event performs exactly:

1. lower all clocks and apply all fully-known drives;
2. evaluate once;
3. raise every listed clock without an intervening evaluation;
4. evaluate once; and
5. sample every declared output at the exact event time and boundary.

The external differential matrix contains:

- a two-stage directed scalar fixture with backpressure and acknowledgement
  round trip;
- a three-stage multi-leaf fixture with coprime rational periods and nonzero
  phases;
- a two- or four-stage non-coprime zero-phase fixture that reaches
  simultaneous destination consume/refill;
- a coordinated-reset and expected-unilateral-flush fixture; and
- a fixed-seed matrix of reduced rational schedules and ready/valid/payload
  streams.

All Verilator inputs are fully known. The gate compares every defined external
output after every event, not only a final checksum. A separate sequential-edge
bridge deliberately evaluates after each raised clock. The fixture generator
must find and then freeze the first exact time, boundary, output, expected
value, and sequential value where this wrong bridge differs. Absence or drift
of that required mismatch fails the gate.

The gate reuses the existing locked Verilator runner, validator, image, and
schema-2 stimulus contract. It records exact fixture/event/coincidence counts,
all bundle and result digests, start/end HEAD and status, a complete repository
input manifest, and the physical-claim exclusions.

## Synthesis-structure evidence

The synthesis bundle uses the production public constructor, canonical CDC
admission, codec, and SystemVerilog emitter. A dedicated versioned handshake
shape manifest identifies all state roles and payload leaves; it must not
overload the bit-synchronizer shape schema.

For synchronizer depth `N` and `L` flattened payload leaves, the expected
pre-map state is exactly `2*N + 3 + 2*L` positive-edge registers:

- `N` request synchronizer stages in the destination domain;
- `N` acknowledgement synchronizer stages in the source domain;
- request toggle, acknowledgement toggle, and destination valid; and
- `L` source payload-hold plus `L` destination payload registers.

The checker proves exact clocks, widths, reset muxes, predecessor chains,
payload correspondence, capture/consume enables, endpoint aliases, absence of
bypass, absence of extra sequential state, and absence of memories/latches.
It checks pre-map RTLIL from the existing pinned runner. A passing report says
only that the generic pre-map state/dataflow shape matches; placement,
metastability, MTBF, and timing closure remain false.

Checker self-tests include a missing request stage, acknowledgement bypass,
wrong-domain stage, payload-hold bypass, mismatched leaf order or width,
destination-output bypass, incorrect capture/consume control, hidden payload
fanout, extra state, and memory/latch insertion. These hand-authored parser
fixtures are checker tests, not synthesis evidence.

## Named formal evidence

Formal bundles use the phase-neutral typed-artifact registry and the exact
pinned Phase 4 Yosys/SymbiYosys/Bitwuzla runner. They use task/result schema 2
with two explicitly bound sparse domains, legal low/high clock transitions,
bounded clock-gap fairness, atomic global-pre-state coincidence, coordinated
reset initialization, source protocol assumptions, and a bounded eventual-
ready assumption for completion claims.

The stable assertion labels are:

1. `one_item_in_flight_capacity`;
2. `source_payload_stable_while_outstanding`;
3. `destination_response_stable_under_backpressure`;
4. `no_duplicate_acknowledge_or_consume`;
5. `watched_transaction_data_integrity`; and
6. `watched_transaction_completes_under_bounded_clocks_and_eventual_ready`.

The completion bound is generated from the declared request/acknowledgement
stage counts, maximum source/destination clock gaps, and eventual-ready bound;
the exact derivation and integer result are included in the task manifest.
There is no unconditional liveness claim.

Separate covers are:

- `coincident_source_destination_edge`;
- `simultaneous_destination_consume_and_refill`; and
- `watched_transaction_accept_capture_consume`.

The watched-transaction ghost state nondeterministically selects one accepted
source item, records every payload leaf, and follows it through destination
capture and exactly one consumption. It prevents a vacuous data-integrity pass
and proves leaf order as well as value equality.

Each assertion has one isolated negative fixture with exactly one declared
stable expected-failure label and exactly one retained counterexample trace.
The negative mutations respectively permit a second outstanding request,
overwrite one held payload leaf, change one destination leaf under
backpressure, duplicate an acknowledgement/consume event, corrupt one watched
leaf, or remove the bounded completion progress. Wrong/additional labels,
missing or multiple traces, an absent cover witness, timeout, inconclusive,
unsupported, or tool error are all non-pass.

## Commit and gate sequence

The reviewable implementation order is:

1. primitive type, exact structural validator, codec golden, and malformed
   records;
2. public LunaWire constructor and CDC provenance/fanout tests;
3. LunaWave directed, unknown-control, reset, and atomic-order tests;
4. phase-neutral width-aware Verilator-v2 bridge extraction with unchanged
   synchronizer bundles;
5. handshake replay/trace/VCD and pinned differential fixtures;
6. synthesis shape checker, self-tests, and pinned synthesis matrix;
7. formal bundles, isolated negatives, covers, and pinned formal matrix; and
8. inclusion in the unchanged-snapshot aggregate Phase 5 gate.

Each step is warning-strict tested and committed before the next. Pinned gates
fail closed when their exact OCI tool is unavailable; a host-tool fallback is
not evidence.
