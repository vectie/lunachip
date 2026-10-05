# FluxTile provisional standalone descriptor-ring reader

This slice fetches the existing 32-byte descriptor packet from a bounded host
ring and offers its four lanes atomically. It does **not** execute descriptors,
parse their command syntax, arbitrate a shared transport, or integrate the
ring with `queued_tile`. It is a provisional single-clock construction and
simulation contract, not a frozen ABI or a full Phase 6 gate.

## Ring ownership and publication

`descriptor_ring_reader(host_bytes~ : UInt64, ring_depth~ : Int)` configures
an exclusive host-byte aperture in 1 through 2^32
and a power-of-two ring depth of 2, 4, 8, or 16. Runtime configuration supplies
a UInt32 base byte address and UInt32 sequence origin. Configuration is accepted
once after reset. The base must be 32-byte aligned, and the complete ring must
fit: `UInt64(base) + depth * 32 <= host_bytes`. Validation occurs before any
address narrowing or memory request. An end exactly at 2^32 is legal; a
UInt32-wrapped end is not.

Unsupported depths raise `RingReaderError::InvalidRingDepth(value~)` and
unsupported apertures raise `RingReaderError::InvalidHostBytes(value~, maximum~)`
before construction. A configuration handshake captures base/origin. The next
validation edge either establishes configured status with P=C=origin or faults;
invalid configuration leaves both counters at their reset value zero.

The sequence origin is a legitimate empty-ring starting point, not a debug
override: both producer and consumer start at that value. Physical slot
index is the low `log2(depth)` bits of consumer. Thus arbitrary origins and
normal UInt32 wraparound are part of the public behavior.

The host writes all 32 descriptor bytes before publishing the new producer
sequence. Published slots stay immutable until consumer has advanced past
them; the reader is not a cache-coherency or host-memory-barrier mechanism.
Consumer advances only on the atomic output packet ready/valid handshake,
not on memory-request acceptance or the final response.

Publication uses UInt32 modular subtraction. With old producer P and consumer
C, a candidate Q is accepted as valid only if both `(Q-P) mod 2^32` and
`(Q-C) mod 2^32` are at most depth. Unchanged producer is a legal no-op.
Backward movement therefore cannot masquerade as a valid small forward
increment. Producer may fill the whole ring, including the currently held
packet's slot, but may not overwrite an unresolved consumer slot.

Capacity validation uses the **pre-edge consumer**, with no credit for a
packet ACK on that same edge. A publication that would fit only after that
ACK faults. The acknowledged packet still advances consumer exactly once;
the invalid publication does not change producer.

## Handshakes and fetch order

| Signal | Direction/type | Meaning |
| --- | --- | --- |
| clock/reset | Input Clock/Reset | Rising edge, active-high synchronous reset |
| config_valid | Input Bits1 | Offer runtime ring configuration |
| config_base/config_origin | Input UInt32 | Host base and initial sequence |
| config_ready/configured | Output Bits1 | Configuration admission/status |
| publish_valid/publish_ready | Input/output Bits1 | Producer publication handshake |
| publish_producer | Input UInt32 | Candidate producer sequence |
| producer_count/consumer_count | Output UInt32 | Committed sequence counters |
| descriptor_valid/descriptor_ready | Output/input Bits1 | Atomic output packet handshake |
| descriptor_lane_0..3 | Output Bits64 each | Little-endian descriptor bytes |
| fault_valid/fault_code/fault_address | Output Bits1/UInt3/UInt32 | Sticky reader fault status |

The memory request and response signals retain the exact names and widths in
[the portable transport contract](PHASE6_PORTABLE.md).

Configuration-ready is available only before configuration and outside reset
or fault. Publication-ready is available only in the empty/ready boundary, or
while a complete packet is offered **and** its consumer is ready. It is not
available during a stalled request, outstanding response, or held packet with
packet-ready low. An offered publication must hold its candidate stable until
accepted; merely presenting valid cannot alter a stalled request or packet.

The reader fetches each descriptor using 32 acknowledged one-byte reads. Each
request uses bytes=1, mask=0001, data=0, write=0. Addresses run from
`base + (consumer mod depth)*32` through that address plus 31. One tagged
transaction may be outstanding. Tags increment on accepted requests and begin
at zero after reset; they are independent of descriptor IDs and sequence
counters. Request payload stays stable under memory backpressure.

Responses supply a UInt32 tag, UInt2 status, and Bits32 data; only the low
eight data bits are the fetched byte. Earliest responses may be offered after
request acceptance and must remain stable until response-ready. No zero-cycle
response is required. The hardware assembles four Bits64 lanes in little-endian
byte order, preserving every byte, including malformed descriptor syntax.

No output packet is valid until every byte has received a matching successful
response. All four lanes remain stable under packet backpressure. No later
descriptor is fetched while that packet is held. The consumer ACK retires the
slot, after which the next published descriptor may fetch. The reader never
manufactures an execution completion or a partially fetched packet.

## Sticky faults and reset

Faults are local reader status, separate from the portable command completion
faults. They stay asserted until a joint device/transport reset; there is no
fault acknowledgement, implicit retry, or automatic skip.

| Code | Meaning | Fault address |
| --- | --- | --- |
| 1 | Configured base is not 32-byte aligned | Configured base |
| 2 | Complete ring exceeds the host aperture | Configured base |
| 3 | Producer publication moves backward or overruns capacity | Zero |
| 4 | Matching response reports remote-memory failure | Actual request byte address |
| 5 | Wrong response tag or reserved response status 2/3 | Actual request byte address |

Alignment precedes bounds. Protocol discrepancy precedes remote status: a
wrong tag with status 1 is code 5, not code 4. Invalid configuration leaves the
reader unconfigured; a fault after successful configuration retains configured
status. Consumer and producer retain their last committed values on a fault,
except for the independently valid packet ACK concurrent with a bad publication.
Fault closes configuration/publication, request/response, and packet handshakes.
Partial byte registers must not become an output packet.

Reset suppresses all handshakes and clears configuration, counters, tag state,
assembled packet validity, and fault. The external transport must also flush
old accepted requests/responses before releasing reset. Interrupted fetches
produce no packet. Reset does not undo any prior host write or packet already
accepted by a downstream consumer.

## Independent evidence and next slice

Black-box tests drive only public ports through LunaWave. The existing sparse
byte-memory environment answers actual requests with deterministic stalls and
latency, checks stable requests and tags, and does not implement the reader.
Tests use arbitrary 32-byte patterns to verify all lanes, all supported depths,
empty/full/physical wrap and UInt32 sequence wrap, held packet/publication,
pre-edge capacity and simultaneous bad publication/packet ACK, aperture limits,
partial fetch faults, protocol priority, and an actual reset transport flush.

Deterministic canonical IR round trips and local SystemVerilog emission are
construction evidence only. Existing compute/result/portable canonical
goldens remain unchanged. The separate [host-ring integration](PHASE6_HOST_RING.md)
connects this packet channel to the existing queue through one private shared
arbiter; it does not conflate ring-slot consumption with command completion.
Independent RTL differential, synthesis, named formal, and physical evidence
remain the later gates in `PLAN.md`.
