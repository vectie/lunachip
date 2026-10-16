# Direct queue eventual completion proposal

This document proposes a bounded eventual-completion check for the direct
`queued_concurrent_tile(rows=1, columns=1, max_reduction=2,
host_bytes=1024UL, queue_depth=3)` design. The candidate deadline is 252 DUT
rising edges under request, response and retirement bounds of two edges each.
The deadline comes from controller transitions, not measured simulator latency.

No proof, cover witness or deadline counterexample is recorded for this
proposal. Review the derivation and establish its supporting invariants before
activating a task or reporting a result. This is a small direct-queue check,
not fetched publication liveness, an 8x8 proof or completion of the Phase 6
formal gate. The scope and existing evidence path remain those of
[PHASE6_FORMAL.md](PHASE6_FORMAL.md).

Implementation checkpoint: commits `f00a76e` and `c50261e` generate and register
the three direct-q3 fixtures below through the existing typed contracts and
exporter. Working native fixture/registry/CLI tests pass 23/23. Generation is
not an activated proof or a qualified deadline result. The supporting
FIFO-to-head prefix now has accepted base case, induction, cover and negative
evidence; full retirement/provenance composition, Store/DMA and the other
supporting obligations remain open. See
[the scoped FIFO proof](evidence/phase6-fifo-prefix-proof-20261007.md).

The clean source now passes the full native gate, 955/955 tests, and a fresh
CLI exports all three input sets. The sealed 252-file checkpoint and independent
emitted-premise review are recorded in
[direct completion inputs](evidence/phase6-direct-completion-inputs-20261007.md).
No completion engine result is recorded there.

Do not extrapolate this deadline to the retained 8x8/K16 profile. Extending
the same direct-q3 service arithmetic gives candidate `L=1666`, `S=898`,
`M=99` and `D=11718` DUT edges: at least 23502 global steps for a watch in
the first 32 post-reset edges. Those numbers are an unqualified arithmetic
extension, not an accepted bound or proof. An inductive deadline proof may
avoid that large bounded unroll, but cannot shorten the obligation. Fetched
publication additionally needs a fresh three-client arbiter/reader allowance;
neither direct deadline applies unchanged.

### Direct8 validation checkpoint, 2026-10-16

The ordinary direct8x8/K16/host4096/q3 fixtures are now exercised by13 focused
frozen native tests, including both slots, explicit R2/H2/C2 delays, duplicate
caller IDs, nonzero older work and full-width high-address rejection. The
independent native monitor distinguishes response availability from DUT
readiness and keeps ordinal identity and inclusive deadline semantics.

The exact direct8 deadline-negative task has a qualified actual counterexample
on clean `88c4d3e`: a real canonical LoadA admission precedes an active age-one
failure of the sole selected deadline assertion. All38 original arrays and8960
unknown initial storage bits, unknown read states, full-width address semantics,
seven public premises and23552-step horizon remain. The existing pinned runner
and typed receipt path are used without a new solver framework.

The subsequent full-bound positive run on clean `dea8c5e` times out at600
seconds (last logged assertion check41 of23,552); the11,718-edge deadline is
not qualified. Its ordinal-retirement cover passes at global step13 with a
complete successful Fence witness: admission frame2, ordinal1 retirement
frame12 at age5. Terminal state is observed on that retirement edge, not
recorded as a separately executed terminal task. The useful Store cover and
supporting progress composition remain open; the earlier252-edge proposal is
not silently promoted. Both original unknown memory and full-width address
semantics remain. See the
[direct8 evidence and immutable archive pins](evidence/phase6-direct8-fairness-20261016.md).

## Admission and retirement identity

Watch a descriptor only when `descriptor_valid && descriptor_ready` is true
at a DUT rising edge. The admitted packet consists of all four public
`descriptor_lane_0..3` values at that edge. Do not start the timer when a
producer merely presents valid, or when a fetched producer publishes work.

Caller IDs may repeat. Consequently, `completion_id == watched_id` is not a
sufficient identity check. An independent monitor must count admitted packets
and public retirement handshakes in order. At the watched admission, snapshot
the number of older admitted packets that have not retired. Each subsequent
`completion_valid && completion_ready` decrements that older count until zero;
the next handshake retires the watched packet. Account atomically for an older
retirement on the watch edge when initializing the count. A packet admitted
on that edge cannot itself retire on that edge.

