# Dependency monitor sensitivity on 2026-10-05

The first actual dependency-family execution completed with the exact expected
counterexample for `phase6-dependency-negative-failed-generation-bmc`.
This is monitor-sensitivity evidence, not a production defect or successful
dependency safety proof. Source checkpoint: `0fbb29d`.

## Execution and retained result

The unchanged locked Yosys/SBY/Bitwuzla runner exited zero. SBY returned `FAIL`
at global step13 after285 seconds, selecting only
`latest_writer_matches_independent_model`, stable assertion
`lc_p4_b6c61746573745f7772697465725f6d6174636865735f696e646570656e64656e745f6d6f64656c`.
One actual VCD counterexample is retained. The canonical typed result records
`RESULT counterexample`; the existing full typed-artifact verifier passed
result/task equality, execution, status, versions, provenance, complete output
inventory and trace digest binding.

The task retains bound256 global steps /128 DUT clocks, four legal-host/reset
assumptions and no fairness. It uses the unchanged direct queued
1x1/K2/host1024/q3 graph and48 typed existing-node observations. Its mutant
changes only checked status comparisons from Failed to Success when both
the observed DUT and independent ghost actually report Failed. Production
canonical IR and the isolated observation DUT compare byte-identically to
the initial attempt; the production graph is not mutated.

Independent trace inspection confirms the intended trigger, not an earlier
model mismatch. The solver chose LoadB/B0, caller ID `0xffffffff`, ticket0,
rows2, columns4097, reduction0 and zero base/stride/selectors. Descriptor0.2
syntax and unused fields pass, but the shape rejects with exact fault3 for
the elaborated one-column device. At global step7 it reserves and publishes
the B0 intent; step9 shows actual and ghost B0 Pending with local reject3.
At step11 both become Failed while only checked B0 becomes Success; the
selected assertion fails at step13. All six actual/ghost statuses and tickets
remain matched, other slots stay Empty, and the comparison predicate is true
through step10. The two-step/pre-edge schedule accounts for delayed assertion
sampling. This is not the pre-execution conjectured LoadA unused-field example.

Tool identity remains the locked `linux/amd64` image
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`,
Yosys0.68 (`38e001a6f`), SBYv0.68, Bitwuzla0.9.1. Existing volume transport,
runtime user501:20, disabled network and read-only root filesystem remain
unchanged; all Yosys warnings remain errors.

## Preserved unsuccessful attempt

Checkpoint `6d1beeb` first stopped in preprocessing, runner exit16 / SBY ERROR,
elapsed40s. Automatic conversion of the small reference array
`lc_g_failed_after_success` into registers triggered the strict warning policy.
No solver status or trace was produced, so that attempt is incomplete rather
than a counterexample. Its complete inputs, output and outer log remain
separate from the successful retry.

The retry explicitly declares the nine tiny reference arrays as register
banks with declaration-local `mem2reg`. The
[pinned frontend source](https://raw.githubusercontent.com/YosysHQ/yosys/38e001a6f/frontends/ast/simplify.cc)
uses the same conversion for explicit and automatic cases. No production
memory, assumption, assertion, reset transition, tool lock or warning waiver
changed. Inputs were re-exported with new hashes into a fresh directory.

## Validation and claim boundary

Before the tool run, formal/exporter tests passed59/59. All three original
FluxTile pilot bundles and every fixture in all four older formal families
remained byte-identical after fresh export. The complete native checkpoint
passed772/772 plus interface generation, formatting, strict native check with
warning73, default CLI smoke and dependency/source-size boundaries. The
subsequent explicit-register refinement passed strict checking and59/59
targeted tests; no newer full-matrix result is implied.

Positive safety, five independent covers and the two other sensitivity
negatives remain required. This one counterexample proves neither FIFO
atomicity nor ordered retirement, leases, ticket wrap, liveness, fetched
transport safety or the complete Phase6 gate.

## Retention

The first positive-cover launch was refused by the existing job-schema
preflight, before any tool execution: its separate invalid-syntax cover name
was69 characters rather than the permitted64. `dependency-r2` and
`priority-cover-run.log` retain that input and rejection. The fixture now
uses suffix `invalid-syntax-prior` for that one cover; its property label,
semantics, bound and assumptions do not change. All generated dependency task
names have a native regression check against64. A fresh bundle and successful
existing schema/source-digest preflight are required for further execution;
no schema or runner limit was relaxed.

Original run root:
`/private/tmp/lunachip-phase6-dependency-20261005.Cc5eiH`.
Both attempts are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-dependency-evidence-20261005`:
`negative-failed` / `negative-failed-output` preserve the preprocessing error;
`negative-failed-r2` / `negative-failed-r2-output` preserve the actual result.
Complete output directories compare byte-identically to their originals.
Outer logs stay outside output inventories. The native checkpoint log is
retained alongside them.

| Artifact | SHA-256 |
|---|---|
| `negative-failed-r2/source-set.lcfs` | `45589481044bd349db1f464caa23ce6b6111c416dcfdfe5190afde4ed837e5c0` |
| `negative-failed-r2-output/result.lcfr` | `260d317a0a7350e709006e0292f8474c485078d42f0499dccde804e0513178c5` |
| `negative-failed-r2-output/receipt.lcfe` | `3bd72e08702df3243e4906014f8b23b9e4aa6d0af4f7f5afeea611cb549e9c21` |
| `negative-failed-r2-output/outputs.sha256` | `19848fe1d133fbdfaa43add9679815c155634af58a7cb6ec8f3597eccc1e3ab1` |
| `engine_0/trace.vcd` | `5e149a785461e96b0f3abf85ad6919eaf003cd84fb1da92bf7f98afc4caecf13` |
| `negative-failed-r2-run.log` | `fcfd070192b0e801fe5866cd3f11f3e356298e7ed724a1e8460b806f9c4383bd` |
| `native-gate.log` | `3e511254bad95eb76272955ad79dce1f95aa43bfda21e33750d34eabbec951fe` |
