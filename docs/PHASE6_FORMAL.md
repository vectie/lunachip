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

The separate [queue-conservation seam](PHASE6_QUEUE_CONSERVATION.md) now adds
115 existing-node FIFO/head/entry/retirement/engine references to the same
ordinary direct device. Its [native checkpoint](evidence/phase6-queue-seam-20261006.md)
passes 832 tests with unchanged canonical hardware and a real duplicate-ID,
held-retirement replay. The first supporting structural task, full/refill cover
and population-comparison sensitivity are specified separately. The seam and
native replay do not establish any production formal outcome.
The [implemented structural exporter](evidence/phase6-queue-descriptor-native-20261006.md)
now passes the 838-test full native gate and preserves all 93 older formal
artifact bytes. Its exact 19-helper Boolean SAT check and negated control pass.
Actual structural safety, full/refill cover and population sensitivity remain
separate task outcomes; the [actual queue pilot](evidence/phase6-queue-formal-20261006.md)
now retains a complete full/refill cover and selected population counterexample.
Structural safety times out at the unchanged bound and remains unfinished;
no device safety pass follows from native generation or helper equivalence. The next
[retirement record checks](PHASE6_QUEUE_RETIREMENT_RECORDS.md) are specified
without weakening the original queue or dependency obligations.
Their [native implementation checkpoint](evidence/phase6-retirement-record-native-20261006.md)
now passes842 tests and preserves all113 earlier artifacts. The new profiles'
actual safety, cover and selected negative remain separate required results.
The additive [public packet provenance slice](PHASE6_QUEUE_PACKET_PROVENANCE.md)
independently saves all 256 admitted bits, checks both synchronous transfer
gaps, and binds reservation to ordinal public retirement. It retains all six
queue assertions and appends one identity assertion, with its own coherent
cover and comparison-only negative. Generation and native replay do not
establish its required external safety, cover or selected counterexample.

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
The fresh priority comparison-only negative also completes with runner exit0,
SBY FAIL after453s and the exact selected assertion at global21. Its complete
trace shows actual/ghost B0 Pending/ticket1 while only the checked comparison
substitutes the old ticket0. All six actual/ghost status/ticket pairs match
through the witness; complete typed evidence verifies. This is monitor
sensitivity, not a production defect.
The fresh all-seven-assertion Boolean-adapter safety task also timed out after
601s, last checking global step69 of the required256. Complete output and log
are retained separately; there is no solver status, trace or typed proof
receipt. A shorter progress prefix is not substituted for the declared gate.
The [local generation lemma](PHASE6_GENERATION_LEMMA.md) describes an
exact production-IR cut and independent reset/transition proof as a possible
supporting invariant. Its private exact-root discovery and combinational edge
transfer and shared independent reference are implemented. Separate
[pinned local SAT](evidence/phase6-generation-sat-20261005.md) passes reset base
and free-state step for generation banks, local fault/reject and halted, with
three complete sensitivity counterexamples. The strengthened
[decoder-complete local obligations](evidence/phase6-generation-decoder-sat-20261005.md)
also pass at `f333a2b`, with 795 native tests and independent evidence review.
Full-device composition remains unfinished. No internal
readiness, rejection or ownership predicate is
assumed to make the full task pass.
The separate [generation-support fixture experiment](evidence/phase6-generation-support-20261006.md)
appends p16's reset-guarded all-eighteen-field assertion without replacing any
original assertion or assumption. All 46 ordinary artifacts remain unchanged;
798 native tests pass. Actual preparation has 28 assertions/four assumptions and
unchanged DUT state/memory choices. Its 256-step task times out after 601s while
checking assumptions at global step 62, without a trace or typed proof receipt.
This does not establish a speedup or sequential composition. A scoped
clock/reset bridge is the next semantic obligation.
The [naming-only trace probe](evidence/phase6-trace-projection-20261005.md)
separately validates1,942 conservative wire renamings and four corruption
controls on the exact prepared model. It does not change the runner, execute
a solver, validate projected replay or establish a speedup. Complete projected
witness/counterexample checks remain necessary before integration.
A [separate projected JSON experiment](evidence/phase6-projected-witness-20261005.md)
completes p14 at global 21, all four trace formats and same-model witness replay.
Older-model replay fails on an autogenerated symbolic witness name; JSON import
also drops 112 net signedness metadata fields. No ordinary runner receipt,
cross-model replay or production safety result is claimed. Direct-preparation
integration and the complete projected negative remain required.

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
The private generation discovery/transfer checkpoint at `c2a14f2` passes
785/785 native tests and 65/65 formal-package tests, including ten new focused
tests. Interface generation, formatting, strict warning73 check, CLI smoke
and source boundaries pass; public interfaces and a fresh complete dependency
bundle are unchanged. Independent ghost SAT and composition remain required.

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
verified actual trace. Positive safety, the four remaining dependency covers and
the inner-identity negative remain unrecorded.

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

