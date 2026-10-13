# Phase 6 validation resumption — 2026-10-13

Phase 6 remains in progress. This checkpoint restores the validation environment
after the user-requested VM deletion and resumes the existing Store obligations;
it does not add accelerator hardware, a new ABI, or a new proof-receipt framework.

## Source and native validation

Commit `64d4122` removes four redundant enum qualifications in fetched transport
tests and Store discovery. Hardware construction and public interfaces are
unchanged. Native deny-warning checking with warning 73 enabled passes, as do
native interface generation and formatting checks. The nine selected fetched
transport and Store discovery/closure/rejection tests pass. The standalone
partition script's test passes.

A full native regression was started but deliberately interrupted in unchanged
accelerator tests. It has no passing result for this checkpoint. The historical
1,012-test checkpoint remains historical evidence, not a fresh run.

The new partition preparation runs the native Store artifact collector: its one
test passes with empty stderr. All eight freshly generated artifact bytestrings
match the retained, source-qualified original Store inputs. The original bridge
digest remains `9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121`;
the complete input inventory remains
`6dc96a5d5e214d6facd2349e5b066776380640bc3e7a57e4467ff4706cba800c`.
The sealed, source-bound nineteen-helper equivalence support verifies unchanged.
No new comparison-helper SAT outcome is claimed.

The pre-existing untracked `ir/codec/decode_wbtest.mbt` is neither staged nor
modified; its SHA-256 remains
`733a07a75a013be509738bb853b6fd8d66ca432210a8445db25780acd8d0925f`.

## Dedicated tool environment

The user authorized one replacement VM: `lunachip-validation`, ARM64, four
CPUs, eight GiB RAM, a twenty-GiB data disk and eight-GiB root disk. Host directory
mounts are disabled; the default Docker context is not activated or replaced.
Only the two existing locked OCI images are restored. Actual probes report:

- Yosys 0.68, source `38e001a6f`;
- SBY v0.68 and Bitwuzla 0.9.1;
- Verilator 5.050, release 2026-07-01.

The AMD64 formal image runs through QEMU because Rosetta is unavailable. The
image digests and locks are unchanged. The VM is stopped during native work to
avoid idle-VM memory pressure, then restarted for serial engine work.

## Original Store assertion partition

`scripts/phase6-store-assertion-partition.mbtx` prepares three disjoint groups:

| Group | Original conclusions |
| --- | --- |
| control | reservation exclusion; capture/publication/lease; cursor/progress/terminal; reset establishment |
| data | produced storage; pending read and DMA payload |
| storage | all twelve original enabled memory bounds plus nonrising full-storage hold |

The groups contain 4, 2 and 13 assertions respectively. Selection removes only
complete unselected assertion statements and the unused cover. Every DUT and
observer expression, all original state and source boundaries, and the sole
startup-reset premise remain unchanged at source. No removed conclusion becomes
an assumption. Each group keeps BMC depth 256, multiclock lowering, the pinned
`smtbmc bitwuzla` engine, warning-fatal Yosys preparation and timeout 600 seconds.
Prepared cones may prune unrelated state and must be reviewed independently.

The container uses a read-only root, no network, no capabilities, no-new-privileges
and only owned input/output volumes. Container-local root permits volume writes
without a permission helper; no host repository or filesystem is mounted.
The script records actual child exit/status and retains models/logs before
removing only its own transient volumes. Script collection success does not mean
that an SBY task passed. All three qualified groups are required for the original
nineteen-assertion conjunction at the declared bound.

The fresh inputs, selection manifest and subsequent engine work are retained in
`artifacts/phase6-store-partition-20261013/`, outside temporary folders and sealed
historical archives. One ordinary `_build` cache is reused; compiler outputs are
not copied into proof support.

Reproduction, from the repository root and with a new output directory:

```sh
moon test scripts/phase6-store-assertion-partition.mbtx --deny-warn
moon run scripts/phase6-store-assertion-partition.mbtx -- prepare /absolute/lunachip/artifacts/new-run
DOCKER_CONTEXT=colima-lunachip-validation moon run scripts/phase6-store-assertion-partition.mbtx -- run control /absolute/lunachip/artifacts/new-run
```

