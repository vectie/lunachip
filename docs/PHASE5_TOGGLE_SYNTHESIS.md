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

The checker emits provenance-bound schema-v2 `toggle-synthesis.json`. It names
the artifact kind, fixed fixture topology, expected state count, and exact
Yosys creator. It binds `expected-toggle-shape.json`, `pre-map.json`,
`pre-map.rtlil`, and the Yosys lock by SHA-256, byte count, and a nonempty
assertion. The report contains exactly eight Boolean structural checks; its
deterministic issue list and passing/failing totals must agree with those
checks. `result`, `pass`, classification, and `pre_map_state_shape` are true or
passing if and only if every check passes. All diagnostic reports clear the
structural claim, and every physical or protocol-logic claim remains false.

The pre-map JSON is itself part of the checked contract: it must contain the
exact expected top, exactly the expected number of `$dff` cells, no alternate
stateful cell, and neither memory cells nor module-level memories. The RTLIL
reset/enable check additionally requires every contract entry with `enable:
true` to have the generated immediate self-holding enable mux beneath the reset
mux. `enable: false` is not a negative claim about combinational muxes: request
and acknowledgement next-state logic may legitimately self-hold, and this
evidence deliberately excludes combinational protocol logic.

A separate `scripts/yosys-toggle-synthesis-report-check.sh` independently
exact-validates the expected contract, rehashes all four inputs, checks the
fixed `2/1/9`, `3/2/13`, and `4/2/15` fixture mappings, and accepts only exact
passing counts and narrow claims. The independent self-test mutates all of
those boundaries. Its hand-authored RTLIL and synthetic pre-map JSON are parser
evidence only; generated bundles executed by the pinned runner are the
synthesis evidence.

The focused self-test also schema-validates passing and diagnostic reports,
then rejects fixture-tuple, observed-count, issue-membership, and count-
arithmetic mutants. Symbolic or special inputs and existing, dangling-symbolic,
or special report outputs, including a symbolic immediate parent, fail without
replacing the caller's filesystem object.

## Reproducible gate

Run:

    LUNACHIP_YOSYS_MOUNT_MODE=volume \
    scripts/phase5-yosys-toggle-synthesis-gate.sh [EMPTY_RUN_ROOT]

The gate reuses `toolchain/yosys/lock.json`,
`scripts/phase4-yosys-validate.sh`, and `scripts/phase4-yosys-run.sh` unchanged.
The runner remains bound to the digest-pinned linux/amd64 OCI image with no
network, a read-only root, dropped capabilities, and a generated Yosys program.

The gate accepts only volume transport. Before any Docker operation it creates
the incomplete receipt and records every command outcome. It then records the
active Docker context and daemon response, independently inspects the locked
manifest/config/platform identity, and validates each runner's exact five-line
transport receipt. Bind transport fails before Docker is contacted, retains its
nonzero command in strict incomplete evidence, and cannot publish a pass.

Before materialization, the gate captures a complete repository manifest,
status, and HEAD. It pins every directly executed validator, runner, producer,
independent verifier, self-test, both shared evidence libraries, both toggle
schemas, the gate, and the complete Yosys schema tree. It materializes exactly
the three typed bundles, rejects extra fixtures or bundle entries, validates
each job and its sole top-module source, and executes the locked runner. Runner
outputs and the isolated one-file report directories have exact inventories.
The producer and independent verifier both receive all four provenance-bound
inputs.

The immutable matrix contains exactly three reports and 24 passing structural
checks: stages `2,3,4`, payload leaves `1,2,2`, and state counts `9,13,15`.
Safe manifests independently bind every bundle, synthesis output, report, log,
and metadata artifact. Symbolic links, special files, unsafe paths, missing
files, and extra files fail closed. The repository, every dependency, and all
result manifests are rechecked after the matrix. A complete artifact manifest
is created before the receipt is strictly sealed with `END`; `STATE pass` is
published atomically only after that validation succeeds.

The focused self-test also runs the shared receipt/manifest adversarial suite,
generates the exact three-bundle matrix twice to prove byte determinism,
validates every job and inventory, statically checks dependency closure and
publication requirements, and uses a fake Docker executable to prove the
volume preflight retains incomplete failure evidence without contacting Docker.
