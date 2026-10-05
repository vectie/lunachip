# Fetched remote failure and partial write recovery replay

This workload exercises matching remote status 1 through the fetched concurrent
device, including a genuinely partial host write, retry without reset, failed
operand generations and independent result preservation. It reuses the existing
30-output differential route and eleven-artifact exporter. No hardware, ABI,
formal monitor or general scenario framework changes are required. This is a
fixed functional replay, not the complete Phase 6 gate.

## Fixed configuration and data

Use Device ABI 1.0 and canonical descriptor encoding 0.2 with a 1x2 array,
reduction capacity 2, 4096 host bytes, ring base 3072, four ring slots,
queue/retirement depth three and origin zero. Apply only the initial reset.
Initialize all host bytes to sentinel165, then seed these signed operands:

| Operand | Base and row stride | Values |
| --- | --- | --- |
| A0, 1x2 | 512 and 3 | `[2,-3]` |
| B0, 2x2 | 640 and 3 | `[[5,-7],[11,13]]` |
| A1, 1x2 | 896 and 3 | `[-4,5]` |
| Replacement B0, 2x2 | 768 and 3 | `[[-2,9],[4,-5]]` |

An independent signed matrix oracle yields C0 `[-23,-53]`, C1 `[35,93]` and
recovered C0 `[-16,33]`. Distinct C contents prevent a substituted result slot
from passing accidentally. Derive expected words from operands, never observed
DMA request data. Stores use shape1x2 and row stride12; MatMul uses shape1x2/K2.
All unused descriptor fields and selectors are zero.

## Descriptor sequence and publication

Descriptor position p uses ID301+p and address3072+(p%4)*32. Expected completion
tuples below contain fault, completed bytes and fault address.

| Position | Command | Expected completion |
| --- | --- | --- |
| 0 | LoadA0 from512 | `(0,2,0)` |
| 1 | LoadB0 from640 | `(0,4,0)` |
| 2 | Mat A0/B0 to C0 | `(0,0,0)` |
| 3 | LoadA1 from896 | `(0,2,0)` |
| 4 | Mat A1/B0 to C1 | `(0,0,0)` |
| 5 | StoreC0 to1536, fail second word | `(9,4,1540)` |
| 6 | Retry StoreC0 to1536 | `(0,8,0)` |
| 7 | StoreC1 to1792 | `(0,8,0)` |
| 8 | LoadB0 from768, fail third byte | `(9,2,771)` |
| 9 | Mat A0/B0 to C0 | `(4,0,0)` |
| 10 | StoreC0 to1920 | `(5,0,0)` |
| 11 | StoreC1 to1792 | `(0,8,0)` |
| 12 | Reload B0 from768 successfully | `(0,4,0)` |
| 13 | Mat A0/B0 to C0 | `(0,0,0)` |
| 14 | StoreC0 to2048 | `(0,8,0)` |
| 15 | Fence | `(0,0,0)` |

Publish groups0..2,3..5,6..8,9..11,12..14 and15 with absolute producer counts
3,6,9,12,15 and16. Before every refill require all previous group completions
acknowledged in order, consumer equal producer, and no pending host transaction.
Install complete canonical packets before offering publication; hold its payload
until acceptance. Do not use same-edge capacity credit. The final four ring
slots contain positions12,13,14,15.

## Remote failures and byte checkpoints

At position5, select the actual accepted StoreC word request at1540, validate its
old-C0 value and commit only its low two bytes at request acceptance. Save its
actual global tag and return matching status1. Its failing ACK contributes zero
completed bytes. Before installing or publishing position6, compare all4096 host
bytes:1536..1539 are `[233,255,255,255]`;1540..1543 are `[203,255,165,165]`.
All other bytes equal the operand seeds, installed ring packets and sentinels.
Changing only the ACK after a full four-byte write does not satisfy this case.

Retry position6 succeeds against the same C0 generation, without recompute or
reset. It must precede the rejected MatMul at position9: StoreC has no writer
intent, whereas the rejected MatMul creates a Failed C0 generation.

At position8, operand request addresses are768,769,771,772. Return matching
status1 on the actual saved third request at771 after the first two elements
have committed. Do not request772 during that failed reload. The downstream
MatMul and StoreC reject with faults4 and5 and zero progress/address. In group
9..11 require exactly96 descriptor reads, zero operand reads, zero C0 writes,
two C1 word writes and unchanged accepted/elapsed/active/stall/capture counters.
The destination at1920 remains sentinel165. C1 remains `[35,93]` in both stores.

The successful reload/recompute/store group publishes fresh generations and
produces `[-16,33]`, with three actual active edges and two capture edges.
Final host checks include the old C0 at1536, distinct C1 at1792, recovered C0
at2048 and every byte of untouched padding and the final ring contents. Both
fault injections are once-only; repeated requests at1540 or771 recover normally.

Throughout the epoch require zero reader faults, shared halt and transport fault
address, a continuous global request-tag sequence and no additional reset or
host reinitialization. Expected totals are537 accepted requests and ACKs:
512 descriptor-byte reads,15 operand-byte reads and10 result-word writes. Exactly
two ACKs have status1. Successful loads report14 committed elements. Writes
request40 bytes, physically affect38 bytes and report36 successful ACK bytes.
Keep these three write measures distinct.

## Implementation and validation

Extend the private differential host only enough to apply the selected partial
write before its saved response. Existing host kinds retain their full-write,
status-zero behavior and all77 existing fixture artifacts remain byte-identical.
Reuse the private fetched fault context and checked completion/trace helpers.
Add only `generate_remote_fault_bundle`, `export-remote-fault` and
`audit-remote-fault`, plus checked API documentation, black-box determinism,
complete-port/audit checks, a trace mutation control and CLI identity rejection.

Validate targeted native tests first, then the complete native slice gate.
Export and compare the seven older eleven-artifact fixtures; freeze source bytes
and commit implementation before pinned RTL lint/build/execute and typed audit.
Retain both failed attempts and successful original receipts. Record actual
results separately from this fixed workload specification. Compiler/test and
external engines run serially; parallel agents may edit isolated source or
perform read-only review.

This workload adds no Run-overlap or held-retirement requirement. Arbitrary
invalid descriptors, capacity/origin wrap, remaining synthesis coverage,
full-device safety/fairness and the unchanged-snapshot Phase 5 aggregate remain
separate gates. No physical RAM, metastability, timing, power or silicon claim
follows.
