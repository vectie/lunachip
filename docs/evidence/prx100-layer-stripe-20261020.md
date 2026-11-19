# PRX100 complete BF16/FP32 layer — eight-row DDR requests

| Resident median | Fresh four-row baseline | Eight-row candidate | Reduction |
|---|---:|---:|---:|
| Four-token layer | 649.402 ms | 581.413 ms | 10.47% |
| Cached position-3 decode | 182.845 ms | 169.938 ms | 7.06% |

The matching MoonBit core loader, controller and bridge use two eight-row requests per sixteen-row stripe, with all unstallable DDR returns reserved before issue. FP arithmetic and all 199 integer inputs remain unchanged. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 346 numerical payload files match across profiles.

Timings include launch, completion, actual final-output reads and CPU comparisons, with five samples per workload/profile. Upload, integrity reads, program installation and full diagnostics are separate. Strict native tests (1,274), actual RTL replay, zero-SCC composition, fresh bounded checks and routed timing pass. Failed attempts are retained. One fixed layer/context four is exercised; full-model generation remains open.

- [Measured report](../../artifacts/prx100-layer-stripe-20261020/report.md)
- [Every sample and benchmark metadata](../../artifacts/prx100-layer-stripe-20261020/benchmark.json)
- [Target contract and reproduction](../PRX100_QWEN_LAYER_EIGHT_ROW.md)
