# Bit-synchronizer synthesis-structure evidence

## Scope

This evidence slice checks the generic pre-map structure emitted for LunaChip's
resetless asynchronous-input bit synchronizer. The fixture matrix contains
exactly two-, three-, and four-stage instances. Every instance is constructed
through the public LunaWire bit_synchronizer API, finished through ordinary CDC
admission, serialized as typed IR, and emitted by the production SystemVerilog
backend.

The result is deliberately narrow. A pass says that the locked Yosys 0.68
front-end sees the exact expected chain of positive-edge one-bit sequential
cells before technology mapping. It does not say that a downstream flow added
CDC placement constraints, kept the registers physically adjacent, achieved a
particular metastability probability or MTBF, or closed timing.

## Exact shape contract

Each generated bundle contains expected-cdc-shape.json, validated against
toolchain/yosys/cdc-synthesis-shape.schema.json. It binds:

- the emitted top module;
- the destination clock and asynchronous source signals;
- every ordered stage signal;
- the final output;
- the exact stage count, positive edge, one-bit width, and absence of reset.

scripts/yosys-cdc-synthesis-check.sh parses pre-map.rtlil, not the mapped
netlist. It requires exactly N $dff cells for an N-stage fixture, with one-bit
width, positive clock polarity, one common destination clock, and the ordered
source-to-stage-zero-to-final-stage data path. The output must alias only the
final stage. Any missing stage, wrong clock, wrong width, bypass, additional
state, memory, reset-bearing cell, enable-bearing cell, or negative-edge cell
fails closed.

The checker emits provenance-bound schema-v2 `cdc-synthesis.json` under
toolchain/yosys/cdc-synthesis-report.schema.json. The strict report names its
artifact kind and exact Yosys creator, then binds the expected-shape JSON,
pre-map JSON, pre-map RTLIL, and Yosys lock by SHA-256, byte count, and a
nonempty assertion. The pre-map JSON must itself contain exactly the expected
top module and the fixture's exact number of `$dff` cells; a creator-only,
unrelated, or multi-module document is ineligible. It contains exactly nine
named Boolean checks. A
deterministic issue list contains precisely the failed check names, and the
total, passing, failing, and issue counts must agree.

`pass` and `result` agree with the conjunction of all nine checks. The
`pre_map_structural_shape` claim is true only in a passing report; a diagnostic
failure report records it as false. Physical placement, metastability, MTBF,
and timing closure remain false in every report.

## Reproducible gate

Run:

    LUNACHIP_YOSYS_MOUNT_MODE=volume \
    scripts/phase5-yosys-cdc-synthesis-gate.sh [EMPTY_RUN_ROOT]

The focused gate reuses toolchain/yosys/lock.json,
scripts/phase4-yosys-validate.sh, and scripts/phase4-yosys-run.sh without
copying or relaxing them. The runner still selects only the digest-pinned
linux/amd64 OCI image, disables networking, uses a read-only root, drops all
capabilities, and generates the synthesis program itself.

The gate accepts only volume transport. It records the active Docker context,
daemon response, locked image inspection, manifest/config/platform identity,
and each runner transport receipt. Bind transport fails before Docker is
contacted. That failure remains in a strict incomplete receipt and cannot
publish passing evidence.

Before materialization, the gate captures a complete repository manifest,
status, and HEAD. It pins every directly executed checker, validator, runner,
self-test, shared evidence library, gate, and the complete Yosys schema tree.
It materializes all three typed bundles with cmd/phase5-sync-fixtures, rejects
extra fixtures or bundle files, validates each job, and executes the locked
runner. The checker receives all four provenance-bound inputs. A separate
scripts/yosys-cdc-synthesis-report-check.sh process independently rehashes
those inputs and requires the fixed fixture/stage mapping, exact sequential
cell count, all nine checks, zero issues, passing classification/result, and
the narrow claim boundary. The gate pins and rechecks the producer, independent
verifier, both report schemas, and their shared hashing library.

Safe manifests independently bind every bundle, synthesis output, report, log,
and metadata artifact. Symbolic links, special files, unsafe paths, missing
files, and extra files fail closed. The repository and every pinned dependency
are rechecked after the matrix. The incomplete receipt is then sealed with its
exact record grammar and END marker; STATE pass is published atomically only
after a complete artifact manifest exists. The public matrix is exactly three
reports and 27 passing checks, with stage counts 2, 3, and 4.

scripts/yosys-cdc-synthesis-selftest.sh independently covers:

- strict receipt and safe manifest adversarial cases;
- byte-deterministic generation of the exact two-, three-, and four-stage
  native fixture matrix;
- the exact passing two-stage shape;
- a missing stage;
- a stage on the wrong clock;
- a widened stage;
- a direct source-to-output bypass;
- additional sequential state;
- altered report fields, input digests, issue/count consistency, result/pass
  implication, and overclaimed boundaries;
- tampered expected-shape, pre-map JSON, pre-map RTLIL, and lock inputs, plus a
  symbolic report;
- fixture/stage mismatch, creator-only or wrong-module pre-map JSON, symbolic
  and special inputs, and existing, symbolic, or special report outputs;
- dependency pin/recheck and complete-manifest requirements; and
- a no-Docker bind-transport rejection that retains the exact failed command
  in incomplete evidence and never publishes STATE pass.

The hand-authored RTLIL used by these parser self-tests is not synthesis
evidence. Only the three generated bundles executed through the pinned runner
are synthesis evidence.
