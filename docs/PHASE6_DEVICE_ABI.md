# FluxTile Device ABI 1.0

Device ABI 1.0 identifies the portable fetched concurrent FluxTile-0 profile,
`flux-tile-0/fetched-concurrent`. It binds the existing `FluxTileHostConcurrent`
signal interface and descriptor encoding 0.2 without changing their hardware
graphs. This is a frozen logical contract for external adapters and independent
verification, not a claim of a completed Phase 6 gate or production hardware.

The independent version axes are deliberate: Device ABI is 1.0, descriptor
encoding is 0.2, and capability manifest schema is
`lunachip.flux-tile-capabilities/v1`. Descriptors still begin with bytes `[0, 2]`.
Packets beginning with `[1, 0]` must fail with command fault 12. No legacy
constructor or codec silently adopts a new encoding. Unsupported required
profiles, versions and capabilities must be rejected, not guessed.

## Configuration and descriptor layout

The six configuration values and fixed capabilities are specified in
[PHASE6_CAPABILITIES.md](PHASE6_CAPABILITIES.md). The selected configuration
has one array, two slots per A/B/C kind and one globally outstanding memory
transaction. Rows/columns are 1..8, maximum reduction is 1..4096, host aperture
is 1..2^32 bytes, ring depth is 2/4/8/16 and queue/retirement depth is 2..16.
Runtime ring configuration additionally requires all ring bytes within that
aperture and a 32-byte-aligned base.

| Byte offsets | Encoding |
|---|---|
| 0, 1 | Descriptor encoding major 0, minor 2. |
| 2 | LoadA=0, LoadB=1, MatMul=2, StoreC=3, Fence=4. |
| 3 | Reserved zero. |
| 4..7 | UInt32 caller ID, little-endian. Duplicate IDs are allowed. |
| 8..9, 10..11, 12..13 | Rows, columns, reduction as little-endian UInt16 values representable in UInt13. |
| 14..15 | Reserved zero. |
| 16..19, 20..23 | UInt32 byte base and row stride, little-endian. |
| 24, 25, 26 | A/B/C selector in bit 0; upper seven bits zero. |
| 27..31 | Reserved zero. |

LoadA uses rows=M, columns=K and A selector. LoadB uses rows=K, columns=N and
B selector. MatMul uses rows=M, columns=N, reduction=K and A/B/C selectors;
base/stride must be zero. StoreC uses rows=M, columns=N and C selector. Fence
uses no dimensions, address or selectors. Every unused field must be zero.
Successful loaded operand and stored result shapes must match exactly.

Operands are signed INT8; each MatMul starts from zero and accumulates signed
INT32 values. Arithmetic is fixed-width modular arithmetic. The legal K bound
keeps zero-based INT8 products within INT32 range. StoreC writes little-endian
INT32 words; there is no floating-point, vector or accumulate-existing-result
operation in this profile.

## Portable signal interface

All transfers sample the same rising-edge clock. Control values are Bits1.
The interface has no physical MMIO offsets, PCIe transport or coherency policy.

| Direction | Signals | Types |
|---|---|---|
| Input | clock; reset | Clock; active-high synchronous Reset |
| Input | config_valid, publish_valid, completion_ready, memory_request_ready, memory_response_valid | Bits1 |
| Input | config_base, config_origin, publish_producer, memory_response_tag | UInt32 |
| Input | memory_response_fault; memory_response_data | UInt2; Bits32 |
| Output | config_ready, publish_ready, configured, ring_fault_valid, halted, transport_halted, completion_valid, memory_request_valid, memory_request_write, memory_response_ready | Bits1 |
| Output | producer_count, consumer_count, ring_fault_address, transport_fault_address, completion_id, completion_bytes_completed, completion_fault_address, memory_request_address, memory_request_tag | UInt32 |
| Output | ring_fault_code; completion_fault; queue_occupancy | UInt3; UInt4; UInt5 |
| Output | memory_request_bytes; memory_request_mask; memory_request_data | UInt3; Bits4; Bits32 |
| Output | accepted_steps; elapsed_cycles, active_cycles, stall_cycles; capture_cycles | UInt13; UInt64; UInt7 |

