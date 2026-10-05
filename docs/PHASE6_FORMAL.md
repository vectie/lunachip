# FluxTile formal implementation and claim scope

The Phase 6 formal gate is unfinished. Reuse the existing property/task/result
contracts and pinned Yosys/SymbiYosys runner; add one FluxTile fixture family,
not another receipt framework. Small configurations provide named pilot checks
but do not replace the 8x8 product proof or any requirement in `PLAN.md`.

The native exporter and first public-transport generator are implemented.
Strict native check and all 50 targeted formal/exporter tests pass. The four
older formal fixture families remain byte-identical to their pre-addition
baselines. The complete native checkpoint gate passes 754/754 tests. These
tests validate generation and result handling, not an actual
FluxTile formal outcome.

The first [actual pilot result](evidence/phase6-formal-pilot-20261005.md)
retains the expected request-bounds monitor counterexample and a real
held-request and owned-response cover witnesses. Valid safety and the
first-terminal reachability result remain unrecorded; no completed pilot task
proves production safety.

Export one approved fixture into a new directory:

~~~sh
moon run --target native --release cmd/phase6-formal-fixtures -- export phase6-flux-tile-public-transport /absolute/new-bundle
~~~

The valid bundle contains one 256-step bounded safety task and three separate
reachability tasks. Two negative bundles mutate only monitor observations,
selecting the exact request-bounds or stalled-request assertion. They test
monitor sensitivity, not defects in production RTL. All five host assumptions
are explicit; no fairness or successful-response assumption is made. Later
reset tasks model the ABI's joint-flushed peer, not a stale response presented
during reset, which the independent fault/reset replay checks separately.

## Transport safety at the published boundary

Start with the actual 1x1/K2, host1024, ring4, q2 fetched profile. Symbolic host
and descriptor fields must exercise wide address bounds, read/write payload
rules, stable stalled requests and completions, one outstanding transaction,
no response-edge new request, and reset suppression. Require reachability
covers for stalled requests, owned responses and a command terminal before
interpreting the safety results as useful evidence.

At 128 DUT clocks, these covers do not establish write-path reachability:
successful Store requires at least four fetched descriptors (LoadA, LoadB,
MatMul and Store), whose 128 descriptor bytes alone require at least 384 DUT
edges. The first pilot therefore claims only the reachable first-packet/read
path; the write branch of payload/alignment/aperture assertions is unexercised.
An actual-write cover and safety depth reaching that path remain required for
the complete public transport gate. A longer cover alone cannot extend the
shorter safety result.

An initial bounded search of 128 DUT clocks is a pilot, not a proof deadline.
If the existing two-step clock harness is reused, record 256 global formal
steps and the exact clock relationship. Bounds and assumptions must be named
in the task, not inferred from simulator cycle counts. A bounded pass is only
a pass to that bound; induction remains a separately selected task.

## Queue issue and dependency correctness

Public pins cannot establish private illegal-issue rejection, atomicity of the
four descriptor lanes, latest-writer semantics or slot leases. Introduce only
typed formal observation bindings at existing private composition seams.
Resolve actual node IDs through the emitted name manifest; never guess
ordinals, hierarchical names or add debug ports to the device ABI. Preserve
production canonical graphs and previous fixture bytes.

First check the direct 1x1/K2/q3 queued device so descriptor fetching does not
hide control coverage behind a long horizon. Observe actual lane push/pop,
responses and occupancies; head reservation/decoded fields; engine and inner
core acceptance; writer/status/tickets and leases; valid/terminal retirement
entries. Independently model intended latest writers in the monitor rather
than asserting the DUT's own dependency-ready predicate. Checks must catch
failed generations falling back to old valid SRAM, syntax rejection erasing
intended writers, an older completion overwriting newer intent, and incorrect
same-edge publication priority. Existing single-FIFO proofs are component
evidence, not proof of this four-lane composition.

Require relevant covers and retained negative fixtures that violate the
selected properties. Try selected occupancy/flag/address induction only after
base cases and supporting invariants pass. Keep semantic issue/dependency
checks distinct from structural occupancy checks.

## Eventual completion with explicit fairness

Watch an admitted command, not arbitrary published work: publication can be
invalid, halted or never admitted. State initial reset followed by no reset,
producer payload hold, request-ready within R DUT edges, a matching successful
response within H edges and completion-ready within C edges. Do not assume
internal device progress. If testing poison or remote faults, use separate
tasks with their documented terminal obligations rather than successful-host
assumptions that exclude those cases.

Derive the completion deadline from bounded older owners, arbitration grants,
maximum transfer counts, dispatch/collector gaps, compute wavefront steps and
capture. Every term must follow actual controller transitions; measured average
latency is not a bound. Activate the watch early enough for the full deadline,
require a terminal cover and retain a deliberately shortened-deadline failure
to reject vacuous progress assertions. A direct-queue bound cannot be reused
for publication-to-completion through the three-client fetched reader.

## Existing export and evidence path

Use `FormalPropertyPlan`, `FormalSignalBinding` and
`export_yosys_clocked_properties` with the existing timing contract. The
`formal/systemverilog::integrate()` convenience function emits concurrent SVA,
so it is not the existing locked-Yosys export path. Reuse `BoundedProofTask`,
`GateTask`, `verify_task_property_binding`, `map_sby_result` and artifact
regeneration/verification selection; extend its family registry additively and
keep prior canonical bundles unchanged.

Retain exact labels, engines, bounds, legal/fairness assumptions, clock steps,
source/RTL/tool identities and witness/counterexample digests. Tool startup
failure means incomplete execution, never a hardware counterexample or pass.
The first synthesis slice has passed under the unchanged lock; formal
execution must be checked independently rather than assuming an earlier
startup problem persists or has been permanently resolved.
