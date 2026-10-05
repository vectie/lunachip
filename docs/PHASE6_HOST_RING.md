# FluxTile host ring integration

The provisional `ring_tile` shell connects the hardware descriptor-ring
reader, bounded command frontend, and real load/compute/store engine to one
host-memory request/response port. Host software writes descriptor bytes and
publishes a producer count; hardware fetches those bytes, enqueues complete
packets, executes commands, and stores matrix results. The external memory
environment never performs the device computation.

This shell does not freeze device ABI version 1 or complete Phase 6. Operand
and result slots are still singular, commands execute serially, and the
dependency scoreboard and decoupled engines remain later work. Independent
RTL, synthesis, and named formal gates retain the requirements in `PLAN.md`.

## Public construction and ports

`ring_tile(rows~, columns~, max_reduction~, host_bytes~, ring_depth~,
queue_depth~)` preserves the existing compute/aperture limits. Host ring depths
are 2/4/8/16; command queue depths are 2 through 16. These are distinct
capacities. The host ring stores published descriptors until the hardware
copies them into the command queue; the queue then owns that copied packet.

The direct `descriptor_valid` and four input lanes of `queued_tile` disappear
from this shell. The host instead uses `config_valid`, `config_base`,
`config_origin`, and `publish_valid`, `publish_producer`, with the reader's
ready outputs. Configuration is accepted once until joint reset. The reader
validates alignment/aperture before setting `configured`; both counts start
at the accepted origin on successful configuration. Publication is checked
against pre-edge free capacity, without same-edge packet-transfer credit.
See `PHASE6_RING.md` for exact reader rules.

The shell publishes `producer_count`, `consumer_count`, `configured`, and
`ring_fault_valid`, `ring_fault_code`, `ring_fault_address`. Reader faults are
separate from command completions: a partial fetch has no reliable command ID.
The queue's completion and compute-counter ports remain unchanged.
`transport_halted` reports shared transport poison, not an ordinary reader
remote failure. `transport_fault_address` retains the failed accepted external
request's byte address while poisoned and is zero otherwise.

The external host-memory channel retains the portable request/response fields.
Descriptor and operand reads request one byte, mask 0001, and zero write data.
INT32 result stores request four bytes, mask 1111, with little-endian data.
Both readers and stores receive acknowledged responses. There is exactly one
accepted external request awaiting a response.

## Descriptor ownership and backpressure

The reader transports all 32 raw descriptor bytes without parsing their
version, opcode, or reserved fields. Once fetched, all four 64-bit lanes remain
stable until the command frontend accepts the packet atomically. Only that
handshake advances the consumer counter. Completing a fetch alone does not
release its host ring slot, and completing the command is not required before
the host may reuse that released slot.

The command queue validates malformed packets and returns faults in accepted
entry order. Its occupancy excludes the active head, so it can own
`queue_depth + 1` unresolved accepted commands. Once that storage fills, an
additional fetched packet remains with the reader and its consumer count
does not advance. Completion backpressure does not change a held completion
payload, even while descriptor fetch continues into available queue slots.

Host software must make descriptor bytes visible before publication and must
not overwrite a slot before consumer advancement. The configuration origin
is a real empty-ring starting sequence; it allows wrapping UInt32 counters
without a hidden simulator-state override. Power-of-two ring depth makes low
consumer bits select the correct physical slot through counter wrap.

## Shared requests and transaction identity

The arbiter selects reader or data-engine requests fairly at transaction
boundaries and locks its grant before asserting external request-valid. A
stalled request keeps its complete payload, owner, and tag stable. It issues
no second request while a response is outstanding, nor on the same edge that
retires that response.

External tags come from one resettable global sequence. The arbiter records
the selected owner and that client's original local tag when the external
request is accepted. It validates the external response tag before restoring
the local tag and delivering the response to its owner. Blindly rewriting a
malformed global tag to the expected local tag would conceal a protocol fault
and is not permitted. The unselected client receives no response transfer.

Reader and data requests can interleave, but the compute command engine
remains serial and each client retains its own state/identity. Transaction
overlap here does not mean decoupled matrix engines or multiple outstanding
external requests.

## Remote failures and shared transport poison

A matching remote failure is retired normally and delivered only to its owner.
Reader remote fault 4 stops further descriptor fetch and preserves its
consumer count; previously accepted commands can still execute and complete.
Data remote fault 9 retains its documented partial-side-effect behavior and
does not cancel unrelated queued commands.

A wrong global tag or reserved response status on an accepted outstanding
response poisons the shared transport. The response still reaches its true
owner as a protocol failure. Poison then prevents new shared requests and
descriptor admission until joint reset.

The environment must return exactly one response for each accepted request.
Outside the response-wait state the shell keeps response-ready zero, accepts
no response, and performs no ownership/tag validation. It does not claim an
unsolicited-response detector; no synthetic owner, descriptor ID, or command
completion is inferred from a response with no outstanding request.

When the data engine owns the malformed response, its accepted command first
produces fault 10 with its failing byte address and committed progress. Later
accepted queue entries complete in order as fault 15 with zero progress.
When the reader owns it, the reader retains sticky fault 5 and its actual
failed address; a queue head that is still executing is cancelled as fault 15
with its committed transfer progress, and unissued accepted entries return
fault 15 with zero progress. A partially fetched descriptor is not an accepted
queue entry and receives no command completion.

Queue cancellation observes registered poison after the owner has retired
the malformed response. An already visible inner terminal completion takes
precedence over cancellation, and an already held outer completion never
changes. This ordering prevents a data-owned fault 10 from being replaced by
fault 15 and prevents a later unrelated reader failure from altering a result
already offered to the caller. No implicit core reset is used to cancel work.

## Reset and validation scope

Reset is a joint device/transport flush barrier. It suppresses handshakes,
clears arbitration ownership/tags, reader configuration/counters/faults,
queue/head/completion state, transport poison, and operand/result validity.
The environment must discard old pending requests and responses before reset
deassertion. Previously accepted host writes remain committed; reset makes
no rollback or atomic-store promise. Interrupted and queued commands do not
receive manufactured post-reset abort completions.

Black-box tests use the existing sparse byte-memory environment for the
single observed host port. It checks external request stability, one
outstanding transaction, and the global tag sequence, then answers actual
descriptor/data reads and result writes with deterministic stalls/latency.
It contains no controller, queue, ring-reader, or matrix implementation.

The integration cases cover a fetched five-command padded signed matrix
workload whose final host words match the independent matrix oracle; a held
completion that fills the bounded queue and stalls ring-slot release; genuine
origin/counter/slot wrap; data-owned malformed responses; reader-owned poison
with committed cancellation progress; immutable already held completions;
reader-only remote failures while accepted data work drains; and recovery
after an actual external transport flush. These target the composed device
boundary; passing them alone is not the frozen Phase 6 independent-tool gate.
