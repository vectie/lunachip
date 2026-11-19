# PRX100 complete-layer JTAG transfer and readback — 2026-10-19

The same complete BF16/FP32 Qwen3-0.6B layer now has **16.87% lower warm diagnostic end-to-end latency** and **32.58% lower observed cold latency**. Warm full result/KV readback plus CPU checking improves **17.98%**. The changes are a bounded reusable transaction pool, direct binary conversion and a qualified 6→10 MHz JTAG cable setting. Integer and BF16/FP32 hardware remain unchanged.

All **1,970,880 FP32 words** from three successful physical profiles pass the mathematical CPU reference; all 656,960 words per profile are bit-exact across profiles and to the separate operation model. This is one complete layer at context four, not full-model text generation. The optimized CPU remains faster.

## Fresh measurements

The three campaigns ran sequentially on the same PRX100/CPU_TAG cable, without CAD, native-test or CPU-reference jobs competing with timed board execution. Each has one cold observation, three warm full runs, separate three-token prefill and cached one-token decode. The 6 MHz software profile isolates host changes; the final profile uses identical optimized scripts at 10 MHz. These are finite sequential campaigns, not randomized/interleaved statistical trials or tail-latency evidence.

| Measurement | Original 6 MHz | Pooled/binary 6 MHz | Pooled/binary 10 MHz |
| --- | ---: | ---: | ---: |
| Four-token warm kernel median | 0.925792 s | 0.926146 s | 0.927054 s |
| Four-token warm end-to-end median | 7.570103 s | 7.401100 s | 6.292671 s |
| Cold end-to-end | 265.567607 s | 226.017901 s | 179.051100 s |
| Asset upload | 117.668490 s | 102.763870 s | 78.841259 s |
| Initial full input readback | 139.213751 s | 114.833161 s | 93.177303 s |
| Final full input-integrity reread | 140.793113 s | 114.588576 s | 93.862665 s |
| Three-token prefill application | 6.520822 s | 6.430031 s | 5.198709 s |
| Cached-token decode application | 2.209480 s | 2.176939 s | 1.773608 s |
| Warm full result/KV readback + CPU median | 4.625087 s | 4.356383 s | 3.793309 s |
| Six-run diagnostics including final integrity reread | 437.816251 s | 371.383800 s | 298.844353 s |

baseline warm end-to-end samples (ms): `[7570.103,7556.153,7598.973]`.

software6 warm end-to-end samples (ms): `[7236.303,7401.1,7532.95]`.

candidate10 warm end-to-end samples (ms): `[6292.473,6292.671,6373.127]`.

At unchanged 6 MHz, software changes give a signed warm latency reduction of 2.23% and cold reduction of 14.89%. Raising only the cable rate with the optimized scripts gives another 14.98% warm reduction and 20.78% cold reduction. Negative percentages, if present, denote regressions. Each cold number is a single observation; the combined result does not establish a general cold-start distribution. All samples are retained.

Warm application time includes all output/KV poisoning, the autonomous hardware computation, launch/poll/counters and every stage/KV readback with CPU checking. Cold adds upload, full physical input reread and full program upload/reread. The final full input-integrity reread is timed separately and included in the additional six-run diagnostic total. Programming, calibration, tool startup and fixture preparation are excluded. Hardware counter time includes DDR staging, all operators, control and diagnostic stores. Its observed median is 0.925792→0.927054 s (+0.136%) with the identical image and clock; no kernel speedup is claimed.

## Host implementation

Every profile transfers the same 98616 bulk AXI transactions and 25099179 payload words with the same operations, addresses, burst counts and lengths. The original helper creates an object per burst. The selected profile creates 588 objects across the campaign and reuses 98028 slots, a 99.40% reduction in bulk-object creations, with at most 32 live objects. The physical JTAG payload is not compressed or skipped.

