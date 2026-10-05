# Local generation SAT evidence on 2026 10 05

The exact production generation transfer and shared independent reference pass
two separate pinned combinational SAT obligations: reset base and free-state
step. Three comparison controls produce complete counterexamples on their
selected outputs. This proves the named local bank/fault obligations for binary
inputs, not full dependency safety, decoder-intermediate equivalence or
full-device composition.

## Bound inputs and validation

The source checkout is clean and unchanged at `65ebc20` before and after all
five SAT invocations. The fixed fixture is the queued-concurrent 1x1/K2/q3
dependency design. Eighteen production register roots contribute 336 current
state bits; the independent reference receives another 336 free bits. The
thirty-two exact production cuts plus eighteen ghost ports total 1,007 bits.
No ticket, status, descriptor, head-state, event exclusivity, ownership or
progress restriction is added. `I(pre)` is an explicit eighteen-field equality
antecedent in the step expression, not a solver assumption.

The original reference ghost bytes and generation-prefix bytes remain exact
under shared statement factorization. A fresh entire dependency bundle is
byte-identical to the retained pre-change bundle: nineteen artifacts and six
tasks. Strict native checking, formatting, interface generation, 69 formal
package tests, eight exporter tests, all 790 native tests, default CLI smoke
and dependency/source-size checks pass. The public interface adds only the
purpose-specific artifact exporter; production RTL and ordinary task bytes
remain unchanged.

The actual thirteen comparison helpers in this transfer separately pass the
existing pinned pointwise Boolean-equivalence runner and its negated-miter
control. The lemma then uses the exact archived Boolean-adapted transfer RTL,
unchanged raw decoder, shared combinational reference and wrapper. Original
transfer RTL and both production/transfer canonical IR artifacts are retained.

## Exact execution and results

The unchanged locked Yosys 0.68 image and version check are reused. Each run
reads the combined seekable SystemVerilog, prepares `lc_generation_lemma`,
flattens and optimizes it, then executes built-in Yosys SAT with
`-enable_undef -set-def-inputs -prove OUTPUT 1 -verify -show-inputs`.
This is not a bounded SMT task or a four-state equivalence claim. The five
jobs run sequentially, through offline isolated containers with one read-only
input volume and one writable evidence volume; no VM or tool setting changes.
All actual outputs are copied before interpreting their exit status.

| Selected output | Actual exit | Explicit result |
|---|---:|---|
| `base_obligation` | 0 | No model found, SUCCESS |
| `step_obligation` | 0 | No model found, SUCCESS |
| `priority_control` | 1 | Model found, selected proof FAIL |
| `rejection_control` | 1 | Model found, selected proof FAIL |
| `negated_control` | 1 | Model found, selected proof FAIL |

Base requires both POST banks equal and zero whenever reset is high, regardless
of unrelated PRE banks and event payloads. Step requires POST equality and
independent local fault/rejection equality under inactive reset and `I(pre)`.
Both separately check the derived public halted alias against `!reset && raw
poison`; the independent fault logic consumes raw poison directly.

The priority counterexample has A0 Pending with old ticket 1, matching load
terminal ticket 1, reservation/new intent and PRE next ticket 0. New intent
publishes Pending/ticket 0, so the mutated comparison against old ticket 1
fails. The rejection counterexample is a syntax-valid 1x1 StoreC in dispatch
with an Empty source snapshot, giving independent fault 5 and rejection; the
comparison-only negation fails. These are free-cut-state examples, not claims
that the complete device can reach those particular input banks. The plumbing
control negates the step implication specifically.

Independent review matches all fifty declared inputs between stdout model rows,
WaveJSON and VCD for each control: exactly 1,007 binary bits at their original
widths, with all eighteen PRE equalities satisfied. The priority example has
head state 0 and reservation 1, reinforcing the free-cut scope rather than
complete-device reachability. The actual negated-control model has inactive
reset, equal PRE banks and a valid 1x1/K1 MatMul with two saved Success snapshots;
the step is true and its negation is false. In general that plumbing control
can also fail on a vacuous step antecedent; it is not a reachability test.

## Retention and remaining work

Complete inputs, driver source, lock, commands, version checks, logs, exits,
three actual JSON/VCD counterexamples and recursive hash inventories are under
`/private/tmp/lunachip-phase6-boolean-20261005.eg54q2/generation-lemma-sat-output`.
The helper run and original eight-file input bundle are retained beside it.
Byte-identical copies are in
`/Users/kq/Workspace/lunachip/.phase6-boolean-evidence-20261005/` as
`generation-lemma-sat-output`, `generation-helper-equivalence-output` and
`generation-lemma-inputs`. The complete SAT output inventory verifies in both
locations. The independent `generation-lemma-sat-review.md` report is retained
beside the directories in both locations. Temporary containers and transport
volumes are removed.

| Bound artifact | SHA-256 |
|---|---|
| Complete SAT `outputs.sha256` | `44d49900695d773b692852efa2179b4f519bfadf636c19be12e3740c13c1c4ed` |
| Combined emitted/reference source | `141f38245400648cd599a088509bdb3e8a1eb738d553fb143885097b324fc7a3` |
| Priority counterexample JSON | `18a81b52532a21e203ed1bc84cfac3e077f3427ae1fcc8e2250078124d77e682` |
| Rejection counterexample JSON | `3f2aab389a720b340d2c276352ce4bcd58c3f4e36fddebbe3881614e12b722ab` |
| Independent review | `0c19dcad274c43990ebf80abf1dc38363714d17bf1c3dd5774d6774d0ea7ca05` |

Next, bind the exact private DUT decoder projections and complete their stated
intermediate comparisons. Then justify and test supporting-invariant composition
at the original pre-edge/reset boundary without replacing an assertion by an
assumption. The full 256-step safety task remains timed out, and the separate
ownership, issue authorization, FIFO, retirement, lease, ticket-wrap and liveness
requirements remain unfinished. No ordinary typed receipt is created here.
