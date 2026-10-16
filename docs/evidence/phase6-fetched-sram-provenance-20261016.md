# Fetched SRAM capture generation and value provenance

The physical C SRAM capture-generation/value observer is implemented and
native-tested, but its unbounded conjunction remains pending. Four changed
candidates are retained honestly as timeouts after induction failure. The
accepted 119-property fetched packet/dependency theorem remains unchanged;
none of the new SRAM conclusions receives proof credit from these failures.
The scope remains fetched 1x1/K2/host1024/ring4/queue2, not general 8x8
arithmetic correctness or fabricated SRAM measurements.

## Implementation and acceptance sequence

1. Reuse the existing Store/capture observation seam for the exact fetched
   graph. Keep all production nodes, ports, memory policies and metadata equal.
2. Bind the raw accumulator producer independently of the memory write mux.
   Track per-generation capture validity, full producer tickets and values.
   Prove that successful publication has a complete captured basis, and that
   Store reads and public DMA writes preserve that basis without stale fallback.
3. Preserve unknown initial cells/read states and reset invalidation without
   memory erasure. Preserve full cursor/address equations; add no internal
   premises, initialized RAM or successful-response assumptions.
4. Exercise both slots, failed generations, recovery and reset in targeted
   native tests. Run a pinned unbounded conjunction on a clean frozen snapshot
   in a confirmed non-overlapping VM window. Review and seal actual outcomes,
   including unsuccessful attempts, before updating the acceptance ledger.

The starting accepted archive is
`artifacts/phase6-fetched-packet-order-20261016-r2`, inventory SHA256
`63c34f872228c9b477d820c973e1e182ead59ae9cd3b42a9ba87e248675c4319`.
No accepted SRAM provenance proof result is claimed at this checkpoint.

## What the additional check establishes

The new reference follows one physical result through five boundaries. It never
feeds the design or substitutes an expected word for an actual memory value.

| Boundary | Independent reference and checked relation |
| --- | --- |
| Generation acquisition | Save the full UInt32 producer ticket on actual legal inner acceptance; invalidate only that C generation's control history. |
| Physical capture | Save the actual SInt32 accumulator register on capture; compare both original write ports and the selected physical SRAM cell with that saved word. |
| Publication | Published validity/shape and logical Success must identify a complete captured generation; Pending or failed writers cannot authorize stale success. |
| Synchronous read | Save the pre-edge captured word on the actual enabled read; check ReadOld/HoldLast, pending response identity and the Store's saved generation basis. |
| Public Store | Save that independent pending word and the full UInt64 address at internal arbiter snapshot; check Offer/Wait and the later public write/acceptance against them. |

The target is not whether the accumulator computed the correct mathematical
matrix product. It is capture, generation ownership and copying from that
actual producer through the original physical C SRAM and transport. Until the
conjunction passes, these remain checked goals, not accepted formal results.
The exact profile has two one-word C banks, so completeness is specific to
1x1 results, not a general multi-cell capture theorem.

All ten arrays retain unknown initial storage and read states. Reset clears
validity and ownership, not the stored words or unconstrained payload histories.
Original UInt13 fields/cursors, UInt64 calculations, UInt32 request encoding,
UInt34 aperture checks and modular UInt32 tickets remain intact. Constant
observation taps add no production read ports or hardware nodes; prepared-model
observation reads also retain unknown read INIT. The theorem uses the existing
qualified binary helper interpretation, not a new four-state equivalence claim.

## First conjunction and missing ownership history

The first candidate keeps all 119 accepted conclusions and adds 38 assertions
for capture, publication, generation tickets, Store leases, readback and DMA
origin. On clean `6fc5b0c29e7c40222d864e9b990fb7b65f2101e1`, pinned SBY
returns `TIMEOUT 8 179`, child8, after 601 wall seconds. Basecase 0–19 passes
at 105 engine seconds; induction fails at 470 seconds and identifies
`lc_full_dut.lc_fs_latest_generation_1` at 541 seconds. It produces no trace.
This is not a validated reachable counterexample or an unbounded safety pass.