A pool slot belongs to one direction and one of sixteen queue positions. A same-length transaction updates its actual CMD.ADDR and write DATA. Length changes delete/recreate that slot. All commands complete before reuse; slots cannot alias within a queue. Actual write DATA echoes remain checked. Reads execute on the FPGA and fetch each actual DATA property; validated packing plus whole-byte reversal converts Vivado's most-significant-word-first hexadecimal data into little-endian binary files. Fixed-width scanning accelerates uploads. No old read result or expected tensor substitutes for physical data.

The source-bound comparison normalizes only the requested JTAG rate, cable-support check and final pool cleanup, then requires the remaining workload Tcl to be identical. It checks every actual array byte and every bulk operation/address/burst shape/payload length. The control, poisoning, upload-loop, CPU-check and launch/counter Tcl procedures also match byte-for-byte. All diagnostic checks and timer boundaries remain unchanged. Final homogeneous-group response status remains the existing evidence level, rather than an individual per-member AXI response log. Full physical input/program/result checks retain every payload. Profile logs retain preparation/run/finish partitions plus per-group object creation/reuse, binary-read counts and status/DATA/decode costs.

The routed debug hub runs at 25 MHz. The final 10 MHz cable setting reaches the documented 2.5:1 ratio in [AMD UG908 2025.2](https://docs.amd.com/r/2025.2-English/ug908-vivado-programming-debugging/Debug-Cores-Clocking-Guidelines). The driver records supported cable rates, actual requested rate, device ID, DONE and CRC state. Core 25 MHz, DDR UI 100 MHz, both 16-entry queues and the bitstream are unchanged. This qualification applies to this image/cable, not arbitrary targets.

## Numerical workload and checks

Qwen/Qwen3-0.6B revision `c1899de289a04d12100db370d81485cdf75e47ca`, layer 0: hidden 1024, intermediate 3072, 16 query heads, 8 KV heads, head dimension 128. Three-token causal prefill uses IDs 42/100/1000; ID 42 at position 3 exercises cached decode. Context four and KV capacity eight are unchanged. All 27 assets total 31,485,952 bytes; the full program has 2,025 descriptors including HALT. The FPGA still executes RMSNorm, Q/K/V projections, head norms, RoPE, grouped-query causal attention, stable softmax, output projection/residual, post norm, gate/up, SiLU, down and final residual. The host supplies weights, embeddings, immutable RoPE coefficients and descriptors, with no runtime operator intermediates.

Each successful profile checks 400 stage tensors and 40 KV arrays, totaling 656,960 FP32 words, plus the five-word smoke. All stage/KV values pass unchanged mathematical CPU tolerance `1e-4 + 1e-4*abs(reference)` and match the ordered separate-RNE operation model bit-for-bit. Maximum mathematical absolute error: `0.000030517578125`; maximum final-hidden absolute error across 20,480 words/profile: `0.00000286102294921875`. All three program readbacks, 27 inputs before/after, six expected SLVERR guards/profile and every launch counter also pass. There are 18 successful layer-program launches and 60 token-layer executions across the three profiles.

## Retained failure and validation

The first pooled 6 MHz attempt passed smoke computation but stopped before uploading layer weights: shrinking an existing read object's CMD.LEN from 96 to 5 failed because Vivado retained its longer DATA property. Its exact source, Tcl, logs and partial readbacks are retained as `failed-software6-a1`; it is not a successful timing sample. The corrected implementation recreates changed-length slots. The enhanced independent memory mock rejects the exact failed implementation for the same retained-DATA reason, while the corrected version passes on both Mac Tcl and Linux Tcl. An earlier test-only minimum-reuse assertion expected over 1,000 reuses from a 789-transfer fixture; it was corrected before on-board use, and that failed test source/output is retained.

The host test independently checks random byte patterns, little-endian conversion, changed data/addresses/lengths, partial/page-crossing queues, list and binary reads, pool cleanup and rejection of malformed hex, wrong DATA object counts, alignment errors and bad AXI status. It uses 13 sizes including empty, 255/256/257 and 10,001 words, across DDR/scratch addresses. All five final host scripts pass native deny-warning checks and formatting. The comparison's required-gain gate rejects an identical campaign after its raw correctness/identity checks; a positive receipt requires cold, warm and result-readback improvements.

All **1,411 qualified native module input files** and **352 protected production/interface files** retain exact identities, including integer core, FP hardware, CPU/reference/program code and interfaces. Full native info/fmt/check/test with 1,257 passing tests, production RTL differential checks, pinned Yosys zero-SCC synthesis, bounded formal results and routed CAD qualification are **inherited by exact unchanged source/DUT/bit hashes, not rerun for this host-only change**. Their scope and bounds remain those of [the preceding batched-DDR report](prx100-layer-batch-20261019.md).

Vivado 2025.2, `xc7a100tfgg676-2`, cable `ME10E06D1010A`, ID `13631093`. Unchanged bitstream SHA256: `5e33d7b091fb0e8fb985e1409c9dcfd0402be0a84a1c568c7a3ffb3ee748fe22`. Build: `/work/builds/prx100-layer-vivado-20261019-batch-phys-a2`. Inherited setup slack +0.014 ns, hold +0.059 ns, zero failing setup/hold/pulsewidth endpoints and strict DRC with no Error/Critical Warning. Resources remain 22,677 LUTs, 11,080 FFs, 86.5 BRAM tiles and 27 DSPs. Each fresh physical audit binds these qualified sources/bit, actual cable rate and all numerical/counter checks.

## CPU and reproduction

Fresh scalar MoonBit native release four-token CPU samples (ms): `["90","90","90"]`; median **90 ms**. One traced warmup precedes three untraced runs; the epoch-millisecond timer excludes file I/O/model decoding and is compute-only, not BLAS. All 108 release/reference fixture binaries match exactly. The FPGA kernel is 10.30× that CPU compute interval; FPGA diagnostic end-to-end has a different boundary. Improved JTAG time does not imply CPU acceleration. CPU i7-13700, Ubuntu 22.04.5 KVM, 8 vCPUs/40 GiB; pinned Moon 0.1.20261012, moonc 0.10.15+943464bfa and GCC 11.4.0.

Reproduction and host contract: [PRX100_QWEN_LAYER_JTAG.md](../PRX100_QWEN_LAYER_JTAG.md). Use the original 6 MHz scripts from the preceding sealed archive for baseline, the current scripts at 6 MHz for software attribution and `prx100-layer-jtag-profile.mbtx` for the qualified 10 MHz profile; use new output paths for every campaign. The current public board driver, regression test and independent data/physical/comparison auditors record all inputs and results. The existing target build is reused exactly; its full reproducible CAD recipe remains in the preceding report/contract.

The immutable closed-inventory archive `artifacts/prx100-layer-jtag-20261019` retains unique host sources, raw three-profile readbacks, the unsuccessful board attempt, independent tests, numerical/physical audits, CPU timing, source identities and tool versions. It is mirrored to `/work/builds/prx100-layer-jtag-full-20261019-a1/prx100-layer-jtag-20261019`; the adjacent transport receipt records final verification. Prior hardware/native/formal/reference evidence is inherited through sealed source identities instead of copying regression archives. Compiler/Verilator caches and regenerable CAD checkpoints remain outside archives. No data is deleted. Host status preserves history and a previous-configuration recovery record. Final state is healthy/idle/DONE, error zero and configuration CRC zero; programming remains volatile, flash and host OS unchanged.

An additional post-campaign **read-only** health probe refreshed DONE/CRC and read the device identity, healthy/idle flags 5, error 0 and exact final 507-descriptor decode counters. It performed no reset, programming or AXI writes and is excluded from all performance samples. Its sources, raw register/configuration reads and independent final audit are retained separately. The current Linux native project also matches all 1,411 previously compiled source inputs byte-for-byte, including the unchanged allocation-probe manifest override.
