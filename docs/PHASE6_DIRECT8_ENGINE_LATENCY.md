# Direct8 Issue core linkage and command latency composition

The next component connects the accepted 44 engine-progress conclusions to
command-to-Done bounds L1666, S898 and M99 on the original direct8 device.
The 11,718-edge retirement deadline remains open until live-entry ownership,
dependencies and the six-predecessor queue rank are composed as well.

## Issue and core phase linkage

Jointly assert that outer Idle, Issue and Done have idle inner controllers;
Issue accepts into both the slotted controller and core on that edge. Outer
Run owns a Computing, Capturing or Done inner phase. Clear and Run belong to
Computing; capture begins on core Done, and the final write precedes terminal
collection. A cleared lease after final capture is legal while outer Run
collects the inner Done. Keep fault completion paths rather than assuming
every accepted compute is successful.

## Finite work and elapsed time

Use proof-only saturating command-age observers started by the actual engine
acceptance events. Count every elapsed DUT edge until Done, including bus
stalls and response offers. No observer may pause because a response is offered.

Build decreasing potentials from full original cursors, not narrowed cursor
copies. A's conservative ordinal is row*16+column; B's is row*8+column.
Both fit 128 under their original operand-specific shape conclusions. Store
and capture use row*8+column and fit 64. Short rectangles skip unused ordinal
positions, which only decreases the potential faster. Zero extension and
constant shifts are proof arithmetic, never a change to DMA addresses or SRAM.

Loader uses 13 edges per remaining ordinal and Store uses 14. Their phase
offsets account for Commit and indexed read respectively. Subtract the actual
client-watch age only during Request/Wait. The accepted 12-edge inclusive
client assertion alone is insufficient for this phase accounting: establish
the stronger age-11 inclusive ACK conclusion jointly from the unchanged R2/H2
transport, rather than assuming it or silently consuming an extra edge.

Compute uses Issue potential 97, Clear 96, Run 95 minus accepted steps,
capture 65 minus its ordinal, and inner Done 1. Outer Done has potential 0.
Prove positive bounded potentials in active phases, one-edge decrease, exact
age ownership and age+potential bounds. These supply the selected inclusive
command-to-Done deadlines with their existing acceptance margins.

## Qualification

Preserve every older bundle byte-for-byte. The additive latency profile keeps
the original seven public premises, 38 memories, 8,960 unknown storage bits,
unknown read initialization, full UInt64 address intermediates and complete
request payloads. Add no internal ready, phase or completion assumptions.

First check independent native phase/rank/age observers on competing complete
pipelines and fault paths, plus corrupted Issue linkage, high cursor bits,
stalled potential and inclusive-deadline controls. Then freeze a clean source
snapshot and qualify the new conjunction in a coordinated pinned VM window.
Retain timeouts and failures without changing their status or the original
600-second cap. A generated profile or passing native trajectory is not a
formal latency result.
