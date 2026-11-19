# Qwen3-0.6B on PRX100-D: feasibility, updated2026-10-17

Standalone DDR now passes complete256MiB testing after three calibration
cycles, with median1354.957MB/s write ingress and1037.835MB/s read/verify.
See the [memory qualification](evidence/prx100-ddr-memory-20261016.md) for
scope. The [DDR-to-core projection](evidence/prx100-ddr-projection-20261016.md)
now also passes20 physical jobs through BRAM staging, target-side sequencing
and INT32 accumulation, with the portable core unchanged. Full K1024 job time
is median2.36871ms versus177us for the scalar integer CPU reference. A faster
bulk host path and better core/DDR movement remain necessary. The subsequent
[target cache/staging optimization](evidence/prx100-ddr-optimization-20261016.md)
passes the same20 jobs in median1.76730ms,25.39% lower, with the portable core
unchanged; its scalar reference takes183us and that image is9.66 times slower.
The [loading pipeline](evidence/prx100-core-loading-20261016.md) passes
20 jobs at1.37524ms,another22.18% lower, with the same core/clocks. Its refreshed
scalar CPU reference is182us, so the full FPGA interval is still7.56 times
slower. The latest [descriptor publication pipeline](evidence/prx100-publication-20261017.md)
passes the same20 jobs at1.12750ms,another18.01% lower, with original
core/bridge/clocks and bit-exact CPU results. Fresh scalar CPU176us leaves the
FPGA6.41 times slower. The later
[byte-memory port isolation](evidence/prx100-byte-20261017.md) passes fresh
20-job baseline/new-image campaigns at1.12747→1.12710ms, only0.033% lower.
It removes collection-port blocking but leaves the serialized portable byte
protocol unchanged. Fresh scalar CPU184us leaves the FPGA6.13 times slower.
This remains one eight-output block.

The [portable word-read extension](evidence/prx100-word-20261017.md) passes
fresh20-job campaigns on both images against the CPU reference. Target1.3→1.4
median FPGA latency falls1.12710→0.53526ms,52.51% lower (2.11× faster), with
280→76 core requests per tile. Scalar CPU183µs remains2.93 times faster.
DDR staging and bulk host transfers remain performance work; this result
does not establish full-model execution or token generation.

The subsequent [DDR line-staging revision](evidence/prx100-staging-20261017.md)
keeps that exact core and passes another fresh20-job campaign per image.
Target1.4→1.5 FPGA median falls0.53596→0.48102ms,10.25% lower (1.11× faster),
with staging activity27.21% lower and36→9 front-end read requests per tile.
Native DDR bytes remain unchanged. Scalar CPU183µs is still2.63 times faster,
and the host workload remains about97s because JTAG dominates. Core loading,
serialized result writes, bulk transfers and a complete host inference loop
remain necessary work before useful model-level acceleration can be claimed.

The requested model is confirmed as **Qwen/Qwen3-0.6B**. No official
Qwen3.8-0.6B artifact was verified. This combines capacity estimates with
measured physical INT8 tiles and a real quantized Qwen projection block.
It is not full-model execution or general quantization-quality qualification.

## Capacity

