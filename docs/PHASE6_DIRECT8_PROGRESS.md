# Direct8 inductive progress composition

The 11,718-edge completion obligation remains unchanged. The first full
23,552-step BMC attempt timed out; the accepted Fence witness establishes
ordinal retirement reachability, not useful Store execution or universal
completion. This work adds supporting progress conclusions on the original
direct 8×8/K16/host4096/q3 device before composing its service allowances.

## First inductive component

Use exactly the original seven public premises: initial joint reset only,
held producer packet, owned matching successful response, held response payload,
R2 request-ready opportunities, H2 response availability and C2 retirement-ready
opportunities. No premise constrains DUT response readiness, request persistence,
engine progress, dependency resolution or lease release.

Prove request stability, serial transport ownership and DUT response readiness
together with the following progress and observer invariants:

- A request stalled at one rising PRE is accepted at the next PRE. R2 alone
  does not establish this if the DUT can withdraw valid.
- An accepted request has its matching response accepted by the second later
  rising PRE. An independent saturating age keeps counting even if a response
  has already been offered; it must not freeze behind a stuck DUT.
- From the first public request offer, its response is accepted by the third
  later rising PRE: at most one request stall plus H2. ACK at the limit wins.
- Observer ownership/age correspondence is maintained across reset, initial
  offer, acceptance, response and reuse. Ages saturate instead of wrapping.

The proof uses k-induction through the existing typed unbounded-task contract.
Its induction depth is not a smaller substitute for the 11,718-edge deadline.
Both base case and induction must succeed before accepting an unbounded result.
The original memories, initialization, full-width addresses and all public
payload bits remain in the submitted device. No abstract engine or memory cut.

This first component starts at the public offer, not an internal client request.
It therefore does not yet prove bounded arbiter grant or the complete T=6
allowance. Those grant/regrant and client-owner relations must compose next.

## Composition still needed

The source-derived candidate allowances remain T=6, L=1666, S=898, M=99 and
D=7*(4+1666+2+2)=11718. Establish these dependencies as conclusions on the
original model:

1. Two-client arbitration grants a persistent requester after at most one
   competing transaction, including a residual owner. It preserves snapshots
   and routes the eventual ACK to that same client.
2. Loader legal cursors advance on committed bytes; at most 128 bytes and one
   commit edge per byte fit L. Store performs its indexed read/payload edges
   and at most 64 acknowledged words within S. Keep full-width cursor and
   address arithmetic, including rejection and overflow paths.
3. Compute issues, clears, runs its bounded wavefront and captures every active
   C cell within M, then releases its leases and terminal ownership.
4. Queue/head/retirement ownership bounds older work by six without counting
   reserved heads or engine owners twice. Dependencies refer to older writers;
   their progress and terminal results release or reject the waiting head.
5. Compose the seven serialized service allowances and retirement ACK slack
   with the actual ordinal watch. Retain the entire deadline and watch tail.

Existing small-profile safety theorems are not automatically lifted to 8×8.
Any additional invariant is asserted and proved, never silently converted to
an internal-progress assumption.

## Useful Store reachability

Run the already registered useful Store task unchanged: LoadA8×16 at256,
LoadB16×8 at512, MatMul8×8/K16 and Store8×8 at1024, all caller ID73. Its separate
named producer premise fixes only that public sequence. The seven original
host premises remain; memory data and initial SRAM contents are not fixed.

Require all 256 distinct byte-read accept/ACK addresses and all 64 distinct
word-write accept/ACK addresses, three earlier successful retirements and the
watched successful Store ordinal retirement. A Fence, rejection, repeated
address or unacknowledged write cannot qualify it. Extend the independent
native public observer to exercise these same counts and full tags on both
slots, without changing the DUT or claiming native runs are formal witnesses.

## Validation and retention

Use targeted native tests and strict check/info/format first. Confirm original
completion bundles remain byte-identical and the nineteen exact comparator
bodies still match the retained qualified miter. Register new progress inputs
through the existing artifact registry and use the pinned runner/receipt path.
Coordinate a fresh VM window; do not overlap the board-validation jobs.

Retain unsuccessful runs as well as passes, exact source/tool/model identities,
seven selected premises, original memory INIT/read INIT, full-width source
copies and any complete witnesses. A timeout is incomplete evidence. Archive
verification precedes relocation; old sealed archives remain immutable. No
result is recorded for the new progress task at this planning checkpoint.

## Native and input checkpoint

All 19 focused tests pass, including the original direct8/registry/CLI tests,
the new typed component checks and seven native observer/traffic tests. Real
8×8 pipelines in both slots satisfy the transport observer and complete all
256 distinct read ACKs and 64 distinct write ACKs before Store retirement.
High-address rejection and unknown-memory/reset preservation still pass.
An explicit public-frame case reaches the inclusive offer-to-ACK age3 and
accepted-request-to-ACK age2 limits with address0xffffffff and a high-bit tag;
a stuck response consumer and a changed high ACK tag are rejected.

The component has eight selected conclusions and exactly the original seven
public premises. Its typed unbounded task uses induction depth12 global steps,
with a600-second limit; neither number replaces the original completion
deadline. Original direct1/direct8 harness pins, the direct8 DUT/IR and all
old task identities remain unchanged. Strict native check, info and formatting
pass; the only new public API is the optional artifact wrapper for this exact
component ID. Formal execution and useful Store cover results remain pending.
