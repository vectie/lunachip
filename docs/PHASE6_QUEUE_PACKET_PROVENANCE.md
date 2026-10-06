# Direct queue public packet provenance

This supporting check links one independently saved public descriptor to its
FIFO response, captured head, retirement reservation and ordered public
retirement in the unchanged direct 1x1/K2/host1024/q3 device. It fills the packet
identity gap left by structural conservation and stored-record checks. It does
not establish engine ownership, fault/progress correctness or eventual
completion, and does not replace any Phase 6 obligation.

## Fixed execution scope

Reuse all 115 typed observations, the production graph, Boolean adapter,
existing property exporter, task registry and pinned runner. Add no hardware
node, ABI port, internal cut, solver premise or receipt format. Preserve every
older bundle byte. The new profiles retain all six existing queue assertions,
four public-peer assumptions, symbolic later reset and malformed responses,
PRE sampling, two global steps per DUT clock, 256 global steps and timeout600.
There is no fairness assumption.

Add `PacketProvenance` (`phase6-queue-packet-provenance`) and
`NegativePacketProvenance` (`phase6-queue-negative-packet-provenance`). Append
`packet_provenance_ok` and `packet_provenance_transfer_cover` after the existing
12 properties. The positive safety task selects all seven assertions; its
separate cover selects only the new coherent transfer cover. The negative
selects only the new assertion. Emitted DUT memory assertions remain intact.

## Independent watch and transfers

A symbolic monitor-only selection may watch one actual public
`descriptor_valid && descriptor_ready` admission per reset epoch. Save all
four public 64-bit lanes without decoding away reserved or malformed bits.
The watch is not selected by private ticket, caller ID or observed packet
contents. Reset clears selection and transfer history.

Track FIFO position from public admissions and actual pops, not a copy of the
DUT memory. At watch admission, a simultaneous older pop reduces the number of
older queued packets; the newly admitted packet cannot be that pop. At its
ordinal pop, check the synchronous four-lane response at the following PRE
boundary. Require actual capture of that response and check all four head
lanes at the following PRE boundary. Keep the saved head comparison active
until its reservation/dispatch transfer is complete.

At the watched reservation, save the pre-edge write pointer and NextTicket.
Check the subsequent head entry/ticket and allocated live entry against those
saved values and the caller ID encoded in the saved packet. Do not assume
ticket uniqueness; entry/ticket equality is a checked transfer relation.

Independently count older admitted, unretired packets using only the public
admission/retirement handshakes. On watch admission, subtract a simultaneous
older retirement from the pre-edge outstanding count. Each later retirement
decrements that older count. The next retirement when it is zero must match
the watched reservation, live terminal entry and saved caller ID. Duplicate
IDs cannot identify this event by themselves. Clear all history on joint reset.
Counters must fail on underflow, overflow or impossible transfers rather than
wrap into a false identity match. These are safety checks, not progress premises.

## Coherent cover and sensitivity

The cover requires the same watched packet to traverse response, capture,
reservation and ordinal retirement within one reset epoch. Recorded milestones
belong to that one watch; unrelated events cannot satisfy the cover. A full
cover trace must establish every transfer in PRE phase. No cover alone proves
the positive safety obligation.

The sensitivity profile flips bit zero of one saved lane only in the checked
FIFO-response comparison after a genuine watched response whose raw payload
matches. It leaves the DUT, assumptions, saved data, history and all other
comparisons unchanged. Restoring that one expression must exactly reproduce
the positive harness. Acceptance requires an actual complete counterexample
failing the exact selected assertion, not generated expected-failure metadata.

## Validation and remaining gates

Use focused generation/task/registry tests, exact older artifact preservation,
and real-DUT native replay for distinct lane payloads, repeated IDs, full
pop/refill, simultaneous watch admission/older retirement, held completion and
reset cancellation. Independently review counter updates and both synchronous
transfer gaps. Run compiler, tests and external engines serially while agents
author isolated changes concurrently.

Native generation is not formal evidence. Actual acceptance still requires
exact-adapter helper equivalence, full selected safety to the declared bound,
a complete coherent cover and the selected negative through the unchanged
pinned runner. Keep original timeouts and receipts unchanged. Engine-to-entry
ownership, leases/cursors/arbitration, the proposed public-fairness deadline,
fetched write-path safety and the full 8x8 product scope remain mandatory.