This ordinal watch does not restrict IDs or assume an internal ticket value.
Typed observations at the existing private seams can link the independently
tracked packet to its head reservation and internal ticket for supporting
checks. Resolve those observations through the emitted name manifest; do not
add ABI debug ports or guess node ordinals.

The proposed completion obligation is retirement acceptance, which is
stronger than merely reaching a terminal record. A terminal watch also needs
its own reachability cover. Local rejection still fulfills the general
completion obligation, so a separate successful Store cover is required to
exercise useful work and the write path.

## Edge conventions and host assumptions

All ages below count DUT rising edges, not global formal steps. Let `e0` be
the edge accepting the watch. The deadline allows retirement acceptance on
any edge through `e0 + D`, inclusive. A monitor must fail if the watched
packet has not retired at that deadline; it must not silently stop checking
an active watch when the search horizon ends.

Use the existing clock contract: two global formal steps per DUT clock, with
one rising edge per two steps. Establish one initial synchronous joint-reset
edge, then prohibit reset assertion. This proposal does not model later reset
or a stale peer response crossing reset.

Choose positive integer fairness bounds `R`, `H` and `C` with these exact
meanings:

- If a public request first offers `memory_request_valid=1` at edge `e`,
  `memory_request_ready` must allow acceptance on one of the `R` edge
  opportunities `e` through `e + R - 1`. The request remains offered until
  acceptance; payload stability is a DUT property, not a host assumption.
- After a request accepted at edge `a`, the host offers one matching,
  successful response on an edge from `a + 1` through `a + H`, inclusive. Match
  `memory_response_tag` to the accepted `memory_request_tag` and require
  `memory_response_fault=0`. Hold valid, tag, fault and data until response
  acceptance, even if acceptance occurs after that availability deadline.
  This assumption constrains host availability, not response acceptance or
  DUT readiness. Permit no unsolicited or duplicate response and no earlier
  accepted malformed or remote-fault response. For this controller, the
  accepted owner should enter Wait after edge `a` and assert response
  readiness in that window; establish that as a DUT supporting invariant,
  never a fairness premise. An isolated response pulse only at edge `a` does
  not fulfill the obligation.
- If public `completion_valid` first offers a retirement at edge `e`,
  `completion_ready` must allow its acceptance on one of the `C` edge
  opportunities `e` through `e + C - 1`. Apply this to every retirement,
  including older packets, not just the watch.

The producer must hold valid and all four lanes while its descriptor is
stalled. Successful-host assumptions apply to every accepted bus transaction
through the watch deadline, including competing owners. They exclude poison
and remote-fault scenarios, which require separate terminal obligations.
They must not assume internal request readiness, dependency readiness,
engine acceptance, lease release, terminal state or core progress.

The transport observations are the public `memory_request_valid`,
`memory_request_write`, `memory_request_address`, `memory_request_bytes`,
`memory_request_mask`, `memory_request_data`, `memory_request_tag`,
`memory_request_ready`, `memory_response_valid`, `memory_response_tag`,
`memory_response_fault`, `memory_response_data` and `memory_response_ready`.
Retirement uses `completion_valid`, `completion_ready`, `completion_id`,
`completion_fault`, `completion_bytes_completed` and `completion_fault_address`.
`queue_occupancy` reports the packet FIFO, not all admitted unretired work.

## Candidate bound from controller transitions

Define the following conservative service allowances, in DUT rising edges:

~~~text
T = R + H + 2
L = 2 * (2*T + 1) + 2 = 4*T + 4
S = 1 * (2*T + 2) + 2 = 2*T + 4
M = 8
E = max(L, S, M)
D = 7 * (4 + E + C + 2)

R = H = C = 2
T = 6, L = 28, S = 16, M = 8, E = 28
D = 7 * (4 + 28 + 2 + 2) = 252
~~~

The sum serializes work on the watch's preceding command path even when the
real engines overlap. It is intentionally not a tight performance bound.

