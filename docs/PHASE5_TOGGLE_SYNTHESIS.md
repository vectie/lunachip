# Toggle-handshake synthesis-structure evidence

## Scope

This slice checks the generic pre-map state structure emitted for LunaChip's
coordinated-reset toggle handshake. The matrix contains a 13-bit scalar
payload at two synchronizer stages and a two-leaf 13/3-bit record payload at
three and four stages. Every fixture is built through the public LunaWire
`toggle_handshake` API, admitted through ordinary CDC validation, serialized
as typed IR, and emitted by the production SystemVerilog backend.

A pass says only that the locked Yosys 0.68 front-end sees the exact expected
positive-edge register inventory, clock partition, synchronous active-high
zero reset mux, and self-holding enable mux before technology mapping. It does
not prove combinational protocol logic, physical CDC placement, metastability
behavior, MTBF, recovery/removal, timing closure, or unilateral-reset safety.

## Exact state contract

Each bundle contains `expected-toggle-shape.json`, validated against
`toolchain/yosys/toggle-synthesis-shape.schema.json`. The contract binds every
register output, width, clock, reset, and whether it is payload storage with an
enable. For synchronizer depth `N` and flattened payload leaf count `L`, the
inventory is exactly `2*N + 3 + 2*L` registers:

- one source request toggle and `N` destination request stages;
- one held source register per payload leaf;
- destination valid, one destination register per payload leaf, and the
  destination acknowledgement toggle;
- `N` source acknowledgement stages.

`scripts/yosys-toggle-synthesis-check.sh` parses `pre-map.rtlil` immediately
after the locked runner's `proc` pass. At that boundary synchronous reset and
enable are muxes feeding ordinary `$dff` cells. The checker therefore requires
one exact reset-to-zero mux per state cell and, for enabled payload storage, an
inner self-holding enable mux. It rejects missing, duplicate, widened,
misclocked, misreset, nonzero-reset, non-self-holding, extra-state, and memory
shapes. It intentionally does not infer a protocol proof from unrelated
combinational cells.

The independent self-test mutates all of those boundaries. Its hand-authored
RTLIL is parser evidence only; generated bundles executed by the pinned runner
are the synthesis evidence.

## Reproducible gate

Run:

    DOCKER_CONTEXT=colima-lunachip-phase3 \
    LUNACHIP_YOSYS_MOUNT_MODE=volume \
    scripts/phase5-yosys-toggle-synthesis-gate.sh [EMPTY_RUN_ROOT]

The gate reuses `toolchain/yosys/lock.json`,
`scripts/phase4-yosys-validate.sh`, and `scripts/phase4-yosys-run.sh` unchanged.
The runner remains bound to the digest-pinned linux/amd64 OCI image with no
network, a read-only root, dropped capabilities, and a generated Yosys program.

The gate first executes the checker self-tests, then materializes the three
typed bundles, executes the locked runner, validates each pre-map RTLIL result,
hashes inputs and results, freezes git and tool identities, and publishes
`STATE pass` only after the final identity recheck. A missing Docker daemon or
pinned image fails closed and leaves only an incomplete evidence ledger.
