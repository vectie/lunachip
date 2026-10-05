# Provisional two-slot host-memory engine

This is the next implementation contract, not completed evidence.
`slotted_portable_tile(rows~, columns~, max_reduction~, host_bytes~)` connects
the existing acknowledged host-memory transfer controller to the real
two-slot storage in `slotted_execute_tile`. It remains serial: one accepted
command and one outstanding memory transaction. This slice establishes
host-connected slot isolation and successful-load metadata before concurrent
dispatch. It must not claim load/compute/store engine overlap.

## Boundary and ports

Retain all [portable engine](PHASE6_PORTABLE.md) command, completion, memory,
and counter ports, widths, fault priorities, clock/reset and progress rules.
Add UInt1 command inputs `command_a_slot`, `command_b_slot`, and
`command_c_slot`. All three latch on command acceptance; live changes cannot
redirect a transfer or computation. Exactly two physical slots exist for each
operand and result. The module parameter `slot_count` is 2.

LoadA uses A selection and requires B/C selections zero. LoadB uses B selection
and requires A/C zero. MatMul uses all three. StoreC uses C selection and
requires A/B zero. Fence requires all selections zero. A nonzero unused
selection produces existing fault 2 before dimensions/availability/address
checks and before any request or storage effect. Completion identity remains
the accepted caller ID; no new completion selectors are needed by a serial
one-command interface.

This is a direct command-port prototype, not a descriptor ABI change. Keep
draft descriptor 0.1 encoding, reserved-byte rejection, and all existing
portable/queued/ring constructors unchanged. Explicit descriptor slots will
require a separately versioned format and separate admission path later.

## Authoritative metadata and effects

Each physical A/B slot has a wrapper-owned valid bit and exact loaded shape.
Prefixes in the underlying SRAM banks prove physical initialization, not a
successful complete host load. MatMul must pass selected valid/shape checks
before issuing the core. Old prefixes cannot make an incomplete reload legal.

Successful validation of LoadA or LoadB invalidates only its selected slot.
The final committed byte publishes the exact shape and validity. A matching
remote failure leaves that selected slot invalid and preserves every other
slot and both C results; already committed bytes are not rolled back.
Preflight rejection invalidates nothing and emits no memory request.

Selected C metadata is invalidated only after successful MatMul validation
and published after successful complete capture. StoreC requires that selected
valid exact shape. Store success/failure preserves both C results, permitting
whole-rectangle retry. Loading sources never invalidates an older C.
The wrapper owns successful host-operation metadata; the stored core owns
physical result-read visibility. These are distinct responsibilities, not two
independently writable copies of one scoreboard.

Source/destination selectors remain stable throughout validation, transfer,
core issue, capture, reads, and held completion. Existing per-transaction tags,
partial progress, remote/protocol faults, transport lockout, and joint reset
flush rules apply unchanged. Reset clears all slot metadata and core visibility
without erasing SRAM or undoing prior host writes. Interrupted commands do not
produce manufactured completions.

## Shared implementation, not duplicated engines

Reuse the existing portable state machine, request arithmetic, event decoding,
cursor, progress and fault logic. Introduce private construction seams for
selected metadata lookup/update and core construction at existing allocation
positions. The default branch must preserve old canonical IR allocation
order and goldens. The new branch allocates the two-slot metadata and builds
`build_slotted_graph` with latched selections. Do not copy the portable
controller or create a second host-side device model.

Metadata updates remain one-driver register transitions. Selected lookup
signals are pure muxes. A future dispatch/retirement scoreboard may replace
this private serial metadata owner, but no generation tickets or capability
ABI should be added before concurrent admission needs them.

## Functional validation before the next boundary

Use observed acknowledged host requests and an independent byte-memory/matrix
oracle. Verify two distinct persistent C results, mixed A/B selections,
selector latching under stalls and held completions, exact smaller-shape
reloads, selected failed reload invalidation with other slots preserved,
unused-selector fault priority/no issue, selected StoreC and retries, and
joint reset clearing every slot. Include padded signed rectangular matrices
and a maximum array case. Existing legacy goldens must remain unchanged.

Require deterministic canonical round trips and local SystemVerilog emission,
separate memories, and one array's multiply nodes. Targeted strict native
checks precede the existing repository phase gate at the completed slice.
These tests support local construction/simulation claims only. Concurrent
engines, dependency generations, ordered in-flight retirement, slot-bearing
descriptors, ABI freeze and independent RTL/synthesis/formal gates remain
subsequent work. No new assurance framework is required for this slice.
