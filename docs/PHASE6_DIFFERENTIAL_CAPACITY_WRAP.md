# Fetched ring capacity and origin wrap replay

This fixed replay checks ring-slot ownership and bounded frontend saturation
across a real UInt32 producer and consumer wrap. It uses eight canonical Fence
commands, the existing fetched concurrent hardware and the ordinary thirty-output
differential route. No arithmetic, hardware, ABI or formal monitor changes are
required. It closes one independent replay gap, not the complete Phase 6 gate.

## Configuration and packets

Use Device ABI 1.0 and descriptor encoding 0.2, a 1x1 array with reduction
capacity 1, host aperture 4096 bytes, ring base 3072, ring depth two and queue
and retirement depth two. Set origin to `0xfffffffe` through the actual recorded
configuration input. Apply only the startup reset. Every host byte begins as
sentinel 165 except installed descriptors. Fence descriptors have IDs 401 through
408 and zero unused fields and selectors.

Logical position p has UInt32 sequence `(0xfffffffe + p) & 0xffffffff` and
physical address `3072 + (sequence % 2) * 32`. The even origin means this is
also `3072 + (p % 2) * 32`. Install a whole pair before offering publication.

| Positions | Sequences | Offered producer | Refill prerequisite |
| --- | --- | --- | --- |
| 0 and 1 | fffffffe and ffffffff | 0 | Initial host construction |
| 2 and 3 | 0 and 1 | 2 | Committed consumer 0 and idle host |
| 4 and 5 | 2 and 3 | 4 | Committed consumer 2 and idle host |
| 6 and 7 | 4 and 5 | 6 | Six ordered retirements, consumer and producer 4, idle host |

Configuration acceptance is the real pre-edge valid/ready handshake. Once
configuration completes, require producer and consumer `0xfffffffe` before the
first publication. Record every publication handshake and hold its payload until
acceptance. Do not infer admission or capacity credit from descriptor read ACKs,
and never use same-edge consumer advancement to overwrite a slot.

## Saturation and held slot

Hold completion readiness at zero through the first three publications. With
depth two, bounded owners admit five commands: two retirement entries, one
dispatch head and two FIFO entries. The sixth descriptor is fully fetched but
not admitted. At the blocked checkpoint require producer 4, consumer 3, queue
occupancy two, exactly 192 accepted descriptor reads and matching successful
ACKs, and no pending response or stalled request. The oldest completion is the
immutable successful tuple `(401,0,0,0)`.

Position five has sequence three and occupies physical slot one, bytes
3104 through 3135. It remains host-owned until packet admission advances the
consumer to four. Slot zero is already reusable, but this replay overwrites
neither slot during the hold. Check all 4096 bytes against the sentinel and the
installed packets at this boundary.

Hold for another 32 complete quiet edges. Before and after every edge, require
unchanged consumer, producer, queue occupancy and oldest completion. No request
or ACK may be accepted; pending and stalled host state stay empty. Compare the
saved 32 bytes of slot one throughout. Publication readiness is zero because
the reader holds a backpressured Packet, not because ring occupancy exhausts
all physical credit. Keep all five compute counters zero.

## Drain and recovery of credit

Release completion readiness and retire IDs 401 through 406 in order, each with
fault, completed bytes and fault address zero. The sixth command creates its
completion obligation only when the held packet is admitted. Require consumer
and producer four, queue occupancy zero and an idle host before installing the
last pair. Publish producer six and retire 407 and 408 in order.

Final producer and consumer are six; all eight packets produce exactly eight
retirements. Require 256 accepted descriptor-byte reads and successful ACKs,
global tags zero through 255, zero operand reads, zero writes and zero compute
counters. Reader faults, shared halt, transport fault address and halted alias
remain zero throughout. Compare all 4096 final bytes against sentinel 165 plus
the canonical final packets six and seven. No host reseeding, extra reset or
transport flush is permitted.

## Implementation and validation

Add only the fixture generator `generate_capacity_wrap_bundle`, CLI
`export-capacity-wrap` and `audit-capacity-wrap`, and bounded private workload,
host, checks and stimulus helpers. Forward a private optional `config_origin`
through the ordinary trace writer with default zero; both LunaWave drives and
exported TSV must record the same nonzero origin. If reusing FaultContext, keep
its origin immutable and observe actual configuration acceptance there. Existing
zero-origin callers retain identical stimuli and artifacts.

Add a checked public example, black-box deterministic eleven-artifact and
thirty-output checks, exact workload counts, origin trace validation, a mutated
observation rejection and CLI identity rejection. Run targeted checks first,
then one complete native slice gate. Export all eight older fixtures and require
their 88 artifacts to remain byte-identical. Commit the implementation after
native and compatibility checks, then run unchanged pinned Verilator
lint/build/execute and typed actual-trace audit. Preserve actual logs and
original receipts, including failed attempts, separately from this specification.
Compiler, tests and engines run serially; agents may edit isolated files or
review while those commands run on another frozen checkout.

This replay tests reader origin and producer/consumer wrap, not internal queue
ticket wrap. It adds no invalid publication, Run overlap, arithmetic or reset
recovery claim. Remaining invalid-descriptor coverage, synthesis, full-device
safety/fairness and the unchanged-snapshot Phase 5 aggregate are separate gates.
No physical RAM, analog CDC, timing, power or silicon claim follows.
