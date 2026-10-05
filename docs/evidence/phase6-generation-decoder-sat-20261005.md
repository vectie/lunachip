# Decoder complete local generation SAT evidence

The strengthened local generation lemma passes pinned reset-base and
free-state step SAT at `f333a2b`, including seven exact production decoder
projections. All three comparison controls produce their selected proof
counterexamples. This establishes the stated local binary-input obligations,
not full-device safety or sequential composition.

## Exact extraction and comparison boundary

The extractor follows actual fault-priority muxes, snapshot status and ticket
selectors over all six writer roots, and all six writer publication and ticket
intent trees. It checks types, constants, holds and shared aliases. Every
projection must already be inside the original combinational closure; no
extra cut, input, production node or device port is introduced.

| Projection | Original NodeId | Type | Comparison |
|---|---:|---|---|
| Syntax fault | 121 | UInt4 | All raw descriptors |
| Source 0 | 240 | UInt3 | All raw descriptors |
| Source 1 | 243 | UInt3 | All raw descriptors |
| Writer flag | 235 | Bits1 | Syntax valid |
| Writer index | 233 | UInt3 | Syntax valid |
| Unused fields valid | 180 | Bits1 | Syntax valid |
| Dimensions valid | 224 | Bits1 | Syntax valid |

Syntax validation uses full bytes and all raw dimension bits. Raw source
selection remains defined for malformed descriptors and uses the actual
low-three-bit opcode projection. Production semantic checks truncate opcode
and dimensions; the independent syntax-valid guard prevents falsely requiring
those intermediates to agree on malformed syntax. The reference consumes no
DUT decoder, readiness or rejection predicates.

There are still 32 production cuts totaling 671 bits, 18 independent ghost
PRE ports totaling 336 bits, and 50 free inputs totaling 1,007 bits. The
transfer has 28 outputs, including 18 exact post-edge register transfers.
`I(pre)` equates all 18 state fields as an implication antecedent, not a solver
assumption. Status values, ticket wrap values, descriptors, head state,
reservation and terminal events remain unrestricted.

## Actual results and native validation

The source checkout is clean at `f333a2b` before and after all five invocations.
The unchanged locked Yosys 0.68 image, warning policy and Boolean helper
adaptation are used. All 13 emitted comparison helpers separately pass
pointwise binary equivalence and its negated-miter control. The local wrapper
then runs five serially executed combinational SAT jobs with
`-enable_undef -set-def-inputs -prove OUTPUT 1 -verify -show-inputs` after
preparation, flattening and optimization. No VM, engine, bound or assumption
setting is changed.

| Selected output | Actual exit | Explicit result |
|---|---:|---|
| Reset base | 0 | No model found, SUCCESS |
| Step including decoder comparisons | 0 | No model found, SUCCESS |
| Priority comparison control | 1 | Model found, selected proof FAIL |
| Rejection comparison control | 1 | Model found, selected proof FAIL |
| Negated step control | 1 | Model found, selected proof FAIL |

The reset base equates and clears both POST banks despite unrelated PRE
banks. Step requires decoder, POST-state, local fault/rejection and derived
public-halted agreement under inactive reset and `I(pre)`. These are binary
combinational results, not four-state equivalence or a reachable-state proof.

Independent review matches all 50 ports and 1,007 binary bits across the text,
JSON and VCD models for each control, with all 18 PRE-state pairs equal. The
priority model is unchanged: A0 Pending/ticket1 plus matching terminal and new
intent produces Pending/ticket0. Its head state0 with reservation1 highlights
the free-cut scope. Rejection is a valid StoreC1 with an Empty source snapshot,
independent fault5 and actual rejection1; this is not a prior failed-terminal
history. The negated-step model is a nonvacuous valid 1x1/K2 MatMul with two
saved Success snapshots. A negated implication may also fail on a vacuous
antecedent, so that control is only a plumbing check.

Five new decoder tests cover all 256 opcodes with all eight slot combinations,
raw reserved bits, syntax-fault priority, dimension overflow, valid semantic
boundaries and same-type authoritative wiring drift. All 74 formal-package
tests, eight exporter tests and 795 native tests pass, with formatting,
interface generation, strict warning73 checking, CLI smoke and source-boundary
checks. Public interfaces are unchanged. A fresh ordinary dependency export
is byte-identical across all 19 artifacts and six tasks.

## Retention and next step

The eight input artifacts, helper-equivalence evidence and complete SAT output
are retained under
`/private/tmp/lunachip-phase6-boolean-20261005.eg54q2/` as
`generation-decoder-inputs`, `generation-decoder-helper-output` and
`generation-decoder-sat-output`. Byte-identical copies are under
`/Users/kq/Workspace/lunachip/.phase6-boolean-evidence-20261005/`.
The complete SAT hash inventory verifies in both locations. Commands, lock,
driver source, five logs/exits and three JSON/VCD counterexamples are retained.
The independent `generation-decoder-sat-review.md` is retained beside the
directories in both locations, outside the immutable executed-output inventory.

| Bound artifact | SHA-256 |
|---|---|
| Complete SAT output inventory | `313974d211d5b8136025a82cc1ae245cd2e35be8a71ad255acd2f8e20fd45c50` |
| Combined transfer and reference source | `7315fe261d1ab13815a75d93d2da2749cd34092f7564dc92343da2c02eada73e` |
| Executed driver source | `13ee5fcf8ad7c622b46719c2061d8abbb86b705573e30ee3151eaae308153669` |
| Priority counterexample JSON | `18a81b52532a21e203ed1bc84cfac3e077f3427ae1fcc8e2250078124d77e682` |
| Rejection counterexample JSON | `5d76da81b0a71086e23c0789aff9c6e1aff6ba4c5cf4a2e01d5093054f9b8854` |
| Independent evidence review | `b9bb349ef672235743d6d785d3a15845c6b368d5a9b5e7c5f3bf5b29bb70613b` |

Next, test one additional all-18-field relation assertion at every existing
rising pre-edge boundary, guarded only by reset, in a separately bound
full-harness experiment. Keep all seven original monitor assertions, 20 DUT
bounds assertions, four host assumptions and the 256-global-step horizon.
Do not turn the relation into an assumption or change ordinary bundle bytes.
The last full safety attempt remains a timeout, and ownership, saved issue
authorization, FIFO, retirement, leases, ticket-wrap and liveness remain
separate unfinished obligations. No ordinary typed proof receipt is created.