The next [exact queue control transition lemma](PHASE6_QUEUE_CONTROL_LEMMA.md)
retains production control registers and transfer equations while explicitly
abstracting terminal timing. Its contiguous retirement-ring invariant closes a
gap in population-only induction. Discovery, native extraction, local proof and
whole-device composition are separate checkpoints; none removes the original
queue assertions, assumptions or bounded obligations.

The [local queue-control induction checkpoint](evidence/phase6-queue-control-proof-20261006.md)
now passes all six clock/reset-bridge conclusions by actual base case and
k-induction. Its comparison-only negative fails at a genuine PRE reservation.
Sixteen production registers/37 bits, eight explicit free boundaries and an
independent four-bit public history define its exact scope. Neither terminal
identity nor whole-device composition follows. The original bounded queue,
retirement, packet, memory and full 8×8 obligations remain unchanged.

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

## Remaining closure sequence

Finish the original storage and composition obligations before another
monolithic device attempt. Reuse the accepted queue-control/monitor, ownership
and generation/compute proofs only through audited exact original-node
bindings. The existing selected FIFO induction excludes data ordering and
uses a depth-two UInt8 configuration; it does not establish four depth-three
Bits64 descriptor lanes. Retain their actual storage, pointers, synchronous
read results and head capture before proving packet/retirement provenance.

Complete [Store storage and lease preservation](PHASE6_STORE_PRESERVATION.md),
DMA cursor/address bounds and nested-memory bounds. The fetched device also
needs the actual three-client arbiter and reader relations; the accepted
two-client theorem is not interchangeable. Successful fetched Store needs a
write-path cover and a safety horizon reaching that path, not the existing
128-DUT-edge pilot.

Implement the [ordinal fairness monitor and reviewed deadline](PHASE6_FORMAL_COMPLETION.md)
without assuming internal progress. Derive separate fetched and 8x8 bounds;
the direct 252-edge proposal cannot be reused unchanged. Register and audit
the concrete 8x8 formal scope, then run the phase-boundary native/tool gates
and reconcile every required result. Numerical oracle and independent RTL
results satisfy the numerical requirement; a universal formal MatMul arithmetic
theorem is not an additional Phase 6 prerequisite.

Independent source work may proceed on FIFO/provenance, Store/DMA, fetched
transport and fairness in parallel. Native and solver jobs remain serialized
on the current constrained host. Preserve unsuccessful results; do not weaken
premises or substitute shorter bounds for the declared gate.

## Fetched reader and three client transport checkpoint

The current private projection starts from a fresh ordinary
`ring_concurrent_tile(rows=1, columns=1, max_reduction=2, host_bytes=1024UL,
ring_depth=4, queue_depth=2)` graph. Its canonical design wrapper remains
`phase6-fetched-concurrent-1x1-k2`; the retained original design has digest
`d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79`.
Discovery must reconstruct and check this identity, not reuse direct-device
node numbers, observation inventories or proof digests.

Retain the actual three-client arbiter registers, cyclic selection and route
equations together with every descriptor-reader register, byte assembly and
publication/configuration check. Its checked state inventory is 26 registers
and 666 bits, with complete original typed roots and register specifications.
Raw loader/storer request
fields and response readiness, queue packet readiness and public host inputs
are explicit component boundaries. Reader requests, acknowledgements, packet
assembly, arbiter grants and ownership remain derived from retained controls.
Preserve original constants and arbitrary initial state. A complete source
report, exact sequential copy, native PRE/POST correspondence and narrowly
bound transport/reader assertions precede any supporting proof claim.

This component boundary does not establish successful Store execution from
fetched descriptors: arbitrary external client fields cannot supply that
claim. The separate full original device still requires a successful fetched
Store write, matching public acknowledgement and a named safety horizon that
reaches the write path. Neither the original 128-DUT-edge pilot nor the
accepted two-client theorem closes that obligation.

