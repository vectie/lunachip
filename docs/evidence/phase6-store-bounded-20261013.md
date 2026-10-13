# Store bounded safety validation

Continue from the sealed full Store safety conjunction at `40521bd`. Run a
fresh 256-global-step bounded check of all nineteen original safety assertions
and ninety checked support assertions over the unchanged binary2x2/K2/host1024/q3
projection. This is 128 DUT clocks, not 256 DUT rising edges.

The new task uses exactly the accepted full109 source bytes. Only the task name
and solver policy change from prove/depth20 to bmc/depth256; timeout600,
Bitwuzla, strict preparation warnings and multiclock lowering remain pinned.
The sole premise is the original startup reset. Later reset, host inputs,
unknown SRAM/read initialization and four arbitrary32-bit producers remain free.
All support relations remain assertions, never internal assumptions.

Keep the existing private collector and runner, one native cache outside
evidence and the dedicated QEMU validation VM without Rosetta. Commit the plan,
native-qualified inputs, actual engine outcome and final ledger separately.
Freeze tracked source during execution, retain complete unsuccessful outcomes
and audit copied inputs, prepared models and final solver status before accepting
a bounded result. Historical timeouts and sealed archives remain unchanged.

This task addresses the outstanding Store bounded-safety obligation only.
Overlap witnesses, selected sensitivity, packet/fetched composition, explicit
fairness8x8 and the remaining Phase6 matrix still require their own evidence.
The existing unbounded positive result is not reclassified as this bounded run.

## Native qualified inputs

Three focused native collector tests pass, including the unchanged original
bridge digest, all109 assertion labels, one startup premise, no cover and exact
BMC256 policy. Strict native warning checks, interface generation, formatting
and the existing runner test pass. The bounded collector emits the exact sealed
full source digest
`5d95a3e4f4760ef9256c5b31776292cb717e2abe63f957150d27530e1e006180`.
No hardware or public interface changes accompany this task.

The earlier guided archive also contains accepted original overlap and selected
payload-sensitivity results. Its complete1,076-file checksum inventory verifies
with digest
`1859684cffad802526d2f2f4f0c63ad64da45a16dcfeae7a36143ddcd10bc22b`;
its qualification record verifies at
`1441f3949851524fcc2cc6511ca2bfbdfe2f411d9b0e363286e7ad642a3569ff`.
Review source identity and causal traces before reconciling the latest ledger.
These are input-guided existential/sensitivity evidence, not universal safety.

## Actual bounded outcome

At clean `b48ae30`, the pinned QEMU run returns SBY TIMEOUT, child exit8,
after601 wall seconds. Assertions0–45 finish; the assumptions check at46
starts but does not finish. The engine produces no counterexample or trace
and no full256 result. The status record's39 is process time, not wall time.
This unsuccessful bounded run does not invalidate or reclassify the accepted
unbounded full109 proof, and an unchanged retry is not scheduled.

Copied source/config and HEAD/status before/after match. Prepared JNY, original
RTLIL, lowered RTLIL and final SMT match the accepted full-conjunction models
after normalizing **all** task-filename occurrences. They are not raw-byte
identical filenames. The final solver roster remains109 assertions, the sole
original startup premise and zero covers. Earlier model-review output used
single-occurrence replacement and falsely reported mismatch; the retained
`model-review-all.txt` records the corrected complete comparison. This was an
audit normalization error, not a hardware or solver-source change.

## Original overlap and sensitivity credited

The immutable `.phase6-store-guided-evidence-20261008` already establishes the
original coherent overlap and selected payload sensitivity. Its complete
checksum inventory and qualification record verify. Exact original positive
bridge identity is `9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121`,
the same original body used in the full109 proof. Reversing the negative's
checked bit0 XOR restores its selected positive byte-for-byte; removal of
unselected properties preserves other source lines modulo indentation.

The scenario has1,721 guidance rows targeting only the fifteen original raw
inputs across115 paired global states, with the230–255 tail free. It constrains
no internal state, memory cell, held read, clock, ghost, private readiness or
conclusion. This is an explicit existential scenario, never a safety premise.

The complete230-frame cover trace binds Store ID4/C0/read address0/word10 to
genuine Loader-owned pregrant contention and one opposite C1 generation's
intermediate/final captures. Store grant at191 precedes four public writes:
512/10,516/14,528/15 and532/21, with matching successful ACKtags5/6/7/8.
PRE228 has Done, progress16, fault0 and the original cover predicate; its
sampled property is reached at229. Current combinational state at229 is not
that earlier sampled PRE. The historical actual cover PASS remains338s.

The complete152-frame negative has the genuine held guard true at149–151.
Actual and independent ghost words remain10, while only the checked word
becomes11. The selected p4 fails at151; historical expected FAIL is194s.
This is monitor sensitivity, not a DUT defect. All four trace formats remain
retained in the original archive. No expensive guided task is rerun or copied.

Evidence-local MoonBit audits record both source reuse and complete causal
traces. The prior full109 seal also verifies. Native full PRE/POST snapshot
equivalence, numerical MatMul and public ordinal retirement are not inferred
from these finite formal witnesses. Latest ledgers previously listing the
accepted overlap/sensitivity as pending are corrected by this reconciliation.

The Store unbounded positive conjunction and original overlap/sensitivity
now have accepted evidence. A separate BMC256 PASS remains absent; deciding
whether the stronger unbounded theorem fulfills that named safety gate is an
explicit user choice, not a silent requirement change. Packet/fetched,
explicit-fairness8x8 and the remaining Phase6 matrix are still open.
