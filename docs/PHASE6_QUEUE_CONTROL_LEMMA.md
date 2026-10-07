# Exact queue control transition lemma

The next supporting proof isolates the existing direct 1x1/K2/host1024/q3
queue's control transitions. Its purpose is to establish the inductive state
relations missing from the timed-out structural search, without rebuilding the
device or adding internal progress assumptions. The original bounded queue,
retirement-record, packet-provenance and full 8x8 obligations remain required.

## Exact production projection

Discover state through the existing typed 115-role observation seam. Copy
the original register specifications and combinational next-state cones into
one private sequential module using the existing generation remapping and
closure helpers. Retain widths, initial unknown state, synchronous reset,
enable, edge, next expressions and old-state commit ordering. Metadata capture
and extraction must not change the ordinary device IR, RTL, ABI or existing
formal bundles. Unexpected graph leaves stop discovery instead of becoming
guessed inputs.

The intended state is sixteen production registers totaling 37 bits: four
UInt2 FIFO occupancies, four Bits1 response-valid registers, UInt2 head state,
UInt5 saved head entry, three UInt5 retirement pointers/occupancy, and three
Bits1 entry-valid registers. Resolve their exact types and reset controls from
production nodes. Preserve the derived public admission,
FIFO pop/response/capture, head reservation, public retirement, allocation and
acknowledgment equations; none may become independently free inputs.

For this control-only abstraction, descriptor-valid and completion-ready are
public inputs. Poison, current entry-terminal bits and dispatch finish may be
explicitly free boundaries, provided their original reset and head-state masks
remain in the cone. In particular, free finish affects head transitions only
in Dispatch state three, and free terminal bits still pass through the actual
oldest-entry valid/terminal selection before retirement. An exported raw finish
cut must not be mistaken for an already state-masked finish observation.
Such inputs overapproximate when work may be admitted,
finished or retired; they do not establish terminal identity, fault correctness
or engine ownership. List every cut by role, original node and type. No fairness,
payload agreement, internal readiness or progress premise is introduced.
Arbitrary terminal bits can permit retirement before genuine dispatch finishes;
this projection therefore cannot prove that a reserved head entry remains live.

## Inductive relations

Reset establishes equal zero lane occupancies and response-valid state, an
empty head, zero retirement pointers/occupancy and invalid entries. Subsequent
steps must preserve lane equality, bounded occupancy, the response/capture
gap, and packet population measured by public admission minus retirement.

The retirement invariant must describe the contiguous live interval, not merely
its population. With successor modulo three and read pointer r:

| Occupancy | Live entries | Write pointer |
|---|---|---|
| 0 | none | r |
| 1 | r | successor(r) |
| 2 | r and successor(r) | successor(successor(r)) |
| 3 | all three | r |

Both pointers are in range. Allocation selects a free entry and acknowledgment
selects the oldest live terminal entry. For example, occupancy one, read pointer
zero, write pointer two and only entry zero valid satisfy a population-only
relation, but allocating entry two leaves the next write pointer on the live
entry zero. This unreachable free state demonstrates why population equality
alone is not inductive.

A local step proof may use its explicitly declared current inductive relation
as the induction hypothesis. Reset establishment and preservation must both
pass before it supports a sequential bridge. The whole-device task must not
assume the local relation or an internal transfer predicate. A successful local
proof is supporting evidence, not a replacement for its composition into the
unchanged device gate.

## Implementation and validation order

First implement exact discovery and sequential extraction, with native tests
for deterministic mapping, copied controls, reset, simultaneous full pop/refill,
reservation/retirement wrap, held retirement and later reset. Independently
review every boundary and show ordinary hardware and older bundles unchanged.
This checkpoint validates extraction and selected transitions, not induction.

Then reuse the established local reset/step and clock/reset bridge approach.
Select explicit invariants, retain a sensitivity counterexample and execute
through the pinned toolchain. Record the actual result and scope without
changing original assertion inventories, public assumptions, bounds, timeouts
or unfinished statuses. Tractability is unmeasured until that execution.

Engine-to-live-entry ownership needs a larger relation retaining all three
engine FSMs and tickets, live ticket allocation order and collectors. FIFO data
order needs storage provenance; DMA safety and whole-Store leases need their
own composition. The control-only projection does not establish any of them.

## Native extraction checkpoint

Implementation commit `670ca8cf773bd50181b218cc83ea2098a51574c4` adds only
four private validation files. Its clean native checkout at
`/private/tmp/lunachip-queue-control-native-20261006.xU6xN7` passes interface
generation, formatting, strict native checking with warning 73 enabled, and
108/108 formal-package tests, including four new extraction tests. The complete
native module test matrix was not rerun. Public interfaces remain unchanged.

The tests check exact copied register specifications and aliases, deterministic
mapping, unchanged source IR, forbidden closure leaves, synchronous response
timing, full pop/refill, nonedge hold, poison/reset suppression, held retirement,
simultaneous reservation/acknowledgment and modulo-three pointer wrap. The
forbidden-leaf test directly seeds unretained state or memory reads; it is not
an end-to-end production-next-expression mutation test.