Run `data` and `storage` serially against that same prepared root. Do not retry
into an existing group output or change the declared bound/premise unnoticed.

## Actual engine outcomes

Preparation has passed. The first control launch exits 1 before preparation:
the image's default nonroot user cannot create `/out/control-work`. No model,
SBY status, counterexample or safety result exists. Its full command/exit/logs
are preserved separately as `control-startup-permission-error/`. The launcher
now explicitly specifies container-local `--user 0:0`; all isolation flags,
source, premises and bounds remain unchanged. A fresh corrected run follows.

The corrected control run at unchanged source `e24ebbb` reaches actual SBY
`TIMEOUT`, child exit 8, after 601 seconds. Assertions at global steps 0–50
complete; checking assumptions at 51 starts but does not finish. No engine
status or trace is returned. This is not the required 256-step safety pass,
not a hardware counterexample, and not evidence of a solver speedup.

The final prepared JNY model matches the separately inspected live snapshot
byte-for-byte, SHA-256
`7ed8df68901f4bd652928df143d80f0ce532d26cd756d2333ef79a2e09ff01ee`.
It contains exactly the four selected assertions and unchanged startup premise,
six original memories with two 4x32 result arrays and four 3x64 descriptor
arrays, all with unknown initialization, and fifteen raw `anyseq` cells. The
actual config retains depth256, timeout600 and `smtbmc bitwuzla`; the copied
source equals the prepared selection. HEAD and complete status match before
and after execution. Full inputs, prepared RTLIL/model/SMT and logs are retained
in `control-output/`. Container and owned transport volumes are removed only
after collection. The user explicitly selects continued QEMU use, not Rosetta
installation.

The separate storage13 run at unchanged source `3c115b7` also returns `TIMEOUT`,
child exit8, after602 seconds. Assertion steps0–87 complete; assumptions88 start
but do not complete. No solver status or trace is returned. Its model contains
the exact thirteen selected conclusions, sole startup premise, six original
unknown-initialized memories and fifteen raw `anyseq` cells. The final model
matches its inspected live snapshot, SHA-256
`a0ec7ac9813b00f72d194e2ee9d5fad9767be105e61325367f7be547a6a3125e`.
Config, copied source and before/after HEAD/status remain exact. Full work is
retained in `storage-output/`; the transport container and owned volumes are
removed after collection.

The final data2 run at unchanged source `9728286` returns `TIMEOUT`, child exit8,
after601 seconds. Assertions0–72 complete; assertion73 starts but does not finish.
There is no trace or counterexample. The prepared model contains exactly its two
conclusions and sole startup premise, with six original unknown arrays and
fifteen raw `anyseq` cells. Live and final model bytes agree, SHA-256
`ae142382344a4b57418f20c83a09cf269a3cb1a411b668de75d182736a9fd9fd`.
Config/source and before/after HEAD/status remain exact; all owned containers
and volumes are removed after collection.

| Group | Wall seconds | Last completed assertion step | Outcome |
| --- | ---: | ---: | --- |
| control4 | 601 | 50 | TIMEOUT; assumptions51 unfinished |
| storage13 | 602 | 87 | TIMEOUT; assumptions88 unfinished |
| data2 | 601 | 72 | TIMEOUT; assertions73 unfinished |

None establishes the required256 bound. The complete309-file support, including
the failed permission launch, is sealed by `files.sha256`, SHA-256
`5b2bb8057b8ff2c97660976ed0f6c7c697543641e8469dcfdbb6ed8756002b25`.
It uses approximately64 MiB and contains no compiler cache. The VM is stopped
when idle; its saved profile now explicitly disables Rosetta in accordance with
the user's QEMU-only choice. Both pinned images remain available.

The source explains an important remaining cost: `reset_establishment` checks
all162 retained registers and the complete1,344-bit memory/read-result pair;
the nonrising assertion compares all3,771 original storage bits. Selecting
fewer conclusions does not remove those coupled cones. This observation is not
a proof of the predicates or a measured explanation of every solver cost.
Next composition work should establish the exact clock/reset/storage relations
separately, then the capture/lease/cursor and payload relations, using checked
source-bound supporting invariants. Do not repeat these unchanged timeouts,
assume an unproved internal relation, or shorten the required bounds.

