# FluxTile queued concurrent implementation contract

This implemented functional slice composes the existing concurrent engines with
an atomic packet FIFO, one strict dispatch head, bounded ordered retirement,
and six latest-writer summaries. It is a functional simulation boundary, not
a frozen ABI or fetched-ring integration. Existing constructors and descriptor
0.1 remain unchanged. No new formal/provenance framework is needed here.

## Public construction and packet format

`queued_concurrent_tile(rows~, columns~, max_reduction~, host_bytes~,
queue_depth~)` builds `FluxTileQueuedConcurrent`. `queue_depth` is 2 through 16;
it bounds both the four-lane packet FIFO and the separate retirement table.
One additional synchronous dispatch head may hold a popped packet. The public
ports match the existing atomic-packet queued interface: `descriptor_valid`,
four Bits64 `descriptor_lane_0` through `_3`, `descriptor_ready`,
`queue_occupancy`, `completion_ready`, and the held completion ID/fault/byte
progress/address. The memory port and compute counters remain unchanged;
`halted` and the transport fault address expose sticky transport poison.
Queue occupancy counts FIFO entries only, not dispatch or retirement entries.

The new `device/slotted_descriptor` syntax codec accepts only draft 0.2. Its
32-byte little-endian layout preserves 0.1 offsets, except byte 1 is 2 and
bytes 24, 25 and 26 contain A, B and C slot selectors respectively in bit 0.
Their upper seven bits, bytes 27 through 31, byte 3 and bytes 14/15 remain
reserved zero. Opcode encoding and UInt13 dimension representation are
unchanged. Codec errors have the same priority as the old syntax codec;
out-of-range host selectors are checked, never truncated.

Hardware syntax fault priority is version 12, reserved 13, opcode 1,
dimension representation 14. Syntax-invalid packets create no writer intent.
For syntax-valid packets, operation-specific unused fields produce fault 2:

| Operation | Used selectors | Other unused fields |
| --- | --- | --- |
| LoadA | A | reduction; B/C selectors |
| LoadB | B | reduction; A/C selectors |
| MatMul | A/B/C | base/stride |
| StoreC | C | reduction; A/B selectors |
| Fence | none | rows/columns/reduction/base/stride; A/B/C selectors |

All unused fields must be zero. Preliminary dimension checks precede dependency
waiting or availability rejection, so an invalid shape faults with 3 even when
its producer is Pending, Empty or Failed. Engine exact-shape, stride, alignment
and aperture checks follow. Local rejection has zero byte progress
and zero fault address. All faults remain UInt4; dependency unavailability
uses existing compute fault 4 or store fault 5. No new fault code is invented.

## Dispatch and retirement

Four identical synchronous SRAM FIFOs accept each packet atomically. Acquire
one complete head response, then reserve a free retirement entry at decode.
Reservation records the raw caller ID and a wrapping UInt32 internal ticket.
Ticket values, not caller IDs, identify engine commands and collector results.
Caller IDs may duplicate arbitrarily; they are echoed only on retirement.

Dispatch is strictly in packet order, with no head bypass. It advances after
an engine command handshake or local terminal rejection, not after engine
completion or external ACK. Each engine completion is collected independently
into its reserved retirement entry and acknowledged promptly. Multiple
different engines may complete on one edge. Reuse the engines' existing
one-edge completion-ACK-to-new-accept boundary.

Only the oldest valid retirement entry, when terminal, is externally visible.
Its ID/fault/progress/address remain immutable until ACK. Held retirement
does not prevent engine reuse while table capacity remains. Retirement uses
ring positions and entry validity, not numerical ticket ordering; this works
across ticket wrap. No same-edge free-slot credit is required. Bounded table
capacity prevents a live ticket from aliasing after a full UInt32 wrap.

Fence waits until every older entry is terminal, then completes successfully.
It does not wait for their external ACKs or require their success. No later
packet dispatches through the Fence while older work is unfinished. A Store
becomes terminal only after its final host response or a terminal failure.

