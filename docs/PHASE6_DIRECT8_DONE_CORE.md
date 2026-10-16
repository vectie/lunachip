# Direct8 successful and faulted Done core linkage

The current latency relation permits successful inner Done with core Done,
although final capture should already have cleared the core. Distinguishing
that successful path from faulted inner Done is the next proof obligation for
Issue/core closure and the L1666/S898/M99 composition. Neither latency timeout
is promoted, and the 11,718-edge retirement theorem remains open.

## Original transition relationship

At inner Done, require core Idle when the held core fault is zero and core Done
when it is nonzero. Successful final capture writes the last C cell and clears
core Done on the same edge that enters inner Done. A rejected inner command
enters inner Done and core Done together; its fault ACK clears the core only
when outer Run collects that completion. Preserve both paths and acceptance
priority. Add a conclusion, not an assumption or an internal readiness input.

Resolve state and fault through the existing original-equation aliases. Keep
all UInt13 transfer coordinates, UInt64 pre-encoding DMA addresses, full payloads,
38 unknown memories and unknown registered-read initialization unchanged.
No production equation, ABI port or SRAM reset is changed.

## Separate qualification and latency integration

First select the accepted 44 engine/prefix conclusions plus the existing
outer/inner/core phase relation, immediate Issue acceptance and the new Done
relationship. This 47-conclusion component has 131 actual assertions and the
original seven premises. Its scope is phase linkage, not L/S/M latency.

Separately add Done linkage to all 55 conclusions of the retained service-credit
latency profile: 56 selected conclusions, 140 actual assertions, seven premises.
Both tasks use original k-induction32 and the 600-second cap. Keep every older
artifact identity and failed archive byte-exact. No existing task is replaced
or weakened by selecting the smaller new component.

Validate both profiles with typed binding and original-helper audits. Exercise
successful original direct8 pipelines and the actual underlying slotted core's
invalid-dimension and unloaded-operand fault paths, including held completion
and ACK. Distinguish these natural fault-path tests from the earlier abstract
observer example; do not force an internal fault into the direct8 device.

Freeze a clean source snapshot and coordinate a finite sequential VM window.
Retain every actual outcome with independent original-model review. Accept
unbounded results only after base and induction pass with a verified typed
result and receipt. Live retirement-entry ownership, dependency drainage,
six-predecessor rank, useful Store reachability and the aggregate remain separate.
