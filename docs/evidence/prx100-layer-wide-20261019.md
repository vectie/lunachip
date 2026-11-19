# PRX100 complete-layer wide DDR path — 2026-10-19

The DDR-to-core weight path now carries **128-bit response packets** through MoonBit-generated bridge, controller and banked weight storage. The same complete BF16/FP32 Qwen3-0.6B layer runs on the PRX100 with **29.34% lower warm kernel latency** and **4.42% lower warm diagnostic end-to-end latency**. All **656,960 physical FP32 readback words** match the previous FPGA profile and the separate operation model exactly and pass the unchanged mathematical CPU reference tolerance. The integer core is unchanged.

This demonstrates one complete transformer layer at a tested context of four tokens. It does not demonstrate full-model text generation. The optimized CPU reference remains faster.

## Measured performance

Both fresh campaigns ran after native regressions, CAD and formal jobs finished, on the same board at 25 MHz core, 100 MHz DDR UI and 6 MHz CPU_TAG/JTAG. Queue depth remained 16. Assets, programs, host driver, decoder, poisoning, all stage/KV readbacks and tolerances were identical. Three warm samples per image were taken in sequential campaigns; this is not an interleaved statistical study.

| Measurement | Previous 32-bit path | New 128-bit packets | Speedup |
| --- | ---: | ---: | ---: |
| Four-token warm kernel median | 1.908608 s | 1.348632 s | 1.415× |
| Four-token warm end-to-end median | 8.535245 s | 8.157722 s | 1.046× |
| Four-token cold end-to-end | 264.654716 s | 266.406767 s | 0.993× |
| Three-token prefill kernel | 1.430158 s | 1.010171 s | 1.416× |
| Cached-token decode kernel | 0.478451 s | 0.338461 s | 1.414× |
| Three-token prefill application | 7.290625 s | 7.031338 s | 1.037× |
| Cached-token decode application | 2.397408 s | 2.341428 s | 1.024× |

Baseline warm end-to-end samples (ms): `[8540.069,8535.245,8391.77]`. Candidate: `[8157.722,8010.527,8203.17]`. Every candidate sample is faster than every baseline sample: `true`. Cold has one sample per image and includes host-transfer variability.

In this paired sample, cold end-to-end was **1.752051 s higher (+0.66%)**. Cold JTAG upload and input reread still dominate, and no cold speedup is claimed.

Kernel time uses the active-cycle counter and qualified nominal clock. It includes DDR staging, every operator, control and intermediate diagnostic stores. Warm application time includes output/KV poisoning, launch, polling, counters, all stage/KV readbacks and CPU checking; weights remain resident in DDR but are streamed into the core on every execution. Cold additionally uploads and fully rereads all assets and the program. Programming, calibration, Vivado startup and fixture preparation are excluded. Final full-input integrity reads are timed separately.

Full launches retain 2,024 non-HALT instructions, 63,078,888 main products and 31,594,560 logical DDR words/acknowledgements. `ddr_beats` counts four logical words for each wide packet and one for each existing scalar response/store acknowledgement; it is not a native-DDR bandwidth counter. Raw `counters.tsv`, `launches.tsv` and `timings.tsv` retain each sample. Candidate host traffic comprises 113 control transactions, 6717 bulk groups and 98729 AXI transactions. Group final status is not an individual response-status record for every member; all actual payload bytes are checked.

## Workload and arithmetic

Checkpoint `Qwen/Qwen3-0.6B`, revision `c1899de289a04d12100db370d81485cdf75e47ca`, layer 0: hidden 1024, intermediate 3072, 16 Q heads, 8 KV heads, head dimension 128, RMS epsilon 1e-6 and RoPE theta 1000000. Tokens 42, 100, 1000 form causal prefill; token 42 at position 3 exercises cached decode. Tested context is 4, KV capacity 8. The full program contains 2,025 descriptors including HALT. All 27 assets (31,485,952 bytes), three programs, 80 CPU stage references and tolerances remain identical.

The FPGA executes input RMSNorm, Q/K/V projections, head RMSNorm, RoPE, causal grouped-query attention, stable softmax, output projection plus residual, post-attention RMSNorm, gate/up projections, SiLU gating, down projection and final residual. The host supplies weights, embeddings, immutable RoPE coefficients and descriptors. Runtime normalization, attention and MLP intermediates execute on the FPGA.

BF16 weights, FP32 activations, three-edge FP32 multiplication, separate round-to-nearest-even multiply/add, per-row K order and bounded nonlinear approximations are unchanged. This task changes transfer and storage organization, without changing arithmetic or substituting integer computation. The 352 protected production/interface identities remain unchanged, and every one of the 16 legacy `export-transfer` files is byte-identical to the previous qualified export.

## Wider transport

MIG already returns 128 bits per native read. Marked aligned 128-byte weight requests now return eight four-word packets rather than 32 single-word responses. The controller latches the width flag and checks LAST on the eighth packet. The overlap loader writes all four subword memories on one edge; the delayed word-bank selector follows the synchronous ReadOld/HoldLast read before the unchanged arithmetic pipeline. Only a completely filled ping-pong stripe becomes active. Scalar fallback, unmarked bursts, host cached reads, masked writes and full-line writes retain their formats.

