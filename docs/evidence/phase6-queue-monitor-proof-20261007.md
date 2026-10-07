# Original queue-monitor supporting proof checkpoint

Clean implementation commit `6e5ee3b71b25c1ccdccf0bd14f8f28dbe40579f8`
exports the original queue monitor on the unchanged production controller
projection. All three original conclusions pass base case plus k-induction
through the pinned engine. The original R+1 negative fails only population
conservation with genuine prior admission and reservation history.

Clean targeted native tests pass 137/137. All 178 preceding artifacts are
byte-identical. This closes a binary local monitor/history supporting proof,
not the original full-device or complete Phase 6 gate.

## Exact source and abstraction boundary

The exporter reuses the accepted sixteen production registers/37 bits and
their exact controls, next-state cones, events and public-output drivers. The
original monitor is emitted verbatim: sixteen initialized monitor registers,
35 bits, original wrapping public outstanding counter and all expected-history
updates. Source state totals 72 bits, excluding clock. Public outstanding
history reads only the original public handshakes, never internal population.

The eight existing one-bit cuts remain reset, poison, descriptor-valid,
completion-ready, raw dispatch finish and three terminal bits. Terminal aliases
refer to the same cuts already feeding production logic; completion validity
and descriptor readiness use the actual existing output drivers. Native tests
check typed identities and reject mismatches. No independent transfer event,
new state, boundary cut, shadow controller or held-input premise is added.

The sole assumption is the original sampled-flag startup joint reset. All
later reset and cut timing remain symbolic. Original lane/response history
`p4`, population `p5`, and retirement-event/history/raw-invariant `p6` remain
assertions. In particular, the established raw relation is not assumed and
is not bypassed on later reset. The negative changes only the original checked
retirement population RHS by R+1 after saved admission/reservation history.
It is not the earlier current-reserve-XOR sensitivity test.

The six exported files are proof inputs only. No task family, profile, typed
result receipt or permanent runner is added; original production and formal
bundles are unchanged. Arbitrary terminal timing does not establish engine
identity, packet provenance or ownership of a reserved dispatch entry.

## Native and source compatibility

Frozen checkout:
`/private/tmp/lunachip-queue-control-composition-native-20261007.pnlu45`.
Its previous build cache was reused because host disk space was low. Previous
sealed evidence roots were not modified. Interface generation, formatting,
native deny-warning checking, checking with warning 73, targeted formal and
phase6/phase4 CLI tests, and native fixture CLI build exit zero. Every logged
command retains unchanged committed HEAD and empty source status. The full
native module test matrix was not rerun.

Five added tests cover exact monitor/source identity, all sixteen state and
38 event mappings, terminal/public driver identity, source state inventory,
sole startup premise/all three conclusions, exact R+1-only difference,
deterministic six-artifact export and fresh-directory/overwrite behavior.

Fresh exports require all 178 preceding artifacts across eighteen inventories
to match exact bytes and SHA-256, without normalization. The six new inputs
have a separate inventory. Independent review verifies these comparisons,
all source hashes, and unchanged source/helper/exporter bindings.

- Prior inventory: `e87dced38059bf4320763d1ad69b6072685ec01905a75ffddacb208be0db6bd5`.
- New inventory: `738fe75b6691f59a3de1331db61f450fb53f431d834fac7d16e1b9f74ca8ffac`.

The production/controller/Boolean sources exactly match the accepted four
comparison-helper proof inputs. The historical sealed inventory and actual
positive/negated SAT results were independently verified. Only that pointwise
binary helper lemma is reused; earlier six-conclusion induction, four-state
semantics and full-device equivalence are not substituted. Identical helper
engines were not rerun.

## Actual engine results

Both jobs run serially through the unchanged AMD64 Yosys 0.68, SBY v0.68 and
Bitwuzla 0.9.1 image. Explicit Docker context is `colima-lunachip-phase3`;
scoped volume transport, pinned permission initializer, numeric host UID/GID,
network disabled, read-only root and dropped capabilities remain unchanged.
Global context and VM resource configuration were not changed.

Positive configuration: prove depth 12, timeout 600, multiclock on,
smtbmc/Bitwuzla. Actual child exit 0 and SBY PASS; explicit base case and
induction both pass. Elapsed SBY clock time is three seconds. No trace is
produced. This is unbounded k-induction of the scoped conclusions, not merely
twelve-step bounded safety and not a measured speedup.

