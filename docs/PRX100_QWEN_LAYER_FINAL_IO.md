# PRX100 BF16/FP32 layer final readback and CPU checking

This host and target-program change retains the qualified sixteen-lane
streaming-DDR image, arithmetic cores, clocks, weights and KV layout. It targets
the work between completion and delivery of the verified final hidden states.
The integer core remains unchanged.

`scripts/prx100-layer-final-check.mbtx` implements a persistent MoonBit checker
over a bounded request/reply protocol. At startup it pins the original CPU
fixture manifest and the hashes of all four final reference tensors, rejects
nonfinite reference values, and decodes those references once. Each timed
request still reads the actual returned file, checks all 1,024 finite FP32
values against `1e-4 + 1e-4 * abs(reference)`, computes exact-bit and error
summaries, and hashes the actual bytes. Request identity, file names, reference
identity, count, ordering and shutdown are checked. Actual data and actual
comparisons are never reused from an earlier sample.

`scripts/prx100-layer-final-io.mbtx` emits the vendor Tcl backend from the
digest-pinned 2 ms polling implementation. It creates immutable read transaction
objects for the full, prefill and decode output shapes once, then reuses them
without changing their addresses or lengths. Each launch still performs fresh
queued JTAG AXI reads, checks the response, fetches DATA, writes every output
word, and completes every CPU check inside its resident interval. Busy reads,
unknown shapes, duplicate files and overwriting an unchecked output are errors.
Diagnostic transfers retain the qualified original path.

The first physical experiment retained the original output addresses. It
reduced CPU-check cost, but did not reliably improve full-layer readback. A
profile attributed most readback time to `run_hw_axi`; fetching DATA properties
cost only about 0.3 ms. The final buffers crossed 4 KiB boundaries, requiring 19
bursts and two queued batches for the four-token final results.

`scripts/prx100-layer-final-align.mbtx` pins the original fixture and three
program binaries. It moves only the final output STORE destinations to four
distinct 4 KiB pages at relative DDR offsets `0x05000000`–`0x05003000`, and updates
the corresponding trace metadata. Exactly eight descriptor address words
change across full, prefill and decode programs; all other bytes remain equal.
All original DDR operands, assets and traces lie below the new output region.
Scratch and KV addresses do not move. The aligned outputs require 16, 12 and 4
bursts for full, prefill and decode, each fitting one 16-entry batch.

`scripts/prx100-layer-final-aligned-io.mbtx` applies the trace relocation before
preparing transaction plans. The CPU checker continues to use the original
CPU-reference manifest. The resident runner accepts `2 prepared` for the first
experiment and `2 aligned` for the aligned layout. The campaign itself is
identical to the 2 ms baseline: five four-token full-layer runs, one three-token
prefill and five position-3 cached decode runs, with KV retained on the board.

The resident audit reconstructs the exact emitted host backend and, for the
aligned profile, regenerates and byte-compares the complete permitted layout
transformation. A fresh execution of the relocated program in the unchanged
MoonBit operation model must retain every stage result. Physical program
readbacks, all final and diagnostic tensors, KV, status, counters and every
transaction are independently checked. The paired audit independently checks
the relocated descriptor fields, prepared plans and checker summaries, and
requires equal arithmetic payloads and lower resident latency.

Checker startup, reference preparation and transaction construction are a
separate setup cost. Resident measurements include actual transfers and CPU
comparisons but exclude that setup, initial weight upload, program installation,
input integrity checks and full intermediate/KV diagnostic snapshots. They
describe one fixed Qwen3-0.6B layer with context four and KV capacity eight;
they do not describe full-model inference or cold-start generation.

## Physical measurement, 2026-10-20 Asia/Shanghai (2026-10-19 UTC)

| Median resident latency | Fresh 2 ms baseline | Aligned readback + MoonBit checker |
|---|---:|---:|
| Four-token complete layer | 781.0 ms | 715.8 ms |
| Cached position-3 decode | 220.6 ms | 198.9 ms |
| Four-token final readback | 54.5 ms | 42.0 ms |
| Cached decode final readback | 18.3 ms | 14.5 ms |
| Four-token CPU checking | 57.0 ms | 5.3 ms |
| Cached decode CPU checking | 16.9 ms | 1.0 ms |

Complete-layer resident latency falls **8.3%**, and cached decode **9.8%**. All five observations per workload/profile are retained. Campaigns run sequentially: baseline, prepared unaligned experiment, native/CPU validation, then aligned candidate. Kernel time remains effectively unchanged; the paired audit requires its medians within 1%. Most remaining resident latency is FPGA computation.

All **845,696 FP32 words** across the final paired campaigns pass CPU tolerance and match the ordered operation model bit for bit. All 346 cross-profile tensor/input payload files are identical. Across the baseline, prepared unaligned experiment and final aligned campaign, 1,268,544 words were checked. Maximum stage/final CPU absolute errors are 0.000030517578125 / 0.00000286102294921875. Fresh native CPU release execution reproduces all 108 fixture binaries.

Additional checker/reference/plan preparation costs **793.9 ms** once per session, outside resident samples. At these median savings, that cost amortizes after approximately **13 full-layer runs** or **37 cached decodes**. Short sessions can therefore be slower overall. Weight upload and full diagnostics are additional separately recorded costs.

All 1,264 strict native debug tests pass. The optional release-suite attempt exposed incompatible C result types generated by the pinned compiler in the unchanged `ir` and `validation/differential` test packages; its complete failure logs are retained. No source workaround was made. Fresh CPU reference and relocated operation-model executions use native release builds separately. Both transfer mocks retain all 12,288 words and five corrupted-output cases; the checker protocol has 13 targeted cases, and the layout regression independently proves the exact eight-word relocation, deterministic replay and three rejections. The updated audit reproduces the previous sealed campaign's audit byte for byte. All 1,419 module inputs, including 199 protected integer inputs, remain unchanged. No hardware rebuild or new RTL qualification is claimed.

Reproduce using `scripts/prx100-layer-resident-board.mbtx` with final arguments `2 aligned`, the retained qualification, original template and matching reviewed scripts. Audit using `scripts/prx100-layer-resident-audit.mbtx` with the relocated operation model and the executed frozen driver, then `scripts/prx100-layer-final-audit.mbtx` for the paired comparison. The prepared unaligned experiment and the failed vendor-mock, board-runner preflight and native-suite attempts retain their logs in the evidence.

Evidence: [benchmark](../artifacts/prx100-layer-finalio-20261019/benchmark.json), [raw campaigns, tests and audits](../artifacts/prx100-layer-finalio-20261019/work).

## Follow-up comparison and reporting provenance

The first prepared, unaligned experiment measured 726.2 ms/full and 197.2 ms/cached decode. The aligned profile measures 715.8 and 198.9 ms: full-layer latency is a further 1.4% lower, while cached-decode wall time is 0.9% higher (1.8 ms), despite its readback median falling from 14.8 to 14.5 ms. Five sequential observations per workload are retained; launch/poll variability limits this small incremental comparison. Both final workloads improve against the fresh original baseline shown above.

A post-publication reporting draft was copied into the base archive's recorded-drivers directory during packaging. It did not produce the published benchmark. The base archive remains immutable. The [reporting amendment](../artifacts/prx100-layer-finalio-amendment-20261020/receipt.json) retains the reconstructed executed source, the later draft and an isolated replay that reproduces the benchmark, contract, status and publication receipt byte for byte. Physical data and numerical-audit sources are unaffected.
