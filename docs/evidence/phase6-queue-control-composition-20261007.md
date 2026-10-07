# Actual-device queue assertion composition checkpoint

Clean implementation commit `0b7fc71cc357a97092176d8f60983b84628a5938`
carries the previously proved binary queue-control relation into an existing
actual-device assertion. It changes no production hardware and introduces no
new premise. Clean targeted native tests pass 132/132, and the complete prior
178-artifact inventory has only the exact intended harness/hash changes.

The fresh original whole-device safety task times out after 601 seconds.
It produces no trace or typed safety result. This is not a safety pass,
completed composition proof, or completed Phase 6 gate.

## Exact implementation boundary

The [local control theorem](phase6-queue-control-proof-20261006.md) retains
sixteen original production registers totaling 37 bits. Their actual full-DUT
observations already exist among the 115 queue bindings. The shared invariant
text is reused verbatim over these observations, not over a shadow controller
or separately free internal inputs.

The existing public outstanding counter supplies the history alias. Its
initialization and admission/retirement-only wrapping updates are unchanged.
The added current-event conclusion rejects public underflow and overflow;
history is never repaired from internal population. This permits use of the
local relation without pretending its saturating supporting counter and the
original wrapping counter are unconditionally identical.

Only existing `retirement_event_ownership` (`p6`) is strengthened. Every old
check remains intact. The established raw structural/population relation is
conjoined under the existing first-sample flag, outside the old reset bypass:
later reset PRE cannot hide invalid state. Current event validity remains
reset-gated. The relation specifies the twelve exact contiguous modulo-three
retirement intervals, including the write pointer and live-entry mask; plain
population equality is insufficient.

All old monitor state, expected histories, mutations and host assumptions
remain unchanged. Production IR/RTL, formal DUT, property identities, task
selections, clocks, bounds, timeout and tool pins remain unchanged. No new
task family, profile, receipt, runner, state cut or internal fairness, readiness,
transfer or relation premise was added. This is an asserted conclusion, not
a cached lemma supplied to the whole-device solver.

## Clean native and artifact checks

