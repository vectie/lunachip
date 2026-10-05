# FluxTile formal implementation and claim scope

The Phase 6 formal gate is unfinished. Reuse the existing property/task/result
contracts and pinned Yosys/SymbiYosys runner; add scoped FluxTile fixture families,
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

The implemented `queued_concurrent_dependency_formal_fixture()` constructs
the unchanged direct 1x1/K2/host1024/q3 device and captures 48 typed references
to existing nodes. Its design-owned immutable roles cover the four raw head
lanes, reservation/tickets, six writer generations, two dependency snapshots,
actual engine accepts and terminals, local rejection, compute preflight, and
latched compute identity/shape across the registered Issue gap. Metadata capture
allocates no hardware node or ABI output. Four targeted native tests check
complete module/canonical IR/emitted RTL equality, exact typed name bindings,
a genuinely rejected writer generation, and outer-to-inner compute identity.
These are observation-seam tests, not formal proofs. FIFO atomicity, retirement
entries and physical leases are not observed by this dependency-only view and
still need their own supporting checks.

### Implemented dependency pilot

The `flux-tile-dependency` family now exports the unchanged direct queued
1x1/K2/host1024/q3 graph through this seam. Its isolated formal DUT resolves
all 48 typed observations through the emitted name manifest; production RTL
is retained separately and remains identical across all variants. No new IR
node, public ABI signal or guessed hierarchy is introduced. The compiled
adapter adds observation ports to the isolated formal copy. It also replaces
only that copy's scalar equality/less-than helper bodies with native Boolean
comparisons. The ordinary production emitter retains four-state semantics.
Every register, memory, port, node assignment, invalid-memory X fallback,
property and observation remains unchanged. Uninitialized hardware state still
has arbitrary binary formal values; the adapter does not force it to zero.

The [pointwise helper check](evidence/phase6-boolean-20261005.md) passes pinned
SAT equivalence for all19 helpers actually emitted here (12 equality widths
and7 unsigned comparison widths), plus a negated-miter sensitivity control.
It does not prove four-state or sequential device equivalence, nor prospective
signed helper widths. Equivalence must be checked against the exact fresh
adapter before a device task; this is a procedural precondition, not a new
runner schema or automatic preflight check. The existing runner is unchanged.

An independent monitor decodes raw descriptor syntax and priority, tracks six
writer statuses/tickets and the next reservation ticket, and snapshots sources
before publishing a new intent. It independently predicts local rejection,
collects only matching Pending generations, and gives newer writer intent
priority over an older matching terminal. Outer compute acceptance captures
authorization and ticket/ABC/MNK identity; inner acceptance is checked against
that saved authorization, not a subsequently changed latest writer.

Seven assertions check generation/model agreement, prepublication snapshots,
consumer admission, exact unavailable-dependency rejection, publication
priority, outer-to-inner identity and accepted-owner terminal tickets. The
four legal-host assumptions specify initial reset, descriptor hold, response
hold and joint-reset response flush. Malformed descriptors/responses, remote
faults and later reset remain symbolic; there is no fairness assumption.

`phase6-dependency-latest-writer` contains one bounded safety task and five
separate covers: a failed operand reload followed by Mat fault4; a failed Mat
generation followed by Store fault5; invalid syntax preserving a usable prior
generation; a matching older terminal concurrent with newer intent; and actual
authorized outer-to-inner compute. Cover history binds the same generation
ticket instead of accumulating unrelated events.

Three comparison-only monitor negatives select one exact assertion each:
`phase6-dependency-negative-failed-generation` changes a genuinely observed
Failed status to Success; `phase6-dependency-negative-new-intent-priority`
compares a new ticket as the matching older terminal ticket only on the actual
coincidence; `phase6-dependency-negative-inner-identity` flips reduction bit0
only on real inner acceptance. They do not mutate production RTL or ghost
history. All tasks retain 256 global steps / 128 DUT clocks and timeout600.
Native generation checks are not actual proof results; all positive witnesses,
selected sensitivity failures and safety execution remain independently
required. This pilot does not prove FIFO atomicity, retirement, leases, ticket
wrap, eventual completion or the complete device.
The actual older-terminal/new-intent search reported its cover at step21, but
timed out exporting a VCD that stops after complete step16. Its retained
execution remains incomplete. A separate fresh Boolean-adapter run now
completes with a verified typed witness at step21 after431s. It records an
actual A0 remote-error terminal for ticket0 concurrent with new A0 intent,
then both DUT and ghost Pending/ticket1. This is one cover, not safety.
The fresh all-seven-assertion Boolean-adapter safety task also timed out after
601s, last checking global step69 of the required256. Complete output and log
are retained separately; there is no solver status, trace or typed proof
receipt. A shorter progress prefix is not substituted for the declared gate.
The [local generation lemma proposal](PHASE6_GENERATION_LEMMA.md) describes an
exact production-IR cut and independent reset/transition proof as a possible
supporting invariant. It is not implemented or proved; no internal readiness,
rejection or ownership predicate is assumed to make the full task pass.

