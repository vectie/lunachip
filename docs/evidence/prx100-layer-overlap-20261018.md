# PRX100 four-lane complete-layer DDR overlap — 2026-10-18 UTC

Double-buffered DDR staging is implemented in MoonBit hardware and demonstrated on PRX100 for the same complete BF16/FP32 Qwen3-0.6B layer. The next weight stripe loads while four lanes compute the current stripe. All 656,960 physical readback words are bit-identical to the serialized four-lane FPGA and the separate operation model, and pass the unchanged independent CPU tolerance. The integer core is unchanged.

Warm kernel latency falls **18.45%**; warm diagnostic end-to-end latency falls **5.73%**. The optimized CPU reference takes **90 ms** for the four-token layer and remains faster. This measures one complete layer at context 4, not full-model text generation.

## Workload and implementation

The checkpoint remains `Qwen/Qwen3-0.6B` revision `c1899de289a04d12100db370d81485cdf75e47ca`, layer 0: hidden size 1024, intermediate size 3072, 16 query heads, eight KV heads, head size 128, RMS epsilon 1e-6, RoPE theta 1,000,000. Tokens 42, 100, and 1000 form three-token causal prefill; token 42 at position 3 is cached decode. KV capacity is eight; tested context is four. The 2,025-descriptor full program, all 27 assets (31,485,952 bytes), all 80 CPU stage arrays and tolerances are unchanged.

The FPGA executes input RMSNorm, Q/K/V projections, Q/K head RMSNorm, RoPE, causal grouped-query attention/stable softmax, output projection/residual, post-attention RMSNorm, gate/up projections, SiLU gating, down projection and final residual. The host supplies checkpoint weights, embeddings, immutable RoPE coefficients and descriptors; it supplies no runtime normalization, attention or MLP intermediate.

`designs/qwen_layer/overlap.mbt` adds two banks, each containing four 32-word packed-BF16 synchronous weight memories. The independent loader has empty/request/receive/full states and validates all four 128-byte lines before publishing a stripe. Starting computation launches the next 64-element stripe into the other bank. The one outstanding DDR line remains serialized; row groups and descriptors remain sequential. Each lane retains its original ordered FP32 accumulation and three-stage multiplier. All products drain before bank exchange; four result writes share the original scratch write port. The final chunk does not speculate beyond its matrix. Reset/descriptor initialization invalidate loader ownership; fault cannot be escaped by delayed tokens.

Weights stay BF16 and activations/products/sums stay FP32, with separate RNE operations. No FMA, reduction-order, tolerance, nonlinear approximation or integer-core change. Aliasing and row counts not divisible by four retain scalar fallback. All arithmetic/control/RAM semantics are LunaWire-generated; the target wrapper is checked as an integrated system. See the [implementation contract](../PRX100_QWEN_LAYER_OVERLAP.md).

## Fresh physical performance

Both measured campaigns run after all CAD/native/formal jobs finish, on the same board with a 25 MHz core, 100 MHz DDR UI, 6 MHz CPU_TAG/JTAG, queue depth 16, and the exact same host driver/decoder, assets, program, poisoning and complete stage/KV readbacks. They run sequentially with three warm samples each, not an interleaved statistical study. An earlier contended baseline is retained and independently audited but excluded from these gains.

| Measurement | Serialized four-lane | DDR overlap | Speedup |
| --- | ---: | ---: | ---: |
| Four-token warm kernel median | 3.451926 s | 2.814896 s | 1.226× |
| Four-token warm end-to-end median | 10.365793 s | 9.771835 s | 1.061× |
| Four-token cold end-to-end | 268.233211 s | 270.056767 s | 0.993× |
| Three-token prefill kernel | 2.587644 s | 2.109870 s | 1.226× |
| Cached-token decode kernel | 0.864282 s | 0.705024 s | 1.226× |
| Three-token prefill application | 8.496219 s | 8.185512 s | 1.038× |
| Cached-token decode application | 2.777239 s | 2.641486 s | 1.051× |

Baseline warm application samples(ms): `[10429.434,10225.037,10365.793]`. Candidate samples(ms): `[9792.833,9646.389,9771.835]`. Every candidate sample is faster than every baseline sample: `true`. Three samples establish this measured campaign, not a population confidence interval. Cold has one sample per image; transfer variability limits interpretation of small cold differences.

