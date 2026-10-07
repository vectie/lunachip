# Original two client DMA arbiter proof

The original direct-device two-client DMA arbiter passes scoped unbounded
binary safety by k-induction. Its isolated checked-payload negative fails
solely the intended payload conclusion after an actual grant and committed
stall. The proof uses clean source
`f1493e069c7ffc8804bdb4101df473a8c4bd6f76` and the
[accepted six inputs](phase6-dma-arbiter-inputs-20261007.md). The full Phase 6
gate remains open.

## Component and premise

The exact original component retains eleven uninitialized registers totaling
172 bits, fifteen raw symbolic cuts totaling 233 bits and seven original
constant boundaries. Grant, acceptance, routing and poison remain original
derived equations. The only assumption is first-sampled joint reset; later
reset, contender payloads, readiness and external responses remain arbitrary.
No stability, matching-response, ownership, history or fairness premise is
introduced.

Eight conclusions establish selected payload snapshots and held Offer payload,
public transaction history, saved local-tag identity, owner/fault routing,
arbitration, simultaneous edge updates, reset establishment, absorbing poison
and nonrising state hold. This is binary component safety, not eventual service,
DMA address bounds, Store lease preservation or whole-device safety.

The native 28-alias graph and emission-only 29-output view share identical
108 nodes and specifications. The direct raw-data observation adds no state or
theorem. Saved local-tag identity is compared with independently captured raw
grant identity. Client tag/data record aliases remain a separately reviewed
source contract, not named IR ports or an independent data passthrough proof.

## Reused helper qualification

A fresh read-only audit verifies complete current production/Boolean function
bodies against three members of the accepted 19-helper defined-binary lemma:
equality width two, equality width 32 and unsigned comparison width two,
at retained indices 11, 8 and 14. Both bodies of each pair match exactly.
The entire remaining RTL, including the original width-32 addition helper,
is unchanged.

The audit reconstructs the complete retained 19-helper miter, checks its actual
positive SAT success and selected negated-control failure, sealed manifest,
original clean-source logs and tool pins. This reuses three pointwise binary
results; no new SAT task, four-state equivalence or sequential equivalence
result is claimed. The component induction is a separate new execution.

## Actual prepared model

Independent inspection checks actual JSON, RTLIL and SMT, including both
hierarchical modules and clock lowering. Positive and negative have the same
state-role inventories; the comparison-only mutation adds no controller state.

| Actual inventory | Both models |
| --- | ---: |
| Free anyseq cuts and bits | 15 / 233 |
| Original DUT anyinit registers and bits | 11 / 172 |
| Observer anyinit registers and bits | 28 / 690 |
| Lowered ff cells and bits | 53 / 705 |
| Assertions and assumptions | 8 / 1 |
| Memories, covers and anyconst | 0 |

Observer anyinit consists of seventeen PRE samples/281 bits, ten snapshot and
history registers/237 bits, and the previous original-state pair/172 bits.
The actual model retains the otherwise unused response-data cut. Source storage
declarations total 867 bits; the additional 700 prepared bits are formal clock
lowering and sampling, not extra production hardware.

Six conclusions and the sole startup premise sample original rising PRE
predicates and enable on sampled-low/current-high clock. The two global
conclusions remain always enabled. The actual toggling clock initializes zero,
the sampled clock one, and sampled rising predicates true. Original DUT
state has no initial-value restriction. DUT SMT undefinedness has no premise;
the bridge's only premise is startup reset. Later symbolic reset has no hidden
constraint, and raw establishment is not bypassed by its PRE value.

Prepared RTLIL SHA256 is
`67492b04fee75b0ad9bc82664f5f8027c7f53e8d9cd94a2ce9c56f0d23cf2b39`
for positive and
`fc328c1b490f6c590839903f7984a66566d72511d24f3f22ead671f43f4a5df0`
for negative. SMT SHA256 is
`6c9054695be0a81481e0c4e0a7002043ac619e1948c9e70a2b570f9363239a33`
and `c9f3c58b71c2225b3f6508b4d3cca600a3d671ae2ccd02f5ec7dff10901550b2`
respectively.

## Engine results and actual sensitivity

Both serial jobs use depth 20, timeout 600 seconds, multiclock enabled and
smtbmc/Bitwuzla. The frozen Linux/amd64 image is
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`,
with Yosys 0.68, SBY v0.68 and Bitwuzla 0.9.1. Network access is disabled.
The lock and version runner hashes remain unchanged.

Positive `prove` reports explicit base-case PASS and induction PASS, with
nine SBY clock seconds and thirteen process seconds. No positive trace is
produced. This is unbounded k-induction, not a 20-step bounded-only result.

Negative `bmc` reports FAIL solely for `lc_arbiter_payload` at global step
seven, with four clock/process seconds. Its expected-failure child exits zero;
that is not a safety PASS. VCD, Verilog testbench, SMT replay constraints and
Yosys witness are retained.

| Actual sampled step | Causal witness |
| --- | --- |
| Low PRE 0 | Joint reset commits all eleven roots to zero at POST 1 |
| Low PRE 2 | Idle, reader valid, engine absent: real reader grant |
| POST 3 | Original Offer and independent grant snapshot commit |
| Low PRE 4 | Actual Offer with request readiness zero |
| POST 5 | A real stalled edge commits the stall observer |
| Low PRE 6 | Same saved owner/payload; checked data bit zero differs |

At low PRE six, all original state is independently checked: state Offer,
owner/preference zero, global next/expected tags zero, local tag `0x18000000`,
write zero, address `0xc0000000`, bytes one, mask one and data zero. Arbitrary
contenders have changed without altering the granted identity. Raw and saved
tuple are `0x60000000110000000018000000`; the checked tuple is
`0x60000000110000000118000000`. Their XOR is exactly `1 << 32`, request data
bit zero, with the local tag unchanged. Reset is zero and the same-epoch
snapshot and committed-stall witnesses are one. All seven unmutated
conclusions remain true. No request acceptance, response acceptance or later
sampled reset occurs in this epoch.

Global failure step seven evaluates the preceding low PRE six predicate,
not POST seven. Step eight is the trace sentinel. Independent manual VCD and
equation review, plus root read-only decoding, qualify the actual causal
sensitivity; no new collector program or synthetic diagnostic suite is
claimed. The initial driver's pending classification is preserved, with
subsequent acceptance recorded separately. No engine is rerun. Actual negative
trace SHA256 is
`fe7d635d497d7ca23efa184fcb5230be8c6797218503ef848adbc476bb7c3ff9`.

## Evidence and remaining gate

Complete six-input and 41-engine-artifact manifests verify, actual copied
sources match the pinned inputs, and before/after checkout status is empty
at the exact source commit. Native 171-test validation and the 190-prior-file
byte comparison are reused from the sealed input checkpoint, not rerun.
Production hardware, simulator and emitter sources remain unchanged.

Support root: `/private/tmp/lunachip-dma-arbiter-proof-20261007.S59j0b`.
Repo-local copy: `.phase6-dma-arbiter-proof-evidence-20261007`.
Both verify 190 retained files with manifest SHA256
`617e851681a3550be7d836ee22b508a0839e86b3a39ca44945a888180c78ba26`.
Recursive copies are exact excluding disposable caches. Prior sealed evidence
and the user's untracked codec test remain unchanged.

Store payload/lease preservation, DMA cursor/address bounds, SRAM checks,
storage order/provenance/generation composition, fetched three-client
transport, explicit-fairness completion and full 8x8 formal validation remain
open. No ordinary typed receipt, runtime speedup, FPGA, fabrication or silicon
claim follows from this component proof.
