# Public packet provenance formal execution

The exact p12 sensitivity counterexample and coherent p13 transfer witness
complete through the unchanged pinned runner. Independent review follows the
same publicly admitted packet through the actual PRE boundaries. These
controls are not a positive safety proof. The original all-seven safety task
times out after 601 seconds without a result or counterexample. Phase 6 remains
in progress.

## Exact execution scope

All tasks execute clean frozen source
`51f3fb5a1ccb3a68212f7c5355f0aad2c3a93767` at
`/private/tmp/lunachip-packet-provenance-native-20261006.vlphin`.
The unchanged direct 1x1/K2/host1024/q3 device retains 115 observations, four
public-peer assumptions, symbolic later reset, PRE sampling, two global steps
per DUT clock, bound 256 / 128 DUT clocks and timeout 600. No fairness, internal
readiness or progress premise is added. Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1
use the original locked AMD64 image without networking.

Positive safety selects all seven harness assertions, p4,p5,p6,p8,p9,p10,p12.
The negative selects only p12. Both retain all 20 nested DUT memory assertions:
27 and 21 total respectively. The cover selects only p13 with four assumptions.
Stock SBY cover preparation removes assertions, including nested assertions,
without converting them into assumptions; this is reachability only.

Canonical IR, ordinary production RTL and Boolean adapter are unchanged.
Production SHA-256 is
`977623cc1a7c835ca6da9287c4625ab9f36cf172d30158ae728fc461b630d44f`;
adapter SHA-256 is
`b81ca96190670c59fa630b13430180c48f227cf8a4931256b8d356eb5d1cfef5`.
The exact earlier 19-helper defined-binary pointwise proof and negated control
are copied and reused by matching hashes, not rerun or called four-state or
sequential device equivalence. Both new input bundles are byte-identical to
their sealed native-checkpoint originals.

## Complete comparison sensitivity counterexample

The negative reports only p12 failed at global step 7, completes in 40 wall
seconds and returns accepted runner exit 0. All four trace formats, the original
typed result and receipt are retained. All 28 child output digests and binding
hashes verify independently. The prepared model has 21 assertions, four public
assumptions and zero covers.

PRE2 actually admits and watches four zero-valued public lanes. PRE4 pops that
packet with saved 256 bits still zero, while all four public input lanes have
changed to UInt64MAX. PRE6 has all four synchronous response-valid signals,
zero-valued response data, HeadState 1 and actual HeadCapture. The raw packet
matches the independently saved packet. Only checked saved bit 128 becomes
one, so response_ok, current_ok and p12 fail before sticky failure is set.
All other current checks are true. A concurrent younger admission cannot
replace the existing watch.

Reported step 7 corresponds to PRE6. Subsequent state 7 still advances raw
transfer history to captured head and records the failed comparison. No
sampled reset interrupts the chain. VCD SHA-256:
`62e0ce4f04c56b631e6d4de291f1e20d88bf41ff5825c0c9385a4a79ad09cc92`.
This is monitor comparison sensitivity, not a production defect or a proof
of positive provenance, reservation or retirement safety.

## Complete coherent transfer cover

The positive p13 cover passes at reported global step 13 in 119 wall seconds,
returning runner exit 0 with all four witness formats and the original typed
result and receipt. All 28 child output digests and binding hashes verify.
The actual prepared model contains zero assertions, four assumptions and one
selected p13 cover.

PRE2 watches public lanes `[0,4093,8589934592,0]`, with both older ranks zero.
PRE4 pops the watched packet after public lanes change to zero. PRE6 receives
the original four lanes synchronously and actually captures them. PRE8 has
the matching captured head and reservation, sampling pre-write pointer 0 and
NextTicket 0 with allocation to entry 0 only. PRE10 confirms head and live
entry 0/ticket 0/ID 0; the malformed descriptor finishes locally. PRE12 retires
that same terminal entry with `{id0,fault12,progress0,address0}`, all recorded
watch milestones true and no current or sticky monitor failure.

Reported step 13 corresponds to PRE12; subsequent state 13 invalidates the
entry and advances the retirement pointer and monitor to retired. No sampled
reset or rewatch interrupts the chain. Younger same-ID admissions, including
a simultaneous younger pop and admission at PRE12, do not supply its identity.
VCD SHA-256:
`89cdca3b9b45ffbef001bc2f5736ef510180691f52f780484c91f549ce90d7d5`.
This minimal witness has no older predecessors: nonzero-rank stress remains
separate native evidence. The malformed-packet path does not establish useful
Store progress, engine ownership or positive all-seven safety.

## Incomplete full safety task

The original all-seven safety task retains 27 actual assertions, four public
assumptions and zero covers. It terminates TIMEOUT 8 after 601 wall seconds
at the unchanged declared bound. Last diagnostic progress checks assertions
at global step 33, followed by solver waiting. No assertion failure, trace,
typed result, receipt or child output-digest manifest is produced. This does
not establish a smaller-bound proof or permit changing its expectation.

## Retained support and remaining gates

All three logger HEAD and full-status snapshots match before and after each
command; all status snapshots and stderr files are empty. The sealed original
support root is
`/private/tmp/lunachip-packet-provenance-formal-support-20261006.p87VQg`.
Its byte-identical retained copy is
`/Users/kq/Workspace/lunachip/.phase6-packet-provenance-formal-evidence-20261006`.
The complete 148-file inventory plus `outputs.sha256` includes both accepted
controls, original failure logs, selected sources and reused helper evidence.
Recursive copy comparison and all 148 manifest digests verify with actual
exit 0. Manifest SHA-256:
`681896677c5292ea1966bddec68f824461edebba3e4d1b547f013d18ea11e2b5`.
Temporary automation build cache was moved outside the support root before
sealing; no evidence output is omitted. Neither sealed root accepts new output.

Positive queue, retirement, packet-provenance and dependency safety remain
mandatory. Engine-to-entry ownership, whole-Store leases, cursors/arbitration,
fetched write-path safety, controller-derived fair completion and the full 8x8
product scope remain separate requirements. These finite malformed-descriptor
controls replace none of them; physical claims remain excluded.
