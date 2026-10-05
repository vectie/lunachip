# FluxTile stored-result slice

`stored_execute_tile(rows~, columns~, max_reduction~)` combines the existing
execute graph with one synchronous signed INT32 result SRAM and a serialized
inspection read port. The SRAM, capture cursor/mux, result shape/validity,
request metadata, and ready/valid control are real LunaWire hardware. Tests use
the independent mathematical oracle only to check the device's observed data.

This is a provisional standalone hardware contract. The complete portable
load/execute/store path, descriptor/ring frontend, scoreboard, device ABI, and
Phase 6 independent tool gate remain later slices. The corresponding transport
design is in `PHASE6_TRANSPORT_DRAFT.md`; `PLAN.md` retains the phase exit gate.

## Storage and compute composition

The wrapper uses the same rows/columns limits of 1..8 and reduction capacity of
1..4096 as `execute_tile`. It shares the private execute graph rather than
duplicating operand banks or matrix arithmetic. `execute_tile` keeps its
standalone public ports and canonical artifact unchanged by the composition
refactor; a pre-refactor 2×3, capacity-5 canonical digest regression checks this.

The result SRAM has depth `elaboratedRows × elaboratedColumns`, type SInt32,
one-edge read latency, `ReadOld` collision semantics, disabled-read hold,
single-write rejection, and enabled out-of-bounds faults. Cell (i,j) lives at
physical address `i × elaboratedColumns + j`. The active command's N does not
change this physical stride. Only its active M×N cells are written; inactive
cells retain old bytes but cannot be read as part of the latest valid result.

Legal command acceptance invalidates the previous result's architectural
validity and starts the existing clear/run sequence. The array's last Run edge
finishes arithmetic but does not publish external completion. Starting at the
next edge, the wrapper captures one active accumulator per edge in row-major
order. The internal execute completion remains held while capture reads the
stable accumulators. The last capture edge commits its SRAM write and consumes
the internal completion. External success completion and valid stored shape
become visible after that edge.

With total accepted Run steps `T=K+M+N-2`, no compute stalls, and M×N result
cells, successful completion appears `1+T+M×N` edges after command acceptance.
Compute pauses add their stalled Run edges. `step_ready` cannot pause capture;
it controls the array's logical wavefront only. Result capture does not begin
on the final Run edge, where accumulators still have old pre-edge values.

The existing `accepted_steps`, `elapsed_cycles`, `active_cycles`, and
`stall_cycles` counters keep their execute semantics and freeze after compute.
`capture_cycles` UInt7 starts at zero on every acceptance and counts committed
result writes, reaching exactly M×N on success. Capture and completion/read
backpressure do not inflate compute elapsed cycles. These counters describe
the simulated schedule and do not assert physical clock frequency or memory
technology.

Invalid dimensions or missing operand initialization produce the existing
fault 1 or 2 completion directly on command acceptance. They skip clear,
compute, and capture, leave capture/compute counters zero, and preserve any
previous valid stored result and shape. They cannot turn uninitialized result
data into an accessible result.

## Result-inspection ports

All existing execute inputs/outputs remain, with these additional channels:

| Inputs | Types |
|---|---|
| `result_read_valid` | Bits1 |
| `result_read_row`, `result_read_column` | UInt4 each |
| `result_read_id` | UInt32 |
| `result_response_ready` | Bits1 |

| Outputs | Types |
|---|---|
| `result_read_ready` | Bits1 |
| `result_response_valid`, `result_response_id` | Bits1, UInt32 |
| `result_response_data`, `result_response_fault` | SInt32, UInt2 |
| `capture_cycles` | UInt7 |

Read-ready is one in outer Idle or held Done when reset is inactive and no
response is pending. Compute and Capture accept neither result reads nor
commands. Result validity and shape survive completion acknowledgement.
A read request takes priority over a command in Idle. While a response is
pending, neither a new read nor a new command can be accepted, including its
response-drain edge; readiness uses the old pending state.

An accepted legal read launches the synchronous SRAM read and latches pending,
identity, and fault metadata on the same edge. The memory read-result register
and response metadata commit together; response valid and data are visible
after that one edge. There is no second hidden response-latency state. Read
enable is then zero until the pending response is consumed, so data and
metadata stay stable under response backpressure or changing request inputs.

Fault priority is missing valid result first (fault 2), then a row/column
outside the latest stored active M/N (fault 1), otherwise success (fault 0).
Bounds are checked at full UInt4 width before narrowing the physical address
to the SRAM's exact address width, including non-power-of-two depths. Faulting
reads still accept and publish the requested identity, zero data, and the
exact fault, with no SRAM read operation.

A Done completion and a read request may handshake together. The completion
returns the wrapper to Idle, while the read response remains pending and
stable. Pending response does not suppress the separate completion-valid
channel. Completion can also be acknowledged while an earlier response is
stalled; command-ready remains zero until that response retires.

## Reset and verification scope

Synchronous reset cancels compute, partial capture, held completion, and
pending result response. It resets control/counters and invalidates the stored
result and operand initialization. SRAM bytes remain unreset but cannot be
returned after reset until a later successful command has finished capture.
A legal read request during reset does not handshake. No completion is owed
for an interrupted command under this standalone reset rule.

Black-box tests read SRAM responses and compare them with the independent
matrix oracle for scalar, rectangular, 8×8, signed-extreme, and smaller active
subtile workloads. They check fixed physical stride, exact compute/capture
latency and counters, compute stalls, read/completion backpressure, read
priority, simultaneous completion/read acceptance, full-width bounds faults,
missing results, invalid-command preservation, resets in compute/capture/Done
and with a pending response, and deterministic IR/SystemVerilog with exactly
one additional memory. These are local construction/simulation checks;
Phase 6 differential, formal, synthesis, FPGA, physical-memory, and timing
claims require their later named gates.
