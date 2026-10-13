# Whole Store payload preservation and lease release

This Phase 6 slice connects physical C storage, the indexed result-read
channel and the whole-rectangle Store reservation. The established two-client
arbiter theorem protects a granted request while offered or awaiting a response.
It does not establish that Store supplied the correct C word, that a competing
MatMul cannot overwrite unread words, or that compute leases release only after
the final physical capture.

The first checkpoint adds observation metadata and finite native witnesses,
not another controller, proof exporter or assurance framework. Production
hardware and the existing 115-role queue and 48-role dependency inventories
remain unchanged. The complete Phase 6 gate remains open.

The exact projection and real PRE/POST workload are now accepted checkpoints:
162 retained registers, six complete memories, and 426 compared PRE/POST pairs
cover pre-grant opposite-slot computation, held offers, both whole matrices and
reset retention. See
[the source-bound checkpoint](evidence/phase6-store-storage-correspondence-20261007.md).
No Store preservation theorem or solver result is claimed there.

Private supporting inputs and their exact helper/prepared-model qualification
are now implemented. The first engine experiment completes only the positive
base case through global samples 0–31; induction, overlap cover and selected
negative all time out without traces. See
[the inconclusive experiment](evidence/phase6-store-preservation-experiment-20261007.md).
That experiment closes no whole-Store gate. Its unchanged unbounded attempts
are not retried; later source-bound component results below close selected
conclusions while the remaining bounded/compositional obligations stay required.

## Two different reservations

The storer has no separate leased register. Its original Read, Request and Wait
states define its whole-C reservation. Done still owns a retirement ticket but
no longer reserves C. A successful final host response, remote or protocol
failure, internal read failure, or cancellation ends the operational reservation
at the state commit. The old reservation remains visible at PRE on that terminal
edge; a conflicting MatMul cannot use release-edge credit. Acknowledging a held
completion is not the release event.

The outer compute engine has a separate registered `leased` bit. Legal outer
admission sets it before the inner command handshake. Its exact release is the
inner graph's final capture, or outer Run with an inner stored completion and no
remaining inner ownership. The inner slotted FSM, capture cursor and selected C
slot determine final capture. They are not interchangeable with the outer
compute FSM or an arbitrary completion signal.

The authoritative equations are in `concurrent_storer.mbt`,
`concurrent_ownership.mbt`, `concurrent_compute.mbt`, `slotted.mbt` and
`stored_capture.mbt`. Later reset clears both reservations at the joint edge;
reset-gated handshakes do not imply already-cleared raw PRE state.

Pending-read protection blocks a conflicting, same-C-slot inner slotted command
handshake through its acknowledgment edge. An opposite-C-slot command may
proceed while the saved response drains. It is not an unconditional
outer-admission ban: after Store reaches Done, outer compute may acquire an
Issue reservation while an older response drains, but a same-slot inner
handshake must still wait. The original `slotted.mbt` equation compares the
incoming C selector with the saved response selector.

## Essential state and storage

| Original state | Required purpose |
| --- | --- |
| Store transfer registers | Preserve admitted ticket, slot, rectangle, address parameters, cursor, tags and terminal record |
| Outer compute FSM, lease and selections | Protect the acceptance-to-inner-Issue gap and conflicting source/destination ownership |
| Inner slotted FSM, capture cursor and selectors | Derive physical capture and its final edge from original transitions |
| Inner execute FSM, accepted shape, step count, ticket and fault | Derive completion and legal capture without free core-progress predicates |
| Per-slot C validity and shape | Publish only after actual final capture; invalidate on accepted overwrite |
| Pending read, saved response slot, ID and fault | Preserve identity and status of the synchronous response |
| Both C memories and their read-result state | Preserve captured words, selected addresses, latency and HoldLast behavior |

The Store transfer record has fourteen registers and 284 bits. The inner
slotted record has eight registers and fifteen bits. These are source
inventories, not a complete accepted projection size. Discovery must account
for every required next-state, reset, enable and memory-port expression before
declaring a boundary.

Both C memories use ReadOld, reject simultaneous writes, fault on enabled
out-of-range access, and retain their read result when disabled. A read result
cannot become an arbitrary payload input in a payload-preservation theorem.
Reset invalidates metadata and pending responses; it does not erase SRAM or roll
back committed host writes.

