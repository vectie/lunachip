# PRX100 complete-layer DDR read pipeline — 2026-10-19

The bounded DDR read pipeline is implemented in MoonBit hardware and demonstrated on the PRX100. It reduces warm kernel latency by **32.32%** and warm diagnostic end-to-end latency by **12.94%** for the same complete BF16/FP32 Qwen3-0.6B layer. All **656,960** physical readback words match the previous FPGA profile and the separate operation model exactly, and pass the unchanged mathematical CPU reference tolerance. Both the integer core and BF16/FP32 arithmetic core are unchanged.

This is one complete transformer layer with a four-token tested context. The optimized CPU reference remains faster. It does not establish full-model text generation.

## Measured performance

Both fresh campaigns ran after CAD, native regression, and formal work finished, on the same board at 25 MHz core, 100 MHz DDR UI, and 6 MHz CPU_TAG/JTAG. Queue depth remained 16. The host driver, decoder, assets, programs, poisoning, complete stage/KV readback, and tolerances were identical. Three warm samples per image were taken in sequential campaigns; this is not an interleaved statistical study.

| Measurement | Previous DDR overlap | Pipelined DDR | Speedup |
| --- | ---: | ---: | ---: |
| Four-token warm kernel median | 2.819953 s | 1.908606 s | 1.477× |
| Four-token warm end-to-end median | 9.749874 s | 8.488513 s | 1.149× |
| Four-token cold end-to-end | 266.284437 s | 263.659213 s | 1.010× |
| Three-token prefill kernel | 2.113664 s | 1.430156 s | 1.478× |
| Cached-token decode kernel | 0.706289 s | 0.478452 s | 1.476× |
| Three-token prefill application | 7.863533 s | 7.163657 s | 1.098× |
| Cached-token decode application | 2.681297 s | 2.319695 s | 1.156× |

Baseline warm application samples (ms): `[9749.874,9767.066,9657.953]`. Candidate: `[8485.753,8496.847,8488.513]`. Every candidate warm sample is faster than every baseline warm sample: `true`. Cold has one sample per image; small cold differences include host-transfer variability.

Kernel latency is the actual active-cycle counter divided by the qualified nominal 25 MHz clock. It includes all DDR staging, operators, control, and intermediate diagnostic stores. Warm application time includes output/KV poisoning, launch, polling, completion/counters, every stage/KV readback, and CPU checking. Cold additionally includes all model/program uploads and complete initial input/program readback. Programming, calibration, Vivado startup, and fixture preparation are outside these intervals. The final full-input integrity read is separately recorded. These are fully checked diagnostic application timings.

Full launches retain 2,024 non-HALT instructions, 63,078,888 main products, and 31,594,560 core DDR response beats. Products exclude nonlinear-unit internal multiplies; response beats include store acknowledgments. The exact per-launch counters and phase times are retained in `counters.tsv`, `launches.tsv`, and `timings.tsv`. Candidate host traffic is 139 control transactions, 6717 bulk groups, and 98755 AXI transactions. A homogeneous group's final status is not individual status evidence for every transaction; actual payload bytes are fully read back.

## Workload and implementation

The checkpoint is `Qwen/Qwen3-0.6B`, revision `c1899de289a04d12100db370d81485cdf75e47ca`, layer 0: hidden 1024, intermediate 3072, 16 query heads, 8 KV heads, head dimension 128, RMS epsilon 1e-6, and RoPE theta 1000000. Token IDs 42, 100, 1000 form causal prefill; token 42 at position 3 is cached decode. Tested context is 4; KV capacity is 8. The full program has 2,025 descriptors including HALT. All 27 assets (31,485,952 bytes), three programs, 80 mathematical CPU stage references, and tolerances remain identical.

The FPGA executes input RMSNorm, Q/K/V projections, Q/K head RMSNorm, RoPE, causal grouped-query attention and stable softmax, output projection and residual, post-attention RMSNorm, gate/up projections, SiLU gating, down projection, and final residual. The host provides checkpoint weights, embeddings, immutable RoPE coefficients, and descriptors. Runtime normalization, attention, and MLP intermediates are computed on the FPGA.

The previous bridge issued one native 16-byte read, captured its return, and drained four words through a four-entry CDC FIFO before issuing the next native line. The new opt-in `targets/prx100_layer_ddr` bridge reserves 32 return words before issuing up to eight ordered native reads for one aligned 128-byte request. Separate issue/return counters bound ownership to eight lines. No command issues beyond that reservation. A registered emitter holds payload under backpressure, and a 64-entry response FIFO can retain an entire burst without waiting for slow-side credit synchronization.