At `e32ebef`, strict native check and the four-test source/witness checkpoint
pass. The independently reviewed component export has twelve checked
conclusions, one startup joint-reset premise and a coherent packet cover.
Its wrappers instantiate the full Boolean component module; a runner must
include both sources and flatten that ordinary hierarchy, not replace it
with internal free inputs. All 21 explicit component boundaries remain.
The original twelve conclusions now have an independently qualified unbounded
component proof with four additional checked supporting conclusions. The full
fetched-device write path and fair completion remain outside this result.

Fresh full-device comparison-helper SAT and its selected negated-miter
control pass. Independent review reconstructs all twenty complete pairs,
checks the complete unchanged noncomparison RTL and binds all seven component
pairs, including the previously missing unsigned-32 comparison. This is
all-defined binary pointwise equivalence, not sequential/four-state equivalence.
Complete helper support is sealed at
`/private/tmp/lunachip-fetched-boolean-equivalence-20261007.8FdKVH`, manifest
`71c0dbb44529a3f8427263b5ff8a8a8cfe42544f86922a6046de1d768800e8e8`.
The support has not been mirrored into the repository.

The actual whole-twelve `bmc256` attempt at clean `e32ebef` times out after
601s, child exit8. It completes through step92 and begins checking step93;
there is no returned counterexample or trace and no full256 safety pass.
Complete work is retained in
`/private/tmp/lunachip-fetched-transport-driver-20261007.UswxX2/bmc-output`.
An independently reviewed whole-twelve induction derivative keeps the same
393-node Boolean component, unchanged positive wrapper and sole premise.
Any acceptance requires both base0–19 and temporal induction, actual SBY
PASS/child0 and independent prepared-model qualification; base20 alone is
not substituted for the incomplete256 bound. Full fetched-device write-path
and fairness obligations remain separate.

The same-source `prove20` attempt completes with base0–19 PASS and induction
FAIL, yielding SBY `UNKNOWN`, child exit4 in310s. Independent review confirms
byte-identical prepared models and complete VCD/SMTC/Yosys-witness/replay
traces. The failing global establishment assertion observes an arbitrary
Offer predecessor whose saved arbiter reader tag differs from the reader's
current tag. At actual request acceptance the reader saves its current tag;
the resulting Wait relation then fails. This is not a reset-reachable DUT
counterexample. The next supporting invariant must be **checked**, relating
an Offer owned by the reader to the current reader tag; it must not become
an assumption. Actual support remains at
`/private/tmp/lunachip-fetched-transport-induction-20261008.7gyAXf/prove-output`.

Adding that checked tag relation alone yields another complete SBY `UNKNOWN`,
child exit 4 in 348s: the induction predecessor has a configured, aligned reader
base outside the host aperture. Adding checked configuration-history and
active-reader population relations then yields SBY `UNKNOWN`, child exit 4
in 332s: an arbitrary predecessor contains a nonzero byte beyond the accepted
prefix. On the next owned byte acknowledgement, the actual OR assembly and
the independent shadow's byte replacement disagree. Both have complete
counterexample artifacts, but neither establishes a reset-reachable DUT bug.
Their respective roots are
`/private/tmp/lunachip-fetched-offer-tag-induction-20261008.2if9Dr` and
`/private/tmp/lunachip-fetched-config-induction-20261008.Crutwa`.

The accepted derivative checks all four support relations: Offer reader-tag
ownership, configured base/state validity, nonempty active-reader population,
and zero unwritten byte-shadow tail. It adds assertions, not assumptions;
removing their four complete lines reconstructs the original twelve-conclusion
wrapper exactly. No DUT state, observer update, initialization, cut or premise
changes. The fourth relation has only the original startup-history guard, not
a later-reset bypass. Base 0–19 passes in 36s and temporal induction in 9s;
SBY returns `PASS`, child exit 0, with 40s reported elapsed time (52s process).
This unbounded theorem establishes the original component conclusions beyond
their declared 256 bound under the same sole startup joint-reset premise.

Independent prepared-model review confirms all 26 original registers/666 bits,
21 raw boundaries/332 bits, no memories, sixteen assertions and one assumption.
Prepared arbitrary-initial-state, flip-flop and symbolic-input inventories
remain unchanged. This is not the full eight-public-condition fetched-device
theorem, a useful Store write/ACK result, a fairness theorem or an 8x8 proof.

