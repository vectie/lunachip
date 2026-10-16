# Direct8 engine request and cursor capture lease progress

The first engine-progress induction attempt passes its base case but times
out before induction closes. It does not qualify an unbounded engine proof
or the 11,718-edge completion theorem. The follow-up adds original-equation
ownership conclusions while retaining the first task unchanged.

## First frozen attempt

Source: `0e761ee8cce4931615400ea6a99754ea2a2f2aea`.
Task: `phase6-flux-tile-direct8-q3-engine-progress-r2-h2-prove`.
Result: `TIMEOUT 8 334`, runner child 8, 611 host wall seconds; SBY reports
601 elapsed seconds under the original 600-second cap. Base global steps
0–31 pass at 183 solver seconds; induction's last reported attempt is step 12.
No trace, typed result or receipt is produced.

The task jointly checks 36 selected conclusions and 120 actual assertion
cells under the original seven public premises. The selected conclusions
include the accepted transport/arbiter groups and 14 new engine groups for
request persistence, request/ACK transitions, full-width cursor recurrence,
configuration stability, cursor bounds, loader Commit, Store Read, core
shape/rank/advancement, capture shape/advancement, lease updates and application
of the arbiter's 12-edge client service bound without cancellation.

All 38 memories, 8,960 unknown initial storage bits and unknown read INIT remain
in the compiled model. The 214 bindings retain UInt64 address intermediates,
UInt32 request fields, UInt13 transfer cursors and UInt4 capture coordinates.
Production RTL, canonical IR, the public harness and all previously accepted
typed properties are unchanged. The original 11,718-edge deadline and
23,552-global-step horizon are not shortened or qualified by this task.

Fresh preflight passes 40 native tests, six verifier tests and seven automation
tests, strict checking/info/formatting, nine typed-task checks and seven exact
19-helper audits. The competing two-slot trajectory checks 512 loader commits,
128 Store ACKs, 60 core advances, 128 capture writes and two actual lease
transitions to free. Native negative controls reject withdrawal, high-bit
cursor corruption and stuck capture/lease transitions; finite trajectories
are not formal reachability witnesses.

Independent review confirms assertion/premise/memory counts, unknown read INIT,
exact compiled sources and a clean unchanged frozen head/status. The runner
removes its two owned transport volumes. Before/after inventories match,
the eight protected volumes remain and final ps-a is empty. QEMU, the pinned
tool image and VM configuration are unchanged.

First formal DUT SHA256:
`19aa87319f82b60d40face2c3e0eaa415110857f2e340c9ab97d4215bc3b36b0`.
First source-set SHA256:
`2d03d73bac7a690dfd7713b40047bf6b732cc9c961d2b5044ada94521399fc42`.
First property manifest SHA256:
`63a98e0598d320f7434855b4efffcb9fd70df99e4c7fddc5bc2c061c923bbaab`.

The attempt is sealed at `artifacts/phase6-direct8-engine-20261016-r1`, inventory
SHA256 `44954e445e82b7a05aef6cdb66328176899f9973111abc88731131ffcf989e3f`,
verified before relocation and again at its destination. The timeout is retained
without promotion or replacement.

## Additional induction relationships

Structural review identifies a missing pending-read ownership bridge: an
arbitrary induction-start pending bit can otherwise persist during Store Idle.
Physical prefix readiness and held compute/inner slot relationships likewise
need explicit support. This diagnosis is derived from the equations, not an
engine-generated counterexample from the timed-out run.

The additive owner-support task retains the original 36 conclusions and adds
seven assertions covering pending phase ownership, lease phases, held inner
selectors, active loader/Store lease exclusion, physical prefix bounds and
selected loader-prefix readiness. Original memory ports and response equations
provide 43 additional aliases, for 257 total. Its target conjunction is 43
selected conclusions and 127 actual assertion cells; the premise count remains
seven. The first engine task and older accepted bundles remain byte-identical.

See the [implementation plan](../PHASE6_DIRECT8_ENGINE_PROGRESS.md) for the
remaining composition. Per-engine time bounds, live retirement ownership,
dependency drainage, the six-predecessor rank, useful Store formal reachability
and the same-snapshot Phase 6 aggregate remain open.