Frozen checkout:
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`.
Interface generation, formatting, strict native checking with warning 73,
targeted formal and fixture/formal-CLI tests (132/132), and both native CLI
builds exit zero. Logs bind unchanged HEAD and empty source status before and
after each command. The full native module matrix was not rerun.

Four focused tests check exact register IDs/types/specifications and emitted
aliases, recover both original full harness SHA-256 values after removing only
the exact addition, preserve six queue profile contracts and memory labels,
and check count arithmetic and rejection of noncontiguous population-only
state. Native test development exposed reserved-name/type/deprecation issues
and an expected-label-order error; these were repaired in tests, not by
changing the monitor or original task ordering.

Fresh exports compare all 178 preceding artifacts across eighteen inventories:
142 are byte-identical and 36 have precise strengthening/source-binding deltas.
Each of six queue harnesses recovers its accepted old bytes after removing the
literal proved relation, public-history alias, event predicate and exact `p6`
extension. Only corresponding harness/source-set/job/task/gate hashes differ.
All six local queue-control inputs and all production/DUT/property artifacts
remain byte-identical. No whitespace or general assertion normalization is
allowed. Independent review verifies all 178 digests and nine task hash chains.

Compatibility inventory SHA-256:
`e87dced38059bf4320763d1ad69b6072685ec01905a75ffddacb208be0db6bd5`.

The external comparison helper's first compilation failed for two missing
checked-error annotations. The failed command logs are retained; adding
`raise` to its two synchronous functions repairs only automation typing.
The repaired comparison exits zero. This helper creates no engine result.

The exact full-device production/formal copies pass the unchanged pointwise
Boolean helper check: all nineteen scalar comparison helpers agree for defined
binary inputs, and the negated miter fails its selected proof. This is not
four-state or sequential device equivalence. The earlier local four-helper
result is not substituted for this full-DUT comparison.

## Original safety execution

The ordinary existing runner validates the exact job and typed bundle before
executing `phase6-queue-conservation-bmc`. Configuration remains BMC 256 global
steps, 128 DUT clocks, timeout 600, `multiclock on`, smtbmc/Bitwuzla, all three
queue conclusions and all twenty nested memory assertions. The original four
public host premises remain the only assumptions; later reset, malformed input
and terminal timing are symbolic. No cover is selected in this safety task.

Tools remain pinned to Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1 in the unchanged
AMD64 image. Execution uses explicit `colima-lunachip-phase3` context and the
existing scoped volume transport, network disabled, read-only container root,
dropped capabilities and numeric host UID/GID. Engines run serially. The
global Docker context and VM resource configuration are unchanged.

The actual child exit is 8, SBY status `TIMEOUT`, elapsed clock time 601 seconds.
The last logged query checks assumptions at global step 82; assertion checking
at step 81 completed sufficiently to start that next query. The engine returns
no pass/fail status and produces no traces. The retained original task reached
assumption checking at 96 in the same 601-second timeout; this added conclusion
does not establish useful solver improvement. This single comparison is not a
controlled performance benchmark or a quantified production slowdown.

The prepared model contains exactly 23 assertions: original top-level `p4`,
`p5`, `p6` and twenty nested read/write bounds checks for memories zero through
nine. Its only four assumptions are original `p0`–`p3`; no cover remains
selected. The ordinary configuration removes only the original unselected
`p7` cover. The new relation remains inside an assertion, not an assumption.
Complete source copies, prepared RTLIL/SMT2, configuration, engine logs, status
and transport provenance are retained. No result manifest or typed receipt is
manufactured for this timeout.

Independent prepared-model review verifies the exact assumption conjunction,
with no internal premise, ten retained memories and 172 arbitrary-init cells
in the full DUT. All 115 observation bindings and original rising-edge PRE
samplers remain intact. Source/native mapping, compatibility/hash-chain and
prepared-model reviews find no scope mismatch; they do not replace execution
or establish a partial proof bound.

Prepared RTLIL SHA-256:
`d19a4e77bfc243e70c504ba70292c1faac00fa7ca985cd49a39877c793b54afb`.
SMT2 SHA-256:
`4e6fa45c03c9ac3f115d9ba8b2ce391e74acd3c373a639292e3c23004bbab21a`.

## Claim boundary and next step

Source correspondence and native tests are not a whole-device proof. The
original queue, retirement-record and packet-provenance safety obligations,
FIFO data order, packet identity, engine/ticket ownership, Store leases,
DMA/address and memory safety, explicit-fairness completion, fetched-device
transport and full 8×8 gate remain required. No FPGA, physical memory mapping,
timing, GDS, fabrication or silicon-performance result follows.

Do not repeat this unsuccessful full run unchanged. The next
implementation-driven investigation is to check the exact original monitor
on the accepted 37-bit controller projection, with its original 35 monitor
bits and public history updates. Needed terminal and public-output names are
aliases of already extracted signals, not new state/cuts. The earlier six
local conclusions do not already prove these original monitor histories;
such a supporting result cannot discharge the twenty memory assertions or
replace the full-device/product gate.

## Retention and reproduction

Support root:
`/private/tmp/lunachip-queue-control-composition-20261007.bkszk8`.
It retains fresh exports, exact comparison helper/results, clean command logs,
the actual nineteen-helper miter and negative control, unchanged runner and
lock snapshots, and the actual safety output. Sealed inventory: 486 files,
SHA-256 `57622b4a46f33f2b0e483bbea9ad45acf9f9f48b2a35923f8b47efa63a2e9320`.
Retained copy: `.phase6-queue-control-composition-evidence-20261007` in this
repository. Every listed digest verifies in both roots and their complete
contents compare equal. Build caches remain outside both evidence roots;
neither root may be modified by future experiments.

Regenerate the ordinary safety bundle from the clean implementation commit:

~~~sh
moon run --target native cmd/phase6-formal-fixtures -- export phase6-queue-conservation NEW_DIRECTORY
~~~

The exporter refuses an existing destination. Retained command JSON records
the actual validation and execution. Never rerun automation inside a sealed
evidence root or overwrite its outputs.
