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
No required Store gate is closed. Optional unbounded induction work is paused
while the named bounded/compositional obligations remain required.

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