**Seven packets.** At a watched admission, at most six older unretired
packets can exist: three retirement entries, one separate unreserved head,
and two earlier FIFO packets ahead of the watch in the depth-three FIFO.
The full-FIFO simultaneous pop/push case instead has up to three older FIFO
packets before the edge plus three retirement entries, with no occupied head
in the pop state. Both cases give six predecessors. A reserved head is
already represented by its retirement entry; engine-owned packets are also
represented there. Neither can be counted again. See
[queue composition](../designs/flux_tile/queued_concurrent_graph.mbt),
[head transitions](../designs/flux_tile/queued_concurrent_dispatch.mbt) and
[retirement allocation](../designs/flux_tile/queued_concurrent_retirement.mbt).

**Four head edges.** With prerequisite resources available, the path is
FIFO pop, synchronous response capture, retirement reservation, then engine
issue or local rejection or Fence finish. The head cannot bypass an older
head or consume FIFO data by fall-through. See
[synchronous FIFO](../designs/memory/fifo.mbt) and
[head controller](../designs/flux_tile/queued_concurrent_dispatch.mbt).

**Bus allowance `T`.** Idle grants and snapshots a selected request before
Offer. Under independently established DUT offer persistence and Wait
readiness, the host's `R` ready opportunities and `H` response-availability
bound imply the corresponding transaction service bounds.
Two additional edges conservatively cover grant/regrant and edge-boundary
accounting. The two-client arbiter flips preference toward the other client
at request acceptance, and a sole requester never waits for an absent peer.
A continuously requesting client can therefore have at most one competing
transaction before its own, including a peer's outstanding residual
transaction. Allow `2*T` for each of its transactions. This argument is for
the loader/storer arbiter, not the fetched reader's three-client arbiter. See
[routes](../designs/flux_tile/arbiter.mbt) and
[arbiter controller](../designs/flux_tile/arbiter_controller.mbt).

**Load allowance `L`.** Legal LoadA transfers at most `1*2` bytes and legal
LoadB at most `2*1` bytes. Each byte follows Request, Wait, then one SRAM
Commit edge. Two trailing edges cover Done collection and ACK plus the
subsequent engine-reuse boundary. The cursor advances only on a successful
SRAM commit. See
[loader controller](../designs/flux_tile/concurrent_loader_controller.mbt),
[cursor and preflight](../designs/flux_tile/transfer_helpers.mbt) and
[operand bank readiness](../designs/flux_tile/slotted_bank_storage.mbt).

**Store allowance `S`.** Legal Store transfers at most one `1*1` C word.
Allow two edges for indexed read acceptance and the synchronous held payload
before its bus service, followed by two collection/reuse edges. Successful
host response finishes the word. The whole-rectangle lease prevents a younger
compute from overwriting its C payload. See
[storer data path](../designs/flux_tile/concurrent_storer.mbt),
[storer controller](../designs/flux_tile/concurrent_storer_controller.mbt) and
[held C response](../designs/flux_tile/slotted_result.mbt).

**Compute allowance `M`.** From concurrent engine acceptance, the legal path
is Issue and inner command acceptance, one Clear/prefetch edge, at most
`K + rows + columns - 2 = 2` Run edges, one C capture edge, slotted terminal
consumption by the concurrent compute controller, and engine Done collection
and ACK. Eight edges conservatively cover this path and its reuse boundary.
`step_ready` is wired to constant one by the implementation; it is not a
fairness assumption. See
[engine wiring](../designs/flux_tile/concurrent_clients.mbt),
[core schedule](../designs/flux_tile/execute_graph.mbt),
[capture wrapper](../designs/flux_tile/slotted.mbt),
[capture updates](../designs/flux_tile/stored_capture.mbt) and
[compute controller](../designs/flux_tile/concurrent_compute.mbt).

**Retirement allowance `C + 2`.** Every terminal packet receives external
ACK within `C`, followed by conservative pointer/capacity and admission
observation slack. The implementation need not offer a same-edge credit
when the retirement table was full. Local rejection and Fence termination
fit within the head and terminal-observation allowances. See
[retirement controller](../designs/flux_tile/queued_concurrent_retirement.mbt).