Store safety, the other packet/dependency groups, full fetched
write-path safety and explicit-fairness completion including 8x8 remain open.
No FPGA execution, timing, physical RAM mapping or silicon claim follows.

## Accepted fetched proof made source-reproducible

`validation/formal/fetched_transport_supported.mbt` adds a private, opt-in
collector for the already accepted reader/three-client supporting theorem.
It inserts only the four checked Offer tag, configured-base, active-population
and unwritten-tail conclusions before the original global establishment check.
The first-startup guard is retained; no later-reset bypass, premise, sampler,
state, cut, ABI signal or production operation is added. Removing the complete
four-line block reconstructs the original twelve-conclusion wrapper exactly.
The legacy six-file artifact collector remains unchanged.

Five targeted native tests, strict native checking, native interface generation
and formatting checks pass. Tests bind exact accepted artifact digests:

- original wrapper: `aa105bc8af41f7615bebcaf146aba2843e02c08cd7ad85fe6ec3597afef247a1`;
- sixteen-conclusion wrapper: `4b32fb7ef6ffc8689b38b01562c6f5ef59fa5d7f1b148ba9a6676fd9220c4c8b`;
- unchanged Boolean DUT: `e2fdbb95e931cf6d86abe63b6a94b2a84037bf4798267bd5f6db5d2e9a60fa64`;
- unchanged actual prove config: `dfbb6589baeda8d3cfec87c95e707615a098e89417d25154dc17c92aafe77ba0`.

Opt-in generation, without executing a solver:

```sh
LUNACHIP_PHASE6_FETCHED_SUPPORTED_INPUTS_PRINT=1 moon test validation/formal/fetched_transport_supported_wbtest.mbt --target native --deny-warn --no-parallelize
```

The collector prints `sequential-boolean.sv`, `selected.sv` and `prove.sby`
with exact content/digest boundaries. Both source files and ordinary hierarchy
flattening are required. This reproduces the accepted October8 theorem inputs;
no new solver execution or new theorem is claimed today. The retained
sixteen-assertion proof remains the same scoped binary component result, not
full-device Store safety, fetched write-path coverage, fairness or 8x8 closure.

## Clock/reset and lease component closure

Three parallel agents implement the clock/reset inputs, lease inputs and an
independent read-only source audit. Native/tool execution remains serial.
Design commit `ba8af19`, lease commit `4522524` and clock/reset/runner commit
`5ae10cd` preserve production hardware, public interfaces and the existing
Store bridge digest. Four focused native tests pass (two per family), along
with strict native checking including warning73, interface generation,
formatting and the runner's standalone test. An initial clock/reset test
compared trailing module text incorrectly; its corrected full prefix/suffix
comparison passes without changing emitted inputs.

Eight fresh component tasks are retained in
`artifacts/phase6-clock-lease-20261013/`. Each checks only its named conclusions
against the original graph after assertion-only removal of twelve unrelated
memory bounds. There are no new DUT state elements, control cuts, internal
assumptions or later-reset bypasses. Minimal observers intentionally omit the
original payload ghosts; ghost reset clearing, complete event suppression,
capture ownership/shape, publication and payload remain separate obligations.
The existing sealed nineteen-helper support verifies unchanged.

The first task, `reset-ports`, passes actual basecase0–19 and k-induction under
the locked toolchain in36 wall seconds. Exactly one assertion checks all twelve
original memory-port enable expressions and one assumption requires only the
first sampled reset. The prepared model prunes both C arrays and retains four
original descriptor memories and eleven raw `anyseq` cells; this task is enable
suppression, not storage preservation. Its model digest is
`e886f7e62189e588da156cc6d4b19b480296a1477d6562a4c2d2cfdf46d4e9f4`;
source digest is
`18a6ef602cfb85acf8ab2548f8a58d87d029a5a98d7b2436197c53ebc7969a77`.
Copied source/config and before/after HEAD/status match exactly.

