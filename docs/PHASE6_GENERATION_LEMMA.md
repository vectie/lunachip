# Phase 6 local generation lemma

## Status and boundary

The private production-cone discovery, combinational edge transfer and independent
generation reference are implemented. A separate proof-input exporter supplies
reset/step implications and three comparison controls. The scoped bank/fault
reset and step obligations now [pass pinned SAT](evidence/phase6-generation-sat-20261005.md)
with all three complete sensitivity counterexamples. The strengthened
[decoder-complete reset/step obligations also pass pinned SAT](evidence/phase6-generation-decoder-sat-20261005.md)
at `f333a2b`, with independent evidence review. Full-device composition remains
unfinished. This is not a device gate.
This is one purpose-specific lemma for the fixed queued-concurrent 1x1/K2/q3
dependency fixture, not a generic formal framework or a replacement DUT.
The latest full safety attempt timed out at global step 69 without a trace.
Preprocessing took about 18 seconds; the remaining time was solver search.
Which assertion or cone dominates that search has not been established.
The proposed reduction is therefore an experiment, not a promised speedup.

The full safety task must retain its seven dependency-monitor assertions,
20 emitted memory-bounds assertions, four existing host assumptions, and
256-global-step / 128-DUT-clock horizon. A local lemma alone passes none of them.

## Implemented transfer slice

The fixed fixture resolves eighteen distinct register roots totaling 336 bits
and thirty-two unique cut nodes totaling 671 bits. Cuts retain exact original
NodeIds, types and shared aliases. The closure contains the original typed
combinational nodes needed by every next/reset/enable expression, LocalFault,
LocalReject and the derived public halted output. Unlisted sequential, memory
and input leaves are rejected; no replacement decoder or dependency predicate
is inserted.

The private materializer copies operation kinds, operand order, widths and
slice bounds with deterministic original-to-local IDs. Its combinational module
has eighteen post-edge state outputs, three retained local/halting
observations and seven private decoder projections, with no register, memory
or clock domain. Each edge transfer uses
the checked reset value first, then enabled next state, otherwise free current
state. Existing production IR, RTL, public APIs and formal bundles are unchanged;
this slice is used only by the separate local proof-input exporter and tests,
not injected into ordinary formal tasks or the device runtime.

Focused tests cover discovery and malformed cuts/specifications, exact typed
copying, deterministic construction, arbitrary-prestate reset, event-free hold
and all four reset/enable combinations. These are native construction/simulation
checks, not exhaustive equivalence to the independent ghost. The independent
reference now shares the original ghost's exact reset/update statements with
explicit PRE right-hand sides and POST left-hand sides. Its combinational form
initializes every POST field from PRE, uses blocking assignments, retains
collect then local failure then intent priority, and excludes nonfeeding history
and ownership state. Full original ghost and generation-prefix hashes remain
exact. Run the pinned SAT obligations and sensitivity controls below before
considering composition.
At implementation checkpoint `c2a14f2`, all ten new white-box tests and all
65 formal-package tests pass. The full native gate passes 785/785, with
interface generation, formatting, warning73 checking, CLI smoke and source
boundaries. Public interfaces are unchanged. A fresh complete dependency
export compares byte-identically with the retained pre-slice bundle.

## Separate local proof inputs

`generate_dependency_generation_lemma_artifacts()` exports eight deterministic
artifacts using the existing artifact type. The CLI command
`phase6-formal-fixtures generation-lemma DIRECTORY` refuses an existing output.
It adds no GateTask, ordinary runner mode or result receipt.

The wrapper has fifty free ports: the thirty-two original cut nodes and eighteen
independent ghost PRE fields, totaling 1,007 bits. It connects the exact emitted
transfer through name-manifest ports and retains raw poison as the independent
fault input. The reset-gated public halted alias is checked separately. The
unchanged raw decoder is reused; its unused inner-accept declaration is tied
off outside the generation fan-in without constraining an event cut.

`base_obligation` requires both POST banks equal and zero under reset, without
equating their PRE banks. `step_obligation` uses the eighteen-field PRE relation
as its implication antecedent and checks POST, local fault/reject and halted.
The priority control compares A0's new ticket to its older matching ticket only
when they differ; the rejection control negates the compared actual rejection
only on independent dependency fault 4 or 5. The plumbing control negates the
step obligation specifically, not the combined base/step result.

