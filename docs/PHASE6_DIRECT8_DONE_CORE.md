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

## Validated input checkpoint

Four focused tests pass for profile selection and rollback, both complete
competing direct8 slot pipelines, mutation controls and the underlying 8×8/K16
slotted core. That core naturally produces dimension and unloaded faults, and
also completes a loaded successful command. All three paths hold Done across
backpressure and clear appropriately on ACK. Reset preserves every SRAM cell
and registered-read value, including unknown bits. No internal fault is forced.

Both older latency profiles and the accepted engine profile retain pinned
artifact hashes. Removing the new body and restoring the parent's property
export recovers the parent DUT exactly. Canonical IR, production RTL, public
harness and original bindings do not change. Strict native checking, interface
generation and the automation unit tests pass. These are validated inputs;
neither new conjunction has a formal result yet.

## First result and pending slot support

The separate47-conclusion task on clean a9ab630 times out at the original cap:
TIMEOUT8 328, runner8,609 host wall seconds and601 SBY elapsed seconds. Base
0–31 passes at183 solver seconds; induction last reports step14. Independent
review confirms131 assertions, seven premises,38 memories/8960 unknown bits,
unknown read INIT and exact unchanged sources. No trace or receipt is produced.
The56-conclusion latency profile remains an unexecuted input, not a theorem.

Equation review identifies a further Issue-support candidate. Pending-read phase
ownership alone does not tie the held response slot to the Store slot. An
abstract response slot equal to compute C can therefore block Issue even when
the Store's actual slot is different. This is a structural induction example,
not a reachable trace or a diagnosis returned by the timed-out solver.

Recover the original UInt1 response-slot register whose actual read-accept
event latches the Store slot. Assert pending implies equality with the held
Store slot. Add one original alias and one conclusion, without initializing
memory, fixing data, masking addresses or introducing a premise. Preserve the
47/56 input identities; the new profiles select48/57 conclusions and expect
132/141 actual assertions. Use the second reserved attempt for the full57
conjunction, with the pending-slot relation jointly asserted rather than assumed.

The first archive is sealed at
`artifacts/phase6-direct8-done-core-20261017-r1`, inventory
`34e263d658334b3f2416b91022d84770349e8058697bf251a2497df1520c935e`.
Relocation checks every byte before removing only the temporary source copy.

## Pending-slot input checkpoint

The original-equation binding is unique, UInt1, and adds no state or premise.
Five focused native tests pass, including both complete competing slot
pipelines and all three natural underlying-core success/fault paths. The
pending-slot observer shares the reset guard of its assertion: pre-reset
unknown state is not converted to an integer. No memory value is substituted.
Wrong held-slot controls fail, and the original47 task retains its exact DUT,
source-set and property hashes. Both48/57 profiles regenerate losslessly and
retain the original canonical IR, manifest and public harness.

Strict native checking and interface generation pass with no public interface
diff. The isolated second run will use a clean committed snapshot; this input
checkpoint is not a proof result or an accepted latency bound.

## Second frozen outcome and next gate

Clean `9915fce` passes 56 native, six verifier and seven automation tests,
17 typed task checks and 15 exact helper audits. Its full 57-conclusion task
returns `TIMEOUT 8 435`, runner exit 8, 614 host wall seconds and 601 SBY clock
seconds. Base 0–31 passes at 239 solver seconds; induction last reports step
16. No trace or receipt is produced. Independent review confirms 141 actual
assertions, seven premises, original unknown memory/read INIT, exact sources
and a clean unchanged snapshot. The shared window is released after cleanup.

Both outcomes are sealed and retained in the
[Done linkage evidence](evidence/phase6-direct8-done-core-20261017.md).
The last accepted component remains the earlier 44-conclusion engine/prefix
proof. The new successful/faulted Done relationship and pending-slot support
are tested inputs, not accepted unbounded theorems. The next qualification is
the already exported 48-conclusion phase component, after reviewing its
one-edge original-equation closure. Keep the full latency and 11,718-edge
gates open; no third attempt or longer cap is used in this reserved window.
