# PRX100 complete BF16/FP32 layer — shorter nonlinear schedule

| Resident median | Fresh eight-row baseline | Short nonlinear schedule | Reduction |
|---|---:|---:|---:|
| Four-token layer | 582.576 ms | 563.787 ms | 3.23% |
| Cached position-3 decode | 168.649 ms | 164.214 ms | 2.63% |

The opt-in MoonBit nonlinear engine commits additions in two edges and multiplies in four, preserving the ordered FP32 operations and approximations. On the PRX100, resident four-token layer latency improves from **582.576 to 563.787 ms** (3.23%), and cached position-3 decode from **168.649 to 164.214 ms** (2.63%). Timers include launch, completion, actual final-output reads, file writing and CPU comparisons. Upload, program installation, integrity sweeps and full diagnostics are separate. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 199 integer inputs and FP32 primitives remain unchanged. Controller, wrappers and source timing constraints are byte-identical. The bridge uses equivalent 24-bit aligned extent validation with the same packet and cycle contract. All 1,278 strict native tests, actual core RTL replay, zero-SCC composition, fresh 48-frame core safety checks, all 83 original bridge assertions over 128 global frames, actual 64-bit header equivalence in one frame, complete negative witnesses, and strict timing/clock/DRC/bus-skew gates pass. Routed setup/hold slack is 0.386 / 0.001 ns. [Measured report](../../artifacts/prx100-layer-short-unary-20261020/report.md) retains every observation and failed attempt. This is one complete fixed layer at context four; full-model inference and broader phase closure remain open.

- [Every sample and benchmark metadata](../../artifacts/prx100-layer-short-unary-20261020/benchmark.json)
- [Target contract and reproduction](../PRX100_QWEN_LAYER_SHORT_UNARY.md)