## Latest-writer dependency contract

Maintain one persistent latest-writer summary for each A0/A1/B0/B1/C0/C1:
ticket plus Empty, Pending, Success or Failed. At decode/reservation, snapshot
selected source outcomes before publishing this command's writer intent.
LoadA/B creates an intended generation for its selected operand slot;
MatMul creates an intended C generation. Store and Fence do not write slots.

A syntactically valid writer creates intent even when unused-field or engine
preflight subsequently rejects it. Its terminal outcome becomes Failed.
Thus a rejected reload or MatMul cannot authorize a downstream consumer to
fall back to older valid physical data. Syntax-invalid commands leave all
prior writer summaries unchanged. Successful recovery replaces Failed with
a new generation.

Pending dependencies wait; Empty or Failed dependencies reject compute with
4 or store with 5. Successful dependencies permit engine issue, which still
checks exact physical shapes. Strict dispatch prevents any later head from
publishing a replacement source intent while this head waits. Once engine
acceptance establishes physical leases, dependency references can be dropped.
Producer terminal updates change a summary only if its ticket still matches
that slot's latest writer. New writer publication wins a simultaneous older
producer update. Summaries persist beyond producer retirement; no retained
producer graph or consumer-fanout framework is necessary for strict dispatch.

## Poison and reset

Reuse concurrent-engine fault ownership: malformed response owner gets 10,
unfinished sibling transfer gets 15 with committed progress, and accepted
compute drains normally. Held terminal entries cannot change. Packet admission
stops once poison is visible. Discovery-edge handshakes count as accepted.
Unissued accepted packets are drained into ordered fault-15 entries with zero
progress/address. A previously published but unissued writer intent becomes
Failed. Unreserved canceled packets need no new writer intent. Collectors
continue draining already accepted engine completions during poison.

Joint reset clears FIFO, dispatch, retirement, dependency summaries, engines
and transport; flush old external requests/responses before deassertion. It
does not erase SRAM, undo committed host writes, or manufacture completions.

## Implementation ownership and evidence

Separate the pure 0.2 codec, node-order-preserving private engine extraction,
queued frontend, and independent black-box tests. Reuse transfer controllers,
one array, two storage sets, and the existing two-client bus. Fetched-ring
integration later needs explicit reader/loader/storer three-client arbitration;
it is not included in this packet slice.

Require ordered retirement despite out-of-order engine finishes, duplicate IDs,
held-oldest completion with engine reuse, simultaneous collectors, queue/table
full and wrap, failed preflight writer dependencies despite older physical
data, syntax-invalid non-writers, successful generation recovery, Fence without
external ACK, real DMA/compute overlap, poison and joint reset. Compare all
successful final host bytes with the independent matrix oracle. Require
canonical round trips/local SV, unchanged legacy artifacts, strict targeted
native checks, and the repository phase gate once this slice is complete.
Independent RTL/synthesis/formal gates and final ABI freeze remain separate
requirements before Phase 6 can pass.

Nine independent public-port behavioral tests exercise this boundary. They
observe all eight accepted read/write request/response classes during Run or
capture, and an acknowledged younger store before the oldest command becomes
terminal. Tests hold all retirement ACKs while engines reuse and work passes
Fence; align two engine completions; fill a general-depth retirement/FIFO/head
window and wrap its positions; reject stale physical fallback, preserve prior
intent on syntax failure, recover generations, and prevent a delayed older
Success from replacing a newer Failed intent. Both DMA poison owners, committed
sibling progress, accepted compute draining, ordered cancellation and joint
reset/actual transport flush pass. Ticket arithmetic wraps structurally; no
test claims to simulate four billion commands. Two artifact tests verify
checked queue limits and deterministic IR/SV with one array, two storage sets
and four descriptor SRAMs. A checked public example covers construction.
