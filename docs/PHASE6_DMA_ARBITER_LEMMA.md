# Original two client DMA arbiter proof design

The next Phase 6 supporting proof targets the actual two-client arbiter in the
fixed direct 1x1/K2/host1024/q3 queued accelerator. This is the loader/storer
transport component, not the fetched device's separate three-client arbiter.
The purpose is to establish request stability, transaction ownership, local
tag restoration and poison handling over original production equations.
The completed [queue ownership proof](evidence/phase6-queue-owner-proof-20261007.md)
remains unchanged; its conclusions are not added as internal premises here.

## Exact original component

Use `queued_concurrent_queue_formal_fixture().hardware()` with frozen complete
production IR digest
`35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc`.
Discover actual nodes through public memory-output drivers and original
register-next expressions. Do not infer ordinal ranges, rebuild a replacement
controller, add device ports or alter production construction order.

Retain all eleven original arbiter registers: state, owner, preference,
next global tag, expected global tag, saved local tag, write, address, byte
count, mask and data. Their widths total 172 bits. Their authoritative
equations are in `designs/flux_tile/arbiter_ports.mbt`, `arbiter.mbt` and
`arbiter_controller.mbt`. Copy original clock, edge, reset, enable, initial
values, operands and output drivers with existing formal remapping helpers.

Grant, selected owner, request acceptance, response acceptance, malformed-tag
checking and poison entry remain derived equations. Symbolic boundaries are
raw client request fields, raw client response readiness, reset and external
bus peers. They may change arbitrarily, including stalled contender payloads,
unsolicited responses, colliding local tags and malformed external responses.
No stability, readiness, response-match or eventual-service premise is added
to conceal an arbiter obligation. Recompute the complete cone and leaf
inventory; review it before accepting cuts or exposing proof inputs.

The initial implementation is private discovery and an inspected deterministic
inventory. Exact sequential materialization follows that review, using
existing closure/register-copy support. No generic extraction framework,
public probe API, runner family or proof receipt is required.

## Conclusions and independent observers

The supporting clocked relation must establish these conclusions:

1. A granted transaction snapshots its complete selected payload and local
   identity. Actual Offer payload is stable through external request stalls
   and its acceptance edge despite changing contenders.
2. Actual public request/response history agrees with original Wait ownership:
   at most one accepted outstanding transaction, no unsolicited response
   acceptance, and no new request on the response edge.
3. Only the selected client receives request-ready and response-valid. Response
   local tags restore the saved transaction identity. Malformed external tags
   or reserved status produce the documented client protocol fault and poison
   the arbiter on actual response consumption.
4. Preference changes only at request acceptance and then favors the other
   owner. A sole requester can be selected without an absent peer. This is
   arbitration safety, not eventual service without host/client fairness.
5. First-sampled joint reset establishes state. Later symbolic reset suppresses
   public handshakes and clears state on the original edge; nonrising events
   hold retained state. Poison remains absorbing until reset.

Use one first-sampled startup-reset premise and the existing initialized
global-clock toggle. Saved public history and PRE predicates are observers,
not controller inputs or assumptions. Prepared-model review must distinguish
original DUT state from observer state and verify actual rising/global clock
lowering. Response data is passed through; this slice cannot promise its
stability while the external host changes it.

## Native validation and formal execution

First inspect exact register identities/specifications, closure and all leaves.
Require deterministic inventory and reject source drift. Then compare retained
registers and derived events at PRE and POST against actual direct-queue
execution, mirroring complete foreign LogicValues and preserving startup X.
Reuse existing byte-host scenarios and observer hooks rather than adding a
second transport model. Include stalled requests with competing load/store
traffic, matching and remote-fault responses, malformed tag/status and later
reset recovery. Counters must require the claimed paths to occur.

Use targeted native checks while editing, then interface generation,
formatting, strict native checking with warning 73 and the relevant package
tests at the checkpoint. Existing production IR, ABI and all prior exported
artifact bytes must remain unchanged. Commit the native checkpoint before
proof-input export and serial pinned formal execution.

Run one local induction and one comparison-only stalled-payload sensitivity
control after source and premise review. The negative must mutate only the
checked payload comparison, retain original controller state and other
assertions, and fail solely the intended conclusion after actual grant and
at least one stalled Offer edge. Qualify actual PRE evidence without rerunning
engines after a collector repair. Reuse source-identical accepted helper proofs
where valid; do not retry the unchanged whole-device timeout.

## Remaining obligations

This component result cannot replace whole-Store payload/lease preservation,
DMA cursor and address bounds, nested SRAM checks, FIFO storage order, packet
provenance, generation/ownership composition, the fetched three-client arbiter,
explicit-fairness completion or the full 8x8 formal gate. A Store proof must
retain the inner final-capture and ownership state needed to justify compute
lease release; arbitrary core-progress cuts would permit a premature release.
No synthesis equivalence, runtime speedup, FPGA, physical timing, fabrication
or silicon claim follows from this design.
