# Direct8 successful/faulted Done core linkage — 2026-10-17

This work adds proof-only original-state conclusions for the next
L1666/S898/M99 composition attempt. It does not change production hardware,
qualify the 11,718-edge retirement bound, or replace any failed formal result.

## Relationship and scope

At inner Done, a zero held core fault requires core Idle: successful final
capture already acknowledged the core. A nonzero held core fault requires core
Done until outer Run collects the completion and acknowledges that fault.
The new `d8d_done_core` conclusion preserves both transition paths.

A second conclusion, `d8d_pending_slot`, relates the actual UInt1 pending-read
response selector to the held Store selector. Its binding is derived uniquely
from the original register equation: actual SRAM read acceptance latches the
actual Store slot. It is asserted jointly, never supplied as a premise.
Without this relation, an abstract induction-start response slot can block
Issue despite Store/compute lease exclusion. This structural example is not
a solver-generated counterexample or a reachable hardware trace.

All profiles preserve the seven public premises, original 38 memories/8,960
unknown storage bits, unknown registered-read INIT, UInt13 transfer cursors,
UInt64 pre-encoding DMA addresses, full payloads and the 23,552-global-step
horizon for the separate positive completion task. No memory is initialized,
no address is truncated and no internal handshake is assumed ready.

## First isolated attempt

Clean source: `a9ab6306560d32a8431fe81f73470fe9921a5d8a`.
Task: `phase6-flux-tile-direct8-q3-done-core-link-r2-h2-prove`.

The separate phase component selects 47 conclusions: the accepted 44 engine
and prefix conclusions, the phase relation, immediate Issue progress and Done
core linkage. It contains 131 actual assertions, seven premises, k-induction32
and the original 600-second cap. The separate full 56-conclusion latency profile is
prepared, but not run in this attempt.

Result: `TIMEOUT 8 328`, runner exit 8, 609 host wall seconds, 601 SBY elapsed
seconds. Base 0–31 passes at 183 solver seconds; induction last reports step 14.
No trace, typed result or receipt is produced. The independent review confirms
the exact compiled inputs, original memories/read INIT and unchanged clean
snapshot. Owned transport volumes are removed; protected inventories match
and the final Docker inventory is empty.

Preflight passes 55 native, six verifier and seven automation tests, fifteen
typed task checks and thirteen exact nineteen-helper audits.

| Artifact | SHA256 |
| --- | --- |
| Formal DUT | `8f2556cb2afe1a5c805c41a43355572b3e197caff65f522bc54d9fd42c0fd19b` |
| Source set | `0d9b93fad7ca90b429fe863adfe0567f9d7fb7df7dc13ccd2101c5e367245a1c` |
| Properties | `666370486f7746307ec073e0ac16237314ec974f39f7d8be6734453b92870547` |
| Sealed archive inventory | `34e263d658334b3f2416b91022d84770349e8058697bf251a2497df1520c935e` |

Archive: `artifacts/phase6-direct8-done-core-20261017-r1`. Relocation verifies
the complete byte set before removing only its temporary snapshot copy. The
retained destination is the recovery location.

## Pending-slot refinement

Source `9915fce` preserves both first-profile identities and adds separate
48/57-conclusion profiles with 132/141 actual assertions. The final reserved
attempt selects the complete 57-conclusion latency/support conjunction.

Five focused native tests pass before freezing the snapshot. They cover both
competing complete direct8 slot pipelines, wrong-slot/phase mutation controls,
and actual underlying 8×8/K16 slotted-core success, invalid-dimension and
unloaded-operand paths. These natural core faults are not forced internal
faults in the direct8 outer controller or formal reachability witnesses.
All three core paths hold completion through backpressure, acknowledge it
correctly, and preserve every SRAM cell and registered-read value on reset,
including unknowns. The native pending-slot observer uses the assertion's
reset guard rather than converting pre-reset unknown state to an integer.

Strict native checking, interface generation and all six targeted automation
unit tests pass. No public interface changes. Both new profiles regenerate
losslessly and retain the canonical IR, original manifest and public harness.

The clean frozen preflight on
`9915fceafec915cb07b6942b25386d8487525e53` passes 56 native tests (20 baseline,
10 arbiter and 26 engine), six verifier and seven automation tests, 17 typed task
checks and 15 exact nineteen-helper audits. All older profiles remain available;
neither the 48-conclusion phase profile nor the earlier 56-conclusion latency
profile is executed by the final reserved attempt.

## Final isolated full-latency attempt inputs

Task:
`phase6-flux-tile-direct8-q3-engine-latency-r2-h2-service-credit-done-core-pending-slot-prove`.
It selects 57 conclusions, 141 actual assertions, the same seven premises,
k-induction32 and 600-second cap. This is not a reduced positive-deadline task.

| Artifact | SHA256 |
| --- | --- |
| Formal DUT | `045c9fa8e059502a205ffdbe27751593afe01da76e8c64204b683de7d418a64a` |
| Source set | `c5c81201bca7fa16249bc77f455eaaadaf67041a2da94b1f5d6df6ae1eee7345` |
| Properties | `344f0f869c3a34a0f64859b93ffd52675f485b93c669c628e7926fbc5d0f36cf` |

