# FluxTile portable load/execute/store draft

This document proposes the next implementation slice after `execute_tile`.
It is a provisional hardware interface, not ABI version 1 or a claim that
Phase 6 passed. `PHASE6_IMPLEMENTATION.md` and `PLAN.md` remain normative.
The immediate objective is one real, testable path:

```text
host memory --LoadA/LoadB--> existing synchronous operand banks
            --MatMul------> systolic registers --capture--> result SRAM
            <--StoreC------ result SRAM
```

Build this serial baseline first. The final Phase 6 product still requires the
ring/frontend, dependency scoreboard, decoupled engines, frozen ABI, and the
independent tool gates. One outstanding transfer is a correctness baseline,
not a promised throughput design. No host matrix calculation may implement
device execution or result storage.

## Reuse the existing graph

The available LunaWire builder supports synchronous memories, register handles,
explicit-width arithmetic, muxes, and ready/valid signals. It currently has no
public module-instance builder. Do not add hierarchy machinery just to compose
this slice.

Factor the body of `execute_tile` into a private signal-in/signal-out graph
builder in `designs/flux_tile`, called by both its existing public wrapper and
the new portable device wrapper. Private input/output records can hold wire
signals, returned ready/completion signals, and accumulator signals. Keep the
public standalone port order, node construction order, names, parameters, and
canonical bytes unchanged; capture its canonical digest before the refactor.
No public concrete wire-helper type is needed.

Reuse `execute_operand_banks`, the one-edge prefetch controller, and
`build_systolic_array`. The portable wrapper arbitrates their existing load
ports; it does not create a duplicate operand SRAM or another arithmetic path.
The wrapper alone publishes device completions, operand validity, and result
validity. The execute completion remains internal during result capture.

### First implementation step: isolated result-storage wrapper

Before the full transport wrapper, add a provisional `stored_execute_tile`
with the existing execute load/command ports and a real result SRAM. Its
successful completion becomes visible only after all active M*N result writes
commit; the private execute completion is held throughout capture. Invalid
execute completions skip capture and preserve previous SRAM bytes. The
standalone `execute_tile` canonical artifact remains unchanged.

Capture uses row/column counters and a static mux over the elaborated
accumulator signals. Write only active cells, to physical address
`row*elaboratedColumns+column`; do not compact by active N or initialize/write
inactive cells. Begin capture after the core completion is already visible,
never on its final Run edge. The final capture edge both commits the last
write and consumes the internal execute completion. External success is
visible after that edge.

Add these result-inspection ports:

| Inputs | Outputs |
|---|---|
| `result_read_valid` Bits1; `result_read_row`, `result_read_column` UInt4; `result_read_id` UInt32 | `result_read_ready` Bits1 |
| `result_response_ready` Bits1 | `result_response_valid` Bits1; `result_response_id` UInt32; `result_response_data` SInt32; `result_response_fault` UInt2 |

Read-ready is asserted only while a successful completion is held in Done,
reset is inactive, and no previous result response is pending. The read window
closes when completion is accepted: the caller reads all desired cells before
acknowledging that completion. A read request and completion acknowledgement
may both handshake on the final Done edge. Its response remains valid through
the transition to Idle, and pending response blocks command-ready until the
response is consumed. No new read or command accepts on that response-drain
edge in Idle; readiness uses pre-edge pending state.

Check `row<activeM` and `column<activeN` at full UInt4 width before physical
address truncation. An out-of-bounds read still accepts but returns held fault
1, zero data, and the requested identity, with no memory read. Legal reads
return fault 0. A fault completion does not open a result-read window, so this
wrapper needs no uninitialized-result fault encoding.

On a legal request acceptance edge, enable the synchronous SRAM read and
register response-pending, identity, and fault. The memory read-result register
and response metadata commit simultaneously; valid data is visible after that
edge. This is the declared one-cycle read latency, not an additional wait
state. Disable all further reads while response-pending is one so data remains
stable under response backpressure, including after completion acceptance.
Reset drops both held completion and pending read response and invalidates
result access; memory data itself remains unreset.

