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

Client response tag/data are private construction-record aliases, not named
ports in the canonical component IR. The formal tag conclusion compares the
actual saved local-tag register with the independently captured raw grant tag.
Both client tag fields refer to this register in the reviewed original source;
both data fields refer directly to raw host response data. Keep this source
alias contract separate from formal conclusions. Do not introduce invented
client outputs and prove a tautological alias equality, or claim a separate
response-data passthrough theorem.

The native 108-node component retains its 28 original root/event aliases.
Proof export uses the identical nodes, specifications, domains and metadata,
with one additional direct `raw_response_data_observation` output. This makes
the reviewed but otherwise unused response-data input reachable to the strict
RTL emitter. It adds no operation, state, premise or conclusion and does not
relax emitter reachability. Prepared model review must record whether the
formal optimizer removes this observation and its unused symbolic input.

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

## Discovery checkpoint

The [native discovery checkpoint](evidence/phase6-dma-arbiter-native-20261007.md)
at clean `aa9425a` passes 155/155 targeted tests and preserves all 190 preceding
artifact bytes. Independent inspection accepts eleven original registers/172
bits, seventeen derived events, fifteen nonconstant candidates and seven
retained original constants inside the exact 81-node combinational closure.
The sealed support retains initial failures, corrections and full inventory.
This is discovery only: exact sequential materialization and actual PRE/POST
correspondence remain next, before proof inputs or an arbiter theorem.

## Exact sequential checkpoint

The [materialization checkpoint](evidence/phase6-dma-arbiter-materialization-20261007.md)
at clean `ae84d15` passes 157/157 targeted tests and preserves all 190 preceding
artifact bytes. The accepted private checked module has 108 nodes, eleven
original registers/172 bits, sixteen inputs and twenty-eight original aliases.
Independent operation-by-operation comparison preserves all seven constant
boundaries and unknown startup state. No observer, conclusion or premise is
added. Actual-device PRE/POST correspondence is next; a local theorem remains
pending.

## Actual device correspondence checkpoint

The [finite native correspondence checkpoint](evidence/phase6-dma-arbiter-correspondence-20261007.md)
at clean `3f4b408` passes 159/159 targeted tests. All fifteen foreign LogicValues
and eleven original roots/seventeen events agree at PRE and POST, preserving
startup unknowns and the saved-PRE commit order. Required public transcript
witnesses reach an actual tied load/store grant, three contested Store Offer
stalls, malformed response consumption, four poison edges and reset/fresh
matching recovery. Only tests change; the prior sealed 190-artifact comparison
is reused read-only. Remote/reserved status, active-Wait reset, nonrising events
and arbitrary peers remain outside these finite cases. Reviewed observer
conclusions and proof inputs precede local induction; no theorem is claimed.

## Proof input checkpoint

The [proof input checkpoint](evidence/phase6-dma-arbiter-inputs-20261007.md)
at clean `f1493e0` passes 171/171 targeted tests and freshly preserves all
190 preceding artifact bytes. Three additional actual-device scenarios cover
matching remote fault without poison, both reserved statuses with consume-only
poison, and changed nonrising peers followed by active Offer/Wait reset and
recovery. Six deterministic exports retain the exact original state and
boundaries with the explicit emission-only data observation described above.
Eight reviewed conclusions use one startup-reset premise; the negative changes
only the checked stalled-payload data bit. Defined-binary helper qualification,
prepared-model review, local induction and causal negative qualification remain
next. Proof-input export is not an arbiter theorem.

## Remaining obligations

This component result cannot replace whole-Store payload/lease preservation,
DMA cursor and address bounds, nested SRAM checks, FIFO storage order, packet
provenance, generation/ownership composition, the fetched three-client arbiter,
explicit-fairness completion or the full 8x8 formal gate. A Store proof must
retain the inner final-capture and ownership state needed to justify compute
lease release; arbitrary core-progress cuts would permit a premature release.
No synthesis equivalence, runtime speedup, FPGA, physical timing, fabrication
or silicon claim follows from this design.