Cold end-to-end time increased by 1.824 seconds (0.68%) in this pair. Full uploads and input readback dominate that interval; the kernel improvement does not remove this transfer cost.

Kernel time is the actual active-cycle counter divided by the qualified nominal 25 MHz clock, including DDR staging, operators, control and diagnostic intermediate stores. Warm application includes output/KV poisoning, launch/polling/counters, every stage/KV readback and CPU checks. Cold additionally includes all asset/program uploads and complete physical input/program readback. Programming/calibration, Vivado startup and fixture preparation are outside these intervals. The final all-input integrity readback is recorded separately. These are fully checked diagnostic workload times.

Main full-launch counters remain 2,024 non-HALT instructions, 63,078,888 main products and 31,594,560 DDR responses. Products exclude nonlinear-unit internal multiplies; responses include store acknowledgments. Actual per-launch counters, launch clocks and phase timings are retained in `counters.tsv`, `launches.tsv` and `timings.tsv` and checked independently. Candidate host traffic is 181 controls, 6,717 bulk groups and 98,797 AXI transactions. Group final status is not claimed as individual status for every transaction; all actual payload bytes are read back.

## CPU and numerical checks

Native release CPU four-token samples are 90, 91 and 90 ms; median **90 ms**. Fresh native debug median is 2,739 ms. Release measurement runs after the physical campaigns and collection, avoiding load on timed FPGA runs. All 108 release/debug asset, program and reference binary files are byte-identical. CPU timing excludes asset decoding and file/trace IO and uses scalar MoonBit, not optimized BLAS. FPGA kernel time is 31.28× the release CPU compute time; warm diagnostic application is 108.58×, with different measurement boundaries. No CPU acceleration is claimed.

Each measured image completes six launches: four full programs plus separate prefill/decode, 20 token-layer executions, 400 stage tensors and 40 KV tensors. All 656,960 words pass `1e-4 + 1e-4*abs(reference)`; maximum absolute error is **3.0517578125e-5**. The 20,480 final hidden words have maximum error **2.86102294921875e-6**. All words additionally equal the separate operation model exactly and compare byte-for-byte across FPGA profiles. The five CPU/program/emulator source files are unchanged from the sealed baseline. All 31,485,952 input bytes match initial and final full physical readback; all three programs match. Six invalid/busy accesses return expected SLVERR. Final FPGA status is DONE/idle, healthy, error 0 and configuration CRC-error 0. Task-owned hardware servers are closed; the validated volatile image remains configured and flash is unchanged.

## Qualification and retained rejection

Vivado 2025.2 qualifies `xc7a100tfgg676-2`, CPU_TAG `ME10E06D1010A`, FPGA ID `13631093`. Final setup slack is **+0.217 ns** and hold slack **+0.031 ns**, with zero failing setup/hold/pulse-width endpoints and no DRC Error/Critical Warning. All 1,869 core FF clock pins are checked at 40 ns; the routed debug-hub clock qualifies JTAG at 6 MHz. An intermediate Route 35-39 timing warning resolves during final repair; warning/advisory recommendations remain. Resources: **20,102 LUTs, 9,654 registers, 74.5 BRAM tiles and 27 DSPs**. No clock/constraint/DRC waiver is used.

The initial design passed isolated core tests/replay/BMC but strict physical DRC rejected a cross-module combinational loop: request VALID depended on returned controller health, while the controller protocol checker observed that request. The corrected generator publishes requests from registered ownership/reset only; returned health still gates arithmetic and drives registered abort. The added pinned Yosys integrated flattened zero-SCC/check gate rejects the exact old source and accepts the corrected source. Neither rejected full CAD nor its rejected physical repair was programmed. The old incomplete native run was deliberately stopped, not marked PASS. Exact old inputs/source,solver artifacts,logs,negative check and failed CAD remain retained.

