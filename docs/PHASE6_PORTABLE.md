# FluxTile serial portable transport slice

`portable_tile(rows~, columns~, max_reduction~, host_bytes~)` is the first
complete serial host-memory-to-matrix-to-host-memory hardware path. It reuses
the execute operand banks, systolic graph, and stored-result SRAM. Command
validation, transaction tags, cursors, operand/result validity, completion
state, and all memory requests are LunaWire hardware. The byte-memory model in
tests represents the external environment; it does not perform matrix
computation or implement the device's storage.

The interface is provisional and follows `PHASE6_TRANSPORT_DRAFT.md`. It has
one A slot, one B slot, one C slot, and one outstanding memory transaction.
It does not yet provide the ring/frontend, dependency scoreboard, decoupled
engines, frozen ABI, or complete Phase 6 independent tool gate required by
`PLAN.md`. Existing standalone execute and stored-execute canonical artifacts
remain fixed across private graph factoring.

## Commands and completion

Construction accepts rows/columns in 1..8, reduction capacity in 1..4096, and
the exclusive host byte aperture in 1..2^32. Shape failures retain
`ExecuteTileError`; an invalid aperture raises
`PortableTileError::InvalidHostBytes`. The aperture is a modeled address bound,
not host virtual-memory isolation.

The command input fields are valid Bits1, opcode UInt3, identity UInt32,
rows/columns/reduction UInt13, and base/stride UInt32. Acceptance latches every
field. All requests use the single rising-edge clock and active-high
synchronous reset.

| Opcode | Meaning and dimensions |
|---|---|
| 0 `LoadA` | Row-major M×K INT8 region, rows=M, columns=K, reduction=0. |
| 1 `LoadB` | Row-major K×N INT8 region, rows=K, columns=N, reduction=0. |
| 2 `MatMul` | M×N result from exactly loaded A(M,K)/B(K,N); rows=M, columns=N, reduction=K; base/stride zero. |
| 3 `StoreC` | M×N INT32 stored result with matching C shape; reduction=0. |
| 4 `Fence` | All dimensions/base/stride zero. |

Unused fields are checked rather than ignored. The serial frontend accepts no
new command until the held completion is acknowledged. A completion-drain
edge cannot also accept a command because pre-edge command-ready is zero.

Completion fields are `completion_valid` Bits1, `completion_id` UInt32,
`completion_fault` UInt4, `completion_bytes_completed` UInt32, and
`completion_fault_address` UInt32, with input `completion_ready` Bits1. They
remain stable during backpressure. Byte progress counts retired bank writes
for loads and successfully acknowledged host bytes for stores. MatMul and
Fence report zero transfer bytes. Preflight/internal fault addresses are zero;
remote/protocol failures report the failing transaction's actual byte address.

## Validate before issue

Accepted descriptors enter a separate validation state before any memory
request, operand write, array clear, or result capture. Fault priority is
opcode, unused fields, dimensions, operand/result availability, stride,
alignment, then aperture bounds.

| Fault | Meaning |
|---|---|
| 0 | Success. |
| 1 | Unsupported opcode. |
| 2 | Nonzero unused fields. |
| 3 | Invalid dimensions. |
| 4 | Missing or mismatched operand shapes. |
| 5 | Missing or mismatched result shape. |
| 6 | Stride smaller than a complete row. |
| 7 | Unaligned INT32 store base or stride. |
| 8 | Transfer exceeds the host aperture. |
| 9 | Matching remote-memory failure. |
| 10 | Wrong response tag or reserved response status. |
| 11 | Internal execute/result-response failure, including nested identity mismatch. |

For R rows, C elements per row, and element size E (1 for loads, 4 for
stores), hardware first zero-extends fields to UInt64 and checks
`base + (R-1)*stride + C*E <= host_bytes`, together with `stride >= C*E`.
The chosen field bounds keep this arithmetic below 2^46. It is evaluated
before narrowing individual requests to UInt32, so a wrapped UInt32 end cannot
appear legal. Byte 0xffffffff and an aligned word ending exactly at 2^32 are
legal when the aperture is 2^32. Four-byte stores require aligned base/stride.

