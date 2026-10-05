# FluxTile-0 implementation slices

This is the working Phase 6 design, beginning with the mathematical oracle and
the actual systolic hardware graph. Decisions below remain provisional while
slot ownership and engine overlap are developed. The normative Phase 6 exit criteria in
`PLAN.md` remain in force. A locally simulated arithmetic block does not imply
that the device, independent tool evidence, or the phase gate is complete.

## Implementation and assurance order

Implement one observable hardware slice at a time, test it through public
LunaWire and LunaWave APIs, and commit each coherent slice. Apply thorough
correctness testing to the behavior being introduced. Freeze descriptor fields,
state transitions, and timing only after integration has exercised them. Then
add the expensive formal, fault-injection, synthesis, and provenance work around
those stable contracts. Assurance is a phase exit requirement; its order should
minimize rework when a provisional architecture changes.

Existing language/CDC/formal tool gates remain reusable foundations. Phase 6
should reuse their evidence machinery. New gate formats are justified only by
a demonstrated gap that could accept incorrect hardware or misreport a result.
First-party automation belongs in MoonBit `.mbtx` scripts.

## Architectural decisions

The portable core uses one rising-edge clock and active-high synchronous reset.
A later host transport shell can use the established CDC primitives. Keeping
clock crossing outside the first compute slice makes arithmetic and protocol
failures distinguishable.

The target array is 8 rows by 8 columns. Smaller elaborated arrays from 1 to 8
rows and columns support focused testing and resource experiments; they are
the same generator, not separate datapaths. Operands are signed INT8 and
accumulators are signed INT32. Each matrix command starts with zeroed
accumulators. Fixed-width additions wrap modulo 2^32, consistent with the
language semantics. Initial legal workloads bound K to 4096, so zero-based
INT8 accumulation has magnitude at most 67,108,864 and never wraps. Supporting
accumulate-on-existing-output or larger K requires a separately reviewed ABI
extension and wraparound tests.

The array uses output-stationary processing elements. A travels right, B travels
down, and every element retains its own accumulator. A single `advance` freezes
all operand, valid, and accumulator registers together. Reset and explicit
clear override `advance`, flush operand-valid state, and zero accumulators.
This first control rule permits upstream memory stalls without partially
advancing the wavefront. Fine-grained lane backpressure can follow only when
a workload needs it and its ordering has a clear specification.

Scratchpad and accumulator memories are explicit LunaWire synchronous memories.
They inherit the documented read latency and collision rules. Array registers
are real IR state; host arrays in a testbench or the functional oracle are not
an implementation of accelerator storage or execution.

## Slice 6.1 — Mathematical oracle and streaming systolic array

The functional oracle accepts row-major A(M×K) and B(K×N) and returns row-major
C(M×N). It checks M and N in 1..8, K in 1..4096, exact array lengths, and every
operand in -128..127. It uses ordinary nested row/column/reduction loops with
wider host accumulation and explicit conversion to INT32. It imports no
simulator arithmetic and has no pipeline schedule. This independent form makes
it useful for detecting both arithmetic and scheduling defects in the RTL.

The streaming array accepts one INT8 value and one valid bit per active row on
its left edge, and one INT8 value and one valid bit per active column on its
top edge. The first slice exposes accumulators so tests can observe the actual
hardware state. A later execute controller owns matrix start/end, feed timing,
clear, and architectural result publication.

Let `s` count accepted `advance` edges starting at zero after clear. For
reduction index k, drive A[i,k] into row i at `s=k+i`, and B[k,j] into column j
at `s=k+j`. A cell (i,j) accumulates that product at `s=k+i+j`. Inputs outside
their active windows have valid zero. Therefore all results are complete after
`K+M+N-2` accepted advance edges, including the first at s=0. Paused physical
clock edges do not increase s. The controller must resume the same logical
feed index after a pause.

Tests observe completion after the final accepted edge, exercise signed
extremes, rectangular shapes, zero/identity matrices, and deterministic random
matrices, and compare every accumulator to the independent oracle. Schedule
tests include pauses during fill, active MAC work, and drain, plus clear/reset
while paused and a second matrix after clear. A separate timing check observes
individual cell changes at the expected accepted edge; final numeric agreement
alone cannot establish the wavefront latency.

Commit boundaries: independent oracle, graph construction plus focused
arithmetic tests, then schedule/pause/reset tests and deterministic elaboration
checks. Each commit should remain reviewable without requiring a device driver.

## Slice 6.2 — Execute controller and accumulator publication

Implemented as the provisional `execute_tile` generator. Its real synchronous
operand banks feed the shared systolic graph with a one-step-per-ready-edge
prefetch pipeline. The standalone contract, timing, fault rules, and reset
behavior are specified in [PHASE6_EXECUTE.md](PHASE6_EXECUTE.md). Native
black-box tests cover the controller and exact counters through K=4096. This
does not complete the host-memory transport or Phase 6 exit gate. Its shared
graph now also feeds the real result-SRAM wrapper described below.

Add a hardware controller that accepts a checked M/N/K request, clears the
array, fetches/skews row and column data, advances the wavefront, drains it,
and publishes a stable completion with a result identity. The first controller
can execute one command at a time. It must represent accepted feed index and
phase in hardware registers rather than calling a host matrix function.

