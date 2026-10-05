# Fetched 8x8 device synthesis on 2026-10-05

The unchanged pinned Yosys runner passed generic synthesis for the fixed
8x8/K16, host4096, ring4, q3 fetched concurrent graph. Source implementation
checkpoint: `d4bbe2733d87e13284315831d5c5d86c71d5ca55`; the full native gate
subsequently passed 763/763 tests. Its canonical IR is byte-identical to the
[independently replayed signed two-slot design](phase6-array8-20261005.md).
All nine prior Phase 4 bundles and the earlier 1x1/K512 synthesis bundle also
compare byte-identically after this addition.

## Actual result and limits

Locked image:
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`,
`linux/amd64`; recorded Yosys 0.68 (`38e001a6f`), SBY v0.68 and Bitwuzla 0.9.1.
The existing volume transport, runtime user 501:20, disabled networking and
read-only root filesystem remain unchanged. No tool lock, VM, runner or warning
policy changed. Runner exit zero and retained status `PASS` accompany zero
final check errors, process lowering, `memory -nomap`, `check -assert` and
generic flattened synthesis with latches forbidden and ABC disabled.

The existing inference checker passed `require-memory-cell` against these
exact observed pre-map shapes:

| Count | Depth | Width | Read ports | Write ports |
|---|---|---|---|---|
| 32 operand banks | 16 | 8 | 2 | 1 |
| 2 result memories | 64 | 32 | 2 | 1 |
| 4 descriptor lanes | 3 | 64 | 2 | 1 |

There are 38 `$mem_v2` cells, zero legacy memory declarations and logged
maximum memory-cell count 38. The report says `memory-cell-retained`,
`inferred_memory_claim: true`, `physical_ram_claim: false`, `pass: true`.
The two observed read ports describe the optimized representation, not a
physical two-read-port RAM. No equivalence, technology mapping, area, timing,
power, FPGA or silicon result follows. This one configuration does not finish
the Phase 6 synthesis matrix or formal/product gate.

## Retention and reproduction

All five inputs, complete output, inference report and outer log are retained
outside Git at `/Users/kq/Workspace/lunachip/.phase6-synthesis8-evidence-20261005`.
Input and output directories compare byte-identically to the original run at
`/private/tmp/lunachip-phase6-synthesis8-20261005.uZtvMr`.
Use fresh directories with the existing exporter and runner:

~~~sh
moon run --target native --release cmd/phase6-synthesis-fixtures -- export-array8 /absolute/new-bundle
LUNACHIP_YOSYS_MOUNT_MODE=volume scripts/phase4-yosys-run.sh oci synth /absolute/new-bundle /absolute/empty-output
~~~

| Artifact | SHA-256 |
|---|---|
| `bundle/design.lcir` | `37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8` |
| `bundle/job.json` | `757181d2decf9e0e064b356badd59afbdd4ca1b0b4ca22d1b33f555d20a761ff` |
| `output/pre-map.rtlil` | `2364e4d38ace9f803df5c4b377c3235f03b4d295fd69e3c9325c38be1779ebe4` |
| `output/pre-map.json` | `226a8523030dd76780631c0f0504f0fb49684d6346db21dbab92299df9b0817e` |
| `output/netlist.json` | `87c5529ec5bc73610af01d07a6f07758dc3c950281ab4a305872b9d0d58277f1` |
| `output/netlist.v` | `1219de915e17a5a6a3e1bf1aaa3a2b3193c59c49d62364fd55594863765dd398` |
| `output/yosys.log` | `46c425a6eab6ea74229e193412b2f634c93fdabb28bb7f84a606b69718d70298` |
| `inference-report.json` | `3bb701b286ff981c6fa0feddc871900cd96efdea010614d8492b71e02d1c5f03` |
| `output/tool-versions.txt` | `e97b58b86a15f0cb436978e2b3c7232d0b2d3b8472d7dfbaeebcb938afbf927b` |
| `output/transport-receipt.txt` | `2460bc1e16fe1117ed8cab0beff21d6ed7ae35547b04c822e30d1a1bbd2b7599` |