Ready/valid acceptance occurs only when both values are known one on an active
edge. A producer holds its payload until acceptance. `halted` and
`transport_halted` are identical aliases. A completion payload is meaningful
only while completion_valid is one; reset suppression is not a clearing event
for all payload registers until the reset edge occurs.

Reads transfer one byte with mask 1 and zero request data. Writes transfer four
bytes with mask 15; base/stride must be multiples of four. Each request requires
one response, held by the host until response-ready. A matching accepted, owned
response with status 0 succeeds and 1 is remote failure; a wrong global tag or
status 2/3 on that accepted response is a protocol fault. Outside the wait state,
response-ready is low and unsolicited responses are not accepted or poisoned.
Same-edge request/response completion is not required. Global tags start at zero and wrap modulo
2^32 on request acceptance. No next request accepts on the response-ACK edge.
Byte-range validation uses wide arithmetic before narrowing to UInt32.

## Ordering ownership and faults

Dispatch is strictly in descriptor-admission order with concurrent engine
execution and ordered held retirement. Caller IDs are not dependency tickets.
Latest-writer outcomes exclude stale physical data after a failed intended
generation. Physical whole-slot leases prevent conflicting engine access.
Fence waits for every older command to become terminal, not for its external
retirement ACK or success. A successful StoreC becomes terminal only after its
last host acknowledgement.

Host software publishes only fully visible descriptors. Consumer advancement
means atomic queue admission and permits reuse of that descriptor slot only.
It does not release host operand/output buffers still needed by accepted work.
Host alias dependencies, barriers and coherency remain the host's responsibility.
FIFO occupancy excludes the retirement table, dispatch head and held reader
packet. The latter has no command obligation before atomic admission.

| Command fault | Meaning |
|---|---|
| 0 | Success |
| 1, 2, 3 | Unsupported opcode; nonzero unused field; illegal dimensions |
| 4, 5 | Operand/dependency unavailable; result/dependency unavailable |
| 6, 7, 8 | Invalid stride; store alignment; aperture bounds |
| 9, 10, 11 | Remote memory failure; protocol failure; internal failure |
| 12, 13, 14, 15 | Descriptor version; reserved bits; dimension representation; cancellation |

Syntax priority is 12, 13, 1, 14; semantic preflight then checks unused fields,
dimensions, dependency/physical availability, stride, alignment and aperture.
Protocol failure wins over a remote failure for its owning active transfer.
Registered poison cancels unissued accepted packets with 15. Existing terminal
records are immutable; discovery-edge admissions remain obligations. Accepted
compute drains, and unfinished DMA siblings preserve committed progress.

Reader faults are separate: 1 alignment, 2 aperture, 3 publication, 4 remote and
5 protocol. Reader faults 1..4 stop fetching without canceling accepted queue
work. Reader-owned protocol failure poisons transport but cannot invent a
command ID/completion for a partial fetch. A sibling reader freezes without
manufacturing its own fault. Exact fault ownership and active engine precedence
remain specified in [PHASE6_RING_CONCURRENT.md](PHASE6_RING_CONCURRENT.md).

Progress counts committed load elements or successfully acknowledged store
bytes, not descriptor reads. A failing store may have partial host effects that
are excluded from progress. There is no rollback or atomic rectangle store.

## Counters and reset

Counters describe the latest inner-issued MatMul, not the retiring command.
They clear on inner issue and reset, survive non-compute commands/rejected
preflight and can change while an older completion is held. This profile ties
step-ready high: for a successful M/N/K command, accepted_steps and active_cycles
equal K+M+N-2, elapsed_cycles equals accepted_steps+1, capture_cycles equals M*N
and stall_cycles is zero. Dispatch, outer Issue, DMA and retirement delays are
excluded. These are modeled clocks, not physical throughput or a coherent
multi-register snapshot.

Reset assertion suppresses all ready/valid handshakes immediately; registers
clear on the synchronous reset edge. The host must flush actual old accepted
requests and responses before deassertion. Reset invalidates slot access and
all bounded command owners, but does not erase SRAM, undo host writes or
manufacture completions for interrupted commands.

The capability bridge, manifest and public port/type tests bind this contract
to the actual generator. Independent Verilator agreement, synthesis and named
formal safety/liveness results remain required before the Phase 6 proof claim.