The preceding `f65e565` fix removes the FIFO-specific four-assertion prefix from
the shared unbounded task validator. Other families now default to their exact
complete safety set; FIFO explicitly retains its original four-assertion
induction selection. Four new regressions pass, and all 36 freshly generated
FIFO artifacts match the contemporaneous clean `51f3fb5` exporter byte-for-byte.
The older August evidence differs and is not the accepted compatibility
baseline for this change.

Original command logs and native export comparisons are retained at
`/private/tmp/lunachip-queue-control-support-20261006.xU6xN7`. These are local
validation records, not a sealed formal-result inventory. No new solver,
induction, speedup, terminal-ownership or whole-device result is claimed.
Reset/step proof, sensitivity and sequential composition remain next steps.

## Local induction checkpoint

The subsequent [actual local proof](evidence/phase6-queue-control-proof-20261006.md)
at clean `47736b1` exports six scoped inputs and proves all six bridge
conclusions by base case plus k-induction through the pinned engine. It uses
the sequential clock/reset bridge directly; no separate materialized
free-state one-step task is claimed. A four-bit independent public history
counter and widened six-bit physical population establish conservation.
The negative changes only the checked population at a genuine current-PRE
reservation, producing the intended sole assertion failure. It checks
reserve-decision sensitivity, not a post-reservation committed transition.

All 125 targeted formal/CLI tests pass, and all 172 prior exported artifacts
are byte-for-byte unchanged. The original complete native matrix was not
rerun. The local proof is now established; carrying its relation into the
actual whole-device assertions and proving that composition remain unfinished.

## Actual device assertion composition

Carry the exact local invariant source into the existing full-device queue
monitor. Bind its public-history name to the monitor's existing outstanding
counter; retain that counter's initialization and public-only updates. Add an
asserted current admission/retirement arithmetic check so an invalid update
cannot be hidden by wrapping. Do not repair history from internal state.

Preserve every existing retirement check and conjoin the established raw
relation under the existing `lc_queue_sampled` flag to the existing
`retirement_event_ownership` predicate. The added invariant is not bypassed
on later reset. It uses all sixteen actual state observations, not a local
shadow controller or independently free internal values. Reuse the invariant
text verbatim; the native mapping check must bind its state names, exact types
and canonical IDs to the control discovery roots.

This intentionally changes six queue-family harnesses and their source-bound
digests. Production IR/RTL, formal DUT, property identities, old monitor
history and mutations, public host assumptions, task selections, clocks,
bounds, timeouts and pinned tools remain unchanged. Exact normalization of
only the added source and predicate conjunction must recover each accepted
old harness. No assertion is removed or converted to a premise, and nested
memory safety remains in the actual task.

Native checks and source correspondence precede one fresh ordinary structural
safety execution at the original 256 global steps, 128 DUT clocks and timeout
600. A pass, failure or timeout must be recorded as observed. Adding asserted
support is not a cached lemma, completed composition, or measured improvement;
the original retained outcomes and all larger Phase 6 gates remain required.

The [actual composition checkpoint](evidence/phase6-queue-control-composition-20261007.md)
at `0b7fc71` implements this assertion-only extension. Clean targeted tests pass
132/132; all 178 preceding artifacts are either byte-identical (142) or have
only the exact approved harness/hash delta (36). The actual original safety
task still times out after 601 seconds, last checking assumptions at step 82.
All 23 assertions and four public premises remain present. No proof or useful
solver improvement is claimed; production hardware is unchanged.

## Original monitor supporting proof: next implementation

Reuse the accepted 37-bit controller projection and emit the original queue
monitor verbatim, including all 35 monitor bits, initialized first-sample flag,
wrapping public counter and expected-history updates. The earlier six local
conclusions do not prove these original monitor histories. Do not alter the
accepted local bridge, production next-state cone or original full bundles.

Bind all sixteen state roots and existing event outputs by their typed roles.
Alias entry-terminal observations to the three existing terminal cuts and
completion readiness to the existing public cut. Bind completion validity to
the existing retirement-valid production driver and descriptor readiness to
its existing output; native tests must verify these identities. These are
names for already extracted values, not new state, boundary cuts or premises.

Use only the existing first-sample flag to require startup joint reset. Assert
the original three lane, population and retirement-ownership predicates,
including the new raw relation as a conclusion. Later reset and all eight
boundaries remain free. Reuse the original population-plus-one sensitivity
comparison with all three assertions active; require a genuine nonreset PRE
reservation/admission history, raw population equality and only the intended
population failure. Do not substitute the local reserve-XOR negative.

Check source identity, exact 72-bit production/monitor inventory and bindings
before serialized pinned engine execution. Such a result supports only this
monitor/history subset; it does not discharge nested memory safety, engine
identity, packet provenance, fairness or the full-device/product gate.