The source interface still has one request owner, 32 ordered response words, and LAST only on word 31. Ordinary cached reads, line reads, masked writes, and full-line writes retain their protocol. Calibration loss or malformed returns poison the bridge; it stops subsequent commands and drains remaining ownership with faults. Coordinated physical reset clears both FIFO endpoints and ownership. Job reset does not reset the transport. Tests force all eight unstallable returns to arrive while the consumer is completely blocked, and exercise 2:1, 4:1, and 7:1 clock schedules.

The existing four-lane, three-stage multiplier, ping-pong weight staging, ordered FP32 accumulation, and scalar fallback remain byte-identical. BF16 weights, FP32 activations/products/sums, separate RNE operations, nonlinear approximations, reduction order, and tolerances are unchanged. All previous 16-file overlap exports remain identical; the new profile's core/controller IR and RTL, system wrapper, and XDC are exact. The portable integer path and its existing bridge are untouched. See the [implementation contract](../PRX100_QWEN_LAYER_DDR_PIPELINE.md).

## CPU and numerical validation

Reference environment: Ubuntu 22.04 KVM guest, 8 vCPUs and 40 GiB configured RAM, reporting `13th Gen Intel(R) Core(TM) i7-13700`. Pinned Moon `0.1.20261012 (748b63c)`, moonc `0.10.15+943464bfa`, and `cc (Ubuntu 11.4.0-1ubuntu1~22.04.3) 11.4.0`. Complete OS, CPU, memory, compiler, SDK binary identities, and source inputs are retained. One preceding traced CPU execution warms the reference before three untraced samples; the native CPU timer has epoch-millisecond resolution. The FPGA cold full-layer execution precedes its three warm full executions. Every warm FPGA run still streams all matrix weights from DDR through staging and recomputes every operator; identical instruction/product/response counters exclude result reuse.

Optimized native CPU samples for the same four-token layer (ms): `["93","93","93"]`; median **93 ms**. Debug median is 2750 ms. Release timing runs after physical campaigns and collection, with no concurrent build or benchmark workload. All 108 release/debug asset, program, and reference binaries are byte-identical. The CPU implementation is scalar MoonBit, not optimized BLAS; compute timing excludes model decoding and file/trace IO. FPGA kernel time is 20.52× CPU compute time; diagnostic end-to-end is 91.27×, with different boundaries. No CPU acceleration is claimed.

Each profile completes six launches: cold plus three warm full programs, separate three-token prefill, and one cached decode; 20 token-layer executions. All 400 stage tensors and 40 KV tensors, totaling 656,960 FP32 words, pass `1e-4 + 1e-4*abs(reference)`. Maximum absolute error is `0.000030517578125`; the 20,480 final hidden words have maximum error `0.00000286102294921875`. Every word also equals the independent operation-contract model and the other FPGA profile exactly. All 31,485,952 input bytes match before/after physical readback, all programs match, and six invalid/busy accesses produce expected SLVERR. Final status is DONE/idle, healthy, error 0, and configuration CRC error 0. Task hardware servers close; the accepted volatile image remains configured and flash is unchanged.

## Qualification and reproducibility

Vivado 2025.2 targets `xc7a100tfgg676-2`; cable `ME10E06D1010A`, FPGA ID `13631093`. Setup slack is +0.121 ns and hold slack +0.049 ns, with zero failing setup/hold/pulse-width endpoints and no DRC Error/Critical Warning. All 1869 core FF clock pins are checked at 40 ns, and the actual routed debug-hub clock qualifies 6 MHz JTAG. Advisory warnings remain. Resources: 20640 LUTs, 10764 registers, 74.5 BRAM tiles, and 27 DSPs. No timing, clock, or DRC waiver is used.

The initial full build was rejected before bitstream generation at +0.121 ns setup slack and -0.188 ns hold slack, with two failing hold endpoints. Its routed checkpoint, reports, and source identities are retained. A separate source-pinned physical recovery applies `AggressiveExplore` and hold repair to that checkpoint, verifies the original checkpoint hash remains unchanged, and preserves every RTL/XDC byte and clock. Only the recovered, strictly qualified `transfer-phys-a1` image was programmed for the candidate campaign. No timing exception or relaxed clock was introduced.

The long-running local SSH client did not deliver completion after the guest native work exited. A fresh connection independently verified all five actual phase exit files were zero, the 1,251-test total, the complete 80-reference fixture, and exact executed-driver/input-tar identities. The stale client chain was terminated, and the local native completion gate was restored from those records; it is not presented as a successful stale transport exit. No test was rerun or altered. The recovery receipt and unchanged original guest logs are retained, and subsequent operations use a foreground SSH master with keepalives.