Complete 961-file support is sealed at
`/private/tmp/lunachip-fetched-prefix-tail-induction-20261008.rY0pt8`, with
inventory digest
`828a3d7df95ddf6e7b7954ef97a5e85d38515ba04677b5b3c602ed3126d50317`
and qualification digest
`354c4bfba36424cf793a8155019278fe492001e0d2c2e1518bfdb63a2019b6c1`.
The repository mirror `.phase6-fetched-support-evidence-20261008` passes the
complete checksum inventory and byte-for-byte directory comparison. Original
unsuccessful attempts remain retained separately; they are not reclassified
as passes by the later strengthened induction.

The October13 [source-reproduction checkpoint](evidence/phase6-validation-resume-20261013.md)
now provides `fetched_transport_supported_artifacts()` in the private native
exporter. Five targeted tests reproduce the accepted Boolean module,
sixteen-conclusion wrapper and actual prove config by their complete SHA-256
identities. The original twelve-conclusion source and six-artifact collector
remain unchanged. The four global relations are checked assertions with the
original startup guard, not premises or later-reset bypasses. Opt-in native
collection prints the three inputs without running a solver. This removes an
artifact-only reproduction step; it is not new engine evidence or Phase6 closure.

## Accepted Store projection safety gate

The [full original Store conjunction](evidence/phase6-store-full-composition-20261013.md)
passes all nineteen original safety properties jointly by basecase and unbounded
k-induction, with ninety additional supports checked as assertions under the
same sole startup reset. On2026-10-13 the user explicitly accepts that stronger
theorem as the safety gate for the exact binary2x2/K2/host1024/q3 projection.
It establishes safety beyond256 global steps; no bounded timeout is relabeled
as a pass and induction depth alone is not credited as a theorem.

The [current Store ledger](evidence/phase6-store-bounded-20261013.md) also verifies
and credits the existing original overlap cover and selected payload sensitivity.
That projection's safety/overlap/sensitivity obligations are accepted, without
requiring an additional separate BMC256 PASS. Packet/fetched, host/full-device
bounds, explicit-fairness8x8, numerical/differential and remaining matrix gates
are unchanged. Phase6 is still in progress.

## Accepted original packet conjunction

The [packet retirement composition](evidence/phase6-packet-retirement-20261013.md)
closes all seventeen original safety conclusions jointly for the direct
1x1/K2/host1024/q3 binary projection. Three checked supports link the actual
pending head, live nonterminal entries and exclusive engine tickets, exact
owner events, and real FIFO shape. They add no state, cut or premise. The
original four public-peer premises, symbolic later reset and unknown storage
remain intact.

Both retirement18 and full20 pass basecase0–19 and unbounded k-induction.
Prepared models retain exact assertion rosters, all original register/read
bindings, four unknown-initialized q3/Bits64 arrays and the1,900-bit physical
state observation. The full theorem meets the existing bounded-or-complete-
unbounded qualification route without relabeling any earlier timeout. Verified
same-source p13 cover and selected p12 sensitivity remain accepted; that cover
is local-error retirement, not useful Store work.

This accepts the exact packet projection, not the whole Phase6 gate.
Full dependency/fetched transport and host-address composition, explicit-
fairness8x8 completion, remaining workload/fault matrix and aggregate validation
are still required.

## Full fetched useful Store trajectory and search

The [fetched useful checkpoint](evidence/phase6-fetched-useful-20261013.md)
checks the unchanged complete fetched1x1/K2/host1024/ring4/q2 device with its
existing directed R1/H1/C1 host. Native execution reaches the full useful
predicate at PRE edge418:132 distinct expected reads and ACKs, an actual
four-byte Store at768 with value−29, its owned ACK and four successful ordinal
retirements. This validates the candidate512-edge trajectory budget, not a
formal cover or safety horizon.

Two pre-engine export rejections are retained and repaired. Current typed
BMC and cover inputs verify, but the actual original1024-step cover search
times out after601s, completing0–319 and starting320, without traces. Its
models retain all eight host premises, the nonconstant original useful cover
and ten unknown-initialized memories. No safety assertion is checked by this
cover-mode result. Complete accepted full-device comparison helper bytes and
the historical seal verify without a new equivalence run.

The useful formal cover and full-device safety horizon remain open. A later
input-guided cover may restrict only public inputs along the recorded native
trajectory while preserving all original host assumptions and the complete
initialized DUT prefix; it cannot establish symbolic safety or fairness.
Do not retry the unchanged timeout. Exact accepted Store and packet scopes,
explicit-fairness8x8 and all remaining Phase6 gates stay unchanged.