Prepared-model review matches all 157 labels, the original five assumptions,
zero covers, ten arrays retaining 640 unknown initial storage bits and unknown
read INIT, and twenty complete qualified binary helper pairs. Source/config
copies and full clean before/after Git identity match. All 22 focused frozen
native tests pass. Two fixture/docstring tests and collector/reviewer unit
tests also pass during implementation. The production graph is unchanged.

The sealed archive `artifacts/phase6-fetched-sram-20261016-r1` has inventory
SHA256 `01ef778e8ecc83d79304667cdec4b8dde398e55a1553f683418a29e6f2e17bff`.
Its VM window is released after owned cleanup, before host review/archival;
the protected PRX100 volumes and QEMU configuration are unchanged.

Inspection of the collection equations motivates two additional checked
Pending-generation ownership relations: each C ticket must belong either to
the reserved MatMul head for that C slot or to the actual current Compute.
Collection compares full tickets; ownership is therefore needed to rule out
unreachable induction states that give both C banks the same live ticket. This
is a proof-closure hypothesis, not a claim that such a state is reachable.
A third checked relation carries the physical generation basis of a successful
reserved Store head through its wait before outer acceptance, including the
absence of a conflicting Compute lease. The original
157 conclusions remain selected; no ownership relation is assumed.

The changed candidate has 160 assertions. Native checks cover the same full
ticket ownership and held-head basis across both slots and the failed-writer/
recovery trajectory. The original configuration, observation IR, name manifest,
public symbolic inputs and memory/address semantics remain unchanged. The
changed candidate requires its own actual formal result.

## Reserved Store basis and lease phase

The 160-assertion candidate on clean
`b2bd6ac082cdb74b28de0c1252512501c23ca2a3` returns `TIMEOUT 8 149`, child8,
after 601 wall seconds. Basecase 0–19 passes at 89 engine seconds; induction
fails at 301 seconds and identifies `lc_full_dut.lc_fs_reserved_store_basis`
at 342 seconds. Trace export begins at 348 seconds but remains incomplete.
There is no validated reachable counterexample or proof credit from this run.

Its prepared-model review matches all 160 labels, five public assumptions,
zero covers, ten unknown arrays with 640 initial storage bits and unknown read
INIT, and twenty complete qualified helper pairs. The exact source/config
copies and clean before/after identity match. All 22 focused frozen native
tests and preparation checks pass. The sealed second-attempt archive
`artifacts/phase6-fetched-sram-20261016-r2` has inventory SHA256
`639e7c96c11fc675cedf6ecba77ff15a22e7c33484f41867077ee969e67d45b7`.
Both unsuccessful archives are verified before and after relocation.

The next candidate checks two original lease lifecycle facts explicitly:
Compute leases occur only in Issue/Run, and Issue holds a lease. These relations
exclude unsupported stale-lease or unleased-Issue induction states when a
successful Store head is waiting. Pending C ownership additionally requires
the original full raw MatMul syntax in its head branch: exact version/opcode,
reserved bits and full 16-bit field-fit checks, without requiring dimensions
or unused fields to pass. Malformed syntax publishes no intent; syntax-valid
commands with later local faults still own Pending generations until rejection.
This is equation-derived proof support, not a claim about an inspected complete
counterexample or a new input restriction.

The candidate now selects 162 assertions, with the same public assumptions,
configuration, IR and name manifest. Four focused native tests pass with the
lease lifecycle and exact syntax checks, including both slots, failed writers,
recovery and full-value/full-ticket sensitivity checks. An actual unbounded
result remains required. Each job uses a separately confirmed VM window,
released after owned cleanup; the protected volumes and QEMU configuration
remain unchanged.

## Internal snapshot grant and public acceptance

The third candidate on clean `3294cb825d5b4fcdc408515e26d02c0d5629d22e`
returns `TIMEOUT 8 174`, child8, after 601 wall seconds. Basecase 0–19 passes
at 95 engine seconds. Induction fails at 284 seconds and identifies
`lc_full_dut.lc_fs_store_grant_reverse` at 325 seconds. The trace export remains
incomplete. Prepared-model review matches all 162 labels, five assumptions,
zero covers, ten unknown arrays with 640 initial storage bits and unknown read
INIT, and twenty complete qualified helper pairs. All 22 frozen focused native
tests pass, but this conjunction receives no unbounded proof credit.

