# Direct queue formal pilot outcomes

The actual full/refill capture cover and population sensitivity control pass
their exact acceptance checks. The three-assertion safety task times out;
there is no queue safety proof result. Phase 6 remains in progress.

## Frozen inputs and retained results

All three jobs use clean, unchanged
`011a0485865571a6237f6b92ed3c82ce9a24cfe4`, the direct 1x1/K2/host1024/q3
device and all 115 exact typed observations. Each logger's before/after HEAD
and complete status snapshots match. The unchanged pinned runner uses Yosys
0.68, SBY v0.68 and Bitwuzla 0.9.1, Linux AMD64, image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`.

Every task retains four explicit public-peer assumptions, no fairness premise,
PRE sampling, two global steps per DUT clock, a 256-global-step/128-DUT-clock
bound and 600-second timeout. The source/task/property selections are specified
by [the conservation design](../PHASE6_QUEUE_CONSERVATION.md).

The complete original directory, including failed safety output, is retained at
`/Users/kq/Workspace/lunachip/.phase6-queue-formal-evidence-20261006`.
Its 321 inventoried regular files plus `outputs.sha256` match
`/private/tmp/lunachip-phase6-formal-compat-20261006.ISG3ZQ` by recursive byte
comparison; all 321 digests verify. Retention inventory SHA-256:
`9cdea2d10d2bc0ef44be3801b93882dbfa5b5c1b0851f72203fb0ece0ac2756e`.

| Selected task | Actual outcome | Recorded time |
| --- | --- | --- |
| `phase6-queue-conservation-bmc` | TIMEOUT; runner exit8; no trace or typed result | 601 seconds |
| `phase6-queue-conservation-cover-full-refill-capture` | PASS; typed cover witness; runner exit0 | 133 seconds |
| `phase6-queue-negative-population-bmc` | Exact selected p5 FAIL; typed counterexample; expected runner exit0 | 53 seconds |

The safety task selects p4 lane atomicity/response, p5 population conservation
and p6 retirement event ownership. It reaches assumption checking at global
step96 before timing out. That diagnostic progress is not a partial proof
receipt, a bound reduction or a completed safety task. Its timeout and missing
trace/result remain unchanged; the cover and negative cannot substitute for it.

## Complete full/refill capture witness

The cover selects only p7. Actual rising PRE step12 has reset0, public
valid/ready/admit1 and head-pop1. All four FIFO lanes have occupancy3, full1,
push-valid/ready1 and pop-request/ready1; response-valid is0. After that rising
edge, every lane remains full and its response becomes valid, while the sampled
full/refill history becomes1. Adjacent rising PRE step14 has reset0, head
state1/capture1/pop0, all four response-valid1 and the corresponding cover
predicate1. The prepared sampler reports p7 reached at global step15.

Clock sampling matters: these even global samples have clock0 and feed the
following rising transition. Odd-step reset values are not an independent
rising PRE reset; they must not be mistaken for vacuous reset-gated history.
The final synthetic time marker is not another DUT observation. All four legal
predicate wires remain true throughout the complete witness. No additional
internal-progress assumption is present.

Exactly one complete VCD is retained, together with its Yosys witness, Verilog
testbench and SMT constraints. All 28 child output digests verify. Actual VCD
SHA-256 matches typed result, receipt and output inventory:
`0721449735dc27ce6e0a6eb0d636fd8e93ef74918b0ba3f71f7f34a8433025ae`.

## Exact population sensitivity counterexample

The negative selects only p5. Rising PRE step2 admits a public packet; step4
pops all four lanes, step6 captures all four responses and admits another
packet, and step8 reserves the actual retirement entry. At rising PRE step10,
reset0 and both saved event flags are1. Retirement occupancy1 agrees with live
entries[1,0,0], all four FIFO occupancies are1, no unreserved head remains,
and outstanding2 equals physical population2. The raw population relation is
true. The comparison-only mutation changes checked retirement occupancy1 to2;
p5 becomes false and is reported at global step11. No retirement ACK occurs.

Positive and negative canonical IR, ordinary production RTL and formal DUT
are byte-identical. Their harnesses differ only in that selected comparison
expression; history and assumptions are unchanged. This is monitor sensitivity,
not a production hardware counterexample. Other properties are unselected, so
their apparent agreement in this trace does not constitute their formal pass.

Exactly one complete base VCD and all three companion formats are retained.
All 28 child output digests verify. Actual VCD SHA-256 matches typed result,
receipt and inventory:
`637c3783e2c8e9093cdc0adec08e44f610bf7e0a69a0642b9cc0f57591885895`.

Independent read-only reviews checked both actual traces, all selections and
input/result/receipt hashes. The earlier exact 19-helper pointwise Boolean SAT
and negated control are retained in this same root. They bind adapter SHA-256
`b81ca96190670c59fa630b13430180c48f227cf8a4931256b8d356eb5d1cfef5`
and production SHA-256
`977623cc1a7c835ca6da9287c4625ab9f36cf172d30158ae728fc461b630d44f`.
They prove defined-binary helper equivalence, not four-state/sequential safety.

## Claim boundary

These results establish one reachable coherent full/refill capture and one
selected comparison sensitivity control on the exact binary-adapted device.
They do not prove queue safety, saved admission-packet identity, immutable
retirement, engine ownership, leases, ticket wrap, eventual completion,
fetched/8x8/full-device safety or completion of Phase 6. The separate
[retirement-record native checkpoint](phase6-retirement-record-native-20261006.md)
does not change those outcome boundaries. Physical claims remain excluded.