The controller's result remains stable until accepted by downstream storage.
The memory read's one-cycle latency is visible in feed scheduling. An empty or
stalled input queue pauses the whole wavefront; result backpressure stalls
publication rather than recomputing a matrix. Count elapsed device cycles,
accepted advance cycles, and stalls separately so tests can explain timing.

Gate this slice with start/busy/completion transitions, exact minimum cycle
counts under zero stalls, varied read latency/backpressure, reset in every
phase, and multiple consecutive commands. Compare only published outputs with
the oracle, while retaining cell-level schedule tests from slice 6.1.

## Slice 6.3 — Scratchpad and memory request/response path

The result-storage portion is implemented by `stored_execute_tile`: one real
INT32 SRAM, active-cell capture before completion, persistent stored shape,
and a held one-edge read response. [PHASE6_RESULT.md](PHASE6_RESULT.md) specifies
its provisional timing, arbitration, and faults. The first serial
`portable_tile` host-memory request/response path now executes
LoadA/LoadB/MatMul/StoreC/Fence through the real banks and result SRAM.
[PHASE6_PORTABLE.md](PHASE6_PORTABLE.md) records its exact faults, partial-side-
effect rules, reset/flush contract, and independent byte-memory integration
tests. This baseline is not the queued, decoupled final device in slices 6.4/6.5.

Introduce bounded on-device operand storage and INT32 result storage. Fix bank
counts, capacities, and address units after the execute controller exposes its
actual access needs. Use a simple portable ready/valid memory port before
selecting an FPGA or PCIe transport. Requests carry operation, bounded byte
address, byte count/mask, and a transaction identity. Responses carry that
identity, data, and an explicit success/fault status.

Initially allow one outstanding transfer per controller. This makes ordering
and retry behavior inspectable before adding transaction queues. A testbench
memory model may return responses with deterministic variable latency and
backpressure; it is an environment, not a device implementation. Check address
range and arithmetic overflow before any request is issued. Reject invalid
transfers with a typed completion fault. Specify which bytes can have committed
when the environment reports a transfer failure; successful partial writes
must never be presented as a successful complete command.

Exercise read and write stalls, boundary addresses, unaligned requests under
the selected policy, response faults, masks, and reset with an outstanding
request. The first end-to-end workload is Load A, Load B, MatMul, and Store C.

## Slice 6.4 — Device ABI draft and descriptor frontend

The provisional format 0.1 is now implemented in the pure
`device/descriptor` codec and `queued_tile` hardware. Four 64-bit lanes accept
one atomic 32-byte packet into a bounded SRAM queue; one active head serializes
issue and holds ordered completions. Syntax checks precede narrowing and core
preflight. Protocol fault 10 closes admission and drains previously accepted
queued entries as fault 15 before requiring joint device/transport reset.
[PHASE6_FRONTEND.md](PHASE6_FRONTEND.md) specifies capacity, full/refill/wrap,
fault priority, and the independent host-byte integration tests. This is a
register-packet boundary, not a frozen ABI v1. The separate host-ring shell
described below now supplies this queue with fetched packets.

Publish device contracts in `device/`, independently of construction and
simulation packages. `designs/flux_tile` can consume them; `device` must never
import a simulator, the graph builder, LunaFlux, or LunaNexa. Hardware frontend
state and descriptor validation implement the same public contract.

The draft ABI is little-endian with explicit major/minor version, byte-addressed
host memory, and capability limits for matrix shape, K, scratchpad/result
capacity, ring depth, outstanding operations, and supported command flags.
Start with a fixed descriptor width aligned to the transport's natural beat;
the byte layout is frozen only after the frontend and transport tests agree.
No stable ABI number or register offset is assigned by this planning document.

Draft command semantics:

| Command | Required behavior |
|---|---|
| `LoadTile` | Copy a bounded rectangular INT8 operand region from host memory into a named operand slot, with explicit dimensions and source stride. |
| `MatMul` | Reference two initialized operand slots, check M/N/K compatibility, compute into a named INT32 result slot, and publish completion only after the final value is stored. |
| `StoreTile` | Copy a bounded INT32 result region to host memory with explicit destination stride. |
| `Fence` | Complete after all earlier accepted commands reach their terminal completion state and their successful stores have received acknowledgement. |

Every descriptor carries opcode, version, flags, command/completion identity,
and the fields used by its opcode. All reserved fields and unsupported flags
must be checked; unknown encodings produce an exact fault. Validation is
all-before-issue for dimension, slot, address, stride, and dependency errors.
Memory response faults discovered after issue have their own documented
termination rule. The first ABI does not promise cancellation or atomic host
memory stores.

Use monotonic producer/consumer counters for a bounded ring and expose the
chosen wrap/overflow behavior explicitly. Commands become accepted when the
frontend commits a valid ring entry, not when software writes an intermediate
descriptor beat. Completions have one terminal status per accepted identity and
remain stable under completion-queue backpressure. Reset invalidates in-flight
work under a documented reset generation, so stale completions cannot match a
new command by accident.