## Input-guided fetched cover experiments

The [input-guided ledger](evidence/phase6-fetched-input-cover-20261013.md)
binds419 complete native PRE frames to twelve original public inputs at global
states0..837. Tail838..1023 remains free of input guidance. The pinned engine
retains initialization, all transitions and eight original host premises even
when early queries are skipped; no output, private state or memory is guided.

Skip832 actually returns `ERROR 16 803` with a kernel-confirmed Bitwuzla OOM
kill at query832. The separate skip839 variant returns `TIMEOUT 8 85` after
601 wall seconds, stopping at552 before any reachability query. Independent
reviews accept both unchanged actual models; no trace exists to qualify.
Neither is a cover PASS, safety FAIL or evidence of unreachability. Prior
accepted Store/packet proofs and recorded timeouts are unchanged.

The next encoding candidate is `--nomem` under the pinned formal memory-mapping
flow. Actual transformed initialization, state/held reads and address semantics
require review before accepting an eventual witness. No state cut, shortened
prefix, extra host assumption or enlarged resource budget is authorized by
this checkpoint. Useful cover and all other full-device gates remain open.

## Qualified memory mapping and packed state

The [2026-10-14 encoding ledger](evidence/phase6-fetched-nomem-20261014.md)
preserves all physical memory words, uninitialized read/storage state and
original address semantics while changing solver representation. The mapper's
new zero-width C-address equality is folded to true without removing external
address guards. Every other mapped item/equation is retained. Packed-state
export preserves every functional definition and initialization clause, with
complete disjoint field coverage and no new premise or state cut.

Actual outcomes are separately retained: original mapped SBY exporter ERROR;
folded standalone host timeout before query839; packed standalone query839
followed by kernel-confirmed Bitwuzla OOM. The packed prefix completes in 4s,
but no SAT/UNSAT result or trace returns. The useful cover stays unaccepted.
Standalone outcomes have no fabricated SBY status or original typed receipt
and are not inserted into the aggregate as one. Prior Store/packet theorem
acceptance and all historical failures remain unchanged.

Field-split state reconstruction and exact transition recurrence are now
implemented and independently qualified for the original first late query839.
The full initialized states0..839 and all839 transitions remain; only the
existing public inputs are guided. Complete565-leaf/9716-bit reconstruction
preserves Bool/BitVec sorts, memory initialization and original equations.
Recurrence substitutes386779 uniquely determined fields from461 original
transition sources while retaining those original transition assertions.

Both actual direct Bitwuzla runs end in kernel-confirmed OOM, child137 without
host timeout: field split about322s at7.47GiB anonymous RSS; recurrence about
451s at7.48GiB. Neither returns SAT/UNSAT or a certificate. No first-query
failure exhausts the original1024-step search window, and neither outcome
is a proof failure or SBY/typed receipt. Exact substitution and fewer fresh
variables do not establish reduced peak memory or a useful-cover pass.

Next is a separately qualified formulation deriving44 child input fields from
original hierarchy equations and263 state0 field constants from original
initialization. Preserve all264 initialization clauses, including the child
invocation, plus18 unknown memory words and11 undefined slices. Same-step
aliases must not reference the whole state they help construct. No new private/
output/numeric premise or enlarged VM follows from this checkpoint. Full
fetched safety, fairness8×8 and matrix/aggregate still require independent
results.

## Original-equation input aliases and specified initialization

The [alias/initialization checkpoint](evidence/phase6-fetched-alias-init-20261014.md)
now implements the previously proposed derivation. Independent AST review
accepts all44 typed input aliases and263 original state0 constants. All36960
input substitutions and263 initial substitutions are checked;40542 fields
remain fresh. Producer bits invert the original concatenation exactly31..0.
Same-step aliases reference declared parent fields/literals, never the whole
state they construct. All original initialization, hierarchy, transition,
host-premise, guidance and cover assertions remain.

The original18 memory words640bits,11 undefined slices166bits, four invalid C
read sources and ten old held-read samples352bits retain their original unknown
semantics. Specified zero candidate samples do not initialize their memories.
No address guard, read/write/collision equation or reset priority is altered.