The exported inventory binds the production and transfer IR, original and
Boolean-adapted transfer RTL, unchanged decoder, shared reference and wrapper.
Construction tests verify separate free state, exact fragment reuse, deterministic
artifacts, and no clock/history/assumption insertion. Separate pinned SAT evidence
passes the two named obligations and all three sensitivity controls at `65ebc20`.
At that checkpoint, 790 native tests, 69 formal-package tests and eight CLI tests
passed; the entire ordinary dependency bundle remained byte-identical.
Seven private outputs now alias the actual syntax fault, both source indices,
writer flag/index, unused-field validity and dimension validity. The extractor
follows checked LocalFault priority muxes, both status/ticket snapshot selectors
over all six writer roots, and all six publication and ticket-intent trees.
It rejects changed types, constants, holds or aliases, and requires every
projection to be inside the existing closure, never a new cut. `inputs.txt`
records their original NodeIds and types. Production construction is unchanged.

`step_obligation` now also compares syntax fault and both raw source indices
unconditionally. Writer identity and unused/dimension validity are compared
under the independent syntax-valid guard, preserving malformed full-byte
inputs and the production truncation boundary. No reference predicate consumes
these DUT outputs. The strengthened obligations pass, and all three controls
produce their expected counterexamples in the separate pinned run at `f333a2b`.
All 74 formal-package tests, eight exporter
tests and 795 native tests pass. The exact ordinary dependency bundle and
public interfaces remain unchanged. This closes the stated local binary
decoder/bank comparisons, not sequential composition or full-device safety.

## Exact production extraction and reuse

Start from `queued_concurrent_dependency_formal_fixture()` and its immutable
`hardware()` and 48 typed observations, as `dependency_formal_dut.mbt` does.
Do not reimplement `queued_concurrent_dependencies_connect`, dispatch, or head
counter updates in a second production-like builder. Keep production IR/SV intact.

Add only a private, fixed-purpose extractor in `validation/formal`. Resolve:

- `NextTicket`, `HeadTicket`, six `WriterStatus`/`WriterTicket` pairs, and two
  `DependencyStatus`/`DependencyTicket` pairs: exactly 18 register roots.
- Each root's actual `RegisterSpec.next()`, `reset()`, and `enable()` from
  `Module::node`; follow their combinational operands using canonical IR nodes.
- Actual `LocalFault` and `LocalReject`, including raw descriptor decoding,
  source resolution, syntax/unused/dimension checks, and fault-priority cones.

Construct a small combinational module using existing typed IR construction and
the existing SystemVerilog emitter. Copy operation kinds/types from the source
cone, with deterministic original-NodeId-to-local-NodeId remapping. Replace only
explicit cut nodes with typed inputs. Materialize each register's edge transfer:
reset value first, then enabled next value, otherwise its free pre-state value.
Reading `next()` alone is insufficient. Reject unexpected reset/domain/type,
memory reads, unlisted sequential cuts, or operation shapes instead of guessing.

Cut the 18 current register values, four actual raw-head lanes, actual head state,
actual reservation event, raw transport poison, and actual load/compute terminal
valid/ticket/fault events. Preserve node aliases: a shared production node has
one cut input, not separately free values. Publication and local-fault logic
consume raw transport poison. The public `halted` output is instead the exact
production expression `!reset && raw_poison`; verify that expression and retain
it as a derived alias, never as a second free input. It agrees with the raw
cut only in the inactive-reset step obligation. The reset base must establish
the register relation independently of arbitrary raw poison and pre-state.
Treat reservation and terminal events as arbitrary agreed observations; impose
no ownership, readiness, success, fairness, or event-exclusivity assumption.
If the actual cone needs another state cut, record it explicitly and stop for
review. Never cut DUT syntax, dependency-ready, local-fault, or local-reject into
shared oracle inputs. No ABI ports or production graph changes are needed.

Reuse `dependency_decode_source()` unchanged for the independent raw decoder.
Reuse the generation prefix of `dependency_ghost_source()` through a minimal
private factorization, so the existing monitor and lemma consume the same
reference update source. Preserve existing bundle bytes under that refactoring;
exclude owner/authorization/cover-history state from this local lemma only.
Do not substitute DUT-computed predicates into that reference.

## Relation and independent obligations

For each side, state is next/head ticket (32 bits each), six writer
status/ticket pairs (2/32), and two snapshot status/ticket pairs (2/32): 336 bits.
Let `I(pre)` equate every corresponding field, including both snapshots and
head ticket in every state, not only the monitor's dispatch-state guard.
All ticket bits remain free, including wrap values; this is modular bookkeeping,
not proof of global ticket uniqueness or safety across wraparound.

