# PRX100 complete-layer batched DDR requests — 2026-10-19

Four strided weight-row reads now share one DDR request and source owner. The complete BF16/FP32 Qwen3-0.6B layer runs on the PRX100 with **31.32% lower warm kernel latency** and **2.61% lower warm diagnostic end-to-end latency**. All **656,960 physical FP32 readback words** pass the mathematical CPU reference and are bit-exact to the preceding FPGA profile and the separate operation-contract model. The integer core is unchanged.

This is one complete transformer layer at context four, with prefill and cached decode. It does not establish full-model text generation. The optimized scalar CPU reference remains faster.

## Measurements

Fresh baseline and candidate campaigns ran after native tests, CAD and formal tasks completed, at the same 25 MHz core, 100 MHz DDR UI and 6 MHz CPU_TAG/JTAG clocks, with queues of 16. Both used the same assets, program, host driver, decoder, poisoning, tolerances and full diagnostic/KV readback. There are three warm samples per image in sequential campaigns, not an interleaved statistical study.

| Measurement | Separate row requests | Four-row batches | Speedup |
| --- | ---: | ---: | ---: |
| Four-token warm kernel median | 1.348449 s | 0.926146 s | 1.456× |
| Four-token warm end-to-end median | 8.055206 s | 7.844811 s | 1.027× |
| Four-token cold end-to-end | 266.195312 s | 265.894296 s | 1.001× |
| Three-token prefill kernel | 1.010034 s | 0.693308 s | 1.457× |
| Cached-token decode kernel | 0.338414 s | 0.232839 s | 1.453× |
| Prefill application | 6.908387 s | 6.571839 s | 1.051× |
| Decode application | 2.418149 s | 2.255771 s | 1.072× |

Cold end-to-end improved by 0.301016 s (0.11%). Cold has one sample per image and includes upload/readback variability. This single pair does not establish a general cold-start speedup.

Baseline warm application samples (ms): `[8162.42,8055.206,8043.822]`; candidate: `[7844.811,7858.003,7777.908]`. Every candidate warm sample is faster than every baseline sample: `true`.

Kernel time is the active-cycle counter divided by the qualified nominal clock, including all operators, DDR staging, control and diagnostic stores. Warm application time includes poisoning, launch, polling, counters, every stage/KV readback and CPU checking. Weights reside in DDR and are streamed into the core on every run. Cold additionally uploads and fully rereads all assets and the program. Programming, calibration, Vivado startup and fixture preparation are excluded; the final complete input-integrity reread is recorded separately. Raw counters, launches and timings retain each sample.

## Request batching

The MoonBit generators publish a matched opt-in core/controller/bridge profile through `export-batch`. Each request reads four 128-byte rows separated by the matrix byte stride and returns 32 ordered 128-bit packets. LAST appears only on packet 31. The controller keeps ownership for the whole batch; the loader advances its lane every eight packets and activates a stripe only when all four lanes are full. Dense weight source requests fall **983,040 → 245,760** for the four-token workload, a 75% reduction. These request counts are derived from the unchanged executed descriptor bytes, not a newly instrumented request counter. Native bytes and commands are unchanged.

The bridge retains eight reserved native-return slots per row. It recycles them only after that row's final registered packet is accepted by the response FIFOs, then starts the next strided row without another source request or request-CDC round trip. Four joined response FIFOs retain the preceding checked reservations and coordinated reset. The transfer ceiling remains one 128-bit packet per two core edges, theoretically 200 MB/s at 25 MHz; this is not a native-DDR bandwidth measurement. No larger native return buffer or additional compute lanes are introduced.

The read-data header uses bit 31 to mark four-row mode, low 28 bits for positive 128-byte-aligned stride and zero reserved bits 30:28. The bridge checks the full extent in 30 bits before any native command. Illegal headers/extent return the full faulted shape. Malformed native responses or calibration loss poison further issue, with a faulted suffix and held packet stability. Coordinated reset invalidates every CDC endpoint; a job reset does not independently reset transport. Ordinary word/line requests, host writes and scalar fallback retain their formats. See [the interface contract](../PRX100_QWEN_LAYER_BATCH_DDR.md).

The four BF16/FP32 arithmetic lanes, three-edge multipliers, per-row K order, separate RNE multiply/add, nonlinear approximations and synchronous ReadOld/HoldLast ping-pong memories retain their behavior. All 352 protected production/interface files and all 16 preceding `export-wide` files retain exact identities. Full executions still retire 2,024 non-HALT instructions, 63,078,888 main products and 31,594,560 logical DDR words/acknowledgements. `ddr_beats` counts logical words rather than physical packets or native bandwidth.

## Numerical workload

Checkpoint `Qwen/Qwen3-0.6B`, revision `c1899de289a04d12100db370d81485cdf75e47ca`, layer 0: hidden 1024, intermediate 3072, 16 Q heads, 8 KV heads, head dimension 128, RMS epsilon 1e-6 and RoPE theta 1000000. Tokens 42/100/1000 form causal prefill; token 42 at position 3 exercises cached decode. Tested context is four and KV capacity eight. All 27 assets (31,485,952 bytes), three programs and 80 CPU stage references are unchanged. The full program has 2,025 descriptors including HALT.

