# Retirement record formal execution

The held-payload negative control produces its exact selected counterexample
and passes the unchanged runner's acceptance checks. The adjacent-edge cover
times out during witness export, so the reachability discovery is not an
accepted cover result. Full retirement safety remains a separate obligation.
Its original six-assertion task also times out; neither control supplies a
bounded safety pass. Phase 6 remains in progress.

## Exact execution scope

All jobs use unchanged, clean commit
`1c9277730aab2c77653518bd71c74d75d1914a91` in the frozen retirement checkout.
They retain the direct 1x1/K2/host1024/q3 device, 115 observations, four
public-peer assumptions, no fairness, PRE sampling, two global steps per DUT
clock, bound 256 / 128 DUT clocks and timeout 600. The original pinned runner,
Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1 execute without networking in the locked
Linux AMD64 image. Source/task selections follow the
[retirement design](../PHASE6_QUEUE_RETIREMENT_RECORDS.md).

Positive safety selects p4,p5,p6,p8,p9,p10; negative selects only p10. Both BMC
models also retain all 20 emitted DUT memory assertions. The cover selects p11
and four assumptions; stock SBY cover preparation removes assertions, including
the 20 nested memory assertions. It does not convert them into assumptions.
No internal premise, reduced bound or source cut is introduced.

Canonical IR, ordinary production RTL and Boolean adapter remain byte-identical
to the original queue fixture. Production SHA-256 is
`977623cc1a7c835ca6da9287c4625ab9f36cf172d30158ae728fc461b630d44f`;
adapter SHA-256 is
`b81ca96190670c59fa630b13430180c48f227cf8a4931256b8d356eb5d1cfef5`.
The earlier actual 19-helper defined-binary pointwise proof and its negated
control are copied and reused by these exact input digests, not rerun or
relabeled as sequential or four-state equivalence.

All three logger HEAD/status snapshots match before and after execution;
complete status snapshots are empty. Original inputs, results, receipts and
failures are retained at
`/Users/kq/Workspace/lunachip/.phase6-retirement-record-formal-evidence-20261006`.
The 142-file inventory plus `outputs.sha256` matches the original support root
`/private/tmp/lunachip-retirement-formal-support-20261006.Zrixy0` by recursive
byte comparison; all 142 digests verify. Inventory SHA-256:
`a9ac3182d133d33c3518b56482c81642a96c8889796e6e16ed62fc9d5ff89188`.
The temporary trace viewer is retained unused and uncompiled; independent
trace review inspected original VCD values, not a transformed replay.

## Incomplete full safety task

The original task selects all six harness assertions together with the 20 DUT
memory assertions and four assumptions. Actual execution terminates TIMEOUT 8
after 601 wall seconds at the unchanged bound. Last diagnostic progress is
assumption checking at global step 63, after assertion checking at 62. No trace,
typed result or receipt is produced. Completed solver prefixes are not a
smaller-bound proof; no expectation, timeout or bound is changed to accept them.

## Incomplete cover witness

The exact p11 cover is discovered at reported global step 23 after 31 solver
seconds. The job then spends the remaining budget exporting model values and
terminates TIMEOUT 8 after 601 wall seconds. No typed result or receipt is
produced. Only a partial VCD exists; the Yosys witness, Verilog testbench and SMT
constraints are absent.

The retained VCD contains complete states 0..21, followed by a state 22 header
without signal values. PRE20 has reset 0, clock 0, valid 1 / ready 0 and oldest
entry 0 / ticket 0 held with payload `{id0,fault12,progress0,address0}`. Younger
entry 1 / ticket 1 is valid and nonterminal, and the real ticket-matched loader
collector fires. Post-state 21 shows that younger entry terminal and the oldest
record unchanged. Required next rising PRE22 is missing: post-state 21 cannot
replace it. Partial VCD SHA-256:
`902f3cdfd8a50774771dc12236bd0107dde5d1d77fb4bac7672de29167b462ef`.

## Complete comparison sensitivity counterexample

The negative reports only p10 failed at global step 15 and completes all four
trace formats in 202 wall seconds. Expected-failure acceptance returns runner 0,
with the typed counterexample and original receipt retained. All 28 child
output digests and result/receipt/input bindings verify independently.

PRE12 genuinely holds entry 0 / ticket 0: reset 0, valid 1, ready 0 and payload
`{id4294967295,fault0,progress0,address0}`. PRE14 has ready 1 for release while
pointer, ticket and complete raw payload remain unchanged. Saved hold and
raw-stable qualifiers are true; only checked saved ID becomes 4294967294.
p10 fails despite release-edge ready 1. Reported step 15 corresponds to PRE14;
post-state 15 is release aftermath. No intervening rising PRE reset invalidates
history. The one comparison mutation, not a DUT change, causes the failure.
Complete VCD SHA-256:
`c289ccb19c3e089e18ca267c6b17202b5d0df771c7ce62d23f44d928ddd2e0f7`.

## Claim boundary

This establishes sensitivity of the selected held-completion comparison,
including its release edge. It does not prove positive retirement safety,
complete cover reachability with a retained witness, public-admission packet
provenance, engine ownership, leases, ticket wrap, fairness, fetched/8x8/full
device safety or the complete Phase 6 gate. Physical claims remain excluded.
