# FluxTile provisional descriptor and queued frontend

This slice adds a bounded, serial device frontend to the existing portable
engine. It is a provisional simulation contract, **not a frozen device ABI**,
a host command-ring fetcher, a dependency scoreboard, or a full Phase 6 pass.
The independent RTL, synthesis, and named formal gates remain separate work.

## Descriptor 0.1

The public `device/descriptor` package owns the software codec. A descriptor
is exactly 32 bytes, little endian. The hardware accepts all four 64-bit lanes
atomically on one rising edge; there is no streaming assembly or partial lane
acceptance. Lane 0 contains bytes 0 through 7, with byte 0 least significant.

| Bytes | Field |
| --- | --- |
| 0 | Major version, exactly 0 |
| 1 | Minor version, exactly 1 |
| 2 | Opcode: LoadA 0, LoadB 1, MatMul 2, StoreC 3, Fence 4 |
| 3 | Reserved, zero |
| 4..7 | Command ID, UInt32 |
| 8..9 | Rows, UInt16 on wire, maximum representable 8191 |
| 10..11 | Columns, UInt16 on wire, maximum representable 8191 |
| 12..13 | Reduction, UInt16 on wire, maximum representable 8191 |
| 14..15 | Flags, zero |
| 16..19 | Base byte address, UInt32 |
| 20..23 | Row stride in bytes, UInt32 |
| 24..31 | Reserved, zero |

The codec checks syntax, not dynamic operand/result availability, configured
array shape, stride/alignment, or the host aperture. Those checks remain in
the real portable engine. Opcode-specific dimensions and unused fields are
described in [the portable contract](PHASE6_PORTABLE.md).

## Public generator and boundary

`queued_tile(rows~, columns~, max_reduction~, host_bytes~, queue_depth~)`
returns a real hardware module. Array/capacity/aperture limits remain those
of `portable_tile`; queue depth is 2 through 16. Invalid queue depths raise
`QueuedTileError::InvalidQueueDepth` before construction.

| Signal | Direction/type | Meaning |
| --- | --- | --- |
| clock/reset | Input Clock/Reset | Same synchronous reset domain as the core |
| descriptor_valid | Input Bits1 | Producer offers an entire descriptor |
| descriptor_lane_0..3 | Input Bits64 each | Atomic descriptor payload |
| descriptor_ready | Output Bits1 | Acceptance is valid AND ready on an edge |
| queue_occupancy | Output UInt5 | Queued descriptors, excluding the active head |
| halted | Output Bits1 | Transport unavailable until joint reset |

Memory request/response, completion, and compute-counter ports are unchanged
from the portable engine. Completion fault remains UInt4, adding syntax faults
12 through 14 and queued transport-unavailable fault 15. IDs are opaque raw
UInt32 values; duplicate IDs are permitted and ordering never depends on ID.

## Queue and completion ordering

The queue uses four same-depth synchronous 64-bit FIFOs with shared push/pop
handshakes, not a software queue. One head slot owns the currently decoded,
executing, or held-completion command. Thus maximum accepted but unresolved
capacity is `queue_depth + 1`, once the head has been acquired. Occupancy alone
does not count that head.

An empty queue does not bypass: an enqueue first commits to FIFO storage; a
later edge may pop it, and the synchronous read is captured into the head on
the following edge. A full FIFO may pop and push on the same edge using
`ReadOld`, preserving the oldest descriptor before replacing its slot.

No later head is acquired until the current external completion is
acknowledged. Completion payload is stable under backpressure. An external
completion ACK empties the head; only a later edge may pop the next queued
descriptor. The frontend captures the core completion before acknowledging
the core, so clearing the inner completion cannot change the outer payload.
Descriptors may still enqueue during an ordinary held completion if there
is FIFO capacity. Offered payload must remain stable while valid and not ready.

## Validation and faults

Malformed descriptors are accepted when space exists and reported in queue
order; rejection is not an admission-side diagnostic. Syntax priority is:

1. Fault 12: unsupported version.
2. Fault 13: any reserved byte or flags bit is nonzero.
3. Fault 1: unsupported full eight-bit opcode.
4. Fault 14: any UInt16 dimension has bits above UInt13 set.
5. Existing portable preflight priority and faults 1 through 11.

Every syntax failure echoes the raw ID from bytes 4..7, with zero completed
bytes and zero fault address, and issues no host transaction. Syntax checks
occur before narrowing opcode or dimensions. A malformed descriptor cannot
become a different legal command by truncation.

An ordinary remote fault 9 completes its command and does not halt the queue;
later accepted descriptors still execute, observing the portable engine's
documented invalidated operand slots and preserved results.

## Transport lockout and reset

When the inner engine reports protocol fault 10, the frontend closes admission
on observing that fault and latches `halted`. The triggering command completes
first with fault 10 and its failing request address. All other previously
accepted descriptors drain in FIFO order as fault 15, preserving raw IDs but
with zero progress/address. Fault 15 takes precedence over their syntax: no
cancelled descriptor is decoded into a new transaction. An enqueue accepted
on the fault-discovery edge belongs to this cancelled prefix as well.

After the cancelled queue drains, admission remains closed and no additional
completion or memory request is produced until reset. Reset aborts the head,
held completion, and all queued descriptors without manufacturing abort
completions. It clears operand/result validity, counters, and the halt latch.
FIFO/SRAM cell contents need not reset because their validity state does.

Reset is the same **joint device/transport barrier** as the portable engine:
discard old pending requests/responses before releasing reset. Resetting only
the core is not permission to deliver a stale response later. Already accepted
host writes are not rolled back by either kind of reset.

## Independent tests and remaining gate

Black-box frontend tests drive only public ports through LunaWave. They reuse
the existing sparse byte-memory environment, which answers actual observed
transactions with deterministic latency/backpressure, checks stable requests,
and never implements the device datapath. A padded 3x2, K=5 workload queues
LoadA, LoadB, MatMul, StoreC, and Fence; final host bytes are checked against
the independent matrix oracle, with padding untouched.

Focused protocol coverage includes depth-three full refill/wrap, no empty
bypass, opaque raw IDs and lane snapshots, syntax priority/full-width checks,
held completion, protocol lockout with same-edge admission, cancellation of
malformed queued commands, and real transport flush on reset. Artifact tests
check deterministic IR/SystemVerilog, queue-memory structure, and checked
queue limits. A fixed pre-frontend portable digest guards internal factoring.

These are simulation checks, not formal queue-safety or eventual-completion
proofs. A future stable integrated design still needs independent RTL
differential evidence and the named Phase 6 gates. A fetched host ring,
dependency scoreboard, and decoupled execution are intentionally later slices.
