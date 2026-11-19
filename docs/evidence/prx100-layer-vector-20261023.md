# PRX100 interleaved nonlinear pipeline — 2026-10-23

| Median resident end-to-end, five samples per image | Fresh baseline | Candidate | Reduction |
|---|---:|---:|---:|
| full | 385.397 ms | 353.926 ms | 8.166% |
| decode | 111.483 ms | 105.826 ms | 5.074% |

Fresh profiling identified 68.600 ms in the SiLU-and-store groups. The opt-in MoonBit core interleaves four nonlinear elements through shared FP32 arithmetic while preserving each element's microprogram, constants, rounding and operation order. Matrix accumulation, weight delivery, clocks and host policy remain unchanged. Fresh physical campaigns measure four-token resident layer latency **385.397 → 353.926 ms (8.166% lower)** and cached position-3 decode **111.483 → 105.826 ms (5.074% lower)**. FPGA execution changes 330.929 → 296.650 ms for the layer and 84.694 → 76.063 ms for decode. Resident timing includes launch, polling, counters, final readback, file writes and CPU checks; uploads, program switches and full diagnostics are recorded separately. All 896,896 checked FP32 words pass the original CPU tolerance and match the ordered operation model; 317 cross-image tensors are byte-identical. Validation includes 1,600 bit-exact nonlinear lane cases, 180 complete-core alias/tail/fault cases, 1,297 strict native tests, 129,142 actual RTL replay cycles, fresh bounded core/unit safety with negative controls, full digital zero-SCC synthesis, and strict routed timing/DRC/clock/skew checks. All 199 integer inputs and all three previous hardware exports remain unchanged. Every sample is retained; separate bitstream campaigns retain host timing noise. The result covers one complete fixed layer 0 at context four and cached decode. Full-model inference and Phase 7/8 closure remain open.

- [Complete report and every sample](../../artifacts/prx100-layer-vector-20261023/report.md)
- [Machine-readable benchmark](../../artifacts/prx100-layer-vector-20261023/benchmark.json)
- [Contract](../PRX100_QWEN_LAYER_VECTOR.md)