The FPGA executes input RMSNorm, Q/K/V projections, head RMSNorm, RoPE, causal grouped-query attention, stable softmax, output projection plus residual, post-attention RMSNorm, gate/up projections, SiLU gating, down projection and final residual. The host provides weights, embeddings, static RoPE coefficients and descriptors; it supplies no runtime layer intermediates.

Each image runs six launches: cold, three warm full runs, prefill-only and cached decode, totaling 20 token-layer executions. Every one of 400 stage tensors and 40 KV arrays passes the unchanged mathematical CPU tolerance `1e-4 + 1e-4*abs(reference)`. All 656,960 words are additionally bit-exact across profiles and to the operation model. Maximum mathematical CPU absolute error: `0.000030517578125`; maximum across 20,480 final-hidden words: `0.00000286102294921875`. The five-word smoke, six expected SLVERR responses, all programs and all input assets before/after also pass. Group completion status is not an individual per-member AXI status record; all actual payload bytes are checked.

## Qualification

Vivado 2025.2 targets `xc7a100tfgg676-2`. Accepted build: `/work/builds/prx100-layer-vivado-20261019-batch-phys-a2`. Bitstream SHA256: `5e33d7b091fb0e8fb985e1409c9dcfd0402be0a84a1c568c7a3ffb3ee748fe22`. Setup slack **0.014 ns**, hold **0.059 ns**, zero failing setup/hold/pulsewidth endpoints, and no DRC Error/Critical Warning. The clock check covers 1871 core FF pins and the routed 25 MHz debug hub supports 6 MHz JTAG. Resources: 22677 LUTs, 11080 FFs, 86.5 BRAM tiles, 27 DSPs. Programming is volatile; flash and host OS are unchanged.

Strict native info/fmt/check/test gates pass 1257 tests, including 32 targeted tests. Independent replay uses the exact production core and bridge; the bridge checks all 12477 atomic events without masks. The core replay checks 104,711 cycles and 2,408,353 defined output words. Only invalid raw uninitialized program/scratch DATA may be masked, with every defined output checked. Pinned Yosys 0.68 synthesizes all three modules and reports zero combinational SCCs in the complete generated digital composition.

Fresh Bitwuzla bounded tasks pass core 48 clock edges, controller 32 edges and bridge 128 global steps. The bridge uses fixed 4:1 clocks and eight-step coordinated boot; other inputs are free. Its 51 assertions include 16 joined FIFO reservation/transfer/pointer checks and two batch-recycle checks. Observation-only views are reversible and production identities are exact. Core reset-wire, controller write-wire and bridge calibration-wire sensitivity tasks produce complete expected-failure traces. These prefix results are not unbounded liveness, full-layer arithmetic or analog CDC proofs.

The initial route failed setup by 0.161 ns; a first physical-only optimization improved it to a 0.093 ns miss but remained rejected. The accepted routing uses Vivado 2025.2's documented `route_design -directive AggressiveExplore`, followed by physical optimization and hold fixing. It retains the same RTL, clocks and XDC. Both rejected attempts, their reports and exact source-checkpoint hashes are retained. No failing image was programmed and no timing or DRC limit was waived.

## CPU and retention

Fresh scalar MoonBit native release CPU median: **90 ms** for four tokens. FPGA kernel time is 10.29× this CPU compute interval; diagnostic application time is 87.16× it across different boundaries. CPU runs use one traced warmup and three untraced samples, an epoch-millisecond timer, and exclude file I/O/model decoding; this is not BLAS. All 108 release/debug/prior binary fixtures are identical. CPU: i7-13700, Ubuntu 22.04.5 KVM, 8 vCPUs/40 GiB; pinned Moon 0.1.20261012, moonc 0.10.15+943464bfa and GCC 11.4.0.

All 16 hardware exports reproduce byte-for-byte on the actual Linux executable after full phase gates. All 1411 actual first-party inputs reproduce from the exact frozen source tar using the pinned formatter and the documented Linux allocation-probe C-manifest override. The original inputs and actual formatted source are retained.

Reproduce from the retained source/inputs with `export-batch`, `scripts/prx100-layer-build.mbtx` and the pinned MIG root. This measured build additionally needed `scripts/prx100-layer-batch-route.mbtx` on the rejected initial checkpoint, then `scripts/prx100-layer-batch-route-aggressive.mbtx` on the rejected first repair. Both helpers pin the exported inventory and core source, retain source-checkpoint hash guards, and accept only strict timing/DRC closure. Use fresh output roots and apply recovery only to a failed routed checkpoint; stop when a qualified build passes. Then use the unchanged `prx100-layer-board.mbtx` with the matching qualification receipt. `prx100-layer-batch-audit.mbtx` checks full raw numerical identities and matched conditions before accepting kernel and warm end-to-end improvements; an identical-campaign negative control rejects zero gain.

The immutable closed-inventory archive `artifacts/prx100-layer-batch-20261019` is mirrored to `/work/builds/prx100-layer-batch-full-20261019-a1/prx100-layer-batch-20261019`. It retains unique source/IR/RTL, raw readbacks, CPU references, formal models/traces, tool identities, reports and unsuccessful attempts. Baseline CAD and operation-model evidence are inherited by exact source identities and sealed references. Compiler/Verilator caches and regenerable CAD projects/checkpoints remain outside archives. No task data is deleted. Host status preserves all historical fields and the previous configuration, with a task-scoped unchanged-integer flag.