### Separate directed fetched Fence profile

`phase6-flux-tile-directed-first-terminal` selects the distinct
`flux-tile-directed-first-terminal` family, not the symbolic public transport
family. Its one cover uses the unchanged fetched DUT with initial joint reset
and no later reset, legal configuration base512/origin0, one published Fence
ID1, ready request/completion peers and immediate matching successful responses
owned by actual accepted requests. Saved actual addresses select the fixed
descriptor0.2 byte image. No internal progress is assumed.

The cover requires all 32 ordered one-byte descriptor read handshakes and 32
owned matching ACKs, no outstanding response or new bus handshake on the
retirement edge, P=C=1 and actual successful Fence ID1 retirement. Counts
saturate rather than wrap. Its 12 explicit host/reset assumptions and one
cover contain no safety assertion or fairness deadline. The 256-step bound
and timeout600 remain unchanged. This concrete legal-host reachability profile
does not replace the original timed-out symbolic first-terminal task or prove
transport safety, write coverage, dependencies, liveness or the product gate.
The [first execution](evidence/phase6-directed-20261005.md) stopped on solver
EOF at global128 without a witness. Its complete attempt remains retained.
The directed profile now drives its12 host inputs directly from the same
legal-host equations and actual handshake state, exposing constants before
SMT. Bound, timeout, selected assumptions, observation timing, production RTL
and all symbolic pilot profiles remain unchanged. Speedup is unmeasured;
the external result remains required. The fresh direct-host run also stopped
with solver EOF after493s, last logged step127, with no witness. Both complete
attempts are retained separately; neither proves an unreachable cover, a
production defect or a successful formal result. Scoped kernel journal logs
now correlate both solver EOFs with global VM OOM kills of Bitwuzla. No VM
allocation or tool setting has been changed. No unchanged retry follows.

The CLI exports all eight exact identities only into fresh directories. The
phase-neutral verifier rejects cross-family fixture selection. The original
three public-transport bundles and standard inventory remain unchanged.
The integrated formal/exporter tests pass 59/59; all three original FluxTile
bundles and every bundle in all four older formal families compare
byte-identically after fresh export. The full native gate passes 772/772,
including interface generation, formatting, strict check with warning73,
default CLI smoke and dependency/source-size boundaries. This validates the
implementation checkpoint, not an external formal outcome.
After the Boolean helper refinement, a fresh full native gate at `39afd37`
passes775/775 with interface generation, formatting, strict warning73 check,
default CLI smoke and dependency/source-size checks. It does not convert the
subsequent full-horizon safety timeout into a proof.

The first dependency sensitivity execution stopped during strict Yosys
preprocessing: automatic conversion of a tiny reference array to registers
triggered `logger -werror .*`, before any solver status or trace. The complete
attempt is retained at
`/Users/kq/Workspace/lunachip/.phase6-dependency-evidence-20261005/negative-failed-output`
with its immutable input and outer log. Source checkpoint `6d1beeb`; runner
exit16, SBY `ERROR`, elapsed40s. It is neither a counterexample nor a proof.

The harness now explicitly declares its nine tiny reference arrays as fixed
register banks with declaration-local `mem2reg` attributes. The
[pinned frontend source](https://raw.githubusercontent.com/YosysHQ/yosys/38e001a6f/frontends/ast/simplify.cc)
uses the same register conversion for explicit and automatic cases. No global
warning waiver, `nomem2reg`, production-memory attribute, tool lock or property
change is introduced. Regenerated hashes and a fresh output are required;
native checks cannot establish successful tool parsing or proof execution.
The [fresh retry](evidence/phase6-dependency-20261005.md) now completed with
the exact selected Failed-generation monitor counterexample at step13 and a
verified actual trace. Positive safety, the four remaining dependency covers and the
other two negatives remain unrecorded.

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

The [direct-queue completion proposal](PHASE6_FORMAL_COMPLETION.md) derives
a candidate 252-edge deadline for R=H=C=2 from controller transitions,
including six possible predecessors. It specifies an admission/retirement
ordinal watch so duplicate caller IDs cannot satisfy the wrong obligation.
Supporting invariants and actual proof/cover/sensitivity results remain required;
the candidate deadline is not recorded formal evidence.

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