This narrow read window is an inspection contract for the isolated capture
slice. The full portable wrapper below instead owns result-slot validity and
uses the same SRAM read port for a later StoreC command. Do not freeze the
inspection-window rule as the final device ABI.

## Initial capacities and command ports

Use the same elaborated rows/columns in 1..8 and reduction capacity in 1..4096.
Start with exactly one A slot, one B slot, and one C slot. Add slot selection
only with the scoreboard. A and B reuse the existing per-row/per-column INT8
banks. C is one real synchronous `SInt(32)` memory of depth `rows*columns`.
Its physical address is `row*columns + column`, independent of the active N.
Use `ReadOld`, `HoldLast`, `Reject` multiwrite, and `Fault` bounds policies.

New construction entry point: provisional
`portable_tile(rows~, columns~, max_reduction~, host_bytes~)`. `host_bytes`
is an elaboration-time UInt64 in 1..2^32, an exclusive byte bound. This bound
is a modeled accessible aperture, not host virtual-memory isolation.

All signals use the existing rising-edge clock and synchronous active-high
reset. Control handshake values are `Bits(1)`.

| Command input | Type | Meaning |
|---|---|---|
| `command_valid` / output `command_ready` | Bits1 | One command handshake. |
| `command_opcode` | UInt3 | Draft LoadA=0, LoadB=1, MatMul=2, StoreC=3, Fence=4; others invalid. |
| `command_id` | UInt32 | Completion identity, latched on acceptance. |
| `command_rows`, `command_columns`, `command_reduction` | UInt13 each | Opcode-specific dimensions below; wider than M/N capacity so malformed values are representable. |
| `command_base`, `command_stride` | UInt32 each | Byte address and row stride for transfers; zero for MatMul/Fence. |
| `completion_ready` | Bits1 | Accept the held terminal completion. |

LoadA describes an M-by-K row-major host region: rows=M, columns=K,
reduction=0. LoadB describes a K-by-N row-major region: rows=K, columns=N,
reduction=0. MatMul uses rows=M, columns=N, reduction=K. StoreC uses rows=M,
columns=N, reduction=0. Fence has zero dimensions/base/stride. No flags,
dependency fields, ring entries, or serialized descriptor layout are frozen
here. All unused fields must be zero rather than silently ignored.

One command is outstanding, including completion publication. Command-ready
is zero during work and while a terminal completion is stalled. An accepting
completion edge cannot also accept another command. This gives the first
frontend an unambiguous, observable boundary before queues are introduced.

## Portable host-memory port

Use one unified request channel and one response channel, with exactly one
accepted but unanswered request at a time. Every read and write receives an
acknowledgement; a posted write is not completion.

| Device request output | Type | Meaning |
|---|---|---|
| `memory_request_valid` / input `memory_request_ready` | Bits1 | Request handshake. |
| `memory_request_write` | Bits1 | Zero for read, one for write. |
| `memory_request_address` | UInt32 | Actual byte address, not an aligned beat base. |
| `memory_request_bytes` | UInt3 | Exactly 1 for operand reads, 4 for C writes. |
| `memory_request_mask` | Bits4 | Exactly 0001 for reads, 1111 for writes. |
| `memory_request_data` | Bits32 | Store word little-endian; zero for reads. |
| `memory_request_tag` | UInt32 | Transaction sequence, unrelated to command identity. |

| Environment response input | Type | Meaning |
|---|---|---|
| `memory_response_valid` / output `memory_response_ready` | Bits1 | Response handshake. |
| `memory_response_tag` | UInt32 | Exact accepted request tag. |
| `memory_response_fault` | UInt2 | Draft 0=success, 1=remote failure; 2/3 invalid protocol. |
| `memory_response_data` | Bits32 | Read byte in bits 7..0; upper bits ignored. |

A request payload remains stable from valid assertion through acceptance;
thereafter it is not reissued. A response producer holds its payload until
accepted. Response-ready is asserted only in the response-wait state. A
response may be produced immediately after request acceptance, but must remain
valid through a later edge where response-ready is one: the device does not
require a combinational zero-cycle return path.

