# PRX100 complete BF16/FP32 layer — DDR read-ahead

| Resident median | Fresh32-row baseline | Qualified16-row read-ahead | Reduction |
|---|---:|---:|---:|
| Four-token complete layer |704.242ms|644.422ms|8.49%|
| Cached position-3 decode |195.743ms|187.600ms|4.16%|

DDR matrix stages improve14.42%;SiLU is unchanged. All845,696paired FP32 values pass CPU tolerance and the ordered model bit for bit. All199integer inputs remain unchanged. The selected16-row core is the exact previous qualified core;the32-row read-ahead attempt exceeded placement capacity. Native1,270tests,110,170unmasked bridge RTL events,zero-SCC composition,all83original128-frame bridge properties with exact coverage,and strict routed timing/clock gates pass.

These are resident end-to-end times,including actual final readback and CPU checks,with five observations/workload/profile. Fresh portable CPU computation takes90ms/four tokens and remains faster than the578.398ms FPGA kernel. One fixed layer/context four is exercised;full-model generation remains open.

- [Measured report](../../artifacts/prx100-layer-feed-20261020/report.md)
- [All samples and benchmark metadata](../../artifacts/prx100-layer-feed-20261020/benchmark.json)
- [Target contract and recipe](../PRX100_QWEN_LAYER_READ_AHEAD.md)