Negative configuration: BMC depth 12, timeout 600, all three assertions active.
Actual child exit 0 under expect-fail, SBY FAIL, elapsed SBY clock time four
seconds. Only original `p5` fails at global step 11. VCD, Verilog testbench,
SMTC and witness formats are complete and independently audited.

Both actual prepared models retain exactly three assertions, one startup
assumption, eight one-bit anyseq cells, sixteen DUT anyinit registers totaling
37 bits, and no cover or memory. Positive has 622 cells/49 ff cells; negative
has 643/53, including clock and PRE samplers. Yosys removes unobserved monitor
state: positive retains thirteen monitor registers/32 bits, negative retains
fifteen/34. Thus 72 bits is the exact source inventory, not optimized state
count. The same initialized-zero clock globally toggles; assertions and the
sole premise retain rising-edge PRE sampling. Copied engine sources exactly
match their staged inputs.

## Collector rejection, repair and actual causal witness

The initial outer proof command exits 1 despite both expected engine results.
Its classifier accepts positive but rejects negative because the VCD live-entry
sum has width three rather than the source-declared five. Yosys explicitly
removes the two constant-zero upper bits; SMT zero-extends the sum for its
five-bit comparisons. This is a collector representation error, not a failed
DUT criterion. The original driver, rejection, result and complete outputs
remain unchanged and inventoried.

The corrected external collector pins exactly three bits for this one role;
it does not permit arbitrary width narrowing or change causal checks. A
read-only retained-output mode applies the same proof and counterexample
criteria using saved child exits. Corrected synthetic PRE/POST/missing/unknown
diagnostics and actual retained qualification exit zero. Original output
digests verify before and after qualification. Neither engine is rerun and
the rejected original result is not rewritten. Synthetic diagnostics alone
are not DUT evidence.

Initial driver SHA-256:
`2753b808d9a2575f67f018dc0a438778a0f246211ee6dc5f585b468d75303027`.
Corrected driver SHA-256:
`41808563cb9929943cb935bc39e94bdd0a85dbe4763e891d95426b2c154ef1b8`.

Actual trace has startup reset PRE `#0`, genuine public admission PRE `#20`
sampled at `#30`, and genuine reservation PRE `#80` sampled at `#90`: head
state two, reserve one, R zero, allocation of entry zero. Failure PRE `#100`,
sampled at `#110`, has reset zero, sampled/history flags one, FIFO occupancy
two in all lanes, head state three, outstanding three, R one, live mask `001`,
read zero/write one, physical population three and checked R two. Raw relation
and invariant are true; p4=true, p5=false, p6=true. Current reserve is zero,
so genuine saved history—not a current reserve defect—qualifies the failure.

## Retention and reproduction

Sealed support root:
`/private/tmp/lunachip-queue-monitor-proof-20261007.Kl6kFe`.
Retained copy: `.phase6-queue-monitor-proof-evidence-20261007` in this repository.
The inventory contains 596 files with SHA-256
`47018399f391333496cd8c769927a4fe29efe0c21202e3f78941f2a45cb81c47`.
All digests verify in both roots and complete contents compare equal. Neither
root may be changed by later experiments; build caches are outside them.

Regenerate inputs from the clean implementation commit into a fresh directory:

~~~sh
moon run --target native cmd/phase6-formal-fixtures -- queue-monitor NEW_DIRECTORY
~~~

Retained command JSON records exact native, export and engine invocations.
Original proof-output keeps its own verified inventory and initial rejection;
the separate retained-qualification logs record the subsequent read-only pass.
Never rerun automation in a sealed evidence root or overwrite its results.

## Remaining gate

The [full-device composition timeout](phase6-queue-control-composition-20261007.md)
is unchanged; this supporting theorem is not a machine-checked discharge of
the full conjunct. Do not retry that full run unchanged or introduce internal
progress/relation premises to obtain a pass. Original complete assertion
inventories, bounds and timeouts remain required.

Full-device composition, all twenty nested memory checks, FIFO data order,
packet provenance, engine/ticket ownership, Store leases, DMA/address safety,
fetched transport, explicit-fairness completion and full 8x8 acceptance remain
open. No FPGA execution, physical memory mapping, timing closure, GDS,
fabrication or silicon-performance claim follows.
