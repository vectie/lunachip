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
source, premises and bounds remain unchanged. A fresh run remains required.

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
installation. The remaining disjoint groups have no outcomes yet.

Store safety, the other packet/dependency groups, full fetched
write-path safety and explicit-fairness completion including 8x8 remain open.
No FPGA execution, timing, physical RAM mapping or silicon claim follows.