## Observation checkpoint

Use a separate Store-preservation fixture of the ordinary direct queued device
at 2x2/K2/host1024/q3. Two rows and columns permit both cursor transitions and
distinguish intermediate capture from final capture. A 1x1 proof cannot by
itself establish a multiword rectangle property.

Capture existing register handles, event signals and C-memory read references
at their authoritative construction sites. Collectors must not call a hardware
builder. Resolve each complete C memory through the actual MemoryRead memory
and port IDs after construction, never guessed ordinals or names. Optional
collectors must leave ordinary construction identical.

Independent tests compare the whole fixture module and serialized bytes with
ordinary same-configuration construction. Check unique roles, exact types,
register controls and memory identities, and separately retain the older queue
and dependency inventories. Add no device debug port or second C-valid table.

## Relations for the supporting proof

Derive the following relations from startup reset and original transitions:

1. Legal Store admission saves its C selector and exact rectangle. Reservation
   persists through indexed reads, request stalls, response waits and final PRE
   acknowledgment. No competing capture targets that slot during reservation.
2. Each indexed read saves its identity and selected slot. A successful response
   is the actual synchronous read of its C word and stays stable while Store
   waits for DMA grant. Opposite-slot capture cannot change that response.
3. Only an actual matching successful host response advances Store cursor and
   acknowledged progress. A failed or unconsumed response cannot advance it.
   Terminal processing releases C while the held completion remains immutable.
4. Compute ownership persists through Issue and intermediate captures. Final
   capture writes the last C cell and publishes validity/shape on the same commit
   that permits later reuse. Admissions still see the old reservation at PRE.
5. Joint reset suppresses handshakes, clears control/validity/pending state and
   starts a new ownership epoch without manufactured completions.

The existing compute projection omits `leased` and frees inner readiness,
completion payload and Store conflict conditions. It cannot establish these
release claims unchanged. Engine/entry ownership establishes ticket identity,
not physical slot protection. Neither theorem supplies an unproved internal
assumption for the full device.

An explicitly reviewed arithmetic abstraction may support a narrower theorem:
arbitrary produced words enter the original capture write ports and are
subsequently read and transmitted unchanged. It must retain actual capture,
publication, ownership, selected address, both memories and their read results.
This proves preservation, not mathematical MatMul. Review every candidate leaf
before accepting such a boundary. Omitting Store progress/address record roots
is permissible only if their completion correctness is explicitly excluded;
never replace an omitted control dependency with a free internal premise.

## Native witnesses and proof order

Existing native tests already cover rectangle overwrite exclusion between words
and through final response, and compute exclusion through final capture. The
missing composed witness delays Store grant behind a genuine outstanding loader
transaction while Store has launched its indexed C0 read. Require actual C1
capture, including final capture, during that delay. Then finish the loader
response and check the first Store word against the C0 oracle before testing a
three-edge held public write offer. Finish the rectangle and verify both old
and newly captured matrices through real host writes.

Holding only an already-granted public offer is insufficient: the arbiter's
payload latch could conceal corruption of the still-pending core response.
Use the existing byte-memory environment and matrix oracle; no internal forcing,
replacement transport or artificial progress is allowed. Require explicit
overlap counters so an unexercised path cannot pass as coverage.

After observation, discover and review the complete control/storage closure.
Materialize original sequential and memory specifications, then compare retained
state and events at PRE and POST with actual hardware. Only afterward add the
relation and original-clock bridge, audit actual prepared models and run pinned
positive and sensitivity tasks serially.

The next bounded implementation is a private, candidate-only discovery report.
Seed all 48 register transitions and controls, all 33 events, both C reads and
every original C-memory port dependency. A register-only walker is insufficient:
retain both complete memories and their synchronous read-result state. Inspect
the four original accumulator registers as arithmetic candidates, while keeping
their actual write-data muxes, cursors, capture and publication controls. Other
foreign input, register and memory leaves need complete source signatures and
seed provenance; loader, arbiter and A/B-validity dependencies are control
candidates, not automatically accepted cuts. Require deterministic discovery,
exact source bindings and rejection of omitted storage/port dependencies before
materialization. Do not add a proof exporter or global observer in this step.