`lease-update` passes basecase0–19 but induction reports
`lc_lease_issue_owned`. Exporting the induction trace then reaches the unchanged
600-second cap: actual task status is `TIMEOUT`, child exit8, wall601 seconds.
The partial346-KiB VCD is retained but is not a complete qualified counterexample.
No startup-reachable hardware failure is established, and the other three
conclusions are not promoted from a failed conjunction. The prepared model has
exactly four assertions and the sole startup premise, digest
`86d2511bdf9eb70c0b3f02376d506ed6b0bf90333ad21ffda2e44b684d193417`.
Source digest is
`c98ecb2cceb8b9f88e157043c8cdd31b6bcae9d9fa0b31e4b78d52e5e9fc9489`.

Source review suggests strengthening Issue ownership with the separately
checked relation `outer State != Run => inner Slotted State == Idle`. This is
an inference from original transitions, not a qualified interpretation of the
partial trace or a proven premise. A fresh assertion-only supported task must
prove both together. Never use `Run => Leased`: final capture releases the lease
while outer Run may persist. Keep the unsuccessful input/output unchanged and
do not repeat it without a changed proof relation.

These are binary component results only. No original Store BMC256 conjunction,
full fetched write path, explicit-fairness completion or Phase6 gate passes.

The assertion-only strengthened Issue inputs are committed at `be9a262`.
Two additional native tests pass, including exact reconstruction of the failed
four-conclusion input after removing the single paired-state assertion. The
fresh five-conclusion `lease-update-supported` task passes both basecase0–19
and k-induction in56 wall seconds. Its actual model has exactly five assertions
and the sole startup premise; the extra relationship is proved, not assumed.
Source digest is
`29f5161e288a61ff69f481e8a2b5e0959767305de9387d7f7725e11e72412c45`;
model digest is
`cdc4841fa6b75f2a7be1ee27f3b488196031a98cd38ac9f0f868188d91247025`.
All inputs and work are retained separately in
`artifacts/phase6-lease-supported-20261013/`. No hardware repair or new premise
was needed. This result establishes the five named local relations, not the
older widened capture/shape conjunction.

`lease-exclusion` passes its four checked reservation/admission conclusions by
basecase0–19 and k-induction in55 wall seconds, model digest
`f98243487e7a832fd5d531619a3193420fcf4ac5d8d9ae53671e1f1b26536a78`.
`pending-protection` passes its four inner-handshake/read/update/selector
conclusions similarly in59 wall seconds, model digest
`77a4c28f5531409ab2f87891ca71e1b4cbba91190de547acb6cfc2daf3f5571d`.
Each actual model contains exactly four assertions and the unchanged startup
premise. Copied source/config and before/after source identity match. In
particular these results establish PRE protection through terminal/release and
ACK edges without treating held Done as a Store reservation or forbidding all
outer compute admissions during a pending read. Physical capture exclusion,
shape/publication and data preservation are still not concluded.

The remaining four clock/reset tasks also pass actual basecase0–19 and
k-induction. The clock/reset family has one selected assertion per task plus
the unchanged startup-only reset assumption, verified in each prepared model.
Both memory tasks retain six original unknown-initialized arrays: two4x32 C
arrays and four3x64 descriptor arrays, plus all six synchronous read states.
No reset-to-zero storage premise is introduced.

| Accepted component task | Conclusions | Wall seconds |
| --- | ---: | ---: |
| reset-ports | 1 | 36 |
| reset-registers | 1 | 71 |
| reset-memory | 1 | 67 |
| clock-registers | 1 | 49 |
| clock-memory | 1 | 44 |
| lease-update-supported | 5 | 56 |
| lease-exclusion | 4 | 55 |
| pending-protection | 4 | 59 |

These eight supporting proofs establish eighteen named conclusions. Their
four additional prepared-model digests, in the order reset-registers,
reset-memory, clock-registers, clock-memory, are:

```text
2d09b8c442b2b464fd438ba4137caa14cf0a03a83c3bc546952ae2a490b9797d
668df9457ddcf7f544ad64ed0c01b2166b5a3dbbfefa1c6399e843f6b9258d0e
abac94e7841f1a68941a009b7401bae4b94d041b83d0e2200ec6e73950c76e4b
8f2613a5cd6bee3a85a97bac3b5cbfeee371d9ef33221fef0592f4522ee16e96
```

