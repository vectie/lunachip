# FluxTile fetched concurrent host device

This implementation boundary connects the raw host descriptor reader to the
draft-0.2 slotted queue and existing concurrent load, compute and store engines.
One three-client arbiter owns the external memory bus. It advances the real
host-connected device, not a second accelerator or a new assurance framework.
All existing constructors, descriptor 0.1 and reader fault meanings remain
unchanged. This contract is provisional; independent RTL/synthesis/formal gates
and device ABI freeze remain separate Phase 6 requirements.

A separate [opt-in word-read constructor](PHASE6_WORD_MEMORY.md) coalesces
descriptor and operand reads. It requires a matching host-memory adapter;
this byte-read constructor and its earlier evidence retain their identities.

## Public construction and ownership

`ring_concurrent_tile(rows~, columns~, max_reduction~, host_bytes~,
ring_depth~, queue_depth~)` builds `FluxTileHostConcurrent`. Array/aperture
limits are inherited from the existing portable core. Ring depths are 2/4/8/16;
queue and retirement depths are both `queue_depth`, from 2 through 16.

Public inputs are clock/reset, reader configuration/publication, completion ACK
and the existing memory channel. Outputs are the reader's ready/configured and
producer/consumer fields, sticky ring faults, queue occupancy, ordered held
completion fields, shared transport halt/fault address and compute counters.
There are no direct descriptor lane inputs in this shell. Ring fault code is
UInt3; command completion fault remains UInt4. No new epoch, dependency-token
input or simulator-only override is added.

Host software writes all 32 descriptor bytes before publication and must not
overwrite a slot before consumer advancement. Configuration supplies the real
initial UInt32 sequence origin. The reader copies raw bytes without parsing;
only complete atomic queue acceptance advances consumer, allowing ring-slot
reuse before command dispatch or completion. A complete but backpressured
packet still owns its ring slot. A partial fetch has no command ID or command
completion obligation. Queue occupancy counts FIFO entries only; retirement,
one dispatch head and the reader's held packet are separate bounded owners.

The packet frontend uses only draft 0.2 and retains the documented strict
dispatch, internal tickets, latest-writer failure propagation, selected slot
leases, terminal-only Fence and ordered retirement from
[PHASE6_QUEUED_CONCURRENT.md](PHASE6_QUEUED_CONCURRENT.md). Caller IDs may
duplicate. Exact shape checks and authoritative C metadata are unchanged.

## Shared transport

Client order is descriptor reader, operand loader, result storer. Starting at
the round-robin preference, select the first requesting client cyclically;
a sole requester never waits for an absent peer. Reset preference is reader.
Advance preference to the accepted owner's successor only on external request
acceptance. A requester that stays valid receives service within three grant
opportunities under a fair responding host; wall-clock or finite-latency
completion is not claimed without that environment assumption.

Capture owner and the entire request before exposing external request-valid.
All payload fields and owner remain stable under backpressure. There is one
globally outstanding transaction, and no new external request is accepted on
the response-retirement edge. Reads transfer one byte; result writes transfer
four little-endian bytes. Global UInt32 tags begin at zero after reset and
increment on external acceptance. Validate the response tag/status before
restoring the owner's local tag; only that owner receives a response. Outside
the outstanding-response state, response-ready is zero and no owner is inferred.

Do not nest two arbiters, allocate a second array, or duplicate data engines.
The existing two-client arbiter remains unchanged for legacy constructors.
The new three-client arbiter is a separately composed private transport.

## Faults and terminal ordering

Reader configuration/publication faults 1 through 3 and matching remote fault
4 stop the reader without shared poison. Its counters/fault address retain
their established meanings. Already accepted queue commands continue normally.
Unfetched descriptors never gain fabricated completions. Matching loader or
storer remote fault 9 remains local and preserves committed progress; other
engines and already accepted queued work may continue.

A malformed accepted response poisons shared transport after discovery. If the
reader owns it, sticky ring protocol fault 5 records the actual failing byte
address. Unfinished data transfers cancel with 15 and committed progress. If
loader or storer owns it, that command completes with 10 and actual failing
address; its unfinished data sibling cancels with 15. A sibling reader freezes
without inventing a second ring fault. The shared transport fault address is
the owning accepted request address, zero when not poisoned.