All **1251 native tests** pass, including 26 targeted bridge/core/controller tests. The pinned isolated Linux workspace runs `moon info`, `moon fmt`, strict native check, and strict native test using one active native working cache. Exact physical bridge RTL agrees with LunaWave across **4,229 atomic events**, on every output with no masks. Pinned Yosys 0.68 checks all three components and the complete digital composition, requiring zero combinational SCCs before/after memory inference. The first generated integration-check wrapper had a malformed trailing header delimiter and was rejected before integration synthesis; corrected wrapper/logs are retained separately. Production RTL did not change.

Bridge BMC128 passes **32 named control assertions** with Bitwuzla, a fixed 4:1 clock schedule, an eight-step coordinated boot reset, and otherwise free inputs. The calibration-bypass sensitivity case fails `p_calibration_loss_sticky` at step 13 and retains its counterexample. This is bounded prefix safety, not unbounded arithmetic, full-layer liveness, or analog CDC proof. Core BMC48, controller positive/negative BMC32, and prior arithmetic differential evidence are inherited only after exact DUT/source comparisons and named sealed identities. The actual executed formal runner is retained. Physical audits bind all 15 input payloads, actual chip/bit/clocks, all 441 Tcl comparisons, and counter/wall-time coherence. A zero-gain comparison control must reject identical campaigns.

The 352 protected Mac task-input production/interface files remain byte-identical. The complete actual Linux compiled source is retained alongside the exact input tar. A fresh source-only pinned formatter replay, with the documented Linux C allocation-probe manifest override applied before formatting, reproduces every actual compiled file byte-for-byte: 1399 files; classification counts `{"exact_pinned_formatter_replay":478,"unchanged_input":920,"documented_linux_allocation_probe_override":1}`. Formatting differences are not described as identical Mac source bytes. All 16 export files are independently reproduced by the actual Linux native executable. Pre-existing user changes are preserved.

Qualified build: `/work/builds/prx100-layer-vivado-20261019-transfer-phys-a1`. Candidate: `/work/builds/prx100-layer-board-20261019-transfer-a1`; baseline: `/work/builds/prx100-layer-board-20261019-transfer-baseline-a1`.

| Artifact | SHA-256 |
| --- | --- |
| Qualified bitstream | `735963d7aebb684c5bdb9162da011c691a30ddd7d021d89f496475d1c04eaa73` |
| Input SHA256SUMS | `c5b0c36abb507710ddfbb0919b4d3c5f328b3c7b7dda2e647741b9ffebdf959c` |
| Physical bridge | `37125e7e015e2e1585eb43e0ead5e62ff54fcff494961ec627ba6dbfcd054537` |
| Physical core | `7662b0b93852b5f801b8716c17c25f70e7999f435b2493c7a7b8d008523b0ac2` |
| Canonical core IR | `33b904cae07804999d888992d68e5b28d6110816cd7671a04432c375dd1e08de` |
| Candidate data audit | `69ebe5bbdf1673abcea7a39be37374fdcdf37238623fd8c7839da8d4a11bb41b` |
| Performance comparison | `958dc8e53b0084a4c0ca8e655932ceb9c6fc1bc6f1d45e33cd5fe577358880e3` |

Reproduce export with `moon run --target native cmd/prx100_layer -- export-transfer NEW_ROOT`. Independent evidence commands are `bridge-replay-transfer`, `bridge-formal-transfer`, and `bridge-formal-negative-transfer`. The existing pinned public build driver enforces strict routed qualification. `prx100-layer-ddr-yosys.mbtx` checks exact components and their digital composition; `prx100-layer-ddr-audit.mbtx` checks all raw numerical identities and matched measurement conditions before accepting gains.

The closed-inventory archive `artifacts/prx100-layer-transfer-20261019` is mirrored to `/work/builds/prx100-layer-transfer-full-20261019-a1/prx100-layer-transfer-20261019`. It retains unique source/IR/RTL, actual board readbacks and inputs, CPU references, solver models and traces, logs, tool pins, CAD reports, and the rejected integration-wrapper attempt. Previous sealed evidence is inherited by exact hashes/seals, without copying regression archives. Compiler/Verilator caches and regenerable CAD checkpoints/projects stay outside archives. No task data is deleted. Host status preserves historical fields, the previous configuration, and the historical global core-edited flag; a new task-scoped flag records the unchanged integer core.
