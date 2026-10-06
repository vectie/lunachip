# Queue assertion partition measurement

The fixed Queue/FIFO partition also times out after 601 seconds. It reaches
assumption checking at global step 97 rather than the original step 96, but
does not finish the 256-step task. No trace, typed safety result, parent receipt
or bounded conjunction is produced. This experiment does not establish a
useful performance improvement; further splitting and the remaining bank/control
invocations are not pursued at this checkpoint. Phase 6 remains unfinished.

## Scope and source binding

The documentation scope is committed at `d33241a`; the fixed experimental
adapter and its narrowly scoped execution corrections are committed at
`0c60da1`, `cb26e9c`, `bca2760` and `a9b7c8f`. The actual solver invocation uses
`a9b7c8fd32ea5034764fe023dd2bdbc4617e480b`, with identical before/after HEAD
and complete status snapshots. Tracked files are clean; existing untracked
evidence and `ir/codec/decode_wbtest.mbt` are preserved, not described as a
clean immutable checkout.

The adapter is `scripts/phase6-queue-assertion-partition.mbtx`, SHA-256
`3b12cbd743ae66a4c2e2dc344f45fa6646600861bd0fe505b281017cf3a5e6fb`.
It is a fixed measurement prototype, not a second general-purpose runner or
typed collection framework. The ordinary runner remains byte-identical at
SHA-256 `82f85a040af591720a52d20ad9c18b8d0828163fb766f1fe3a1fed499144f56a`.
The actual image and tool versions retain the original lock: Yosys 0.68,
SBY v0.68, Bitwuzla 0.9.1, Linux AMD64, image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`.

The original bundle passes its existing canonical regeneration/binding check.
The actual SBY DUT and harness are byte-identical to the retained original
queue-conservation sources. The complete original task, bundle, runner and
[timeout evidence](phase6-queue-formal-20261006.md) remain unchanged; all 321
original evidence digests verify again.

## Actual selection and preservation

The original frontend has 28 flavored `$check` cells: 23 assertions, four
public-peer assumptions and one cover. Each exact qualified selector resolves
to one object. The selected set is exactly the three top queue assertions
p4/p5/p6 plus eight DUT `lc_mem6..9` read0/write0 bounds. The complementary 12
operand/result-bank assertions and p7 cover are removed, not made assumptions.

Both selection-boundary RTLIL snapshots use pinned Yosys `write_rtlil -sort`.
Without sorting, deleting a check can relocate unchanged surviving cells in
the frontend dictionary. With canonical object order, independent review
finds only the 13 intended formal cell blocks removed, including their
attributes. All remaining nonformal content and all retained check blocks are
byte-identical. The actual SBY boundary snapshots match the checked preflight
snapshots exactly. This is not a claim of byte-identical prepared backends:
ordinary preparation/cleanup changes assertion-sampling representation.

The actual prepared model independently contains exactly 11 assertions, four
original assumptions and no cover. Executed config matches the supplied
config byte-for-byte: bounded safety, 256 global steps, 600 seconds, multiclock,
`smtbmc bitwuzla`, unchanged warning policy and ordinary `prep`. PRE clock
sampling and two global steps per DUT clock are unchanged. No fairness,
internal-progress premise, state/event cut or assertion-to-assumption
conversion is introduced.

## Measured outcome

Preparation reaches solver start in 22 seconds, versus 18 originally. These are
single paired runs, not an isolated or statistically repeated optimization
study; snapshot IO and ordering differ. Solver-relative timestamps are:

| Global step | Original assumptions / assertions | Queue/FIFO assumptions / assertions |
| --- | --- | --- |
| 80 | 6:31 / 6:37 | 6:28 / 6:34 |
| 94 | 9:13 / 9:20 | 9:02 / 9:09 |
| 95 | 9:23 / 9:31 | 9:11 / 9:20 |
| 96 | 9:38 / not reached | 9:24 / 9:31 |

The last query is assumption checking at 97, at solver-relative 9:33. The
600-second limit terminates the job with actual SBY exit 8 and
`TIMEOUT 8 23`; elapsed wall time is 601 seconds. Late assumption checks still
consume roughly 7–9 seconds. The outer adapter and logger record child exit 1
because the experiment refuses to treat timeout as success. The logger itself
returns 0 after recording that actual child failure and matching source context.
The experiment record explicitly says `TYPED-RESULT none` and
`ORIGINAL-TASK-RESULT unchanged`.

Neither step 97 progress nor the selected 11-cell inventory is a partial safety
pass. The independent 12-assertion bank partition and unchanged population
mutation under the new selector remain unexecuted. Therefore no conjunction
or new negative-control acceptance is possible. The original qualified p5
counterexample remains its separate, unchanged evidence.

## Validation and retained unsuccessful attempts

Strict standalone compilation/help and targeted formatter checks pass after
correction. Three earlier attempts stop before SBY: an emulated `/bin/chmod`
hang terminated in its exact owned container (exit 137); a preflight snapshot
pathname mismatch; and a nonformal comparison rejection caused by dictionary
order. Their actual exits/logs are retained. The corrections reuse the ordinary
runner's pinned-image permission initializer, name both snapshot paths
explicitly, and sort both boundaries. None changes chip RTL, ABI, product API,
assumptions or proof bound. The initial strict compiler diagnostics are also
retained rather than relabeled as a successful check.

No product MoonBit package changes in this experiment. The earlier 845/845
native milestone is not represented as a newly rerun gate. Source authoring,
inventory/preservation review and performance review use parallel agents;
the root serializes compilers and actual engines. Independent final reviews
agree on the exact model inventory, unchanged sources/config/boundaries,
terminal timeout and absence of a proof claim.

The complete 543-file support inventory plus `outputs.sha256` is retained at
`/Users/kq/Workspace/lunachip/.phase6-queue-partition-evidence-20261006`, a
recursive byte-identical copy of
`/private/tmp/lunachip-queue-partition-support-20261006.WFm5dA`. All 543 retained
digests verify. Inventory SHA-256:
`9954e60a6ffc64f7d657df586a8fc583a2e323a8f7eaaea62340db64b4661fd1`.
This root includes the actual configurations, snapshots, prepared model,
SMT, logs, source contexts and executor bytes for reproduction.

## Decision

Keep the fixed adapter only as reproducible experiment tooling. Do not add a
permanent typed shard collector, more assertion splits, unchanged reruns or a
weaker bound on the basis of this result. Any subsequent proof strategy needs
its own justified design and measured evidence. Original queue safety,
retirement-record, saved identity, ownership, lease, completion and full
fetched/8x8 obligations remain required. The experiment measures proof-tool
cost, not physical chip, GPU or inference throughput.