All **1,237 native tests pass** on the corrected input, including 12 targeted core/controller tests. The isolated Linux workspace runs `moon info`, `moon fmt`, strict native check and strict native test with the pinned baseline SDK. The existing C allocation-probe manifest alone receives its recorded Linux GNU-feature/libdl build override. One active native working cache is reused. The exact pre-phase source tar is retained. A fresh export from the actual final Linux executable reproduces every payload and the closed 16-file inventory hash of the qualified inputs. The actual post-info/fmt compiler input is also recorded: 1,378 files, with complete bytes for 479 transformed files retained in `actual-compiled-source.json`. A source-only replay of the pinned formatter reproduces 478 changes exactly; the remaining file is the documented Linux build override followed by that formatter. This replay creates no native compiler cache.

The exact physical RTL passes **105,976 LunaWave/Verilator cycles and 2,331,472 output-word checks**. Only 835 raw uninitialized RAM data observations with valid=0 are ignored. Tests cover signed multi-stripe/multi-row computation, simultaneous DDR response/compute, request stalls, warm starts, reset, tail/in-place fallback, prefetch faults, malformed LAST and health-loss drain stickiness. Pinned Yosys 0.68 retains memories and checks both separate components and the flattened actual system, requiring zero combinational SCCs. Independent physical audits bind all 15 source files, actual chip/bit/clocks, all 441 Tcl comparisons and counter/wall-time coherence. A zero-gain negative control rejects identical campaigns.

Actual-core BMC48 passes eight control assertions with Bitwuzla, initial reset only and all other inputs/unwritten RAM symbolic. This bound cannot reach a complete four-line stripe; it is not an arithmetic or full-layer liveness proof. Controller positive/negative BMC32 evidence is inherited only after exact DUT identity. Multiplier replay is inherited only after all arithmetic dependencies remain byte-identical to sealed evidence. Each actual executed timeout-adjusted formal runner is retained separately; the legacy runner's copied `driver.mbtx` is correctly identified as historical rather than executed code.

All 352 protected production/interface files remain byte-identical in the repository. All 18 integer exports, 16 previous floating-point projection exports and 16 serialized four-lane exports remain byte-identical. Pre-existing user work is preserved.

## Identities and reproduction

Qualified build: `/work/builds/prx100-layer-vivado-20261018-overlap-a2`. Candidate: `/work/builds/prx100-layer-board-20261018-overlap-a1`. Quiet baseline: `/work/builds/prx100-layer-board-20261018-overlap-baseline-a2`.

| Artifact | SHA-256 |
| --- | --- |
|Qualified bitstream|`d9d4323399b77bcfad7dfd06ed0487841bd326afad9b785d19bf310817ce4e7f`|
|Input SHA256SUMS|`502890683cd1ca5fb1d3722ee53c0996c7b2563fcf9d8f76e608c805d1e089f2`|
|Physical core.sv|`7662b0b93852b5f801b8716c17c25f70e7999f435b2493c7a7b8d008523b0ac2`|
|Canonical core IR|`33b904cae07804999d888992d68e5b28d6110816cd7671a04432c375dd1e08de`|
|Candidate data audit|`26be02f5b6cf1dbfcfe023193f36b5e5bea5d4835ae1d6de0deb5b913973c2f7`|
|Performance comparison|`53813403dee9dedc2ac66d3556a3c68c787df87274a902690046cbe770a1b412`|

Use `moon run --target native cmd/prx100_layer -- export-overlap NEW_ROOT`; the CLI also provides `replay-overlap` and `core-formal-overlap`. The public build driver and optional source-pinned `prx100-layer-overlap-route.mbtx` require strict routed timing/DRC gates. `prx100-layer-yosys.mbtx` now includes the integrated zero-SCC gate; `prx100-layer-overlap-audit.mbtx` checks unchanged raw data/conditions and measured gains. The accepted formal job uses 2,400 s inner and 3,000 s outer budgets without changing bound/assertions.

The closed-inventory archive `artifacts/prx100-layer-overlap-20261018` is mirrored to `/work/builds/prx100-layer-overlap-full-20261018-a1/prx100-layer-overlap-20261018`. It retains unique final and rejected sources/IR/RTL,actual board arrays and inputs,references,CPU timing identities,solver models/logs,tool pins and CAD reports. Caches,Verilator objects and regenerable CAD checkpoints/projects are excluded; original task data is not deleted. Earlier sealed archives remain immutable and inherited evidence is identified by exact hashes/seals. Host status preserves every historical field and the previous FPGA configuration, with an explicit task-scoped integer-unchanged flag.