## Supporting invariants still required

The bound relies on these structural properties. They must be checked rather
than assumed as internal progress:

- All four FIFO lanes accept and pop atomically, preserve packet order, and
  produce their synchronous responses together. Occupancies and pointer
  ranges must justify the six-predecessor bound and independent ordinal
  monitor.
- Every dispatched engine command owns exactly one live retirement entry;
  head reservation, ticket assignment, terminal collection and retirement
  preserve that ownership without loss, duplicate collection or ID aliasing.
- Pending dependency generations refer to older writers. The head snapshots
  sources before publishing its own writer intent, and strict dispatch
  prevents younger replacement while it waits. Empty, Failed or replaced
  generations reject instead of waiting for future work. Same-edge writer
  publication must take priority over older terminal updates.
- Engine and slot conflicts drain accepted older owners. A younger command
  cannot seize the watched command's occupied engine or conflicting lease;
  unrelated bus competition is bounded by the actual two-client arbitration.
- A legal loader cursor starts at zero and advances monotonically on commit,
  so initialization prefixes permit its writes. A legal Store holds its
  synchronous C payload until consumption and excludes conflicting compute.
- Compute accepts at most the configured dimensions, advances its bounded
  wavefront without an internal step stall, captures every C cell and releases
  leases at final capture. Invalid preflight takes a terminal path.
- Engine completion ready is asserted outside reset; collectors match
  internal tickets and cannot discard an outstanding completion. Fence waits
  for older terminal records, not their external ACKs. Public retirement
  remains ordered and stable under backpressure.

The relevant dependency and ownership code is
[dependency publication](../designs/flux_tile/queued_concurrent_dependencies.mbt),
[dispatch resolution](../designs/flux_tile/queued_concurrent_dispatch.mbt) and
[engine leases](../designs/flux_tile/concurrent_ownership.mbt). Read-only
inspection identified no structural wait cycle under the specified host
assumptions. That is an inference supporting this proposal, not a proof result.

## Proposed tasks and sensitivity checks

Use 640 global formal steps, corresponding to 320 DUT clocks. Select watches
only on admissions during the first 32 post-reset DUT edges. The last eligible
watch then has its entire 252-edge deadline within the horizon, including the
initial reset edge and additional margin. Late watches must not weaken the
assertion by running out of horizon.

Add tasks through the existing `FormalPropertyPlan`, typed
`FormalSignalBinding`, `export_yosys_clocked_properties`, `BoundedProofTask`,
`GateTask`, property-binding verification and result mapping contracts. Do not
introduce another runner, receipt framework or production graph mutation.
Suggested task identities and obligations are:

- `phase6-flux-tile-direct-q3-eventual-r2-h2-c2-d252-bmc`: assert the ordinally
  watched retirement handshake by age 252 under the named assumptions.
- A terminal cover for an admitted watch, plus a retirement-handshake cover
  for that same watch. Covers must identify the watched packet rather than
  any unrelated completion.
- A successful LoadA, LoadB, MatMul and Store sequence, watching the admitted
  Store. Require an actual write request and its matching ACK, followed by
  successful watched retirement. A rejection-only witness does not establish
  useful-work or write-path reachability.
- A sensitivity task using identical RTL and host assumptions but a deadline
  of one DUT edge. Watch a real admitted, legal `1*2` LoadA; select only the
  shortened-deadline assertion. Its retained counterexample must show actual
  admission and failure of that deadline, not a startup failure. This checks
  the monitor and does not claim a production defect.

Also seek witnesses for nonzero older occupancy, retirement backpressure,
competing bus owners and a pending dependency. These expose the assumptions
and controller paths behind the conservative bound; they do not replace the
supporting invariants or extend a safety result beyond its selected horizon.

Retain exact assumption labels, edge conventions, watch identity and window,
deadline calculation, clock/global-step mapping, selected properties, pinned
tool identities, canonical IR and RTL/source digests, and witness or
counterexample digests. A bounded pass would establish only the selected
obligation through that bound. An execution failure is incomplete evidence.
Until such results exist, all tasks and the 252-edge deadline remain proposed.