Sensitivity changes only checked conclusions, not controller or memory behavior.
A payload mismatch requires genuine Store acceptance, indexed read and committed
pregrant/offer hold. A premature-release sensitivity requires actual intermediate
capture with an outstanding original lease, not a fabricated state. Preserve
other conclusions and public premises; independently qualify the exact sampled
PRE frame and sole intended failure.

Use targeted tests during implementation, then interface, format and strict
native checks at the checkpoint. Reuse unchanged accepted source-bound evidence;
do not retry the unchanged whole-device timeout. Commit design, observation and
verified native work in coherent steps. FIFO storage/provenance composition,
DMA and nested memory bounds, fairness, fetched transport and full 8x8 formal
checks remain required.

## Clock/reset and lease closure checkpoint (2026-10-13)

The next implementation separates checked conclusions, not the original DUT:

- Clock/reset support checks register reset establishment, suppression of real
  handshakes, memory/read-result retention on reset, and nonrising state hold
  independently. Reset remains synchronous; raw PRE reservations need not be
  cleared before the reset edge. SRAM contents are never assumed zero.
- Lease support checks the outer registered lease update and exact release,
  old-PRE Store exclusion, and same-C pending-read protection through its ACK
  edge. Held Done is not an operational Store reservation; outer admission and
  the inner slotted handshake must not be conflated.
- Each selected lemma retains the original projected transitions, source
  bindings, arbitrary arithmetic producers and startup-only reset premise.
  Removing unrelated assertion statements is permitted; adding an internal
  assumption, free control input or later-reset bypass is not.

Use separate unbounded k-induction tasks where the relations permit them, with
the locked engine, multiclock lowering, fatal preparation warnings and retained
prepared models. An induction depth is not a replacement for the original
BMC256 obligation. A passing component theorem is accepted only for its exact
conclusions and source; composition into payload preservation remains separate.
Timeouts and induction counterexamples must be retained without promoting the
Phase 6 gate. Do not repeat unchanged previous partitions.

Source work may run in parallel agents; native compilation and external engine
runs stay serial on the dedicated QEMU-only validation VM. Commit the design,
then targeted-test-qualified implementation, then qualified engine outcomes in
separate checkpoints. Reuse the single repository compiler cache and keep it
outside proof evidence. Historical sealed archives remain immutable.

The implemented private input families are `store_clock_reset_*` and
`store_lease_*` in `validation/formal`. Five clock/reset tasks separately check
all twelve actual memory-port enables under current reset, all 162 register
reset values after the prior sampled reset, retention of the 1,344 memory/read
bits under that reset, and nonrising hold of the 2,427 register bits and 1,344
memory/read bits. These minimal observers do not check the original payload
ghost clearing or complete reset-event suppression; those remain composition
obligations.

Three lease tasks check twelve conclusions: exact final capture/release and
registered lease update with Issue ownership; operational Store reservation and
conflicting admissions; and pending-read exclusions, update and saved-selector
hold. Exact final capture preserves the source's modular four-bit addition.
The older widened five-bit relation additionally requires checked reachable
shape/cursor bounds. These tasks deliberately do not establish capture implies
lease, capture exclusion during Store, publication, payload or memory bounds.
Generating a task is not evidence that any conclusion passed an engine.

The [actual engine checkpoint](evidence/phase6-validation-resume-20261013.md)
now passes all five clock/reset tasks and three lease tasks by k-induction,
checking eighteen conclusions. Issue ownership needs one additional **checked**
outer/inner state-phase assertion; the original failed conjunction and partial
trace are preserved. This is not a hardware repair or an internal assumption.
The exact successful source/model inventories and unsuccessful attempt are
sealed, while the full Store conjunction and Phase6 gate remain open. The next
step is explicit source-bound composition into capture, publication and payload,
not another unchanged timeout run.

## Capture/publication and payload composition (2026-10-13)

Continue from the eighteen checked clock/reset and lease conclusions, without
turning them into internal assumptions. New private tasks first separate exact
capture-cursor and metadata transitions from reachable capture ownership,
shape and bounds. Final capture must write the last physical cell and publish
the selected slot's validity/shape on the same commit; invalidation clears
validity while the existing shape fields retain their source-defined behavior.
Compose the needed checked support with the original capture/lease conclusion.