The checked CDC primitive supports at most 64 payload bits. Four coordinated 64-entry FIFOs therefore carry the packet head and extra words. Source and destination reservations verify that all four lanes can transfer before publishing a shared pulse; no independent writer or reader can spend those reservations. This intentionally supports one 128-bit packet per two core edges, a theoretical **200 MB/s** payload ceiling at 25 MHz, rather than 400 MB/s. That ceiling is not measured native-DDR bandwidth. The native eight-command/32-word reservation still absorbs unstallable returns. Held packets remain stable; calibration or malformed-return faults stop further issue and drain faulted suffixes. Coordinated reset discards all lanes; job reset does not reset CDC endpoints.

The design still has one source request owner, four ordered arithmetic lanes and row/descriptor boundaries. These remain opportunities for further overlap. See [the interface contract](../PRX100_QWEN_LAYER_WIDE_DDR.md).

## Correctness and physical evidence

Each profile runs six launches: cold plus three warm full four-token executions, prefill-only and cached decode. This covers 20 token-layer executions, 400 stage tensors and 40 KV arrays: 440 arrays / 656,960 FP32 words. Every physical word is byte-identical across profiles and against the separate operation-contract model. The unchanged mathematical CPU criterion is `1e-4 + 1e-4*abs(reference)`; maximum absolute error is `0.000030517578125`. The 20,480 final-hidden words have maximum absolute error `0.00000286102294921875`. A five-word smoke program, six expected SLVERR responses, all three programs and all 27 input assets before/after execution also pass.

Vivado 2025.2 targets `xc7a100tfgg676-2`. Accepted build: `/work/builds/prx100-layer-vivado-20261019-wide-a2`. Bitstream SHA256: `13e3f13bcbe1d2c6135a764f604b22f036acd0a7a99afb36cbc319e55473db21`. Setup slack **0.027 ns**, hold slack **0.057 ns**, with zero failing setup/hold/pulsewidth endpoints and no DRC Error/Critical Warning. The clock check covers 1871 core FF clock pins. Resource use: 22575 LUTs, 11052 FFs, 86.5 BRAM tiles and 27 DSPs. The routed debug hub is 25 MHz, qualifying 6 MHz JTAG. Programming is volatile; flash and host OS remain unchanged.

Native phase gates pass 1254 tests, with 29 targeted tests. Exact physical RTL agrees with LunaWave for 104,711 core cycles and 7,521 bridge atomic events. Only invalid raw uninitialized program/scratch DATA may be masked in the core replay; every defined output is checked. The bridge replay has no masks. Native packet tests additionally use 2:1, 4:1 and 7:1 clock ratios. Pinned Yosys 0.68 synthesizes all three modules and finds zero SCCs in the complete generated digital composition.

Fresh Bitwuzla BMC tasks check the core at 48 clock edges, controller at 32 and bridge at 128 global steps. The bridge uses fixed 4:1 clocks and an eight-step coordinated boot, with other inputs free. Its 49 assertions include 16 FIFO reservation/transfer/pointer invariants. Observation-only DUT views are reversible and bound to exact production artifacts. Core, controller and calibration-bypass sensitivity tasks fail with retained counterexamples. These are bounded digital prefix results, not unbounded liveness, complete-layer arithmetic or analog CDC proofs.

## CPU reference and reproducibility

Fresh scalar MoonBit native release CPU median: **93 ms** for the same four-token complete layer. FPGA kernel time is 14.50× that CPU compute interval; warm diagnostic application time is 87.72× it, across different timing boundaries. The CPU implementation is not BLAS. All 108 release/debug/prior binary fixture files are identical. One preceding traced CPU execution warms arrays; three untraced runs use an epoch-millisecond timer and exclude file I/O/model decoding. CPU: 13th Gen Intel Core i7-13700, isolated Ubuntu 22.04.5 KVM guest, 8 vCPUs, 40 GiB RAM; Moon 0.1.20261012 / moonc 0.10.15+943464bfa / GCC 11.4.0.

All 16 hardware export files reproduce byte-for-byte on the actual Linux native executable after pinned info/fmt/check/test gates. Every one of the 1404 actual first-party build input files reproduces from the exact phase-input tar using the pinned formatter and documented Linux C allocation-probe manifest override. Actual formatted source, original inputs and tool identities are retained; Mac/Linux source formatting equality is not assumed.

Generate with `moon run --target native cmd/prx100_layer -- export-wide NEW_INPUTS`, then use `scripts/prx100-layer-build.mbtx` with the exported inventory hash and pinned MIG root. The unchanged `prx100-layer-board.mbtx` runs the benchmark; `prx100-layer-wide-audit.mbtx` requires raw numerical identities, matched conditions, and improvements in both kernel and warm end-to-end time. A zero-gain negative control must reject identical campaigns.

The closed-inventory archive `artifacts/prx100-layer-wide-20261019` is mirrored to `/work/builds/prx100-layer-wide-full-20261019-a1/prx100-layer-wide-20261019`. It retains unique MoonBit/IR/RTL inputs, all raw readbacks, CPU references, solver models/traces, tool pins, reports and attempted validation/build logs. Existing sealed regression evidence is inherited by exact identities and seals; compiler/Verilator caches and regenerable CAD projects/checkpoints remain outside the archive. No task data is deleted. Host status preserves the previous configuration and historical global core-edited flag; a new task-scoped flag records the unchanged integer core.

The first core negative used a write-control inversion. It detected `p_read_only_burst` at step 36, then exhausted its resource budget during witness export; its TIMEOUT and partial outputs are retained and are not accepted as a completed sensitivity task. The selected negative instead bypasses the DUT reset pin while preserving the exact production DUT, all properties, the 48-edge bound and the external initial-reset assumption. It fails `p_reset_idle` at step 2 with complete VCD, replay testbench and solver witness. The production core's positive 48-edge proof is unchanged.
