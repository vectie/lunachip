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

The checker emits cdc-synthesis.json under
toolchain/yosys/cdc-synthesis-report.schema.json. Its claim boundary records
physical_placement, metastability, mtbf, and timing_closure as false.

## Reproducible gate

Run:

    DOCKER_CONTEXT=colima-lunachip-phase3 \
    LUNACHIP_YOSYS_MOUNT_MODE=volume \
    scripts/phase5-yosys-cdc-synthesis-gate.sh [EMPTY_RUN_ROOT]

The focused gate reuses toolchain/yosys/lock.json,
scripts/phase4-yosys-validate.sh, and scripts/phase4-yosys-run.sh without
copying or relaxing them. The runner still selects only the digest-pinned
linux/amd64 OCI image, disables networking, uses a read-only root, drops all
capabilities, and generates the synthesis program itself.

The gate runs the checker self-tests, materializes all three typed bundles with
cmd/phase5-sync-fixtures, executes the locked runner, validates each pre-map
RTLIL result, hashes bundles and results, freezes the git/tool identities, and
publishes STATE pass only after the final identity recheck.

scripts/yosys-cdc-synthesis-selftest.sh independently covers:

- the exact passing two-stage shape;
- a missing stage;
- a stage on the wrong clock;
- a widened stage;
- a direct source-to-output bypass;
- additional sequential state.

The hand-authored RTLIL used by these parser self-tests is not synthesis
evidence. Only the three generated bundles executed through the pinned runner
are synthesis evidence.