The transaction counter starts at known zero under reset and increments on
accepted requests only. It wraps modulo 2^32. Reuse is safe in this serial
baseline only because the environment owes exactly one response per request,
and no request issues before the previous response retires. Reset additionally
requires the explicit transport flush rule below. Do not rely on an unreset,
unknown persistent tag counter.

Byte reads support every address. Four-byte writes require base and stride
multiples of four. There are no bursts or arbitrary partial masks yet. A
future aligned bus shell translates these operations without changing their
byte-addressed meaning. Testbench storage is an external memory environment,
not an implementation of on-device banks or computation.

## Validate before issue

Command acceptance latches every field; validation is performed against those
latched values before any memory request, bank write, clear, or result capture.
Use separate Validate and operation states, keeping wide validation logic off
the valid/ready acceptance path. Invalid commands publish one exact fault.

For a transfer rectangle with R rows, C elements per row, and element size E
(1 for loads, 4 for stores), require positive legal dimensions and
`stride >= C*E`. Define in UInt64 hardware:

```text
row_bytes = C * E
end_exclusive = base + (R - 1) * stride + row_bytes
end_exclusive <= host_bytes <= 2^32
```

Zero-extend the validated UInt32 base/stride and UInt13 dimensions before
arithmetic. With the declared widths the maximum expression is below 2^46;
UInt64 operations cannot overflow. `mul_low` on UInt64 operands is therefore
exact here; no division/modulo or dynamic slice is required. Do not compute
the range in UInt32 and infer safety from its wrapped value. Only after this
check may the per-request address be truncated to UInt32. Use an exclusive
end so the legal last byte at 0xffffffff remains representable.

LoadA additionally checks M<=rows and K<=max_reduction. LoadB checks
K<=max_reduction and N<=columns. MatMul requires 1<=M<=rows, 1<=N<=columns,
1<=K<=max_reduction and exact valid loaded shapes A=(M,K), B=(K,N).
StoreC requires valid C with exact stored shape (M,N). Exact shapes are the
first baseline; subtiles are a later explicit extension, not accidental stale
bank-prefix reuse. Validate unused fields and opcode first, dimensions next,
operand/result availability next, and address/stride/alignment last. Preserve
this deterministic fault priority in tests.

## Hardware states and result publication

Load path:

```text
Idle -> Validate -> LoadRequest -> LoadWait -> LoadCommit
                         ^                        |
                         +---- next element ------+
                     final element -> Done
```

Invalidate the selected A/B slot only after successful validation, before the
first request. Iterate host elements in row-major order with hardware outer
and inner counters. Map A host (i,k) to bank i, index k; map B host (k,j) to
bank j, index k. A successful response is captured in a one-entry register;
LoadCommit drives the existing bank load port and waits for its handshake.
No cursor moves until that write commits. Mark the complete operand shape
valid only on the final committed element. Loads do not invalidate C.

Existing bank prefix counts need not be reset on each load: overwriting old
prefixes and appending new elements is supported already. Wrapper validity
prevents a failed reload's mixed data from being used. A successful later load
rewrites every element of its declared shape. Keep the standalone execute
core's prefix check as a local invariant, not a replacement for slot validity.

MatMul path:

```text
Validate -> ComputeIssue -> ComputeWait -> CaptureC -> Done
```

On validated issue invalidate C, send one request to the private execute
core, and tie its step-ready high for this SRAM-backed baseline. Hold execute
completion-ready low while waiting and capturing; this keeps its accumulator
signals stable. Capture one active INT32 cell per edge into C using a static
mux over the elaborated accumulator signals and row/column address counters.
After the last SRAM write commits, set C shape/valid and consume the execute
completion on that same edge. Only then publish external MatMul success.
Capture consumes M*N edges. It must never read final accumulators on the
final Run edge itself: those registers commit simultaneously, so capture
starts after the execute completion is visible.

Store path:

```text
Validate -> StoreRead -> StoreRequest -> StoreWait
                ^                           |
                +------ next element -------+
                     final acknowledgement -> Done
```

