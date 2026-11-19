# Real Qwen3-0.6B projection on PRX100, 2026-10-16

The physical PRX100 passes a real W8A8 query-projection block from
Qwen/Qwen3-0.6B. Channels0..7 of layer0 `self_attn.q_proj.weight` use their full
1024-input reduction on three normalized real token embeddings. All1536 FPGA
partial results and24 final host sums match the CPU INT32 reference exactly.
Dequantized results agree with a separately evaluated CPU quantized dot product
within1e-9. All18,819 UART exchanges pass framing/CRC/correlation/status/payload
checks, all768 ordered completions are fault-free, and guards remain unchanged.
The portable core and existing Array8 bitstream are unchanged.

This is an eight-channel slice of the2048-output projection, before query-head
normalization and RoPE. It does not execute the full projection, attention,
transformer layer, language model or token generation.

## Exact model data and input preparation

The source is the official [Qwen checkpoint at immutable revision
c1899de289a04d12100db370d81485cdf75e47ca](https://huggingface.co/Qwen/Qwen3-0.6B/tree/c1899de289a04d12100db370d81485cdf75e47ca).
The retrieved tensors are BF16, decoded little-endian. Their byte ranges are
derived from the retained safetensors header, whose SHA256 is
`399d16f500e925c7e923fe05966c6df6862ab64da60916843119e802f1801bca`.

| Source tensor / selection | File byte start | Bytes | SHA256 |
| --- | ---: | ---: | --- |
| layer0 q_proj, output rows0..7, shape8x1024 | 647535848 | 16384 | `cb9d24b0df44d72c143c9296593a6c6f63c62b7fb7e29cd31bb5794c8571735f` |
| layer0 input_layernorm,1024 weights | 622365416 | 2048 | `8d634da920e8c6b12832fa35034be83946b401d335a5ffdb67fca0291ddc71fa` |
| embedding token42 | 311286504 | 2048 | `2dfad801d9bd371861b3a1a08fd8b7de7e44388d1f74505d702c13d9d6fafb03` |
| embedding token100 | 311405288 | 2048 | `3a99a53eb0f8875dec44c6a2318cc01b02881d891693e746fe9928a92bd31097` |
| embedding token1000 | 313248488 | 2048 | `ef863079cf021df4c0e26950ec3467ca9b6ebdf2b26fbf48ac86d30bed6bb13a` |

Every range request checks its exact Content-Range, returned length and the
revision's linked LFS identity. The upstream full file is1,503,300,328 bytes,
LFS SHA256 `f47f71177f32bcd101b7573ec9171e6a57f4f4d31148d38e382306f42996874b`.
Only the header and selected tensor ranges were downloaded; that full-object
digest is an upstream identity, not a locally verified full-file checksum.
Local hashes above cover every retrieved tensor byte. API metadata, header,
selected response identity headers, config and Apache2 license are retained.
Raw redirect headers with ephemeral anonymous signed URLs remain in the
working download directory and are excluded from the archive.

Inputs are checkpoint embedding rows42,100 and1000, identified by numeric
token IDs rather than an asserted prompt text. For each embedding e and real
layer0 normalization weight g, the host computes
`x[k] = e[k] * g[k] / sqrt(mean(e*e) + 1e-6)`.
The epsilon comes from the [pinned config](https://huggingface.co/Qwen/Qwen3-0.6B/blob/c1899de289a04d12100db370d81485cdf75e47ca/config.json).
This follows the input RMSNorm/projection structure in the
[Transformers Qwen3 implementation](https://github.com/huggingface/transformers/blob/v4.51.3/src/transformers/models/qwen3/modeling_qwen3.py).
Here RMSNorm and the floating-point reference use FP64 host arithmetic on
decoded BF16 values. They do not emulate PyTorch's intermediate FP32/BF16
rounding, and this is not a full-framework numerical-parity claim.

## Quantization and CPU comparisons

Quantization is a defined experiment, rather than a published quantized model:
one symmetric scale per output weight channel and one per input vector,
zero points0, integer codes−127..127. For a nonzero vector,
`scale=max(abs(values))/127`, and
`q=sign(value)*min(127,floor(abs(value)/scale+0.5))`.
Zero vectors use scale1. Tie rounding is away from zero. The selftest checks
BF16 decoding, zeros, signed half ties and extrema.

The FPGA receives INT8 x and the transposed INT8 weight tile B[k,j]=W[j,k].
Sixty-four1x16 by16x8 products compose each1024-term projection. Host INT32
accumulation combines the64 partials; each final channel is dequantized as
`integer_sum * activation_scale * weight_scale[channel]`.
All scales, integer codes, source floating values and normalization inputs are
retained in the pinned fixture:
SHA256 `409ca5210ca8a10a2799f66590ab0ccee51f1cc501d8dc738a1334a71dfe225e`.

Three comparisons are kept separate:

- Every FPGA partial and full accumulated result equals an ordinary CPU
  integer dot product exactly.
- FPGA sums dequantized on the host agree within1e-9 with a CPU dot product
  of individually dequantized input/weight values. The residual is floating
  summation order, not FPGA arithmetic error.
- Comparison with the original decoded-weight FP64 projection characterizes
  this experiment's W8A8 quantization error:

| Token ID | Exact INT32 output, channels0..7 | Max absolute quantization error | Relative L2 error |
| --- | --- | ---: | ---: |
| 42 | [8756,13785,-12344,6958,8277,24542,6348,17217] | 0.00281449 | 2.63487% |
| 100 | [33633,20707,-26431,-35708,-30498,38848,26458,-10697] | 0.00424659 | 0.92330% |
| 1000 | [26671,31770,27315,-25737,5502,23851,-4307,-3116] | 0.00498970 | 1.69166% |

Relative L2 is `norm(dequantized-original)/norm(original)` over these eight
outputs. These three inputs and eight channels do not establish perplexity,
generation quality or general model quantization accuracy.

## Measured performance

The same Ubuntu22.04 guest,8vCPUs and persistent CP2102 UART session are used.
The scalar CPU reference benchmark runs in MoonBit/moonrun Wasm on that guest:
five samples of1000 complete eight-channel K1024 projections each, with a
retained checksum. Integer batch times are183,182,182,184,182ms; FP64 batch
times179,179,181,179,180ms. Thus median per-projection times are182us for the
integer reference and179us for FP64 (means182.6us and179.6us). This is not
optimized BLAS, native SIMD, a production runtime or a token benchmark.

| Input | FPGA harness wall time | Sum of UART round trips | Compute-counter windows summed |
| --- | ---: | ---: | ---: |
| token42 | 74.914s | 31.670s | 30.72us |
| token100 | 77.739s | 31.764s | 30.72us |
| token1000 | 76.287s | 31.704s | 30.72us |
| Whole three-input campaign | 229.224s | 95.157s including setup | 92.16us |

Each input performs8192 MACs through64 tiles. A tile's existing counter is24
compute cycles (480ns at nominal50MHz), followed by8 active capture cycles;
capture counters sum to512 cycles/10.24us per projection. Compute windows
exclude captures, descriptor fetch, operand DMA, result stores and UART. They
are not complete accelerator latency and must not be used as an inference
speedup claim. No external frequency or power measurement was performed.

UART timings use1ms epoch timestamps around request write / exact32-byte reply
read, including bridge/USB/OS scheduling. Harness wall times additionally
include per-tile fixture/descriptor/transcript I/O, checks and host sums;
download, normalization, quantization and CPU benchmark preparation are outside
the board campaign interval. The whole-suite interval also includes small
per-vector bookkeeping, and excludes setup and final serial shutdown.

Each later projection uses6272 framed exchanges; the first adds Configure.
At16 request +32 response bytes,115200baud8N1,6272 exchanges alone require
at least26.133s of wire time. The observed31.7s UART intervals are consistent
with transport dominating. The present end-to-end FPGA path is much slower
than the scalar CPU reference for this block. No acceleration is demonstrated.

## Hardware checks, reproduction and evidence

One initial Reset/Configure is followed by192 batches with monotonically
advancing producer counts and alternating slots; no between-tile reset.
Each batch has LoadA16 bytes, LoadB128 bytes, MatMul and StoreC32 bytes,
complete descriptor upload, result sentinels and adjacent guards. Early reads
must be busy; all four ordered completion IDs/byte counts are checked. Every
result is read back, counters match, all Diagnostics words are zero, and
Completion is empty after draining. Final producer/consumer/retired are768;
the board is left configured and quiescent. No transaction required a retry.

The existing [Array8 image/programming evidence](prx100-array8-matrix-20261016.md)
is reused. Bitstream SHA256 before/after the campaign:
`3e575862fa4520ddbd23fab02e516d46560584715db1b6667152b4bbbc66f55b`.
No new RTL, synthesis, programming, package, USB mapping or OS change was made.
Source acquisition, quantization/reference generation and UART execution are
MoonBit scripts in `scripts/prx100-qwen-source.mbtx`,
`scripts/prx100-qwen-quantize.mbtx` and `scripts/prx100-qwen-projection.mbtx`.
The acquisition script expects the pinned revision's API JSON and initial
eight safetensors bytes; exact input URLs and response identities are retained.
Inside the existing guest with its baseline Moon toolchain:

```text
moon run /work/prx100-qwen-projection.mbtx -- run /work/builds/prx100-qwen-projection-NEW
```

It requires the pinned fixture at `/work/prx100-qwen-fixture-20261016/fixture.json`
and a fresh output root. The actual root is
`/work/builds/prx100-qwen-projection-20261016-a1`.

The archive `artifacts/prx100-qwen-projection-20261016` retains raw model
ranges and metadata, exact source/quantizer/as-run driver, complete fixtures,
192 sets of raw UART request/reply transcripts and metadata, serial log,
CPU benchmark, partial/final references and results, source/tool identities,
validation logs and an independent offline audit. The audit decodes BF16
arithmetically, reconstructs RMSNorm/codes/scales, checks original model-byte
hashes, verifies frame CRC/correlation and result addresses, and recomputes all
24 final integer/dequantized outputs. Inventories and retained copies are
verified before sealing; caches and earlier archives are not copied. Originals
and all existing sealed archives/recovery volumes are preserved.

Strict native checking, interface generation, formatting and warning-strict
standalone script checks pass. All207 captured production source/interface
identities remain unchanged. The full native suite passes1,094/1,094 with zero
failures; its complete log is retained with the final campaign evidence.
No portable construction, IR, simulator or
emitter semantics were modified.
