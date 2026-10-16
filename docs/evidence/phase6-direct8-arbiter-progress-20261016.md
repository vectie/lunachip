# Direct8 arbiter and local queue progress proof

The original direct8×8/K16/host4096/q3 device now has an unbounded proof of
arbiter grant service, persistent-client grant/ACK bounds, and local head,
engine Done and collector transitions. The full 11,718-edge completion theorem
remains open. The new conclusions retain exactly the original seven public
premises, unknown memory and full-width addresses.

## Accepted result

On clean `a2f8b8222e5995f9a81ce55e71314d2996cee8d2`, task
`phase6-flux-tile-direct8-q3-arbiter-queue-progress-r2-h2-prove` returns
`PASS 0 564`, runner child 0, 310 wall seconds. Base case 0–31 passes at 182
engine seconds; temporal induction succeeds at 192 seconds and reports passed
at 197 seconds. Both branches finish within the original 600-second limit.
Induction depth 32 global steps is not a reduced completion horizon.

The typed result records unbounded k-induction32, seven assumptions,
22 selected properties and `RESULT proved`. The compiled model checks 106
assertion cells jointly: 22 selected conclusions, 76 original automatic memory
bounds and eight accepted FIFO pointer-range supports. No proof premise is
added for internal readiness, persistence, grant, engine or queue progress.

The locked Yosys 0.68/SBY 0.68/Bitwuzla 0.9.1 image runs under QEMU. No Rosetta,
VM configuration, tool/image identity or completion deadline changes.

## What the component proves

The accepted eight public transport conclusions are re-proved jointly with
fourteen new groups:

- Actual Idle selection and grant-to-Offer transition capture the complete
  selected payload and owner. Offer/Wait retain address, data, mask, size and
  local tag; preference updates on public request acceptance.
- Wait/tag history, routed ready/valid and ACK ownership hold. Matching
  successful public responses cannot poison the arbiter.
- A granted transaction receives its ACK within T=6 DUT edges. Independent
  saturating time continues after a response is merely offered; inclusive ACK
  at the limit wins.
- A persistent client receives its own grant within T and its ACK within 2*T,
  allowing a competing transaction or residual owner. Before local acceptance,
  withdrawal cancels only that persistence watch, never the granted bus
  transaction. After acceptance it cannot cancel. A genuine granted/accepted
  watch is required for the local ACK, preventing an unrelated ACK from
  clearing the timer.
- Actual head pop/capture/reserve/finish events advance the head at the next
  PRE. Each actual engine Done state releases to Idle at the next PRE under
  the queue's wired completion-ready. A matching collector sets its entry
  terminal at the next PRE unless same-edge allocation takes its documented
  priority.

The persistent-client qualification matters: this does not yet prove that
every loader/Store request persists until acceptance. Likewise local Done
release and collector commit do not establish a live matching retirement
owner for every Done engine. Those links remain explicit composition work,
not hidden assumptions. See the
[implementation and composition plan](../PHASE6_DIRECT8_ARBITER_PROGRESS.md).

## Original model and typed source placement

The metadata-only direct queue fixture accepts the 8×8 profile while retaining
its byte-identical default 1×1 graph. Its 115 roles refer to existing nodes.
Original arbiter equations resolve eleven state registers, 22 interface roles
and 17 events; all 165 backend aliases use actual emitter names. The older
free-input arbiter projection is not substituted into this proof.

Removing the exact proof-only overlay recovers the accepted FIFO-supported
formal DUT byte-for-byte. Production RTL, canonical IR, public harness and
name manifest remain unchanged. All 38 memories, 8960 unknown initial storage
bits and unknown read INIT remain in the actual compiled model. All nineteen
qualified comparator bodies remain exact; no address truncation or SRAM
initialization is introduced.

The first frozen preflight on `2df7b4d` passes 30 native and six script tests
but stops at a legacy verifier rule requiring every property label in the
wrapper harness. The new typed predicates/assertions reside inside the actual
DUT, with no added ports. No VM job, model, result, receipt or trace is produced
by that stopped attempt.

