# Direct8 Issue core linkage and engine latency attempts

Two additive profiles implement Issue/core phase linkage and finite-potential
composition for L1666, S898 and M99. Both pass base global steps 0–31 but time
out before induction completes. Neither profile has a typed proof result or
receipt. The accepted component remains the earlier 44-conclusion engine/prefix
proof; whole-command bounds and the 11,718-edge theorem remain open.

## First latency profile

Frozen source: c8112daaac2445ce90be068dbd57f59c1027a101.
Task: phase6-flux-tile-direct8-q3-engine-latency-r2-h2-prove.
Result: TIMEOUT 8 295; runner 8; 608 host wall seconds. SBY reports 601 elapsed
seconds under the unchanged 600-second cap. Base 0–31 passes at 162 solver
seconds. Induction last reports step 13; no trace is produced.

Nine new groups retain all earlier 44 conclusions, for 53 selected conclusions
and 137 actual assertions: Issue/core linkage, immediate Issue acceptance,
client phase ownership, inclusive age-11 ACK service, bounded positive work
potentials, one-edge decrease, command-age ownership, age-plus-potential bounds
and inclusive L1666/S898/M99 command-to-Done deadlines. All are assertions,
not additional premises.

Formal DUT SHA256:
92627660c73df11ab7a7d0b031811aa9bd671afe3b8bc489929006777c575bb1.
Source-set SHA256:
60033d1f5b789ea013b140cee44a409ae7b02432af9ff1d099322b2f94c1516d.
Property manifest SHA256:
7943e86d813f8f63521f879414ba25b45676a573ed0ab77938970fa3d4a96644.

Archive: artifacts/phase6-direct8-latency-20261016-r1.
Inventory SHA256:
59179deef6fc095bebb296015912301590001b2fdc58df1e74185c49f6e45cfe.

## Service credit profile

Frozen source: 40ed661f769edfad7edec5b4df3033d61d00f594.
Task: phase6-flux-tile-direct8-q3-engine-latency-r2-h2-service-credit-prove.
Result: TIMEOUT 8 296; runner 8; 610 host wall seconds. SBY reports 601 elapsed
seconds under the same cap. Base 0–31 passes at 163 solver seconds. Induction
last reports step 12; no trace is produced.

This profile keeps all 53 conclusions and adds inclusive grant-age-4 service
and client service-age carry. A waiting client carries age through the competing
transaction, must win the subsequent idle grant, and after that grant has age
at most service age plus 5. The conjunction selects 55 conclusions and contains
139 actual assertions. These are equation-derived candidate supports, not a
solver-produced diagnosis of the first timeout. No speedup or proof pass is
inferred from the different final induction step.

Formal DUT SHA256:
f6540f7cc1e0ddce8c5c7ffc0d758794d3f8cddc78c56fc10716ab3a11e43067.
Source-set SHA256:
32076aeeb5bb28e6693139b42b27de07220204f6e96f4ecf31ad75180c251de2.
Property manifest SHA256:
e94f860b654149e02377fa6b8808a8685e202d9ca5299aed5ea741d7aa972c3a.

Archive: artifacts/phase6-direct8-latency-20261016-r2.
Inventory SHA256:
d1eaca44b60fe7bd35d22e401ff2f9c765affcb10bd69760ab770c39d803a5d2.

## Validation and preservation

First frozen preparation passes 48 native, six verifier and seven automation
tests, twelve typed task checks and ten exact nineteen-helper audits. The
service-credit preparation passes 50 native, six verifier and seven automation
tests, thirteen typed task checks and eleven exact helper audits. Strict native
checking, formatting and interface generation pass; public interfaces do not
change.

Independent native observers check both complete competing slot pipelines and
a compute preflight-fault command. They check full-cursor work ranks, exact
age ownership, decreasing potential and completion bounds. Negative controls
reject parked Issue, high cursor bits, stalled rank, overdue completion, excess
service credit and a stolen regrant. Every legal transfer rectangle's rank
recurrence is checked, including short-row skips and row wraps. Native runs are
not formal reachability witnesses or unbounded proofs.

Both independent original-model reviews confirm exact compiled source copies,
clean unchanged frozen head/status, seven public premises, 38 memories, 8,960
unknown initial storage bits and unknown read INIT. The original 76 automatic
bounds and eight FIFO supports stay selected. All 257 original-equation aliases
retain UInt64 DMA intermediates, UInt32 request fields, UInt13 transfer cursors
and UInt4 capture coordinates. Production RTL, IR and public harness remain
byte-identical. Older accepted and timed-out bundles retain their pinned hashes.

The original 11,718-edge deadline, full watch tail, fairness windows, QEMU-only
tool environment and pinned image remain unchanged. Both runners remove only
their two owned transport volumes; before/after inventories match and eight
protected volumes remain. Final ps-a is empty. The reserved two-attempt VM
window is released with no further job queued.

The original temporary directories
_build/phase6-search-snapshot-20261015/artifacts/phase6-direct8-latency-20261016-r1
and the corresponding r2 directory were relocated to the archives above after
checksum inventory verification and complete byte comparison. The retained
archives are the recovery locations. Compiler caches are not archived.

## Next phase closure obligation

An additional host-only abstract observer example, added after both frozen
attempts, shows a precision gap in the current latency phase relation. All four
targeted latency-observer tests pass, including this new regression; it is not
part of either frozen solver snapshot. Outer Run, inner Done, core Done and
fault 0 satisfy that relation. On the original terminal collection equations, the inner
controller becomes Idle and the outer controller becomes Done, but the core
does not clear: fault ACK is false for successful completion and no final
capture occurs on this edge. The next phase relation fails.

This example concerns the latency observer relation alone. It is not a reachable
device trace, a solver counterexample or proof that it caused either timeout.
In a reachable successful completion, final capture would already have cleared
the core before inner Done. The next candidate support is therefore the exact
inner-Done/core-fault relationship: successful inner Done requires core Idle;
faulted inner Done retains core Done until its collection edge. Prove this
on original equations as an additional conclusion before claiming phase closure.

After command latency qualifies, live retirement-entry ownership, dependency
drainage, the six-predecessor queue rank, useful Store formal reachability and
the same-snapshot Phase 6 aggregate still remain. See the
[latency implementation plan](../PHASE6_DIRECT8_ENGINE_LATENCY.md).
