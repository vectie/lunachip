# PRX100 ordered FP32 feedback and weight delivery — 2026-10-23

| Median resident end-to-end, five samples per image | Fresh baseline | Candidate | Reduction |
|---|---:|---:|---:|
| full | 510.974 ms | 390.559 ms | 23.566% |
| decode | 140.466 ms | 115.450 ms | 17.809% |

The opt-in MoonBit design accepts an ordered FP32 accumulation every core edge and delivers sixteen BF16 weights per edge through a 256-bit target path. The close/far FP32 adder preserves round-to-nearest-even, gradual underflow and the original per-product order; the existing BF16-specialized multiplier reduces unnecessary width. Fresh physical baseline and candidate campaigns measure resident four-token layer latency **510.974 → 390.559 ms (23.566% lower)** and cached position-3 decode **140.466 → 115.450 ms (17.809% lower)**. FPGA execution changes 448.660 → 330.928 ms for the full layer and 114.127 → 84.694 ms for decode. Resident timers include launch, polling, counters, final readback, file writes and CPU checking. Upload, program switching and full diagnostics are separately recorded. All 896,896 checked FP32 words pass the original CPU tolerance and match the ordered operation model; 317 cross-image tensors are byte-identical and 108,544 actual checker words are independently rechecked. All 1,295 strict native tests, actual core/bridge RTL replay, universal feedback-adder equivalence, bounded safety with complete negative controls, zero-SCC synthesis and strict physical timing/clock/DRC/skew gates pass. A protocol proof caught surplus error packets after rejected wide reads; the corrected path and its regression passed before programming. All 199 integer inputs remain unchanged, and legacy exports remain byte-identical. Clocks and host policy are unchanged. Five packed samples per workload and image retain every observation; separate image campaigns still include host timing noise. This is one complete fixed layer 0 at context four and cached decode; full-model inference and Phase 7/8 closure remain open.

- [Complete report and all samples](../../artifacts/prx100-layer-feedback-20261022/report.md)
- [Machine-readable comparison](../../artifacts/prx100-layer-feedback-20261022/benchmark.json)
- [Contract](../PRX100_QWEN_LAYER_FEEDBACK.md)