The sealed third-attempt archive `artifacts/phase6-fetched-sram-20261016-r3`
has inventory SHA256
`ef9957460552b1818736573c260d5f9332c2d2287c6c04835a846aa2ba85938c`,
verified before and after relocation.

The original three-client arbiter equations reveal a concrete observer error,
independent of the incomplete trace. Internal grant saves the selected payload
while the arbiter is Idle. The public request is offered afterward; the client
receives `StoreRequestAccept` only when that public offer is accepted. The
observer incorrectly equates these distinct events and samples origin too late.
This is an instrumentation error, not a production hardware defect.

The corrected observer saves the independent pending capture word and full
UInt64 address on internal Store snapshot grant. It checks that grant against
Store request validity and the pending generation basis. A separate assertion
checks public client acceptance against the actual public valid/ready, owner
and saved provenance. It replaces the incorrect grant-equals-accept assertion;
the false version remains retained in the failed archives, not silently passed.
The candidate still contains 162 assertions and the same original premises.

The native reference now checks that internal Store snapshot occurs before
client acceptance, then compares the saved independent capture word/full
address with actual arbiter Offer/Wait state and public writes on every edge.
Both-slot trajectories pass this causal separation check under stalls. Four
focused native tests pass; the source regression also requires snapshot-time
sampling and rejects the old erroneous assertion label. Another actual formal
result is required before accepting the SRAM gate.

## Corrected snapshot candidate: retained unresolved identity check

On clean `bf2630f488b16ee31130195f2a39c01db410daad`, the corrected
162-assertion conjunction returns `TIMEOUT 8 144`, child8, after601 wall
seconds at the original600-second limit. Basecase0–19 passes at87 engine
seconds. Induction fails at284 seconds and identifies
`lc_full_dut.lc_fs_store_grant_identity` at321 seconds. VCD export starts at325
seconds and remains incomplete at timeout. This is not a validated reachable
counterexample or a partial/unbounded safety pass.

Prepared-model review matches all162 labels, five original public assumptions,
zero covers, ten unknown arrays retaining640 initial storage bits and unknown
read INIT, and twenty complete qualified binary helper pairs. Submitted source/
configuration and clean full before/after Git identity match. All22 frozen
focused native tests and preparation checks pass, including the corrected
snapshot-before-public-accept histories. The actual submitted SV SHA256 is
`f6f4e9894d4087a224d0cff61720ac877e8cf82c657ff704f8344e3a63e42e66`.

The sealed fourth-attempt archive `artifacts/phase6-fetched-sram-20261016-r4`
has inventory SHA256
`6da1e4021d5c291b69a766571f67ee28da653e4133718a2c05502c2bcae0a6a9`,
verified before and after relocation. The separately confirmed single-job VM
window is released immediately after owned cleanup, before host-only review
and archival. Fresh ps-a is empty; all eight protected PRX100 volumes and the
QEMU-only configuration remain. No fifth job is queued.

The next precise unresolved link is the independently saved pending read's
generation/request identity at internal Store snapshot. The current assertion
requires request validity, a valid pending captured basis, matching full producer
ticket and Store ID, and the independent response word. Before adding checked
history support, derive its ownership through the held Store Request from the
original read/Store transitions; the incomplete trace alone does not identify
which conjunct fails or establish a production defect. Do not replace that
identity with a premise or sample the expected value from the output under test.

This checkpoint intentionally does not run an unchanged fifth attempt or the
full final matrix. Physical SRAM provenance, explicit-fairness8x8 completion,
typed safety receipt integration and final same-snapshot matrix/aggregate remain
open. No older q3/8x8 result or directed Store cover receipt is promoted.

## Pending read ownership through a held Store request

The next candidate adds one checked history relation, not a new premise:
while the original Store state is Request2, a pending read must retain its
captured basis and match the Store's full producer ticket, full request ID and
selected C slot. This relation connects the accepted read with an arbitrarily
long held request before internal snapshot or public acceptance.