Commit `09509ac` checks labels across the exact digest-bound job source roster.
Legacy predicates still require wrapper labels; child conclusions require the
actual single compiled DUT module instantiated as `lc_dut`, one label across
all compiled files and correct module placement. Child assumptions are
rejected; canonical regeneration and source hashes remain mandatory. Six
verifier tests cover legacy FIFO bundles and wrong, duplicated, moved,
uncompiled and unsafe source cases. The complete fresh arbiter bundle is
byte-identical to the first export: verification support changes, not search
constraints or premises.

## Validation and identities

Fresh frozen preflight passes 30 native tests, six verifier tests and six
automation tests, strict check/info/formatting, eight typed task checks and
six exact nineteen-helper audits. Both complete slot pipelines and full-width
high-address rejection pass. An eight-command overlap requires real arbitration
contention, 512 read grants/ACKs, 128 write grants/ACKs, eight head paths and
matching Done/collector counts 4/2/2. Those counts are transfers across two
pipelines, not claims of 512 distinct host addresses. Native sensitivity tests
reject bit 31 snapshot changes and a stuck response consumer; inclusive T6/
client 12 ACKs pass. Original unknown-memory and reset-preservation checks pass.
These native trajectories are not formal reachability witnesses.

Independent host review confirms 106 compiled assertions, seven premises,
38 memories/8960 unknown storage bits, unknown read INIT, exact source copies,
and clean unchanged frozen head/status. The typed result and receipt verify.
The runner removes only its two owned transport volumes and byte-compares
before/after volume inventories. Fresh ps-a is empty and exactly the original
eight protected volumes remain. The VM and unused second slot are released
before host review/archive work for the separate target-only board campaign.

Canonical IR SHA256:
`12e94f78c7136ada755eed2f35c92af52d77aa75fa2f1398bab19872057ff3ae`.
Formal DUT SHA256:
`5693cc7d3e08fb237ccfd838034d5b7d80d5c46d2379c42da079e7e719e59c41`.
Source set SHA256:
`c926f4093bdc2fe1e00ca53680c3d9e572b9edb58644020e655ccd43f22e48bc`.
Property manifest SHA256:
`f4c157b8bdd571ff2a857ccc638cf574fcf0826cc5a204ec3707be1421e2bcd6`.
Result SHA256:
`3aa5a6aa6e633e6fc04427e207d153ac63a190d57c22578598b9956631f4030b`.
Receipt SHA256:
`b587d1bab53351becc6c2877beb8e149e896ee80f3eb1f5d7ec586eb48850c4f`.
Retained host reviewer SHA256:
`f63bacaa93f14e2916e7eb66fa111900d7a4019000ac3765292f9f01a914c4c5`.

The stopped preflight is sealed in
`artifacts/phase6-direct8-arbiter-20261016-r1`, inventory SHA256
`48bf821e139d002a78cd47f6642dabb4d4fbc6c565c172fadfe49d9ea0265802`.
The accepted proof is sealed in
`artifacts/phase6-direct8-arbiter-20261016-r2`, inventory SHA256
`3715190a2520cd51ad60de565cb4c4e34a6c8b0e5aa34ac698c5a25dcd4eda22`.
Both archives are verified before relocation and again at their destinations.
No older archive or unsuccessful result is overwritten or relabeled.

## Remaining 11,718-edge composition

Prove engine request persistence, loader cursor/commit and Store word progress,
bounded compute/capture and lease release, every engine's live entry ownership,
older-writer dependency drainage and the six-predecessor queue rank. Then
compose the candidate L1666/S898/M99 allowances and final 11,718 deadline.
The full 23,552-step positive BMC and useful Store cover timeouts remain honest;
no completion horizon or watch tail is shortened. Useful Store formal
reachability, final typed aggregate integration and the same-snapshot Phase 6
gate remain open. Fetched publication needs its own transport allowance.