Independently prove, under `I(pre)` and inactive reset:

- Actual syntax fault and raw source projections agree for all 256 raw bits.
  Writer identity, unused fields, and dimensions agree when syntax is valid.
  Production truncates opcode/dimensions before semantic checks; equality of
  those intermediate predicates on invalid syntax is neither true nor needed.
  Preserve full-byte syntax validation and low-bit source projection even when
  syntax is invalid; the positive task still includes every malformed descriptor.
- Actual local fault agrees with independently resolved snapshot generations:
  halted 15, syntax fault, unused 2, dimension 3, Mat dependency 4 / Store 5, then
  success 0, in that priority. Actual reject equals dispatch-active plus that
  independently expected nonzero fault. These are conclusions, not assumptions.
- `I(post)` holds after the exact source transfer and independent ghost update.
  Snapshots read pre-edge generations. Only matching Pending terminal tickets
  collect; local failure uses independently expected rejection; new intent
  overrides an older matching terminal/local failure for the same writer.

## Reset base and unconstrained-state step

Use two explicit combinational SAT obligations:

~~~text
base: reset_active                         => I(post) and every reset field=0
step: !reset_active and I(pre)             => decoder/reject agreement and I(post)
~~~

All pre-state bits and cut-event payloads are free binary inputs. Implement the
relation as an antecedent of the proved expression, not an external assumption
that the production monitor is correct. No reachable-state enumeration, forced
zero pre-state, initial-success state, or constrained ticket values is allowed.
The actual register reset specifications establish the base even for unrelated
pre-states. Joint reset in the existing full harness connects that base to the
first observed nonreset boundary; assertions must keep their original pre-edge
clock interpretation. No extra progress assumption is introduced.

## Pinned SAT evidence and sensitivity controls

Follow the existing Boolean-helper equivalence `.mbtx` evidence pattern with
the unchanged image digest, Yosys version, lock, warning policy, and runner
contract. Do not change engines, VM resources, safety bounds, or task flags.
Use actual emitted cone and reference bytes, not a hand-written status model.
For the combinational lemma, flatten/optimize then use the existing pinned SAT
pattern `-enable_undef -set-def-inputs -prove OUTPUT 1 -verify`, selecting
`base_obligation` and `step_obligation` in separate jobs.
Every binary input value is free; definite-input semantics is not a claim of
four-state simulation equivalence and must not constrain real unknown state.

Require explicit successful base and step results, then real SAT counterexamples
for separate comparison/transfer mutations:

- On a matching older terminal plus new intent, select the old terminal ticket
  instead of the actual new-intent ticket; require unequal old/new ticket values
  in the witness, without constraining the positive task.
- Mutate the compared actual local-rejection result on a failed dependency;
  require the independent expected fault 4 or 5 and rejection event in the witness.
- Negate `step_obligation` as a plumbing control; do not substitute the
  aggregate base/step result.

Archive complete commands, source sets, hashes, logs, exit/status results, and
counterexample inputs. A cut-state mutation witness demonstrates local lemma
sensitivity, not full-DUT reachability. A timeout/error is not a proof result.

## Composition acceptance and next decision

Record production IR/SV, typed-role-to-NodeId/type map, exact extracted closure,
register specifications, reference decoder/update bytes, emitted lemma, helper
rewrite/SAT evidence, and tool-lock hashes. Composition accepts only the same
production fixture and exact source closure; any hash/role/width/reset drift
invalidates the local evidence. Retain the unmodified production SV archive.
Use existing checked artifact/source-set facilities, not a new schema or runner.

First try the proved all-boundary relation as an additional supporting assertion
in the existing full harness. Do not replace an original assertion with an
assumption. Measure the unchanged 256-step task and retain all seven plus 20
assertions. If an assume-guarantee cut is subsequently proposed, its substitution
and closure must be independently justified against these exact source hashes.

