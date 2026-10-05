# Fetched concurrent device synthesis on 2026-10-05

The unchanged pinned Yosys runner passed generic synthesis for
`fetched-concurrent-1x1-k512-overlap`. Source snapshot:
`951dd23df8bda1203670ce1032e735d1a1a42ffd`.
The checked configuration is 1x1, reduction capacity 512, host4096, ring4 and
q3. Canonical IR, capabilities, emitted RTL and name map are byte-identical to
the independently validated [concurrency replay](phase6-concurrent-20261005.md).
This is one configuration, not the complete Phase 6 synthesis gate.

## Execution and observed memory representation

The locked image is
`ghcr.io/zubax/zubax-fpga-toolchain-oss@sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775`,
platform `linux/amd64`. The recorded tool versions are Yosys 0.68
(`38e001a6f`), SBY v0.68 and Bitwuzla 0.9.1. The existing volume transport used
the pinned-image permission initializer and runtime user 501:20, with
networking disabled and the root filesystem read-only. No tool lock, VM
configuration, warning policy or runner changed.

The runner exited zero and retained `status.txt` containing `PASS`. The flow
checked hierarchy, lowered processes, retained memories with `memory -nomap`,
ran `check -assert`, emitted pre-map RTLIL/JSON, and completed generic flattened
synthesis with latches forbidden and ABC disabled. The final check reported
zero problems. Earlier process-startup failures are not a blocker for this
successful run, but do not establish that future formal processes will start.

The source IR has ten memories, each with one synchronous HoldLast read and
one full-word write. The observed pre-map representation has ten `$mem_v2`
cells, no legacy memory declarations, and these exact shapes:

| Count | Depth | Width | Read ports | Write ports |
|---|---|---|---|---|
| 4 operand banks | 512 | 8 | 2 | 1 |
| 2 result memories | 1 | 32 | 2 | 1 |
| 4 descriptor lanes | 3 | 64 | 2 | 1 |

The unchanged inference checker passed `require-memory-cell` with those
observed shapes. Its retained report says `memory-cell-retained`,
`inferred_memory_claim: true`, `physical_ram_claim: false`, and `pass: true`.
This checks the inspected snapshot, not a prediction for every configuration.
The two pre-map read ports are an emitted/optimized representation, not a
promise of a physical two-read-port RAM or synchronous hardware mapping.
No synthesis equivalence, area, timing, power, FPGA or silicon claim follows.

## Retention and reproduction

The five input artifacts, complete runner output, inference report and outer
log are retained outside Git at
`/Users/kq/Workspace/lunachip/.phase6-synthesis-evidence-20261005`.
The original run root is
`/private/tmp/lunachip-phase6-synthesis-20261005.X48acl`.
Both retained bundle and output directories compare byte-identically to the
original run. Use new export and output directories:

~~~sh
moon run --target native --release cmd/phase6-synthesis-fixtures -- export /absolute/new-bundle
LUNACHIP_YOSYS_MOUNT_MODE=volume scripts/phase4-yosys-run.sh oci synth /absolute/new-bundle /absolute/empty-output
~~~

All 35 targeted synthesis/exporter tests pass. All nine earlier Phase 4
bundles remain byte-identical. The complete native slice gate passes 743/743
tests, interface generation, formatting, strict native check with warning 73,
default CLI smoke and dependency/source-size boundaries. Larger 8x8 synthesis,
independent replay and named formal tasks remain required.

| Artifact | SHA-256 |
|---|---|
| `bundle/design.lcir` | `4b10085bf8190905952a181df5a6080791f2116af78c6fff76e0b0a183930a5d` |
| `bundle/job.json` | `2144cbf5456b5f37b1da723f872b47a984f4a2d5a5dc5ff17be1a730b0f48981` |
| `output/pre-map.rtlil` | `962ff24362be68582e80e568ea699de38334883710671dc442e6e70522b88554` |
| `output/pre-map.json` | `5579a367f2a574426d83b20520e3f83c954ca3d92f72b76fed6283b917a15f26` |
| `output/netlist.json` | `dc3e72c759be861cb999434682e603ffef9f7b14e96cfc902234324009f51fd7` |
| `output/netlist.v` | `7d91c78fcd91f2a7d5eee8631aa73fb91d38185d73d1c3cdf94269a274680f77` |
| `output/yosys.log` | `8142264d96ba85f22bbc014d7d5996e23973956cd6d255adc34c8af3c299e8bf` |
| `output/memory-report.json` | `c0fffdc168596bf9d7aa905d505f29cf6a19caf9da4cb42cb8ff5b917f53223b` |
| `output/tool-versions.txt` | `e97b58b86a15f0cb436978e2b3c7232d0b2d3b8472d7dfbaeebcb938afbf927b` |
| `output/transport-receipt.txt` | `2460bc1e16fe1117ed8cab0beff21d6ed7ae35547b04c822e30d1a1bbd2b7599` |
| `toolchain/yosys/lock.json` | `b068cdf2900f18b15ec6b484971ac6c8c634767f67ad2a42ef009469b1830973` |
| `scripts/phase4-yosys-run.sh` | `82f85a040af591720a52d20ad9c18b8d0828163fb766f1fe3a1fed499144f56a` |
| `scripts/phase4-yosys-inference-check.sh` | `483fc1c920ca46ccbca1e8b502ada478fb03c9ae1f3fb4710dcc1c447d031f2c` |
