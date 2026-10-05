# Fetched device synthesis fixture

The first independent synthesis slice now passes the unchanged pinned Yosys
flow. It uses the same 1x1/K512, host4096, ring4, q3 configuration and design
identity as the successful [concurrency replay](evidence/phase6-concurrent-20261005.md).
[The retained result](evidence/phase6-synthesis-20261005.md) records the exact
ten pre-map memory cells and their observed port shapes. Larger 8x8
configurations remain required for the product proof.

The fixed 8x8/K16, host4096, ring4, q3 input generator and `export-array8`
command are implemented. Canonical IR matches the retained signed two-slot
replay exactly. All 37 targeted synthesis/exporter tests pass; the new source
inventory contains 38 memories: 32 signed-eight-bit operand banks at depth
16, two signed-32-bit result memories at depth 64, and four 64-bit descriptor
lanes at depth three. These are source-IR checks, not retained-cell or physical
mapping results. The nine-fixture Phase 4 matrix remains separate and unchanged.

~~~sh
moon run --target native --release cmd/phase6-synthesis-fixtures -- export-array8 /absolute/new-bundle
LUNACHIP_YOSYS_MOUNT_MODE=volume scripts/phase4-yosys-run.sh oci synth /absolute/new-bundle /absolute/empty-output
~~~

## Reuse the existing synthesis boundary

The narrowly named generator in `validation/synthesis` returns the existing
read-only `BundleArtifact` collection. Elaborate through checked capabilities
and `ring_concurrent_from_capabilities`, then reuse the current private job JSON
and digest helpers. Retain canonical IR, capabilities, emitted SystemVerilog,
name map and `job.json`. Do not extend `SynthesisKind` or change the nine-fixture
Phase 4 matrix. A focused native exporter may write this bundle only to a new
directory; it is not another tool runner or evidence protocol.

The unchanged runner is:

~~~sh
scripts/phase4-yosys-run.sh oci synth /absolute/bundle /absolute/empty-output
~~~

It validates source digest bindings and retains pre-map RTLIL/JSON, generic
netlist, command inputs, logs, status, versions and the transport receipt.
Preserve tool, image/platform, source, capabilities, canonical IR and RTL
identities, including failed attempts. A process-startup failure is an
infrastructure failure, not a hardware counterexample. Do not reconfigure the
stopped Rosetta VM without user approval.

## Memory obligations and limits

The exact source-IR inventory is `2*rows + 2*columns + 6`: two A banks per row,
two B banks per column, two C memories and four descriptor lanes. The A/B banks
are signed eight-bit elements at reduction-capacity depth; C memories are
signed 32-bit elements at rows-times-columns depth; descriptor lanes are
64-bit words at queue-depth. Validate the source inventory and emitted names
through the canonical module/name map, not hard-coded generated identifiers.

This count does not promise the same number of retained `$mem_v2` cells. The
1x1 fixture has one-word C memories that Yosys may lower or transform. Inspect
the actual pinned pre-map output before specifying retained counts, port shapes
or inference checks. Reuse the existing inference checker only if its declared
classification matches the observed design; do not label a single-write device
as an observe-only multiwrite fixture to obtain a pass.

## Verification order

First run targeted bundle/exporter tests for deterministic bytes, strict new
directory handling, capability/IR identity and source memory inventory. Compare
all nine existing Phase 4 bundles byte-for-byte. Then export and run pinned
Yosys, inspect every report and record only the observed generic synthesis and
pre-map representation. No result implies physical RAM mapping, technology
mapping, area, timing, power or silicon performance. The larger device matrix,
named formal tasks and remaining differential fixtures stay separate gates.