Rejected preflight commands preserve all old valid slots and have no side
effect. Successful validation of a load invalidates only its selected A/B
slot; full completion makes that exact shape valid. A partial failed reload
leaves the selected slot invalid even if earlier prefix writes committed.
Old initialized bank prefixes never substitute for exact wrapper shape
validity. Loads, including failed loads, preserve previous C.

## Memory transactions and compute/store order

The request channel outputs valid Bits1, write Bits1, byte address UInt32,
bytes UInt3, mask Bits4, data Bits32, and tag UInt32. Read requests use bytes=1,
mask=0001, data=0. Write requests use bytes=4 and mask=1111 with a little-endian
INT32 word. The environment supplies request-ready and responses containing
valid, tag, fault UInt2, and data Bits32; the device returns response-ready.

Every request remains stable through its ready/valid handshake. Its tag
increments only on request acceptance and is distinct from command identity.
Exactly one transaction can remain unanswered. The earliest response can be
presented immediately after request acceptance, but the environment must hold
it until the subsequent wait state asserts response-ready. No combinational
zero-cycle response is required. Status 0 is success, 1 is a remote failure,
and 2/3 are protocol faults. Tags must exactly match the accepted request.

Load responses commit one byte into the appropriate bank before the next
host element issues: A(i,k) maps to bank i/index k, B(k,j) to bank j/index k.
MatMul invalidates C only after validation, issues the existing execute core,
and advances the SRAM-backed wavefront without transport stalls. The execute
completion holds accumulators stable while M×N capture writes commit. External
MatMul success appears only after the final write, with the exact stored shape
marked valid.

Store launches a synchronous C read, then holds that word in the request
state. It reads no next element until the current word's matching success
acknowledgement. Its completion follows the final acknowledgement rather than
request acceptance. C remains valid after store success or failure, permitting
an explicit whole-rectangle retry. The device does not retry automatically.
Fence completes after validation because all earlier commands are serialized
and all successful stores have already received acknowledgement.

Compute counters retain their execute/capture meanings. Loads, stores, and
Fence and preflight faults retain the last MatMul counters; the next validated
and issued MatMul or reset clears them.
Transport stalls change overall command duration but do not retrospectively
inflate accepted array steps or compute/capture counters.

## Failures, reset, and evidence scope

Remote failure stops the current transfer. Successfully retired load bytes or
acknowledged store words remain committed. A failing store word may have
committed any subset of its bytes; byte progress excludes that transaction and
does not promise that it had no effect. There is no rollback or atomic-store
claim. A matching remote failure retires the outstanding transaction and
allows later commands.

Wrong tags and reserved statuses publish fault 10 and enter transport lockout.
Completion can be acknowledged, but no further command/request accepts until
reset. A response discrepancy can leave an unresolved request, so merely
reusing the command ring or identity would be unsafe.

Reset is a joint device/transport barrier. It suppresses requests,
response-ready, and completions; clears control, tags, counters, and slot
validity; and resets the execute core. The environment must flush accepted old
requests/responses before deassertion. Memory cells remain unreset and
previously performed host writes are not rolled back. Interrupted commands
produce no new completion. Independent core reset without a transport flush
is outside this provisional contract.

Independent integration tests answer observed requests with a sparse byte
memory and deterministic stalls/latency. They compare final host words to the
matrix oracle for padded non-square and 8×8 workloads, exercise little-endian
signed values and smaller repeated workloads, aperture boundaries and rejected
wraparound descriptors, exact faults and no-issue validation, failed reloads,
partial stores and explicit retry, tag/status lockout, real reset flushes, and
deterministic IR/SystemVerilog with no duplicated memories. This establishes
only the named local construction/simulation evidence; Phase 6 independent
RTL, formal, synthesis, FPGA, and physical performance claims still require
their later gates.