Both attempts use the pinned AMD64/QEMU toolchain image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`
with Yosys 0.68, SBY 0.68 and Bitwuzla 0.9.1. The reserved window permits only
these two sequential attempts; no full native gate or other Docker job
overlaps them. VM configuration and protected volumes are not changed.

Result: `TIMEOUT 8 435`, runner exit 8, 614 host wall seconds and 601 SBY
elapsed clock seconds. The status's 435 is process time, not wall duration.
Base 0–31 passes at 239 solver seconds; induction last reports step 16. No
trace, typed result or receipt is produced. A change in the last logged step
between different profiles is not evidence of a speedup or a proof diagnosis.

Independent review confirms 141 actual assertions, seven premises, original
38 memories/8,960 unknown storage bits, unknown read INIT, exact compiled
sources and a clean unchanged source snapshot. Protected volume inventories
match and Docker is empty after the owned transport cleanup. The shared VM
and host/native window is released before archive and documentation work.

Archive: `artifacts/phase6-direct8-done-core-20261017-r2`, inventory
`967b645ba0f76bc8de294de848623c07ea12cd4908d6808b69c7e1be3da549e3`.
The complete retained model, logs, preflight inputs, source copies, reviewer
and outcome are sealed. Relocation checksums and byte-compares the full tree
before removing only the temporary snapshot copy. No cache or protected VM
volume is pruned.

## Isolated 48 conclusion phase inputs

Clean source: `94cb36ddda6615f2f38939a30680e97fd8e866c8`.
Task: `phase6-flux-tile-direct8-q3-done-core-link-r2-h2-pending-slot-prove`.
This task selects the accepted 44 engine/prefix conclusions plus exactly
`d8l_phase_link`, `d8l_issue_progress`, `d8d_done_core` and `d8d_pending_slot`.
It contains 132 actual assertions, the original seven premises, k-induction32
and the original 600-second cap. No command-latency conclusion is selected.

The strengthened native regression checks exact parent-44 inclusion, exactly
those four additional phase labels, unchanged premise labels and all three
existing input hashes. No formal input or production equation is changed.
The transition review retains success/fault ACK priority and the original
pending-clear/Store-Done history rather than assuming internal readiness.

Five focused tests and strict native checking pass before freezing inputs,
with no public interface diff. Frozen preflight passes 56 native, six verifier
and seven automation tests, 17 typed task checks and 15 exact nineteen-helper
audits. The full latency profiles are exported and checked, but not executed
in this new isolated window.

| Artifact | SHA256 |
| --- | --- |
| Formal DUT | `62d831f5960c33677444c3352138aa869dfd0458339b17d64e0a9de231f81304` |
| Source set | `387673527f12298e5ea79e4bc1a8a56f4516adeb7bea8f340ac416777fbbf37a` |
| Properties | `0c426d7ecec636bc0be5fcda83dee28e8bdf9a0041e365c7e9086b073d08c59f` |

## Accepted isolated phase result

The 48-conclusion task on clean `94cb36d` returns `PASS 0 835`, runner exit 0.
Base 0–31 passes at 184 solver seconds; temporal induction succeeds after the
last attempted step 19, and the induction engine reports pass at 480 solver
seconds. SBY clock time is 596 seconds within the unchanged 600-second cap;
host runner wall time is 608 seconds. The status's 835 is process time, not
wall duration.

The verified typed result records `CLASS unbounded`, `INDUCTION k-induction 32`,
`ASSUMPTIONS 7`, `PROPERTIES 48` and `RESULT proved`. Independent original-model
review confirms all 132 assertions, 38 memories/8,960 unknown bits, unknown
read INIT, exact compiled sources and a clean unchanged snapshot. Success and
fault Done/core linkage, immediate Issue acceptance and pending-response slot
identity are therefore qualified jointly with the existing engine/prefix facts.
This is a phase proof, not a command-latency bound or a reachability witness.

| Retained result | SHA256 |
| --- | --- |
| Typed result | `b1c6d2eb0ea2e48773e47c4b30011216b03e965bfd11b8c0b0e5c4eb6436f706` |
| Typed receipt | `7ad1d6841363c93a96c1c35dae209fc3220fabb878ecc6c6845a8b21a1d38f98` |
| Sealed archive inventory | `069b7c17ce3e775863fd1fd8be11eba35818b033f629acf849d502221ac14b36` |

Archive: `artifacts/phase6-direct8-done-core-20261017-r3`. The complete model,
logs, inputs, source identities, reviewer, typed result and receipt are sealed.
Relocation verifies the checksum inventory and byte-compares the entire tree
before removing only the temporary copy at
`_build/phase6-search-snapshot-20261015/artifacts/phase6-direct8-done-core-20261017-r3`.
The retained archive is its recovery location. No cache or protected VM volume
is removed. Protected volume inventories match, Docker is empty after owned
transport cleanup and both shared resource windows are released. Only one
formal job is needed in this new window.

## Remaining acceptance boundary

The accepted component now includes all 48 phase/engine/prefix conclusions on
`94cb36d`. Earlier sealed timeouts remain unchanged and are not promoted.
L1666/S898/M99 command-to-Done bounds are not selected by this phase task.
Live retirement-entry ownership, dependency drainage, six-predecessor rank,
useful Store formal reachability and the complete 11,718-edge theorem remain
separate outstanding obligations. See [the design](../PHASE6_DIRECT8_DONE_CORE.md)
and [the completion contract](../PHASE6_FORMAL_COMPLETION.md).

Next qualify command-age/potential and service-credit composition for the full
latency conjunction. The accepted phase component does not by itself promote
the existing 57-conclusion timeout. Keep the original seven premises, memory
and address semantics, cap and separate positive-completion horizon. No full
latency retry or redundant second phase run occurs in this window.