Test encoder/decoder golden bytes, reserved bits, truncated descriptors,
ring-full/ring-empty/wrap, malformed commands, exact typed faults, and stalled
completion publication. ABI major version 1 is assigned only when these rules
and the complete command path are stable.

### Host ring implementation

The standalone `descriptor_ring_reader` validates ring base/capacity/aperture
in UInt64 before issuing reads, fetches a complete 32-byte entry through the
existing portable tagged request/response contract, and holds four Bits64 lanes
until the consumer accepts the packet. The integrated `ring_tile` connects it
to the command queue and real load/compute/store path through one shared bus.
Ring consumption advances only on packet acceptance, never on a partial fetch
or command completion. Malformed descriptor syntax remains the queued
frontend's responsibility. [PHASE6_RING.md](PHASE6_RING.md) specifies the
standalone reader and [PHASE6_HOST_RING.md](PHASE6_HOST_RING.md) specifies
shared ownership, poison, and cancellation in the composed device.

Specify bounded producer/consumer accounting, wrap, failed-fetch behavior,
and the joint reset barrier before implementation. Start host-ring depths at
2/4/8/16: low consumer bits then select an entry consistently across UInt32
counter wrap. The existing descriptor FIFO's general-depth support remains
separate. Check each modulo-2^32 producer advance against available capacity;
do not use `wrapping_count % general_depth` without a reviewed origin rule.
The host publishes only after bytes are visible and may reuse an entry only
after consumer advancement. A failed partial fetch has no reliable command ID:
hold a sticky ring fault/address, preserve consumer, and require joint reset
instead of manufacturing a descriptor completion.

Independent native tests cover actual fetched bytes, ring-index/counter wrap,
empty/full producer publication, stalled packet publication, partial-fetch
faults, and reset without replacing hardware with a host queue. The private
shared-bus arbiter locks stalled payloads, fairly selects transactions, and
validates global response tags before restoring the owner's local identity.
The integrated shell exposes only one memory port. Existing evidence machinery
is reused; no final ABI offsets or independent RTL gate pass are assigned.

### Next reviewable implementation boundary

The standalone `slotted_execute_tile` now supplies two real A/B bank sets and
two persistent C SRAMs around one compute/capture engine. Public-port tests
demonstrate unrelated operand loads and result reads during Run and capture,
with explicit source/destination ownership and unchanged legacy canonical
goldens. [PHASE6_SLOTS.md](PHASE6_SLOTS.md) records this provisional contract.
The direct `slotted_portable_tile` now connects host loads and stores to both
slots by reusing the serial transfer controller, with latched selectors and
authoritative complete-load validity/exact shapes. Six independent host-byte
tests and a deterministic artifact check pass; its contract is in
[PHASE6_SLOTTED_PORTABLE.md](PHASE6_SLOTTED_PORTABLE.md). The fetched-ring device
still uses the serial, single-slot portable engine.
The next boundary is concurrent host integration: independent transfer engines,
bounded dispatch/retirement with dependency/failure propagation, and a separately
versioned descriptor admission path with explicit slot references. Serial
host-connected storage isolation alone does not complete slice 6.5 or freeze
the ABI; no new assurance framework is introduced.

## Slice 6.5 — Dependency scoreboard and decoupled engines

After one-command execution works, separate load, execute, and store hardware
controllers behind bounded queues. A scoreboard owns operand/result slot
availability and outstanding command dependencies. Begin with declared slot
ownership and in-order issue; permit overlap only when there is no read/write
or write/write conflict. Dependency identities must carry enough generation
information to avoid aliasing after ring reuse or reset.

Tests deliberately create RAW, WAR, and WAW conflicts, full queues, simultaneous
completions, and long-lived memory stalls. Verify every accepted command reaches
exactly one terminal state under a fair memory environment. Failure propagation
to dependents and `Fence` is explicit. Add counters for elapsed cycles, array
advance/MAC cycles, load/execute/store stalls, transferred bytes, successful
commands, and faults; define reset, saturation/wrap, and snapshot semantics.

## Slice 6.6 — Frozen Phase 6 gate

Freeze the observable ABI, accumulator semantics, memory policy, command fault
rules, and counters once the complete path passes functional integration.
Then use pinned Verilator for cycle-by-cycle agreement at the device boundary
and pinned Yosys for the supported emitted artifact. Exercise random legal
matrices, signed edge values, variable memory latency, command/completion
backpressure, and injected invalid descriptors. Record deterministic seeds and
retain minimized replay data for mismatches.

Formal tasks cover bounds before issue, no illegal command issue, queue safety,
dependency ordering, stable stalled payloads, exactly-once completion, and
eventual completion under named fairness assumptions. Safety and liveness
claims name their tasks, engines, assumptions, and bounds. A bounded result is
not an unbounded proof. Heavy artifact closure/provenance follows this stable
gate and reuses existing tooling rather than growing ahead of the design.

Phase 6 passes only when all normative `PLAN.md` gates pass. Runtime counters
measure modeled device cycles; they do not imply frequency, area, power,
physical RAM mapping, FPGA execution, or fabricated-silicon performance.
