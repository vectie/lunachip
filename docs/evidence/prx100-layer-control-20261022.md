# PRX100 complete BF16/FP32 layer: checked JTAG control

| Median resident end-to-end, five alternating pairs | Legacy host path | Completion snapshot | Reduction |
|---|---:|---:|---:|
| Complete four-token layer | 530.920 ms | 517.736 ms | 2.48% |
| Cached position-3 decode | 148.310 ms | 138.997 ms | 6.28% |

A fresh same-session comparison alternates the legacy and optimized host paths on the exact same sixteen-row BF16/FP32 image. Five pairs per workload, with order reversed each pair, measure full-layer end-to-end latency **530.920 → 517.736 ms** (2.48% lower) and cached position-3 decode **148.310 → 138.997 ms** (6.28% lower). Warm launches reuse the latest physically validated count under exclusive logged control ownership. The checked two-word DONE poll supplies status and a legal nine-word read revalidates count and captures counters; redundant count/status round trips are removed. Final DDR readback, file writes and CPU comparisons stay in the timer. All 448,448 FP32 words across 317 tensors pass CPU tolerance and match the ordered model; all 54,272 actual checker words are independently rechecked. All 1,284 strict native tests pass. Both complete 1,432-input source cohorts, all 199 integer inputs, FP hardware, programs, clocks and bitstream remain unchanged. Five altered auditor inputs are rejected. Existing physical/digital/formal gates are inherited by exact identity and complete sealed-parent verification. [Measured report](../../artifacts/prx100-layer-control-20261022/report.md) retains every pair and failure. This remains one fixed layer 0/context four and cached decode; full-model inference and Phase 7/8 closure remain open.

- [Every pair and measurement](../../artifacts/prx100-layer-control-20261022/benchmark.json)
- [Contract and reproduction](../PRX100_QWEN_LAYER_CONTROL.md)

[Post-close verification](prx100-control-close-20261022.json) and [sealed closure supplement](prx100-control-closure-20261022/README.md) retain the late filename-check failure and successful recovery; [mirror verification](prx100-control-closure-mirrors-20261022.json) binds the supplement to the unchanged primary archive.