Payload work first relates independently sampled raw arithmetic producers to
each original C cell, then checks the original synchronous ReadOld/HoldLast
result. Carry the independent expectation through the saved pending response
and original Store DMA grant/public write. Per-cell “last captured value” is a
narrower theorem than complete current-generation rectangle coverage. A
tracked-read or successful-fault guard is not evidence that every admitted
Store read obtains that basis; that eligibility and full generation linkage
must be checked separately before accepting whole-Store preservation.

Retain both C memories and real read state, exact controls, source selectors,
and the reviewed four raw production boundaries. Unknown SRAM initialization,
arbitrary later reset and startup-only reset remain unchanged. Use assertion-
only support, native source/hash regressions, pinned prepared-model review and
actual serial engine outcomes. Do not replace expected payload with the output
under test, silently cut ownership/control, or claim full8x8/fair completion
from this2x2 component checkpoint. Commit design, verified inputs and accepted
or inconclusive engine evidence independently.

The [accepted capture/payload checkpoint](evidence/phase6-validation-resume-20261013.md)
now closes the original capture/lease p2 and produced-storage p3 conclusions
with jointly checked cursor, ownership, shape, metadata and generation-prefix
support. Eleven scoped tasks pass k-induction; one smaller engine crash is
preserved as an error while a stronger read task proves its cell conclusions.
The joint raw-producer-to-public-Store transport task passes with an explicit
captured-read basis guard. It is not yet original p4: connecting latest-generation
eligibility to that basis and proving the full13-bit Store cursor, selected
shape and reservation relation remain the next checked composition step.
Production hardware, ABI and public interfaces are unchanged; the complete
Store conjunction and Phase6 remain open.

## Original Store p4 checked composition (2026-10-13)

The [accepted p4 checkpoint](evidence/phase6-store-p4-composition-20261013.md)
now jointly proves exact original p1, p3 and p4 with85 checked assertions for
the unchanged binary2x2/K2 projection. Generation publication/coverage links
directly to original synchronous reads and pending raw-producer expectations;
no second physical-history observer or extra payload-basis guard is needed.
Old-PRE Store reservation protects selected metadata/cells through terminal
edges. Full13-bit cursor bounds justify the actual truncated read fault/address,
while host-address arithmetic retains its original32-bit modular semantics.

Three actual tasks pass k-induction. A narrower70-assertion cursor task times
out after failed induction due to unlinked generation metadata; its partial
trace is retained. Every cursor relation passes inside the stronger83/85 tasks
that jointly assert original p3; the unsuccessful task is not reclassified.
Both C memories and real read state retain unknown initialization, arithmetic
producers remain arbitrary, and startup-only reset is the sole premise.

Next compose original p5 cursor/progress/terminal and p6 complete reset ghosts,
then full Store conjunction and memory bounds. BMC256, overlap/sensitivity,
packet/fetched and explicit-fairness8x8 obligations remain required. Hardware,
ABI and public interfaces are unchanged; Phase6 is still in progress.

## Whole original Store safety conjunction (2026-10-13)

The [accepted full safety checkpoint](evidence/phase6-store-full-composition-20261013.md)
jointly proves all nineteen original safety conclusions for the unchanged
binary2x2/K2 projection: original p1–p6, twelve enabled memory-port bounds and
global nonrising hold. Full109 assertions comprise those19 and90 checked
supports; the only original statement removed is the unrelated overlap cover.
Earlier proofs are never converted to internal assumptions.

P5 and p6 require no new runtime observers. P6 keeps original complete reset
ghosts, all162 register reset checks and1,344-bit memory/read retention; global
hold observes3,771 physical-state bits. Eight additional range assertions bind
the actual depth3 FIFO pointers after validating original fire/hold/reset/wrap
recurrences. Four C UInt2/depth4 bounds are legitimate binary tautologies, not
logical rectangle or host-address bounds. All six SRAM/memory INIT values and
unreset snapshots remain unknown.

All four new tasks pass basecase0–19 and k-induction with independently audited
prepared/final models. Inputs, logs and models are sealed without compiler
caches, and the QEMU-only VM is stopped. Hardware/ABI/API remain unchanged.
The positive conjunction is closed for this projection, but original BMC256,
overlap/sensitivity and broader packet/fetched/explicit-fairness8x8 obligations
remain required. No numerical MatMul, full-device, FPGA or Phase6 pass is claimed.
