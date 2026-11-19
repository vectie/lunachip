# PRX100 complete BF16/FP32 layer — sixteen-row matrix owner

| Median resident end-to-end | Fresh eight-row baseline | Sixteen-row owner | Reduction |
|---|---:|---:|---:|
| Complete four-token layer | 559.188 ms | 530.673 ms | 5.10% |
| Cached position-3 decode | 157.923 ms | 158.436 ms | -0.32% |

The opt-in matched MoonBit core/controller/bridge replaces two eight-row owners with one sixteen-row DDR owner per matrix stripe, retaining sixteen ordered BF16/FP32 lanes, identical arithmetic and clocks. Fresh resident full-layer latency improves from **559.188 to 530.673 ms** (5.10%), while cached position-3 decode rises from **157.923 to 158.436 ms** (0.32% slower). Its FPGA kernel nevertheless improves 6.17%; recorded host/control/readback overhead offsets that saving. Timers include launch, completion, actual final-output reads, file writes and CPU checks; upload, program switching, integrity sweeps and full diagnostics remain separate. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 199 integer inputs and FP arithmetic primitives remain unchanged. Only the internal observe_beat width changes from six to seven bits in each wrapper; all other wrapper bytes, source XDC, host ABI and pins remain exact. All 1,284 strict native tests, fresh RTL replays, zero-SCC composition, core/controller 48-frame safety, all 83 bridge assertions over 128 global frames, 64-bit header equivalence and complete negative calibrations pass. Strict route, clock, DRC and all 12 bus-skew gates pass; setup/hold slack is +0.130/+0.001 ns. The 1,432-input source cohorts preserve 479 pre-existing Mac/Linux variants; all 27 changed inputs and 15 selected canonical/emitted files match across hosts. [Measured report](../../artifacts/prx100-layer-sixteen-row-20261021/report.md) retains all observations and attempts. This is one fixed complete layer 0 at context four and cached decode; full-model inference and Phase 7/8 closure remain open.

- [All samples and benchmark metadata](../../artifacts/prx100-layer-sixteen-row-20261021/benchmark.json)
- [Contract and reproduction](../PRX100_QWEN_LAYER_SIXTEEN_ROW.md)
