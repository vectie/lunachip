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

The accepted FIFO-supported variant proves these eight conclusions by base
case and unbounded k-induction on clean `25f9bd9`, under exactly the original
seven premises. It checks92 actual assertion cells and preserves all38
memories/8960 unknown storage bits and unknown read INIT. See the retained
[engine evidence and archive pins](evidence/phase6-direct8-progress-20261016.md).

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
component ID. The first transport induction and useful Store cover subsequently
time out at their unchanged600-second limits. The former passes its base case
but reports FIFO bounds failures during induction; the latter last checks
step63 of23,552 and produces no witness. Neither result is accepted as a
theorem or useful reachability. See the
[retained engine evidence](evidence/phase6-direct8-progress-20261016.md).

## Induction support refinement

The first engine run passed its base case through global steps0–11, then
reported induction failures at `lc_mem34_read0_bounds` and
`lc_mem37_read0_bounds`. These are the original depth3 descriptor FIFO read
addresses, not host address arithmetic. The emitted two-bit pointers reset to0,
hold while idle and wrap2→0 on a transfer. Access-conditional bounds do not
exclude an arbitrary induction-start pointer3 during earlier idle steps.

Retain that attempt unchanged. A separately named `-fifo-support` component
adds eight unconditional-after-reset pointer-range assertions, one read and
one write pointer for each original FIFO. Resolve them from actual memory
address ports and the emitter manifest, checking original register type,
clock/reset and lack of explicit initialization. These are additional
conclusions, not assumptions. Removing the assertion-only overlay must recover
the original formal DUT byte-for-byte; production RTL, IR, public harness,
all seven premises, unknown memory and full-width host addresses stay unchanged.
Both base0–11 and induction subsequently pass (`PASS 0 278`,183 wall seconds).
Fresh frozen preflight passes all20 focused tests, seven typed task checks and
five exact nineteen-helper audits. The refinement is accepted only for this
public transport component; the complete11718-edge composition and useful
Store formal reachability remain open. The next proof edge is actual
two-client grant/regrant and routed-owner composition, not another unchanged
full-bound BMC retry. Useful Store needs an original-model-validated witness;
native trajectories and the timed-out cover are not substitutes.
