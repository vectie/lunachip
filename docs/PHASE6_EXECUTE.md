# FluxTile execute slice

`designs/flux_tile.execute_tile` constructs a standalone hardware slice with
synchronous operand memories, a single-command execute controller, and the
existing output-stationary INT8 systolic array. Its control, prefix tracking,
read addresses, operand qualifiers, counters, and accumulators are LunaWire
hardware nodes. The independent matrix oracle is used only by tests.

This port contract is provisional. It is not a frozen device ABI, command
ring, host-memory transport, DMA controller, dependency scoreboard, or complete
Phase 6 device. `PLAN.md` still owns the Phase 6 exit gate.

## Construction parameters

`execute_tile(rows~, columns~, max_reduction~)` accepts an elaborated shape of
1..8 rows and 1..8 columns and an operand-bank depth of 1..4096 elements.
Invalid values raise `ExecuteTileError::InvalidParameter` with the parameter
name, value, and limit. Each row owns one signed INT8 A memory; each column owns
one signed INT8 B memory. Memories use explicit single-clock, one-edge read
latency. No reset initialization of their data cells is assumed.

Each command can use a smaller active M/N/K than the elaborated capacity.
Only active row and column banks must be initialized. The controller zeros all
array accumulators for each legal command, and inactive cells remain zero.
Results are signed INT32, with fixed-width modular accumulation. The bound
K≤4096 means an INT8 matrix starting at zero fits exactly in INT32.

## Standalone ports

All handshake/control values are `Bits(1)`. The sole domain uses `clock` and
active-high synchronous `reset`.

| Inputs | Types and interpretation |
|---|---|
| `load_a_valid`, `load_a_row`, `load_a_index`, `load_a_data` | Bits1, UInt4, UInt13, SInt8; one A-bank write request. |
| `load_b_valid`, `load_b_column`, `load_b_index`, `load_b_data` | Bits1, UInt4, UInt13, SInt8; one B-bank write request. |
| `command_valid`, `command_rows`, `command_columns`, `command_reduction`, `command_id` | Bits1, UInt4, UInt4, UInt13, UInt32; one matrix request. |
| `step_ready` | Bits1; permits one logical wavefront step during Run. |
| `completion_ready` | Bits1; accepts the held terminal completion. |

| Outputs | Types and interpretation |
|---|---|
| `load_a_ready`, `load_b_ready` | Bits1; current request has a legal bank/index and the controller is Idle. |
| `command_ready` | Bits1; the controller is Idle and can accept a request. |
| `completion_valid`, `completion_id`, `completion_fault` | Bits1, UInt32, UInt2; stable terminal result identity and status. |
| `accepted_steps` | UInt13; accepted logical Run advances for the current command. |
| `elapsed_cycles`, `active_cycles`, `stall_cycles` | UInt64; the per-command counters defined below. |
| `accumulator_i_j` | SInt32 for every elaborated cell; architectural result when success completion is valid. |

Transfers occur on rising edges when both ready and valid are known one.
Command identity and dimensions latch on acceptance; later changing command
inputs do not affect an in-flight command. Loads are accepted only in Idle.
Clear, Run, and Done deassert both load-ready outputs and command-ready.

## Operand initialization and simultaneous requests

Each bank has a resettable initialized-prefix count. A ready write has a valid
bank, an index less than capacity, and an index no greater than its prefix.
Writing the current frontier appends one initialized element. Writing below
the frontier overwrites an existing cell without changing the prefix. A hole
above the frontier, an invalid bank, or a capacity-overflow index has ready
zero and never issues a memory write.

Command acceptance validates M/N/K and requires every active A/B bank's prefix
to be at least K. A legal command reads only that initialized range. Address
bounds are checked at the UInt13 request width before explicit conversion to
the memory's exact address width; address truncation is not a bounds policy.

An Idle load and command may both handshake on the same edge. The command
checks the old committed prefix counts: an append on its acceptance edge
cannot cure missing initialization and produces fault 2. The append itself
still commits. An overwrite of an already initialized cell on command
acceptance is visible to reads launched by the following Clear edge. No
combinational forwarding of prefix metadata is implied.

## State, read latency, and completion timing

The controller executes `Idle → Clear → Run → Done → Idle` for a legal command.
Acceptance enters Clear and resets per-command counters. The next edge clears
the full array and launches the first synchronous operand reads for logical
step s=0. It increments elapsed cycles by one, regardless of `step_ready`.
The following edge can consume the now-registered read results in Run.

Let s count accepted Run advances beginning at zero. A[i,k] enters its array
row at s=k+i, B[k,j] enters its column at s=k+j, and cell (i,j) accumulates that
product at s=k+i+j. Every accepted Run edge consumes prefetched data and
launches reads/qualifiers for s+1. Memory read enables, qualifiers, wavefront
state, and array state advance together. Inactive windows have valid zero.

When `step_ready` is zero in Run, the entire logical wavefront and prefetched
data/qualifiers hold. Physical clock time and stall counters still advance.
The last product reaches the last active cell after exactly `K+M+N-2` accepted
Run edges. That edge enters Done and exposes success completion. With no
stalls, elapsed cycles at completion equal `1+K+M+N-2`; the acceptance edge
itself is excluded.

Done holds completion valid, identity, fault, counters, and accumulators until
completion is accepted. Completion backpressure consumes no Run advances and
does not increment elapsed or stall counters. Acceptance of a completion
returns Idle; a command cannot also be accepted on that Done edge because its
pre-edge command-ready was zero.

## Faults and counters

`completion_fault` is 0 for success, 1 for invalid dimensions, and 2 for missing
initialized active operands. Invalid dimensions have priority when both checks
would fail. Dimension checks require 1≤M≤rows, 1≤N≤columns, and
1≤K≤max_reduction. A rejected command latches its identity and enters Done
directly, with all per-command counters zero. It neither clears previous
accumulators nor issues compute/read work.

Counters reset on every command acceptance and on reset. `accepted_steps`
and `active_cycles` both count accepted Run advances, including fill and drain
steps rather than only cycles with a multiply. `stall_cycles` counts Run edges
with step-ready zero. `elapsed_cycles` counts the one Clear edge plus every Run
edge, so `elapsed_cycles = 1 + active_cycles + stall_cycles` at successful
completion. Invalid completions have all four counters zero. Counters freeze
in Idle and Done; they are modeled clock counts, not a physical-frequency or
throughput measurement.

## Reset and evidence scope

Reset has priority in every state, including a paused Run or stalled Done.
It drops in-flight completion, clears control/counters, flushes operand
qualifiers and array state, and resets every initialized prefix. Memory data
cells remain unreset but cannot be consumed until their banks are reloaded.
An interrupted command receives no terminal completion after reset; this is
the provisional standalone reset rule, pending the future device generation
and cancellation contract.

Black-box tests compare every intermediate cell to the mathematical wavefront
and final results to the independent matrix oracle. They exercise rectangular
and 8×8 shapes, K=1, signed extremes, active subsets, prefix holes, reloads and
overwrites, same-edge loads/commands, dimension and initialization faults,
fill/drain stalls, changing busy inputs, completion backpressure, reset in
every state, exact counters, and deterministic IR/SystemVerilog artifacts.
Heavy proof and provenance gates follow integration of the complete portable
device boundary. This slice alone does not establish Phase 6 differential,
formal, synthesis, FPGA, timing, power, or physical implementation claims.