The derivation uses the original `concurrent_storer_controller` and
`slotted_result_storage` equations. Read1 enters Request2 only on the actual
read handshake, unless terminal handling takes priority and enters Done4.
That same handshake saves pending word/ticket/ID/slot. Request2 holds without
public request acceptance; its core response-ready is false, so pending and its
metadata hold. Store ID/slot and the saved generation basis cannot change there,
because outer acceptance is only from Idle0. Acceptance advances Request2 to
Wait3; poison/fault can instead enter Done4. Joint reset clears the two control
machines together, without erasing SRAM or initializing payload histories.

Extend the native reference with independent pending ticket/ID/slot histories,
check that relation on every Request edge and internal Store snapshot, and
exercise a long held public request plus wrong-high-ticket/ID/slot sensitivity.
Keep the existing162 conclusions, original five public assumptions, unknown
memory and complete address equations unchanged. Freeze and native-check the
changed163-assertion candidate before one separately coordinated pinned run;
review and seal its actual outcome before accepting any new scope.

The implementation adds exactly `lc_fs_held_request_owner` to the submitted
observer. Four focused native tests pass, including sixteen actual Request
edges held by public backpressure, snapshot-before-acceptance, and rejection of
independently corrupted high producer-ticket bits, high Store-ID bits and the
C slot. The two-slot failed-writer/recovery history still passes. Native
checking, interface generation, formatting and the collector unit test pass;
no public interface changes. Source retention now includes the original Store
controller, client wiring and transfer latches used in this derivation. The
unbounded result is still required.

The163-assertion candidate on clean `d5234fe7b8bf7578426627eed770f0042015307f`
returns actual `TIMEOUT 8 222`, child8, after601 wall seconds. Basecase0–19
passes at153 engine seconds; induction fails at333 seconds and identifies
`lc_full_dut.lc_fs_busy_not_latest_success_0` at381 seconds. Trace export begins
at395 seconds and remains incomplete. The different failing label is not proof
credit for the snapshot subset or a validated reachable counterexample.

All22 frozen native tests and preparation checks pass. Prepared-model review
matches all163 labels, five assumptions, zero covers, ten arrays with640 unknown
initial storage bits and unknown read INIT, and twenty qualified helper pairs.
Source/configuration copies and clean before/after identity match. The submitted
SV SHA256 is `bd04870dc3c4ec9c806ed1161123cc29edbbfb0f25494f2188ee3abb1f8b05d8`;
its only difference from r4 is the one added assertion. Configuration, observation
IR and name manifest remain byte-identical.

The sealed fifth archive `artifacts/phase6-fetched-sram-20261016-r5` has inventory
SHA256 `1ecceee1e85846935448557cc6c9faecd3dafcf22253d054a65c9473e7a990d4`,
verified before and after relocation. The one-job VM window is released after
owned cleanup before host review/archive. Fresh ps-a is empty and the same eight
protected PRX100 volumes and QEMU/profile/deadline remain.

## Reserved MatMul generation before Compute acceptance

Inspection of `queued_concurrent_dependencies_connect` identifies the converse
of the existing Pending ownership relation as the next proof-closure candidate.
While a syntax-valid MatMul head remains Reserved and transport is not poisoned,
the selected C writer must be Pending with the full head ticket. Reservation
publishes this intent before dispatch, with priority over older collection;
strict head ordering prevents younger replacement. Local rejection or engine
acceptance consumes the reserved head. A pending older producer cannot collect
the new full ticket while the head still owns its distinct retirement entry.

Poison is essential: reservation may drain an already captured packet after
transport halts, but publication explicitly checks `!engine.halted`. Therefore
the proposed assertion is guarded by the actual raw arbiter Poison state; it
does not demand publication for poison-drained heads. It does not assume poison
away or relax any original conclusion. Native checks will mirror the exact raw
syntax, selected slot/status/full ticket and poison condition. This equation-
derived reverse ownership support must receive its own actual formal result.

The changed candidate adds `lc_fs_reserved_mat_intent` as one assertion,
bringing the conjunction to164. It adds no ghost state or input constraint.
Four focused native tests pass with the mirrored selected-slot Pending/full-
ticket check, including both C slots and failed-writer/recovery histories.
Native checking, interfaces, formatting and the collector unit test pass.
Original reservation, publication, descriptor and dispatch sources are retained
alongside the Store sources. A fresh confirmed VM window permits one changed
candidate only; the original600-second child limit remains.