All nine actual jobs, including the unsuccessful original Issue conjunction,
retain input/config copies, prepared RTLIL/JNY/SMT, logs, versions, actual
statuses and before/after source identity. The two roots are sealed by
`files.sha256`, with digests:

```text
phase6-clock-lease-20261013: c06f7f6f4ff3aaf8265c39c73200a54b39d7dc466aa500262a5388af2e98cc25
phase6-lease-supported-20261013: 1c05c84ee89057500f9a5afcbb168a8d4faefdd37056888584ba0e48107d521c
```

The support occupies approximately136 MiB combined, with no compiler cache
inside it. The single reused repository `_build` is approximately654 MiB;
the dedicated QEMU-only VM is stopped after collection. Production hardware,
ABI and public interfaces remain unchanged. Six focused native tests and the
runner test pass; no fresh full-native or complete Phase6 aggregate is claimed.

Next: explicitly compose the checked source-bound clock/reset and lease
relations into capture ownership/shape, publication and whole-Store payload
preservation. Complete ghost clearing/event suppression and memory bounds,
then remaining packet/fetched and explicit-fairness completion including8x8.
Do not replace any of those obligations with an assumed component relation or
the failed20-step base case.

## Capture/publication and Store payload composition

Design commit `92ec892` defines the next composition slice. Three parallel
agents implement capture/publication, payload observers and independent source
review, with compiler and QEMU-only tool jobs still serial. Commit `fd259be`
adds four capture groups; `77857ef` adds seven payload groups and the existing
runner's opt-in collection mode. Four focused native tests, interface/format
checks, strict native checking including warning73 and the runner test pass.
A concatenation syntax error was corrected before collection; no hardware,
public interface, ABI or retained original artifact changed.

Fresh inputs are retained in `artifacts/phase6-capture-payload-20261013/`.
Native tests pin the original Boolean and Store bridge bytes and reconstruct
the complete original body after removing the new observers and twelve
unselected bounds assertions. Every composed supporting relation is an
assertion; startup reset remains the sole premise. No component lemma becomes
an assumed control signal or read payload.

`capture-cursor` passes its three exact modular cursor/state conclusions by
basecase0–19 and k-induction in35 wall seconds. `capture-publication` passes
eight validity/shape/write-enable equations in35 wall seconds. Invalidation
clears validity but does not erase shape or SRAM; final capture publishes the
selected PRE shape at the same commit. Each prepared model has exactly the
selected assertion roster and one startup premise. Copies and before/after
source identities match. Model digests, in that order:

```text
a6f9517e58ee382fe2bbd5306d3fac710e06302c44ef0fdddbd5bfb2e6c628f9
77831631569cb6904dc33301ee690dabcb4df6304547df760c6c864650af5992
```

Capture reachability and original-p2 composition still require actual engine
outcomes. Payload tasks distinguish per-cell last-capture history, ReadOld/
HoldLast, pending identity and local real-response DMA transport from the joint
raw-producer-to-public-write expectation. The joint task's captured-read basis
is a checked condition, not a proof that every published rectangle supplies
complete latest-generation coverage. Original whole-Store preservation and
Phase6 remain open until those eligibility and generation links are established.

`capture-safety` passes its fourteen conclusions by actual basecase0–19 and
k-induction in33 wall seconds. `capture-composition` passes all twenty-six
checked conclusions in35 wall seconds, including the **original**
`lc_capture_publication_and_lease` predicate under label
`lc_capture_original_p2`. Reachable ownership, fault, shape and cursor bounds,
the widened final-capture equality, exact lease/cursor updates and all eight
metadata/write-enable equations are checked together, not assumed. The actual
prepared models contain exactly14/26 assertions respectively and one startup
premise. Their model digests are:

```text
d0d322212994808b9ca3014f5b9ecb31d45f406feb95bf479e8dac58473fc395
46029eb2a7ee2b24f62c3731af3219b1846427df67a45eebae315e7e826be695
```

This closes that source-bound binary capture/lease component conclusion and
adds the explicit publication equations. It does not yet prove actual SRAM
word preservation, original Store reservation exclusion, full generation
coverage or the complete Store conjunction. The unchanged whole/control
timeouts are not rerun or reclassified as passing.