The [official configuration](https://huggingface.co/Qwen/Qwen3-0.6B/blob/c1899de289a04d12100db370d81485cdf75e47ca/config.json)
has hidden size 1024, intermediate size 3072, 28 layers, 16 query heads,
8 KV heads, head dimension 128 and tied vocabulary of 151936 embeddings.
Counting its projection, embedding and normalization tensors gives 596049920
parameters. The [model card](https://huggingface.co/Qwen/Qwen3-0.6B)
rounds this to 0.6B, with 0.44B non-embedding parameters.

The count, including tied output embeddings and Q/K normalization, is:

```text
151936*1024
+ 28*(1024*2048 + 2*1024*1024 + 2048*1024 + 3*1024*3072
      + 2*1024 + 2*128)
+ 1024 = 596049920
```

The retained configuration is pinned to model commit
`c1899de289a04d12100db370d81485cdf75e47ca`, file SHA256
`660db3b73d788119c04535e48cf9be5f55bc3100841a718637ae695b442f27dd`.

| Representation | Raw weights only | Fits board's 256MiB DDR3? |
| --- | --- | --- |
| BF16 / FP16 | 1136.88MiB | No |
| INT8 | 568.44MiB | No |
| Packed4-bit | 284.22MiB | No |
| Packed3-bit | 213.16MiB | Weights alone; research candidate |
| Packed2-bit | 142.11MiB | Weights alone; research candidate |

These are ideal packed tensor sizes, excluding scales, zero points, alignment,
unquantized tensors, activations, workspace and KV cache. They are not GGUF
file-size predictions. At FP16, KV storage is
`2 * 28 * 8 * 128 * 2 = 114688 bytes/token` (112KiB/token):
512 tokens need56MiB; 2048 need224MiB. INT8 KV halves these ideal sizes,
before scale/metadata costs. Aggressive weight/KV quantization needs its own
accuracy and implementation validation; fitting packed weights is insufficient.

The board guide specifies 128Meg x16 DDR3 (256MiB), and the schematic names
MT41J128M16HA-125 and XC7A100T-2FGG676I. These local source documents are
`~/Downloads/PRX100/PRX100-D开发板硬件参考指南.pdf` and
`~/Downloads/PRX100/PRX100_DDR原理图.pdf`. Artix-7 100T has4860Kibit
(607.5KiB) block RAM and240 DSP slices
([AMD device table](https://www.amd.com/en/products/adaptive-socs-and-fpgas/fpga/artix-7.html)).
Neither full-model weights nor a useful full-model KV cache fit BRAM. Initial target
host memory is only4KiB. The separate DDR target now stages through that same
4KiB contract while keeping weights and activations in external DDR3.

## Compute and transport

FluxTile currently implements INT8 x INT8 -> INT32 matrix tiles. Full inference
also needs quantization/scaling, RMSNorm and Q/K normalization, RoPE, attention
and softmax, SiLU/gating, residuals, KV management and model scheduling.
The K16 portable core requires accumulation outside its result operation for
long reductions; the ABI does not accumulate into an existing result. The new
target sequencer performs bounded K1024 INT32 accumulation in FPGA registers.
Model/runtime work belongs outside LunaChip core, with an eventual LunaFlux
adapter. No model-serving dependency is introduced by the board target.

At50MHz,64 hypothetically fully utilized MAC sites give3.2GMAC/s. Dividing
roughly 596M projection MACs/token by this rate gives about 0.186s/token
(5.37token/s), **an ideal arithmetic upper bound, not a throughput prediction**, excluding
attention, loads, captures and all other work. Batch-one decode has one matrix
row; without a changed schedule, an8-row array cannot use all64 sites.
At most8 columns active would reduce that arithmetic-only bound to about
0.67token/s. These ideal limits omit the actual K16 tiling and transport cost.
The [actual Vivado build](evidence/prx100-vivado-build-20261015.md) now passes
routed50MHz timing, and the [broader physical tests](evidence/prx100-broad-matrix-20261016.md)
measure31 compute-counter cycles for a full8x8/K16 tile (620ns at nominal50MHz),
plus64 active capture cycles. The counter window excludes capture/DMA/UART;
it is not full command latency or model performance.

115200baud8N1 transports at most11520 payload bytes/s before framing.
Streaming a complete raw4-bit weight set once takes about7.19hours; INT8
about14.37hours. Autoregressive layer streaming repeats weight traffic per
token unless weights remain resident. UART is unsuitable for this path.
DDR3 integration alone would not remove the current one-outstanding,
byte-read device-interface bottleneck. No DDR bandwidth estimate is claimed.

The current UART protocol carries only four useful Write32 bytes in each
16-byte request /32-byte reply exchange. Even an ideal stream of such writes
is limited to960 useful bytes/s, before USB/OS gaps. Sending596049920 INT8
weight bytes that way has a172.47-hour wire-time floor. This is a transport
lower-bound calculation, not an inference benchmark. A faster bulk interface
and resident/reused weights are essential for useful model performance.

## Measured stepping stone and path to a model

The physical [2026-10-16 campaign](evidence/prx100-broad-matrix-20261016.md)
passes40 matrix cases, including20 repeated full tiles, plus a synthetic
1x1024 by1024x8 projection composed from64 K16 FPGA tiles. All512 partial
results and eight host-accumulated outputs match a direct full-width reference.
The complete projection takes76.591s in the verification harness, including
31.888s of UART round trips. These are synthetic INT8 operands, not Qwen
weights or a quantization-quality result. No model tokens have been generated.

That model-facing milestone now passes: the
[real Qwen projection](evidence/prx100-qwen-projection-20261016.md) uses pinned
layer0 query weights, channels0..7 with full K1024, and three real token
embeddings normalized with the checkpoint's input RMSNorm weights. Symmetric
W8A8 uses per-channel weight and per-vector activation scales. All1536 FPGA
partials and24 final integer outputs match exactly; dequantized outputs match
the CPU quantized reference within1e-9. Relative L2 errors against the original
FP64 projection are2.63487%,0.92330% and1.69166% over those eight channels.
These are three-input block characterizations, not full-model quality results.

The board harness takes74.914–77.739s per projection, including31.670–31.764s
of UART round trips. The same Linux guest's scalar MoonBit/Wasm references
take median182us (integer) and179us (FP64), measured over1000-iteration batches.
No end-to-end acceleration is demonstrated by that UART run. Its long-reduction
accumulation, normalization and scaling run on the host; the portable core is unchanged.
Model loading and execution still belong in an external adapter, outside
LunaChip. The later DDR target moves sequencing and INT32 accumulation into
the FPGA. Its18 full jobs take2.36706–2.36940ms, with all original partials and
repeated final sums checked. DDR wait is median1.06819ms and core loading/control
1.22880ms; compute counters sum to30.72us. The complete path remains13.4 times
slower than the177us scalar integer reference. JTAG uploads11264 bytes in17.327s
and verifies them in20.171s, so it remains a diagnostic loader.

The optimized target reduces DDR wait to0.49702ms and descriptor staging by
30.24us, while core service stays1.22880ms. Its median complete FPGA time is
1.76730ms; all1560 partial checks and160 final sums pass across20 jobs. JTAG
resident launch through observed DONE is15ms and the full diagnostic campaign
98.235s. The transfer/control measurements still preclude a host acceleration
claim, and full-model execution remains unimplemented.

The next target revision overlaps BRAM staging with core service and removes
partial-write control bubbles. Its20 jobs and the same1560 partial/160 final
checks pass at median1.37524ms. Inferred DDR/core overlap is0.38674ms; the
core counter remains1.22880ms. Fresh scalar CPU time is182us and host JTAG
launch/observation15ms. The target1.1 phase counters overlap and must not be
added. The remaining core byte-memory service and bulk host path still limit
larger blocks; no full-model acceleration is demonstrated.

After that, run a short-context host inference loop with selected linear
operations offloaded to the FPGA and normalization, attention, activations,
residuals, KV and sampling on the host. First establish numerical agreement
and actual generated tokens; then measure whether offloading helps. UART can
support a slow correctness experiment, but these measurements give no reason
to expect acceleration through the present transport.

Standalone board inference is a separate milestone: integrate/test DDR3 and
bulk transfers, choose a weight/KV representation that fits the actual256MiB
budget with workspace, and add a suitable quantized data path and runtime.
Ideal4-bit weights alone still exceed DDR capacity. A smaller language model
could reduce that memory burden, but it would still need the missing operators,
runtime and data path; matrix correctness alone does not make a language model.

## Decision

The [2026-10-16 DDR3 and data-path investigation](PRX100_DDR_DATA_PATH.md)
now identifies the existing RTL8211E Gigabit Ethernet PHY as the bulk host
path and CPU_TAG JTAG-to-AXI as an interim diagnostic path. Vivado confirms
package pins and available MIG/clock/debug IP; TEMAC reports Design_Linking.
DDR3 clock/pin qualification, calibration and a target-only sequencer/BRAM path
now pass the linked physical gates. MAC licensing/implementation and actual
bulk throughput remain open. The new measurements show both serialized DDR
words and the byte-oriented core load/control path still limit job latency.

Full standalone Qwen3-0.6B inference is **not a practical deliverable for the
UART/BRAM target**. A host-assisted, numerically checked quantized matrix-tile
experiment is feasible after board bring-up, without promising acceleration.
A future standalone experiment would require DDR3, a viable sub4-bit model,
short/quantized KV, new numerical datapaths and a much better memory interface.
That is a separately scoped architecture project, not an extension hidden in
the first PRX100 shell. UART/BRAM mapping, matrix edge cases, repetition and a
synthetic K1024 projection and first real quantized Qwen projection now pass.
Expand numerically checked model integration and improve weight/data movement
before expecting useful host-assisted inference performance.

## DDR result-write continuation — target1.6

The [batched DDR result writes](evidence/prx100-results-20261017.md) pass a fresh20-job campaign per image: **0.48054→0.45618ms median**, **5.07% lower** (1.053×). All40 jobs match the signed CPU reference; writes fall520→130 per full block, with the same portable core and clocks. The scalar CPU is183µs; the new FPGA remains2.49 times slower. Host/JTAG transfers remain dominant; full-model inference remains separate work.

## DDR streaming continuation — target1.7

The [DDR streaming and descriptor staging continuation](evidence/prx100-stream-20261017.md) passes40 fresh A/B jobs: **0.45630→0.41775ms median**, **8.45% lower** (1.092×), with the exact portable core and clocks. Front-end reads fall576→128/full block; native traffic is unchanged. Scalar CPU183µs remains faster; host/JTAG and full-model integration remain open.

## Floating-point board continuation — 2026-10-17

A separate [MoonBit BF16 / FP32 scalar engine](evidence/prx100-fp-20261017.md) now passes55 physical board jobs, including all24 selected Qwen outputs and their repeats, CPU-exact at25MHz. It uses1 DSP and2006 LUTs for the complete target. Maximum absolute error over the24 outputs is0.0004582244441 versus the pinned original FP64 block, compared with0.004989698 for the prior INT8 fixture. This establishes floating-point compute feasibility and improved precision for that block; it does not run the full model. The eight-channel engine-activity sum is1.31072ms versus68µs scalar CPU FP32. Full BF16 weights still exceed256MiB DDR, so weight streaming and model integration remain necessary.

The [FP1.1 pipeline](evidence/prx100-fpp-20261017.md) adds eight lanes at 50 MHz. A fresh physical comparison reduces the same eight-output block's engine time from 1310.72 to 102.48 µs, a 12.79× improvement, while preserving every FP32 reference bit. All 320 outputs from 40 jobs pass, including 18 full projections and numerical edge cases. The complete target uses 8589 LUTs and 8 DSPs; the integer core is unchanged. Scalar CPU FP32 remains faster at 68 µs. JTAG needs about 46 seconds to upload each 32 KiB operand image, so bulk transfers, DDR staging and weight reuse remain essential before larger model work. The BF16 model memory requirement and remaining Qwen operators are unchanged.
