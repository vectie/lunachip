# Sequential generation bridge

At clean source `eafe2b144d49ec239795479a1139e32322bb9906`, the exact
eighteen-register generation bridge passes actual k-induction with the pinned
Yosys/SBY/Bitwuzla preparation. Both basecase and induction complete. This is
an unbounded result for this binary sequential slice under its stated clock
and startup-reset environment, not full-device safety or an ordinary gate
receipt. No solver-speedup claim follows from comparing this small slice with
the previous full-harness timeout.

## Exact design and conclusions

The slice copies the existing production closure and all eighteen original
`RegisterSpec`s in original NodeId order: 336 state bits, one rising-edge
domain, no memories, fourteen free nonstate cuts totaling 335 bits, and the
original clock. Reset, enable, initialization, next expressions, widths and
aliases are preserved. All DUT register initial values remain arbitrary.
The independent ghost retains its unchanged decoder and sequential generation
prefix: next/head initialize zero; the other 272 generation bits are arbitrary.

The clock initializes zero and toggles on each global step, exactly as in the
full harness. The only environment assumption is the existing first-edge
`lc_seen_edge || lc_reset`. Later reset and every nonstate cut remain symbolic;
there is no equality, event-validity, owner, authorization, readiness or fairness
assumption. The compared fields are raw next/head, six writer status/ticket
pairs and two dependency snapshot status/ticket pairs.

Four assertions are conclusions, not assumptions:

- Original rising-pre-edge relation, bypassed only by current reset.
- Both banks zero at the rising PRE boundary after a preceding reset edge.
- Both banks agree at every global phase once the initial reset edge commits.
- The full 672-bit DUT/ghost pair holds over every nonrising interval.

The saved previous-reset flag initializes zero; the hold monitor's prior data
does not. Its initialized observation flag disables only nonexistent history.
The actual materializer, not a handwritten POST-fed register bank, is emitted.
Public interfaces, production hardware, ordinary bundles, runners, locks and
resource allocations are unchanged. These exporter/tests add no device or
simulator runtime work.

## Native and compatibility validation

The full native suite passes 802/802. A subsequent comment-only correction
changes “proved” to “asserted”; all 81 formal-package tests and strict native
warning73 checking pass again. Interface generation, formatting, default CLI
smoke and dependency/source-size boundaries pass. Source reviews independently
check exact register mapping and clock/reset sampling.

Fresh exports preserve the original eight lemma artifacts byte-for-byte, and
all 46 artifacts across four ordinary dependency bundles. Five new files are
appended through the existing `generation-lemma` command, with a separate input
inventory; no new public function, ordinary task, schema or CLI flag is added.

The unchanged comparison-helper checker receives exact copies of sequential
production and Boolean-adapted SV. All thirteen helpers pass pointwise SAT
equivalence over defined binary operands; the negated miter fails its selected
proof. This does not establish four-state equivalence or replace the sequential
check.

## Actual execution

The retained external MoonBit driver validates all thirteen artifacts, seven
original and four new SOURCE hashes, unchanged decoder/prefix identities and
production IR binding. It runs two serial SBY jobs using the existing pinned
image: Yosys 0.68 `38e001a6f`, SBY v0.68, Bitwuzla 0.9.1.

Positive: `mode prove`, depth12, timeout600, multiclock on, smtbmc/Bitwuzla.
Actual SBY PASS/exit0 in eight seconds; basecase checks global steps0–11 and
passes. Induction tries steps12,11,10,9 and succeeds, reporting both temporal
induction success and engine PASS. There is no positive counterexample.

Negative: `mode bmc`, depth12, timeout600, same clock, assumptions and state.
Only `lc_reset || lc_all_fields_equal` changes to
`lc_reset || !lc_all_fields_equal`. Actual BMC FAIL at global step3 in four
seconds, selecting only `lc_generation_relation`. SBY exit0 reflects its
declared `expect fail`, not a passing safety assertion. Complete VCD, Verilog
testbench, SMT constraints and Yosys witness are retained. The selected trace
contains a post-reset rising boundary with seen-edge1, reset0, real bank
equality1 and mutated relation0. This checks sensitivity, not a production bug.

Both jobs use the same actual `clk2fflogic` and
`formalff -setundef -clk2ff -ff2anyinit -hierarchy` pipeline as the full harness.
Clean HEAD/status, input hashes, driver and lock remain identical before and
after execution. Actual models and engine logs, not reconstructed status,
determine acceptance.

Independent inspection of both actual prepared models observes four assertions,
one assumption, 35 anyinit, 18 anyseq, 49 ff and no memories. All eighteen DUT
current-state samples remain arbitrary (336 bits); reset-next sample zeros are
not current-state initializers. The ghost retains sixteen arbitrary fields
(272 bits), and the previous-pair monitor retains 672 arbitrary bits. Four
additional anyseq cells are original ghost indexed-read default witnesses;
fourteen are the shared event cuts. Rising checks use prior predicate samples
and the `01` edge detector; global established/hold remain enabled assertions.
The negative starts with unequal banks, resets them to zero, holds them, then
commits equal next-ticket1 and A0 Pending/ticket0. Its selected failure at
global3 evaluates the preceding pre-edge predicate. Neither relation nor
sampler coherence is introduced as an assumption.

## Scope and remaining work

This establishes the clock/reset bridge for generation/snapshot bookkeeping
under arbitrary shared binary events. Composition into the full DUT still
needs explicit boundary substitution and initialization justification; no
bank is eliminated from ordinary tasks here. Engine ownership, saved Issue
authorization, FIFO/memory safety, leases, retirement, ticket uniqueness,
liveness, physical timing and the ordinary full gate remain unfinished.

Reproduce from this committed source using the retained `.mbtx` preparation
and proof drivers and fresh output directories. The helper staging and full
ordinary-byte comparison are recorded separately from engine results.

## Evidence identities

Complete inputs, commands, versions, source-state records, native/helper logs,
actual prepared models, both engine logs, all negative trace formats and the
independent review are retained under
`/private/tmp/lunachip-generation-bridge-20261006.HXsH0r/`. A byte-identical copy
is saved under
`/Users/kq/Workspace/lunachip/.phase6-generation-bridge-evidence-20261006/`.
All 267 inventoried files verify in both locations; script build caches alone
are excluded. Existing nested proof inventories are verified, not rewritten.

| Artifact | SHA-256 |
|---|---|
| Complete retained inventory | `214b41837440ca7d2195a9b9d1dd0465d7e81b0af20b172399706eee9af49b6f` |
| Sequential IR | `6b8e8d244a0f2730f24f4e16e7b22eda36fdb17fa6859dbd145ca95cafe90019` |
| Production sequential SV | `2fb9a568c389b94cc7e90a6d89311cc51d3f2fb7bedf08f2bdbcd55607fc6c2a` |
| Boolean sequential SV | `f7ffa46b6c4b28a331f0ed6611360051f5166d71350bd5131d04b57aa08b3694` |
| Bridge SV | `f3e6d4cc81930d081234098af137d1621b87c05d53b35d511267d11e71a3fbac` |
| Positive actual SMT | `7c497b57b8a11a7efd9db235c1d8902cf0fc162910bebd7d17fa856d2f3493e9` |
| Negative actual SMT | `7fab0715f748b004fe9386079f163dbefafc42cbbaa382c1e89331eae4e69fc7` |
| Proof-output inventory | `cd7954b12094b9c4e9ca261d0b8ab72a2031cdbe08240822afd95b85dcd39e77` |