Actual direct pinned Bitwuzla reaches check839 in6.819s, then the600-second
host deadline expires with `TimeoutError`, null child exit and no verdict/model.
The runner explicitly stops the runtime; subsequent Docker exit137 has
`OOMKilled=false`. Kernel review is retained separately. This is a host timeout,
not an OOM, safety counterexample, unreachability result or typed formal receipt.
The early1.013GiB sample is not peak memory. No useful cover is accepted.

The next separately reviewed candidate is30 output-shadow substitutions from
original hierarchy equations, using a complete child state before parent
construction to avoid cycles. Native outputs/private state are not guidance.
This candidate is not implemented or engine-qualified in the current checkpoint.
Accepted Store/packet scopes and every historical timeout remain unchanged;
full fetched safety, explicit-fairness8×8 and remaining aggregate gates are open.

## Exact output shadows and partial SAT certificate

The [output-shadow checkpoint](evidence/phase6-fetched-output-shadow-20261014.md)
independently qualifies30 original hierarchy-derived outputs using840 complete
7857-bit child states, avoiding same-step parent-state cycles. All458 child
leaves, including `_is`, remain;25200 fresh output shadows become exact original
output-function calls. All other model/command bytes, initialized-prefix states,
unknown-memory/address semantics, guidance, premises and sampled cover remain.

Pinned direct Bitwuzla returns SAT after467.461 seconds. The unchanged600-second
deadline then interrupts certificate serialization after79 known9716-bit states
(`s0..s78`); states79..839 and the final cover response are absent. Explicit stop
produces runtime137 with no Docker/kernel OOM. This is SAT plus incomplete
certificate extraction, not UNSAT, safety failure or accepted cover evidence.

The independent outcome audit and certificate-preparer refusal pass. No untouched
original-model ground check or causal/native audit runs; no original SBY/SMTBMC
typed receipt or aggregate gate is fabricated. Next candidate batches the same
841 certificate terms while leaving all search constraints unchanged. Complete
batched parsing, original-model checking and causal validation are required
before witness acceptance. All remaining Phase6 gates stay open.

## Batched certificate requests without search changes

The [2026-10-15 batch checkpoint](evidence/phase6-fetched-batch-certificate-20261015.md)
combines all841 original terms into one `get-value` list. A separate mechanical
audit verifies the entire search prefix byte-for-byte through `check-sat` and
the original exit suffix. Original unknown memory, full-width address, bounds,
held-read, anyseq, initialization and read/write semantics remain unchanged.

The pinned run returns SAT at410.840 seconds, then times out during serialization
at the unchanged600-second deadline. Only77 complete9716-bit states and a state77
fragment are retained; no closed batch or original cover response returns.
The explicit timeout stop produces runtime137 with no Docker/kernel OOM.
Complete-certificate extraction is refused. No original-model ground or causal
audit runs, and no cover, typed receipt, safety/fairness or aggregate pass follows.

Next candidate packs all840states and the encoded original cover bit into one
lossless8161441-bit observation expression after the unchanged check. Its layout
and decoder require separate qualification; no performance claim or resource
increase is implied. Prior accepted scopes and all historical outcomes remain.

## One lossless certificate expression without search changes

The [2026-10-15 packed-expression checkpoint](evidence/phase6-fetched-packed-certificate-20261015.md)
requests one balanced concat of all840 original9716-bit states and the original
Bool cover encoded as one bit. Independent bottom-up width/layout checking and
byte comparison preserve every search byte through `check-sat`, including full
initialization, all13417 assertions, unknown memory, held reads, anyseq and
full-width address equations. Focused tests and actual pinned tiny/full-width
synthetic format/decoder checks pass. Synthetic literals never enter search.

The fetched run times out before SAT/UNSAT at600seconds; it never exercises
full-search extraction. Runtime137 follows explicit stop without observed OOM.
The unchanged runner also exits1 at checkout-freeze validation: HEAD matches,
but ten unrelated untracked PRX100 additions change full Git status. Prepared
solver input hashes reverify unchanged, but the declared freeze gate is not
waived. The partial outcome is retained, not promoted to an accepted run.

No fetched certificate, original-model ground/causal validation, cover, typed
receipt or Phase6 pass follows. All owned resources are removed. Another job
restarts the stopped VM; its foreign runtime is left untouched and handover
metadata is retained. Further work must coordinate a non-overlapping snapshot
and investigate search variability; no unchanged retry or resource increase is
performed here. Existing accepted scopes and remaining safety/fairness gates
are unchanged.