The experiment has the separate checked fixture identity
`phase6-dependency-generation-support`. It appends
`generation_all_boundary_matches_reference` as property `p16`, after the
unchanged original sixteen property definitions. The predicate compares all
eighteen raw DUT fields with the independent ghost at every rising-pre-edge
boundary, guarded only by reset. It is an assertion, never an assumption or
an extra initial-state restriction. The ordinary four dependency bundles and
their task matrix remain unchanged. The supporting fixture runs one safety
task with eight monitor assertions plus the twenty DUT assertions, the same
four assumptions, depth 256, timeout 600 seconds, and locked engine. Its five
cover definitions remain present but are not new cover tasks; the ordinary
cover gate remains required separately. A supporting result does not replace
the ordinary gate or establish a solver speedup until measured.

The [actual supporting run](evidence/phase6-generation-support-20261006.md)
times out after 601 seconds, last checking assumptions at global step 62 of
256, with no solver status or trace. Preparation preserves the original DUT
state, memory and arbitrary binary choices and adds only the new assertion's
predicate sampler. This assertion-only experiment has not closed the gate.

The next bridge must connect the exact eighteen-field edge transfer and
independent reference to the unchanged prepared global-step clock semantics.
Preserve arbitrary pre-reset banks, the zero-initialized toggling clock, the
existing `lc_seen_edge || lc_reset` startup rule and symbolic later synchronous
resets. Prove reset establishment, enabled transfer/hold and preservation of
the relation at original rising-pre-edge boundaries; account for hold between
edges. Use the same `clk2fflogic`/`formalff` preparation and bind every source
closure, type, alias, reset and sampling role to the retained local evidence.
This is a separate sequential bridge obligation, not a new ownership or
fairness assumption. Any subsequent equality elimination must have explicit
substitution and initialization justification and its own bound source identity.
Neither experiment silently replaces the ordinary gate.

### Sequential bridge implementation contract

Copy the union of the original clock, existing cuts and combinational closure
in original NodeId order. Keep the eighteen state roots as actual registers,
remapping their original next, reset, enable, initialization and domain specs.
Only the fourteen non-state cuts remain free inputs; add the original clock as
the fifteenth input. This preserves 336 state bits, 335 free data/control bits
plus clock, one rising-edge domain and no memories. Do not implement a second
handwritten register bank around the combinational POST outputs.

The bridge uses the unchanged independent sequential generation prefix and
decoder, with the full harness's zero-initialized global toggle clock and
`lc_seen_edge || lc_reset` first-edge assumption. Compare all eighteen raw
current-state fields under only reset at the same rising-pre-edge boundary.
Keep later resets and all non-state cut events arbitrary. Separately check
actual state hold between active edges and reset establishment. No state
equality or event validity becomes an environment assumption.
An additional asserted strengthening checks `lc_seen_edge => I` at every
global phase, without assuming bank equality or sampler coherence. A bounded
bridge pass is not universal composition; require an actual induction result
before using the relation for an unbounded substitution argument.

Append sequential IR, original and Boolean-adapted sequential SV, bridge SV
and a separate bridge input inventory to the existing eight proof artifacts.
Preserve those original eight bytes and the ordinary dependency bundles.
Keep helpers private and reuse the existing exporter and CLI command; add no
public function, ordinary task, schema, result receipt or runner mode.
Native tests must compare every remapped register specification and cone node,
exercise arbitrary uninitialized state, synchronous reset priority and hold,
and bind each bridge port to the emitted name manifest. Pinned external checks
must use the same clock conversion and undefined-value preparation as the full
harness and retain explicit outcomes and a comparison-only sensitivity control.
This bridge remains a local sequential obligation, not the full device gate.

The sequential materializer and five appended artifacts are implemented. The
native gate passes 802/802 tests; after a comment-only wording correction, all
81 formal-package tests and strict warning73 checking pass again. Generated
public interfaces are unchanged; formatting, dependency/source-size boundaries
and default CLI smoke pass. Fresh exports compare byte-for-byte with all eight
retained original lemma artifacts and all 46 ordinary dependency artifacts
across four bundles. Independent source reviews find no functional or sampling
blocker. These checks do not establish the clocked relation: pinned helper
equivalence, actual induction and the selected relation-negative control are
still pending at this implementation checkpoint.

This lemma supports generation/snapshot agreement and independent rejection;
it does not close engine-owner tickets or saved authorization across Issue.
Those require separate exact owner/FSM relations and actual accept/terminal
boundaries. Memory-pointer/occupancy invariants also remain separate obligations.
No FIFO, retirement, lease, write-path, liveness, ticket-wrap, full-safety, or
product-gate completion claim follows from this local lemma.
See `PHASE6_FORMAL.md` and `PHASE6_FORMAL_COMPLETION.md` for remaining evidence.
