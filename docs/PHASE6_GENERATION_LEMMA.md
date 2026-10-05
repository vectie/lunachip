# Phase 6 local generation lemma proposal

## Status and boundary

The private production-cone discovery and combinational edge-transfer slice is
implemented and native-validated. The independent ghost transition,
reset/step SAT tasks and composition remain proposals; there is no lemma proof.
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
has eighteen post-edge state outputs and the three retained local/halting
observations, with no register, memory or clock domain. Each edge transfer uses
the checked reset value first, then enabled next state, otherwise free current
state. Existing production IR, RTL, public APIs and formal bundles are unchanged;
this intermediate slice is exercised only by white-box tests, not injected into
ordinary formal tasks or the device runtime.

Focused tests cover discovery and malformed cuts/specifications, exact typed
copying, deterministic construction, arbitrary-prestate reset, event-free hold
and all four reset/enable combinations. These are native construction/simulation
checks, not exhaustive equivalence to the independent ghost. Implement and
validate that independent reference next, then run the pinned SAT obligations
and sensitivity controls below before considering composition.
At implementation checkpoint `c2a14f2`, all ten new white-box tests and all
65 formal-package tests pass. The full native gate passes 785/785, with
interface generation, formatting, warning73 checking, CLI smoke and source
boundaries. Public interfaces are unchanged. A fresh complete dependency
export compares byte-identically with the retained pre-slice bundle.

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
pattern `-enable_undef -set-def-inputs -prove all_obligations 1 -verify`.
Every binary input value is free; definite-input semantics is not a claim of
four-state simulation equivalence and must not constrain real unknown state.

Require explicit successful base and step results, then real SAT counterexamples
for separate comparison/transfer mutations:

- On a matching older terminal plus new intent, select the old terminal ticket
  instead of the actual new-intent ticket; require unequal old/new ticket values
  in the witness, without constraining the positive task.
- Mutate the compared actual local-rejection result on a failed dependency;
  require the independent expected fault 4 or 5 and rejection event in the witness.
- Negate the aggregate equivalence output as a plumbing control.

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

This lemma supports generation/snapshot agreement and independent rejection;
it does not close engine-owner tickets or saved authorization across Issue.
Those require separate exact owner/FSM relations and actual accept/terminal
boundaries. Memory-pointer/occupancy invariants also remain separate obligations.
No FIFO, retirement, lease, write-path, liveness, ticket-wrap, full-safety, or
product-gate completion claim follows from this local lemma.
See `PHASE6_FORMAL.md` and `PHASE6_FORMAL_COMPLETION.md` for remaining evidence.
