# Toggle-handshake formal evidence

The Phase 5 toggle-handshake formal gate proves bounded, two-state digital
properties of the public LunaWire `toggle_handshake` constructor and the
production SystemVerilog emitter. It reuses the phase-neutral typed-artifact
registry and the exact pinned Phase 4 Yosys, SymbiYosys, and Bitwuzla runner.
The runner, OCI lock, and result collector are unchanged.

## Fixture and timing boundary

Three valid fixtures bind a scalar payload at two synchronizer stages and a
two-leaf `word8`/`tag3` record at three and four stages. The six negative
fixtures use the three-stage record design and mutate exactly one monitored
behavior path while preserving every exported predicate. Every design is
constructed through the public LunaWire API, passes canonical CDC admission,
is serialized as schema-4 IR, and is lowered by the production RTL emitter.

Each schema-2 task binds sparse source and destination domains 0 and 2. One
logical scheduling interval is two formal-engine steps. Requested clocks are
captured on the positive formal-step edge and both are committed on the
negative edge, so coincident DUT edges observe one global pre-state. A high
clock must fall at the next interval and neither domain may omit a rising edge
for more than three intervals.

Both synchronous active-high resets begin asserted. Traffic remains disabled
until each domain has sampled reset, deasserted it, and observed its declared
synchronizer depth in post-reset edges. This is coordinated idle
initialization, not an independent-reset recovery proof. A source-protocol
assumption holds valid and every payload leaf until acceptance. Destination
ready may remain low for at most three destination edges while completion is
claimed.

The watched completion limit is generated per fixture:

    maximum_clock_gap_intervals *
      (synchronizer_stages + eventual_ready_destination_edges + 1)

With a maximum gap of four scheduling intervals and an eventual-ready limit
of three destination edges, the exact limits are 24, 28, and 32 scheduling
intervals for stages two, three, and four. The source set and every execution
manifest record both the formula and integer result. There is no unconditional
liveness statement.

## Properties and ghost model

The harness observes the emitted request/capture/consume controls, held
payload leaves, and acknowledgement toggle. A separate atomic ghost model
tracks the one-item CDC transport and one-entry destination response from the
same global pre-state. A nondeterministic selector records one accepted
transaction and follows every leaf through capture and exactly one consume.

The six stable assertions are:

1. `one_item_in_flight_capacity`;
2. `source_payload_stable_while_outstanding`;
3. `destination_response_stable_under_backpressure`;
4. `no_duplicate_acknowledge_or_consume`;
5. `watched_transaction_data_integrity`; and
6. `watched_transaction_completes_under_bounded_clocks_and_eventual_ready`.

Three distinct cover tasks require individual retained witnesses for:

- `coincident_source_destination_edge`;
- `simultaneous_destination_consume_and_refill`; and
- `watched_transaction_accept_capture_consume`.

Each negative bundle names exactly one expected stable assertion label. Its
production DUT, property predicates, and other five monitored paths remain
byte-for-byte unchanged. The harness injects one semantic mutant into the
path observed by the selected property: a duplicate source-accept event, a
held-word bit flip, a backpressured response-word bit flip, a duplicate
consume event, a watched response-word bit flip, or suppression of the watched
consume/completion event. This makes the intended behavior defect reachable
without weakening or directly masking the exported predicate. The gate
requires exactly one counterexample artifact for each. Wrong or additional
labels, missing or multiple traces, missing cover witnesses, inconclusive
results, tool errors, and timeouts fail closed.

## Reproducibility and claim boundary

Run local deterministic and structural checks with:

    scripts/formal-bundle-selftest.sh
    scripts/phase5-toggle-formal-selftest.sh

Run the pinned matrix with:

    scripts/phase5-toggle-formal-gate.sh [EMPTY_RUN_ROOT]

The gate snapshots the complete repository inputs before and after execution,
binds the lock, runner, gate, and generated-tree digests, and retains incomplete
evidence if any prerequisite or task fails. A pass requires three bounded
safety results, three individual cover witnesses, and six isolated
counterexamples across nine fixtures and twelve tasks.

This evidence excludes analog metastability, MTBF, physical placement,
routing, recovery/removal, timing closure, silicon reliability, and lossless
operation across unilateral reset. If the pinned OCI runtime is unavailable,
the gate fails closed; a host-tool substitution is not evidence.