Already accepted compute continues through Issue, Run and capture on poison.
Existing terminal records and held completions are immutable. The queue drains
unissued accepted packets as ordered fault 15 with zero progress/address and
marks already published unissued writer intents Failed. Terminal work on the
discovery edge wins later cancellation. A packet accepted on that edge counts
as accepted; a held packet never admitted afterward has no completion record.
New publication, fetching, packet admission and DMA requests stop while poison
is visible. Recovery requires joint reset.

Reset suppresses all handshakes and clears reader configuration/counters,
FIFO, dispatch, retirement, dependencies, slot metadata, engine records and
shared ownership/tags/poison. The host must flush old pending requests/responses
before deassertion. Physical SRAM and committed host writes are not rolled back;
interrupted commands get no manufactured post-reset completion.

## Construction and validation plan

Extract a private concurrent-client builder supplied with loader/storer routes
and shared poison, returning only channel signals, requests/readies and core
counter references. Legacy composition wraps it with its original arbiter at
the original allocation positions. Extract the queued frontend's finish step
from engine and public-port construction. Queue helpers need engine channel
signals plus poison, not fabricated memory signals. Preserve the existing
public concurrent and queued canonical graphs during these mechanical seams.

Construct the new shell in this order: three-client registers/routes; reader
registers and pre-edge packet view; queue context and dispatch; concurrent
clients; queue finish; reader graph using queue-ready; three-client controller;
public outputs. Registers/views break construction dependencies; no forward
wires or duplicate controllers are needed.

Use separate owners for transport, private composition seams, top-level shell
and independent public-port tests. Validate the arbiter's fair selection,
stalled payload/local-tag restoration, owner-only remote errors, malformed
global response handling, one outstanding request and reset. Integration tests
must fetch actual host bytes, observe descriptor and operand reads plus result
writes during advancing compute/capture, compare final host results against
the independent matrix oracle, and exercise duplicate IDs/ordered retirement,
held-oldest frontend saturation, packet backpressure, real origin/counter wrap,
partial fetch failure without a fabricated completion, each poison owner,
accepted compute draining, discovery-edge packet admission and joint reset
with actual external transaction flush. Deterministic IR round trips, local SV,
one array/two storage sets/four FIFO SRAMs, unchanged legacy artifacts, targeted
strict native checks and one completed-slice repository gate are required.

## Initial local validation

The implementation passes a native check with warnings denied and warning 73
enabled. Six standalone arbiter tests pass, covering cyclic/skip fairness,
locked requests, owner-only responses, local/global tag separation, remote and
malformed responses, unsolicited responses and reset. Two fetched-shell
artifact/limit tests pass: representative graphs round-trip canonically, emit
deterministic local SystemVerilog, contain exactly one array, two operand/result
storage sets and four packet FIFOs, and expose no direct descriptor inputs.

Both fixed pre-integration graph digests remain unchanged after extracting the
private construction seams: the direct concurrent graph and the queued
concurrent graph each pass their canonical golden test.

Six independent public-port behavior tests also pass, for a fetched-shell
targeted total of 8/8 including the two artifacts. They observe all twelve
reader/loader/storer request-acceptance and response-ACK combinations with
advancing Run/capture counters, and compare padded signed 8x8 results with
the independent oracle. Duplicate IDs, younger store completion before oldest
retirement, engine reuse under held retirement, depth-2 frontend saturation
with ring depths 2/4/8/16, and real UInt32 origin/counter wrap are exercised.
Other cases cover partial reader remote failure without a manufactured
completion, all three protocol owners with nonzero committed sibling DMA
progress and compute draining, immutable held terminals, an actual pending
fetch jointly reset/flushed, and consumer advancement on the exact poison
discovery edge. The latter uses public-observation calibration and a fresh
stimulus replay, not a simulator-state patch.

These tests establish local functional/artifact evidence only, not independent
RTL, synthesis, formal, physical timing or a completed Phase 6 gate.

The completed-slice repository gate passes 708/708 native tests, interface
generation, formatting, warning-strict native checking with warning 73 enabled,
default CLI smoke and dependency/source-size boundaries. The FluxTile package
contains 149 tests and the CLI contains eight. Generated public interfaces add
only the new constructor, not private client or queue construction hooks.
The separately executed `ring-concurrent-demo` checks both result matrices and
all 1024 host bytes; its observed traffic totals and command are documented in
[PHASE6_DEMO.md](PHASE6_DEMO.md).