StoreRead launches one synchronous C read. Its one-edge read latency feeds
the subsequent held StoreRequest payload. The next element is not read until
the current request receives its matching successful acknowledgement. Store
completion is not published on request acceptance. C remains valid after a
store success or failure. A subsequent store can explicitly retry the whole
rectangle; the device itself does not retry automatically.

Fence completes after validation because acceptance is serialized and all
earlier commands and acknowledged stores already reached their terminal
completion handshake. This intentionally simple meaning must be extended,
not silently retained, when queues and overlap are introduced.

## Faults, side effects, backpressure, and reset

Completion outputs are held `valid`, `id`, `fault`, `bytes_completed`, and
`fault_address`; faults are provisionally UInt4 encodings documented beside
implementation. Keep preflight descriptor/dimension/availability/address
faults distinct from remote-memory, transport-protocol, and internal-execute
faults. Add no success path for unknown fault encodings.

Preflight faults have no bank, array, result-SRAM, or host-memory side effect
and preserve prior valid operands/results. Remote read failure stops the load:
earlier bank writes may have committed, but that operand slot remains invalid.
Remote write failure stops the store: previously acknowledged words committed;
the failing word may have committed any subset of its bytes. Never claim
rollback, atomic host stores, or a successful complete command. `bytes_completed`
counts only successfully retired load bank writes or acknowledged store bytes;
it excludes the failing request and does not assert it had zero side effect.

A response with the wrong tag or reserved status is a transport protocol
fault. Retire no new data, publish a fault, and enter link-fault lockout: no
further requests or commands until reset, even after completion acceptance.
There may still be an unresolved accepted request; ordinary command reuse
would make stale responses unsafe. Matching remote-fault responses, unlike
protocol faults, retire the outstanding request and permit later commands.

Reset suppresses requests, response-ready, and completions; resets all control,
tag, counters, operand validity, and C validity; and resets the execute core.
SRAM data cells remain unreset and inaccessible until reinitialized. An
interrupted command emits no post-reset completion. Already accepted host
writes are not rolled back, including a write interrupted before its response.

For this first slice reset is a **joint device/transport reset barrier**: the
shell/environment must flush old accepted requests and responses before reset
deassertion. A unilateral core reset with a still-live response channel is not
supported. Test this actual barrier, not fictional cancellation. Later board
shells or independent reset domains require an explicit epoch/cancel/drain
extension before integration; reset must never be advertised as safe without
one of those contracts.

## Implement and test in reviewable steps

1. Factor private execute graph construction; prove the public wrapper's
   canonical bytes and all existing tests unchanged.
2. Add real C SRAM and serialized capture/readback tests, including 1x1,
   rectangular, 8x8, inactive cells, held internal completion, and reset.
3. Add request/response sequencer plus wide rectangle validation. Test address
   and payload stability, tags, earliest response, long latency, remote faults,
   and lockout on protocol faults before connecting matrix commands.
4. Integrate LoadA/B mapping and slot validity, then the complete
   LoadA -> LoadB -> MatMul -> StoreC path with an independent byte-memory
   model and matrix oracle. Add Fence and exact completion/counter behavior.
5. Run the native phase gate, review the generated public interface, document
   measured modeled cycle counts, and commit. Then extend the descriptor/ring
   and scoreboard slices; freeze the ABI only after those paths work.

Highest-value integration cases are a non-square 3x2 result with K=5, distinct
negative/positive values that expose B transposition, padded host strides,
address 0xffffffff legal for a byte, a legal word ending at 2^32, an end bound
overflow that would appear small in UInt32, and a non-power-of-two K capacity.
Inject stalls at every request, response, bank-commit, and completion boundary.
Check actual final host bytes against the oracle, not just accumulator outputs.
Fail a middle load, reject MatMul on that invalid slot, reload successfully,
and prove no mixed result escapes. Fail a middle store and inspect its allowed
partial host state and progress count. Reset in every state with the transport
flush barrier, then execute a clean second workload with tag zero. These tests
exercise new behavior without adding a premature proof/provenance framework.
