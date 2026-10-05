# Fetched device replay for reader poison and joint reset

This is the next scoped implementation plan, not completed evidence. Reuse the
existing fixed-input trace, public-port collection, ResultProtocol, C++ harness
and typed audit. Add one predefined `generate_fault_reset_bundle()` fixture,
with no general fault-injection framework. Preserve all eleven artifacts of
both existing fixtures byte-for-byte.

## Owned reader response and accepted work

Use a 1x1 array, reduction capacity 64, host aperture 4096, ring base 3072,
depth four and q2 retirement. Preload and drain LoadA1 K16 from bytes 512..527
(ID 81) and LoadB1 K16 from 1280..1295 (ID 82). Then publish positions 2..4
together: LoadA0 K64 from 2048..2111 (ID 83), MatMul A1/B1 into C1 K16 (ID 84),
and Fence (ID 85). Slot zero may be reused only after setup consumer reaches
two. The Fence wraps to that slot but must never become a packet obligation.

Capture the actual accepted Fence-byte read at address 3072 with consumer
four. Hold its owned response until the new MatMul active counter is strictly
between zero and sixteen. Return the saved byte and fault zero, but tag equal
to the saved global tag plus one. On the real response handshake, require the
active counter to advance by one. An unsolicited response does not satisfy
this test. Derive all ownership and progress from saved requests, not live
request outputs after arbitration changes.

Require transport poison and halt, reader fault 5, reader and transport fault
address 3072, producer five and consumer four. No memory request may be
accepted after poison. Measure committed loader bytes L from saved successful
operand ACKs, require 0 < L < 64, and require ordered completions
`[83,15,L,0]` then `[84,0,0,0]`. Hold the oldest cancellation record while the
admitted compute drains, checking valid and every payload field on every edge.
Final compute counters must be accepted=active=16, elapsed=17, capture=1,
stall=0. After retirement, a bounded quiet window must show no Fence completion,
new DMA admission or consumer advancement.

The poisoned MatMul's completion and counters establish compute/capture
drainage, not oracle-checked arithmetic: poison prevents a later StoreC and
reset invalidates its result slot. Verify every host byte, including padding,
against the expected memory with only host-authored descriptor installations.

## Joint reset and pending transaction flush

After poisoned obligations drain, jointly reset hardware and flush the host's
pending/held transaction state. Preserve host bytes and lifetime request counts;
restart only the next global tag epoch at zero. Verify immediate reset
suppression of handshakes before the reset edge and cleared configuration,
ownership, faults and counters afterward.

Reconfigure origin zero and publish LoadA0 K64, ID 91. Wait for its actual
accepted operand request at address 2048, epoch tag 32 after the descriptor's
32 reads. Reset while that saved response remains pending, flush it before
release, and require no interrupted ID 91 completion. Reconfigure again and
publish MatMul A1/B1 into C1 K16 (ID 92) and Fence (ID 93). Require the first
request's epoch tag zero and ordered completions `[92,4,0,0]`, `[93,0,0,0]`:
reset invalidated the earlier operand slots. Require cleared poison and faults.

## Implementation and gate

Separate the host's next-tag epoch from lifetime transaction counts privately.
Keep response gating and the single wrong-tag override local to this fixture;
the existing trace row already carries reset and response tag. Keep every
source file below 500 lines. Reuse completion snapshots and artifact assembly.
Add explicit `export-fault-reset` and `audit-fault-reset` CLI commands through
the current private fixture selector and comparison path.

Run targeted native tests, deterministic bundle repetition and real mismatch
checks, then compare every existing fixture artifact byte. Only after the
owned poison and pending reset assertions pass should the trace be pinned and
run through strict Verilator lint/build/execute/audit. Finish the native slice
gate and retain actual results before recording evidence. This does not cover
loader/storer-owned protocol poison, remote failures, randomized sequences,
capacity/wrap, synthesis or named formal tasks.
