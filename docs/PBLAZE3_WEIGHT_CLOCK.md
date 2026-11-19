# Qwen3-0.6B matrix weight delivery on PBlaze3

## November 17, 1 KiB weight reads and aligned matrices at 100 MHz

The complete Qwen3-0.6B model on PBlaze3 reached **4.889 generated tokens/s**
with the wider reader and LunaFlux matrix alignment. The same-day compact
control reached **4.626 tokens/s** across the same six four-output trials.
Both used a 100 MHz scheduler, 282.353 MHz ordered MAC, 200 MHz × 512-bit
MIG, 30 MHz JTAG and one FPGA start per output. START-to-DONE fell from
18,517,814 to 16,999,937 cycles per output. Each layout used two independent
processes with resident weights and programs. All 24 complete aligned FP32
logit vectors matched the compact control byte for byte.
[Pooled board results](../artifacts/pblaze3-stripe1k-100mhz-20261117-a1/performance-summary.json) · [Full verification and bitstream](../artifacts/pblaze3-stripe1k-100mhz-20261117-a1/RESULTS.md)

Weight-bank wait fell from **50.03 to 35.64 ms/output**. Gaps between DDR
response beats accounted for 8.52 ms of the saving. Cycles receiving a beat
while the scheduler still waited for a full bank accounted for another
5.32 ms. Effective matrix weight bandwidth rose from **7.956 to 8.853 GB/s**
(62.16% to 69.16% of the 12.8 GB/s peak). Over full host generation time,
useful weight bandwidth rose from 5.514 to 5.827 GB/s (43.08% to 45.53%).
Adding 14 KiB of padding made all 178 executed matrices per output eligible
for the 1 KiB path. The FPGA used 128 additional RAMB36 blocks.
[Weight-wait counters](../artifacts/pblaze3-stripe1k-100mhz-20261117-a1/weight-wait-breakdown.json) · [Executed matrix layouts](../artifacts/pblaze3-stripe1k-100mhz-20261117-a1/layout-audit.json) · [Resource report](../artifacts/pblaze3-stripe1k-100mhz-20261117-a1/routed100-wide/utilization.rpt)

## November 17, 100 MHz row scheduler on the complete model

The deployed 64-lane ordered accelerator closes at **100 MHz on the row
scheduler, 282.353 MHz on the MAC and 200 MHz on the MIG**. Its first
three `Hello` four-output trials delivered **4.568 tokens/s** versus
**4.500 tokens/s** on the 75 MHz production baseline (+1.51%).
A second resident process delivered **4.639 tokens/s**. Across all six
trials the board generated **4.603 tokens/s**. START to DONE averaged
185.18 ms per token, versus 190.22 ms on the production baseline. Each
of 24 complete 151,936-word FP32 logit vectors matched that baseline
byte for byte. Both sessions used 30 MHz JTAG, one start per output,
and zero timed weight uploads. The separate higher-divider check missed
109.091 MHz by 0.831 ns on the unchanged route.
[Board results and bitstream](../artifacts/pblaze3-ordered-system-20261116-a1/RESULTS.md) ·
[Machine-readable measurements](../artifacts/pblaze3-ordered-system-20261116-a1/performance-summary.json)

The 100 MHz image uses 512-byte row reads in 32 KiB groups with compact
BF16 weights. Its measured matrix phase reached 7.956 GB/s (62.16% of
12.8 GB/s), with 50.03 ms/output waiting for weight banks. The separate
1 KiB reader at 80 MHz benefits from `PBLAZE3_ALIGN_MATRIX_1K=1` in
LunaFlux. On the same FPGA image and Linux client, 14 KiB of model
padding raised the matrix rate from 7.949 to 8.178 GB/s and generation
from 4.464 to 4.524 tokens/s.
[Same-image layout comparison](../artifacts/pblaze3-ordered-system-20261116-a1/comparison-aligned.json)

## November 16, complete 64-lane ordered MAC and measured MIG bandwidth

The 64-lane FP32-activation × BF16-weight array closes **405 MHz** in out-of-context post-route timing on XC7K325T-2. Moving exponent-difference calculation alongside the magnitude comparison and significand exchange raised the passing frequency from 319 MHz. At 406 MHz setup fails by 0.004 ns. The 700 MHz target misses by 1.039 ns, from FP32 rounding carry to the registered result encoding. Routing accounts for 81.8% of this path's 1.935 ns data delay. The design separately rounds each product and each addition to FP32, preserving column order while interleaving 18 rows per lane. Its RTL reproduced all 2,048 words of a physical Qwen layer-0 Q projection and 218,432 directed and randomized FP32 lane results. [Implementation, coverage and reports](../artifacts/pblaze3-mac64-700-20261116-a1/RESULTS.md)

The board's 200 MHz, 512-bit MIG delivered **11.641 GB/s** on sequential reads and **10.920 / 10.286 GB/s** for 4 / 6 KiB row pitches. With one fresh BF16 weight per active lane per clock, that supplies 14.37 / 13.48 / 12.70 lane equivalents at 405 MHz, or 8.31 / 7.80 / 7.35 at 700 MHz. The existing integrated 75 MHz Qwen image delivered 8.295 GB/s of matrix weights during matrix phases and 4.500 tokens/s across twelve generated outputs with full logits checked outside the timer. The ordered array subsequently ran on the same board with a 75 MHz scheduler and a 290.909 MHz MAC clock. The first 80 MHz scheduler image closed at 259.459 MHz on the MAC and 200 MHz on the MIG. [Board read counters](../artifacts/pblaze3-mac64-700-20261116-a1/mig-board/measurements.tsv) · [Integrated clock and throughput measurements](../artifacts/pblaze3-ordered-system-20261116-a1/RESULTS.md) · [Production benchmark](../artifacts/pblaze3-mac64-700-20261116-a1/production75.json)

## November 16, targeting a 700 MHz compute clock

Vivado 2026.1 closed the register-to-register paths of a single exact 24-by-8 significand multiplier at a 1.428 ns constraint on the XC7K325T-2. Setup margin was +0.301 ns, hold +0.082 ns and pulse-width +0.314 ns. The lane accepts one pair each edge and produces the corresponding 32-bit result on the thirteenth edge, using 575 LUTs and 1,068 flip-flops. Vivado mapped zero DSPs and zero block RAMs. Placement and routing were out of context with a modeled global clock source and unconstrained external data ports. This covers the integer product inside an FP32-activation × BF16-weight lane. The ordered-array measurements above extend this experiment through rounding and FP32 accumulation. The memory interface and clock crossings require system-level timing. [Lane timing](../artifacts/pblaze3-core700-20261116-a1/lane-normalized/summary.rpt) · [Utilization](../artifacts/pblaze3-core700-20261116-a1/lane-normalized/utilization.rpt) · [8,192 cycle-matched products](../artifacts/pblaze3-core700-20261116-a1/verilator-stream.log)

The existing routed 80 MHz full design was analyzed separately with the actual MMCM parameters changed in memory to generate 700 MHz. The DDR reference, MIG UI and debug clocks retained 200, 200 and 100 MHz respectively. The core missed setup by 11.027 ns across 126,170 of 143,517 setup endpoints. The actual DSP configuration also violated its 2.772 ns minimum period by 1.343 ns. No bitstream was generated or loaded in this experiment. The unchanged board throughput evidence uses 75 MHz. [Full-core clock identity](../artifacts/pblaze3-core700-20261116-a1/whole/result.txt) · [Setup](../artifacts/pblaze3-core700-20261116-a1/whole/summary.rpt) · [Pulse width](../artifacts/pblaze3-core700-20261116-a1/whole/pulse.rpt)

For the 1.0 V -2 grade, DS182 lists 710 MHz for the global clock tree, 650.20 MHz for a fully pipelined DSP48E1, and 543.77 MHz for the block RAM write-first/no-change use specified in Table 34. A fast fabric-only compute domain can receive operands through a slower staging domain. At batch one, 64 lanes each consuming a fresh two-byte weight every 700 MHz edge would request 89.6 GB/s, seven times this board’s 12.8 GB/s DDR peak. Clock, supplied operand rate and end-to-end generation therefore require separate measurements. [AMD DS182, Tables 34–36](https://docs.amd.com/v/u/en-US/ds182_Kintex_7_Data_Sheet) · [Board bandwidth measurements](../artifacts/pblaze3-bf16-clock-target-20261115-a1/physical-comparison.json)

## What the 4.30 tokens/s figure bounds

The 64-lane design issues 9,312,256 groups of matrix products per output. At 40 MHz, dividing the clock by that count gives 4.2954 matrix passes/s if each cycle issues one group. At 75 MHz the same calculation gives 8.0539 passes/s. Both estimates omit the rest of the model and host dispatch. The production 75 MHz four-output benchmark averaged 4.452 tokens/s across six trials, with a fastest trial of 4.501. [Hardware counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/attention75/cycles.json) · [Individual board trials](../artifacts/pblaze3-bf16-clock-target-20261115-a1/physical-comparison.json)

For those four output positions the measured 224.64 ms/token consists of 190.22 ms on the FPGA and 34.42 ms on the host and JTAG path. At identical FPGA cycle counts, removing the entire host interval would give 5.257 tokens/s. A 5.00 tokens/s end-to-end target requires recovering 24.64 ms/token. Eliminating the measured 12.50 ms weight stall alone would give 4.714 tokens/s with everything else fixed. These are projections from the existing image. [Matched board measurements](../artifacts/pblaze3-bf16-clock-target-20261115-a1/physical-comparison.json)

In the eight-output run, the first and eighth outputs averaged 181.32 and 220.76 ms of FPGA execution respectively across three trials. From first to eighth, the instruction count increased from 7,742 to 17,598 while the product count increased by 0.136%. Each step from the second to the eighth output added exactly 1,344 instructions. In this context range the attention lowering emits one historical key load, one historical value load and two multiply/add instruction pairs per extra history position, for each of 8 KV groups in 28 layers. At the eighth position the FPGA execution time alone already exceeds the 200 ms budget for 5 tokens/s. Sustaining that rate at this position requires reducing time on the FPGA. [Per-position counters and host timings](../artifacts/pblaze3-bf16-clock-target-20261115-a1/attention75-eight/benchmark/measurements.json)

## November 16, larger row-major reads

The 75 MHz production run measured 1,061,340 exposed matrix weight-wait cycles per token with 32 KiB strided reads. Joining adjacent Q/K/V weights into one instruction per layer reduced this to about 937,198 cycles, or 12.50 ms at 75 MHz. The 60 MHz paired-row comparison had spent 3,971,034 cycles (66.18 ms) waiting for weights. The final LunaFlux program sustained 5.313 GB/s of useful payload over wall time and 4.452 generated tokens/s across two independent processes. [Physical measurements](../artifacts/pblaze3-bf16-clock-target-20261115-a1/physical-comparison.json) · [75 MHz counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/attention75/cycles.json)

The 64 physical lanes can alternate between two independent FP32 row accumulators per lane. Each row receives its BF16 products in increasing column order. The scratch RAM mirror supplies two independent reads per edge for vector operands and scratch dot products. At 60 MHz this design occupies 137,492 LUTs, 230.5 block RAM tiles and 131 DSPs. The routed clock report identifies the 60 MHz compute registers and the 200 MHz MIG UI. [Utilization](../artifacts/pblaze3-bf16-clock-target-20261115-a1/route-embedding60/utilization.rpt) · [Routed clocks](../artifacts/pblaze3-bf16-clock-target-20261115-a1/route-embedding60/diagnostic-routed.txt)

The 32 KiB read command transfers sixteen BF16 row fragments of 1,024 columns. It issues 64 aligned 512-byte reads, allows 16 outstanding and returns 256 ordered 128-byte packets. In the strided variant, the bridge advances four bursts within a row, then advances to the next row with a pitch of 2,048, 4,096 or 6,144 bytes. It checks the entire extent against the 2 GiB aperture before issuing the first burst. The descriptor, checkpoint layout and product order stay compatible with the resident model. Directed simulation covers rejected addresses, delayed responses, all returned words and a last fragment ending exactly at the top of DDR. The integrated LunaWave and Verilator comparison passed across 103,327 observed edges. [Bridge checks](../artifacts/pblaze3-bf16-clock-target-20261115-a1/strided-bridge.log) · [Production replay](../artifacts/pblaze3-bf16-clock-target-20261115-a1/strided-differential/receipt.json)

## November 13, coalesced FP32 writes on 64 lanes

On PBlaze3 the isolated logits-write stream fell from 2,279,041 to 37,984 FPGA response cycles per output (98.33% fewer). End-to-end generation moved from 0.66134 to 0.70419 tokens/s, and core plus instruction-loader time fell from 34,340,281 to 29,749,939 cycles per output. The complete logits matched for all twelve outputs. [Measurement and implementation](../artifacts/pblaze3-store-burst64-20261113-a1/README.md) and [per-token cycles](../artifacts/pblaze3-store-burst64-20261113-a1/per-token-cycles.csv).

## Coalesced FP32 vector loads on 64 lanes

Coalescing contiguous FP32 LOADs reduced measured scalar DDR response time from 11,504,480 to 3,400,720 cycles per output (70.44% fewer). Generation reached 0.66134 tokens/s versus 0.59049 (12.00% faster), and subsequent decode reached 0.63286 versus 0.56108 tokens/s. [Full-model A/B](../artifacts/pblaze3-scalar-load64-20261112-a1/comparison.json), [timed per-token cycles](../artifacts/pblaze3-scalar-load64-20261112-a1/per-token-cycles.csv), [scalar counters](../artifacts/pblaze3-scalar-load64-20261112-a1/scalar-profile.json) and [routed bitstream](../artifacts/pblaze3-scalar-load64-20261112-a1/route/pblaze3.bit).

| Metric | Previous 64-lane image | Coalesced LOAD |
|---|---:|---:|
| Generation, 12 outputs (tokens/s) | 0.59049 | 0.66134 |
| Subsequent decode, 9 outputs (tokens/s) | 0.56108 | 0.63286 |
| Scalar LOAD response cycles/output | 8,365,259 | 261,513 |
| Scalar STORE response cycles/output | 3,139,221 | 3,139,207 |
| All scalar response cycles/output | 11,504,480 | 3,400,720 |
| Scalar LOAD requests/output | 416,000 | 13,000 |
| FPGA core cycles/output | 36,730,267 | 28,239,440 |
| Instruction-loader cycles/output | 6,141,245 | 6,100,841 |
| FPGA core + loader cycles/output | 42,871,512 | 34,340,281 |
| Matrix weight payload (GB/s) | 3.839 | 3.834 |
| Matrix weight payload / 5.12 GB/s compute port | 74.99% | 74.89% |
| Matrix weight payload / 12.8 GB/s MIG | 29.99% | 29.96% |
| Whole-generation useful DDR throughput (GB/s) | 0.705 | 0.790 |
| Logical DDR payload / 12.8 GB/s during core execution | 10.16% | 13.22% |
| Logical DDR payload / 12.8 GB/s during the timed generation | 5.51% | 6.17% |
| Timed wall time outside core + loader (ms/output) | 621.72 | 653.57 |
| Routed LUTs / FFs / RAMB36 equivalents / DSPs | 117,043 / 53,232 / 102.5 / 85 | 116,744 / 54,248 / 102.5 / 85 |

Scalar STORE now accounts for 92.31% of residual response cycles. In the isolated streams, writing the 151,936 FP32 logits costs 2,279,041 response cycles per output. This is the largest remaining scalar stream.

All scalar LOAD descriptors in these four programs start on 128-byte boundaries and contain 128, 192 or 1,024 words. A 128-word head previously incurred 128 serial round trips. It now uses four 128-byte AXI reads. The core captures all 32 words per response and drains them in address order through the existing scratch write port. Short and unaligned prefixes/tails use scalar requests. Each output reads 1,664,000 useful FP32 bytes. The logical model payload includes weights and vector data; the whole-generation percentage divides it by measured wall time and the 12.8 GB/s MIG peak. Matrix percentages use measured matrix time only.

| Replayed address stream | FP32 words/output | Previous response cycles/output | Coalesced response cycles/output |
|---|---:|---:|---:|
| load key | 143,360 | 2,885,435 | 90,711 |
| load value | 143,360 | 2,885,433 | 90,717 |
| store logits | 151,936 | 2,279,041 | 2,279,041 |
| load norm | 65,536 | 1,317,774 | 40,970 |
| load zero | 57,344 | 1,154,170 | 36,284 |
| store value | 28,672 | 430,081 | 430,081 |
| store key | 28,672 | 430,081 | 430,081 |
| load rope | 5,376 | 108,066 | 3,411 |
| load embedding | 1,024 | 20,588 | 645 |

The separate on-board probe grouped original descriptors by tensor role and preserved address order within each group. These role timings can change with DDR locality. The full-model LOAD and STORE figures in the first table use the hardware opcode counters in each of the three timed trials. Subtracting request and local execution cycles isolates response cycles, whose sum matches the independent scalar-response counter in every trial. [Address-stream classification](../artifacts/pblaze3-scalar-load64-20261112-a1/probe-data/roles.json), [baseline probe](../artifacts/pblaze3-scalar-load64-20261112-a1/baseline-roles.json) and [candidate probe](../artifacts/pblaze3-scalar-load64-20261112-a1/candidate-roles.json).

| Output position | Greedy token ID | Previous active cycles | Coalesced active cycles | Saved cycles |
|---:|---:|---:|---:|---:|
| 0 | 21806 | 36,829,017 | 31,824,103 | 5,004,915 |
| 1 | 0 | 40,860,881 | 33,505,814 | 7,355,067 |
| 2 | 358 | 44,893,400 | 35,188,249 | 9,705,151 |
| 3 | 2776 | 48,902,748 | 36,842,958 | 12,059,790 |

Active cycles include core execution and instructions fetched from resident DDR. The position rows average the same three timed trials.

The same PBlaze3, LunaFlux binary, BF16 checkpoint, resident programs, raw `Hello` prompt, 40 MHz compute clock, 200 MHz MIG and 30 MHz JTAG were used. One warm-up preceded three four-output trials. Individual generation trials spanned 0.57802–0.59723 tokens/s before and 0.65728–0.66568 after. The timed loop read the four-byte FPGA argmax. Checkpoint transfer and independent reference validation ran outside timing. The twelve complete 151,936-entry FP32 logit vectors matched the baseline byte for byte. [Input identity](../artifacts/pblaze3-scalar-load64-20261112-a1/unchanged-data-path.log) and [residency](../artifacts/pblaze3-scalar-load64-20261112-a1/residency.json).

Reproduce this image with `moon run --target native --release cmd/pblaze3 -- export-inference-64-load-lines /tmp/pblaze3-load-lines` using a fresh output directory. The prior configuration remains available as `export-inference-64-prefetch`.

## November 12, long weight bursts on 64 lanes

Each output waited 2,392,309 cycles for matrix weights, down from 30,952,100 (92.27% fewer). The 40 MHz core saved 713.99 ms per output in that stall alone. Measured generation changed from 0.40605 to 0.59049 tokens/s (45.42% faster). [Board A/B](../artifacts/pblaze3-mig-prefetch64-20261112-a1/comparison.json), [phase counters](../artifacts/pblaze3-mig-prefetch64-20261112-a1/cycle-profile.json), [per-output timings](../artifacts/pblaze3-mig-prefetch64-20261112-a1/per-token-cycles.csv), [trial log](../artifacts/pblaze3-mig-prefetch64-20261112-a1/remote/run/benchmark/benchmark-result.json) and [routed clocks and interfaces](../artifacts/pblaze3-mig-prefetch64-20261112-a1/route/diagnostic-routed.txt).

| Same PBlaze3 and resident Qwen3-0.6B | Previous 64 lanes | 64 lanes with longer prefetch |
|---|---:|---:|
| Generation, 12 outputs (tokens/s) | 0.40605 | 0.59049 |
| Subsequent decode, 9 outputs (tokens/s) | 0.39166 | 0.56108 |
| Core cycles/output | 67,371,000 | 36,730,267 |
| Instruction-loader cycles/output | 6,771,168 | 6,141,245 |
| Core + instruction-loader cycles/output | 74,142,168 | 42,871,512 |
| Exposed matrix weight wait (cycles/output) | 30,952,100 | 2,392,309 |
| Matrix issue cycles/output | 9,312,256 | 9,312,256 |
| Matrix time (ms/output) | 1,040.83 | 310.47 |
| Useful matrix-weight bandwidth (GB/s) | 1.145 | 3.839 |
| Useful matrix-weight bandwidth / compute port peak | 44.73% | 74.99% |
| Useful matrix-weight bandwidth / 12.8 GB/s MIG peak | 8.95% | 29.99% |
| Whole timed generation, logical payload / 12.8 GB/s | 3.79% | 5.51% |
| Wall time outside core + loader (ms/output) | 609.20 | 621.72 |
| LUTs / FFs / RAMB36 equivalents / DSPs | 109,596 / 41,174 / 102.5 / 85 | 117,043 / 53,232 / 102.5 / 85 |

| Exposed weight wait, mean cycles per output | Previous | Longer prefetch |
|---|---:|---:|
| Receiving weight data | 14,267,225 | 1,992,077 |
| Waiting for the first response | 8,909,286 | 390,607 |
| Gaps between response beats | 6,887,065 | 4,489 |
| Outside an owned response | 888,524 | 5,135 |

The compute-side port transfers 128 bytes per 40 MHz edge. The 1024-bit clock converter feeds the width converter at 200 MHz, where one compute-side beat becomes two 512-bit MIG beats. The unchanged 64-lane BF16 datapath consumes up to 128 useful weight bytes per issue edge, or 5.12 GB/s. The MIG UI and DDR3 pins provide a 12.8 GB/s peak. At batch one these lanes can therefore consume at most 40% of the configured MIG peak as unique matrix weights at the measured clock.

Each long row carries 512 bytes (four compute beats, eight MIG beats). An aligned 16-row request batch fetches 8 KiB of real weights at the original row stride. Two on-chip buffers span 256 columns by 64 rows each. Prefetch continues into the next row group while the current group finishes. The 234 row-major descriptors per output retain their original addresses and payload; the old image read 9,312,256 rows of 128 bytes, the new image reads 2,328,064 rows of 512 bytes. These request counts follow from the resident program and transfer geometry. Measured bus counters are reported separately.

Prefetch raised the fraction of weight packets received during matrix issue from 20.56% to 74.36%. The scalar DDR response now accounts for 11,504,480 cycles per output, followed by 9,312,256 matrix issue cycles. The core and loader together occupy 1.072 s of the 1.694 s measured per output. The other 0.622 s includes host control, launch/poll and transport time.

The bandwidth rows use useful bytes divided by measured elapsed time. The matrix phase uses 1,191,968,768 weight bytes per output. The whole-generation row includes all logically counted DDR data during the timed trial. Bus occupancy requires a separate MIG beat counter.

One warm-up preceded three four-output trials from the raw prompt `Hello`. Trial generation rates ranged from 0.39923–0.41617 tokens/s on the previous image and 0.57802–0.59723 on the new image. The same LunaFlux executable verified 1,192,099,840 bytes of BF16 weights and installed 6,078,080 program bytes before timing. The timer includes FPGA argmax and the four-byte result over 30 MHz JTAG. All twelve full FP32 logit vectors matched the baseline byte for byte. Reading these logits took 15.70 s outside the timers, and the independent reference also ran outside them. [Resident program audit](../artifacts/pblaze3-mig-prefetch64-20261112-a1/residency.json) and [full input identity](../artifacts/pblaze3-mig-prefetch64-20261112-a1/unchanged-data-path.log).

Export the measured configuration with `moon run --target native --release cmd/pblaze3 -- export-inference-64-prefetch /tmp/pblaze3-prefetch-digital` into a fresh directory. The prior 64-lane image is reproducible with `export-inference-64-banked`. [Timing report](../artifacts/pblaze3-mig-prefetch64-20261112-a1/route/timing.rpt), [utilization report](../artifacts/pblaze3-mig-prefetch64-20261112-a1/route/utilization.rpt) and [measured bitstream](../artifacts/pblaze3-mig-prefetch64-20261112-a1/route/pblaze3.bit).

## 32 versus 64 lanes on the full model, November 12

The 64-lane banked image generated **0.40605 tokens/s** on the PBlaze3.
The 32-lane image reached **0.40721 tokens/s**. Each run used the same
LunaFlux binary, resident BF16 checkpoint and programs, raw `Hello` prompt,
40 MHz FPGA clock and 30 MHz JTAG. After one warm-up, three trials
generated four outputs each. The 64-lane generation rates spanned
0.39923–0.41617 tokens/s, overlapping the 32-lane range of
0.40243–0.41504. The default `export-inference` stays at 32 lanes.
`export-inference-64-banked` reproduces the measured 64-lane design.
[Full-model comparison](../artifacts/pblaze3-banked64-20261111-a1/comparison.json)
and [timed trial results](../artifacts/pblaze3-banked64-20261111-a1/remote/run/benchmark/benchmark-result.json).

| Measured per output unless indicated | 32 lanes | 64 lanes, banked |
|---|---:|---:|
| Generation / decode (tokens/s) | 0.40721 / 0.39653 | 0.40605 / 0.39166 |
| FPGA compute cycles | 68,018,265 | 67,371,000 |
| FPGA instruction-loader cycles | 6,771,163 | 6,771,168 |
| Compute + loader cycles | 74,789,428 | 74,142,168 |
| Matrix issue cycles | 18,624,512 | 9,312,256 |
| Exposed matrix weight wait (cycles) | 21,414,039 | 30,952,100 |
| Matrix phase (ms) | 1,057.015 | 1,040.835 |
| Matrix cycles issuing products | 44.05% | 22.37% |
| Useful matrix-weight payload (MB/s) | 1,127.67 | 1,145.20 |
| Useful matrix-weight bandwidth / 2.56 GB/s compute port | 44.05% | 44.73% |
| Useful matrix-weight bandwidth / 12.8 GB/s DDR pin peak | 8.81% | 8.95% |
| Timed wall time outside FPGA compute and loader (ms) | 586.00 | 609.20 |

Doubling the lanes saved 9.31 million issue cycles and exposed another
9.54 million weight-wait cycles. Other matrix work, including stripe
handoffs and pipeline drains, also shrank. All matrix phases combined
saved 16.18 ms/output. Time outside the two FPGA counters increased
23.20 ms/output in this sample. This accounts for the 0.29% lower observed
overall throughput. The two runs give no evidence of an end-to-end speedup.
[Cycle counters](../artifacts/pblaze3-banked64-20261111-a1/cycle-profile.json)
and [wall and FPGA time for each output](../artifacts/pblaze3-banked64-20261111-a1/per-token-cycles.csv).

Of the 30.95 million exposed wait cycles, 14.27 million received weight
packets, 8.91 million waited for the first beat, 6.89 million waited in
gaps between beats and 0.89 million fell outside an owned response. The
separate shape test, weighted by all 234 matrix descriptors per output,
measured 41,632,630 matrix cycles on this image. The original 64-lane
image with distributed storage measured 41,594,784 in the shape test.
The full-model figures above use the banked bitstream throughout.
[Banked shape measurements](../artifacts/pblaze3-banked64-20261111-a1/prefetch64.json),
[original 64-lane measurements](../artifacts/pblaze3-64rows-20261111-a1/prefetch64.json)
and [per-position phase replay](../artifacts/pblaze3-banked64-20261111-a1/phase-per-token.csv).

## Fitting 64 BF16 matrix lanes into the XC7K325T

All three designs below closed timing with a 40 MHz compute clock, a
512-bit compute AXI port and a 512-bit MIG interface at 200 MHz. These
are whole-board counts from Vivado after routing. A RAMB18 counts as half
a RAMB36 when comparing block RAM capacity.

| Routed image | LUTs (of 203,800) | FFs | RAMB36 equivalents | DSP48E1 (of 840) |
|---|---:|---:|---:|---:|
| 32 lanes | 106,933 (52.47%) | 70,031 | 70 | 53 |
| 64 lanes, original weight storage | 175,733 (86.23%) | 106,742 | 70 | 85 |
| 64 lanes, banked weight storage | 109,596 (53.78%) | 41,174 | 102.5 | 85 |

The banked design packs two 64-row weight stripes into 64 dual-port
memories. Each incoming 512-bit beat writes sixteen weight pairs to
distinct banks. On a multiply edge, the core reads one BF16 weight for
each of the 64 rows. The mapping and the rotation back to row order remove
66,137 LUTs from the original 64-lane implementation. It retains the same
ordered FP32 accumulation and produced the same outputs on all 8,703
simulated edges. [32-lane route](../artifacts/pblaze3-inference512-20261111-a1/route/utilization.rpt),
[original 64-lane route](../artifacts/pblaze3-64rows-20261111-a1/route/utilization.rpt),
[banked route](../artifacts/pblaze3-banked64-20261111-a1/route/utilization.rpt)
and [cycle comparison](../artifacts/pblaze3-banked64-20261111-a1/bank-equivalence.log).

At one matrix issue per edge, 64 lanes would consume 128 bytes of BF16
weights per 40 MHz cycle (5.12 GB/s). The current compute port supplies at
most 64 bytes per cycle (2.56 GB/s). The separate memory-side peak is
12.8 GB/s. At batch one, each of the 1,191,968,768 useful weight bytes
per output is used once in the measured matrix instructions. Consequently
the compute port alone limits sustained matrix issue to at most one edge
in two, even before first-response latency, packet gaps and the other
execution phases. [Routed design inputs](../artifacts/pblaze3-banked64-20261111-a1/input/job.json)
and [MIG configuration](../artifacts/pblaze3-banked64-20261111-a1/route/mig-effective.prj).

## 32 row-major lanes and a 512-bit AXI port

The same PBlaze3 generated **0.40721 tokens/s** with 32 lanes, up 13.9%
from 0.35763 with 16 lanes. Both runs used the same LunaFlux client binary,
BF16 checkpoint, resident programs, 40 MHz core and 30 MHz JTAG. One
warm-up preceded three trials of four outputs from the raw prompt `Hello`.
Each of the twelve complete FP32 logit vectors matched byte for byte.
[Physical comparison](../artifacts/pblaze3-inference512-20261111-a1/comparison.json)
and [individual timed outputs](../artifacts/pblaze3-inference512-20261111-a1/per-token-cycles.csv).

| Measured per output unless indicated | 16 lanes, AXI256 | 32 lanes, AXI512 |
|---|---:|---:|
| Generation / decode (tokens/s) | 0.35763 / 0.34696 | 0.40721 / 0.39653 |
| Core cycles | 79,545,315 | 68,018,265 |
| Loader cycles | 6,771,174 | 6,771,163 |
| Core + loader cycles | 86,316,488 | 74,789,428 |
| Matrix issue cycles | 37,249,024 | 18,624,512 |
| Exposed matrix weight wait | 12,570,512 | 21,414,039 |
| Matrix seconds | 1.34519 | 1.05701 |
| Matrix weight MB/s | 886.10 | 1,127.67 |
| Matrix weight bandwidth / compute-port peak | 69.23% | 44.05% |
| Matrix weight bandwidth / configured DDR pin peak | 6.92% | 8.81% |
| Other core / instruction loader / time outside hardware (s) | 0.64344 / 0.16928 / 0.63831 | 0.64344 / 0.16928 / 0.58600 |

The 32-lane core waited 9,907,712 edges while accepting weight packets,
6,130,259 for the first packet of an owned read, 4,763,052 in gaps between
packets, and 613,016 outside an owned response. The gain came from halving
matrix issue cycles. The faster math exposed more of the existing DDR
latency. The 234 matrix descriptors read 1,191,968,768 useful bytes per
output. At 2.56 GB/s their weight reads alone allow at most 2.148 outputs/s.
At the configured 12.8 GB/s pin peak the same calculation gives 10.739.
Both calculations assume continuous transfers and omit the rest of
generation. [Measured cycle partition](../artifacts/pblaze3-inference512-20261111-a1/cycle-profile.json),
[deferred per-position replay](../artifacts/pblaze3-inference512-20261111-a1/phase-per-token.csv)
and [residency audit](../artifacts/pblaze3-inference512-20261111-a1/residency.json).

## Full-model results on the same XC7K325T, November 11

Raising the compute side from **25 to 40 MHz** increased batch-one
generation from **0.25743 to 0.35763 tokens/s** (+38.9%) and decode from
**0.25082 to 0.34696 tokens/s** (+38.3%). This saved **1.08839 s/output**,
compared with the **0.10151 s/output** estimated for the packed prefetch
at 25 MHz. Use `export-inference-256` to reproduce this 40 MHz configuration.
[Measured A/B](../artifacts/pblaze3-weight-clock40-20261111-a1/comparison.json)
and [default build reproduction](../artifacts/pblaze3-weight-clock40-20261111-a1/default-build.log).

| Physical measurement | 25 MHz | 40 MHz |
|---|---:|---:|
| Host time for 12 outputs | 46.61533 s | 33.55468 s |
| Host generation time per output | 3.88461 s | 2.79622 s |
| Core cycles per output | 75,989,183 | 79,545,315 |
| Instruction-loader cycles per output | 5,791,231 | 6,771,174 |
| Core + loader cycles per output | 81,780,415 | 86,316,488 |
| Core + loader time per output | 3.27122 s | 2.15791 s |
| Matrix phase time per output | 2.06814 s | 1.34519 s |
| Exposed matrix weight wait per output | 10,466,488 cycles / 0.41866 s | 12,570,512 cycles / 0.31426 s |
| Matrix weight payload / matrix time | 576.35 MB/s | 886.10 MB/s |
| Matrix weight payload / peak compute AXI bandwidth in the matrix phase | 72.04% | 69.23% |
| All logical DDR payload / core time | 392.97 MB/s | 600.65 MB/s |
| All logical DDR payload / peak compute AXI bandwidth during core time | 49.12% | 46.93% |
| All logical DDR payload / timed host generation time | 307.49 MB/s | 427.17 MB/s |

The compute port accepts one 32-byte beat per cycle. Its peak rose from
800 to 1,280 MB/s (+60%), while the measured matrix weight bandwidth rose
53.7%. This accounts for the lower utilization percentage at the higher
clock. MIG remained at 200 MHz. These ratios measure useful payload against
the compute port peak. The run did not instrument DDR pin occupancy.
At 40 MHz each output still issues 37,249,024 matrix beats. While blocked
on a bank, the core now spends 11,876,568 cycles receiving data, 623,963
waiting for a first beat, 7,980 waiting between beats and 62,000 outside an
owned response. Faster cycles reduced exposed wait time by **104.40 ms
(24.9%)**. Other parts of the core and loader account for the remainder of
the end-to-end improvement. [Physical phase counters](../artifacts/pblaze3-weight-clock40-20261111-a1/cycle-profile.json)
and [all timed token positions](../artifacts/pblaze3-weight-clock40-20261111-a1/per-token-cycles.csv).

LunaFlux used the same BF16 checkpoint, raw `Hello` prompt and 30 MHz
JTAG target. One warm-up preceded three trials of four outputs. Each
trial produced `[21806, 0, 358, 2776]`. The two images produced identical
FP32 logits at all 151,936 vocabulary positions in each of the twelve
outputs. The client read back all 1,192,099,840 weight bytes and installed
6,078,080 program bytes before timing. Timed runs returned a four-byte
FPGA argmax per output. The 16.32 s of full-logit reads and the host
reference checks at 40 MHz were outside the timers. The 40 MHz client adds
routed-clock verification. The two Linux client sources have identical
timed generation loops. [Transport audit](../artifacts/pblaze3-weight-clock40-20261111-a1/performance-summary.json),
[program residency](../artifacts/pblaze3-weight-clock40-20261111-a1/residency.json) and
[timed source comparison](../artifacts/pblaze3-weight-clock40-20261111-a1/linux-client/timed-loop.sha256).

Vivado 2026.1 met timing on the routed 40 MHz image. Whole-design worst
setup, hold and pulse-width slack were 0.176, 0.055 and 0.062 ns. The
compute clock had 4.434 ns of intra-domain setup slack. Resource counts
went from 60,910 to 60,918 LUTs and 38,578 to 38,585 flip-flops. Both
images used 70 RAMB36 blocks and 37 DSPs. [Routed clocks](../artifacts/pblaze3-weight-clock40-20261111-a1/route/diagnostic-routed.txt),
[timing](../artifacts/pblaze3-weight-clock40-20261111-a1/route/timing.rpt) and
[resources](../artifacts/pblaze3-weight-clock40-20261111-a1/route/utilization.rpt).

## Where the 40 MHz image spends a token

The timed 2.79622 s/output decomposes into the following disjoint intervals,
averaged over all twelve outputs. The host row is the residual after
subtracting both hardware counters and includes normal JTAG dispatch,
transfers and polling. It does not measure CPU-busy time.

| Interval | Seconds/output | Share of generation time |
|---|---:|---:|
| Matrix phases, including weight stalls | 1.34519 | 48.11% |
| Remaining core work | 0.64344 | 23.01% |
| Instruction loading | 0.16928 | 6.05% |
| Time outside core and loader | 0.63831 | 22.83% |

The routed MIG AXI interface can carry 256 bits at 200 MHz (6.4 GB/s).
The accelerator AXI interface carries 256 bits at 40 MHz (1.28 GB/s).
This limits the latter to 10% of the physical x64 DDR3-1600 pin bandwidth,
even with one accepted beat on every core edge. Each matrix issue consumes
sixteen new BF16 weights. Sustaining 32 products per edge at 40 MHz would
require 64 bytes of weights per edge, or 2.56 GB/s, for batch-one decode
with the current weight traffic. Both the weight delivery path and the
compute consumer would have to sustain that rate.
[Configured AXI interfaces](../artifacts/pblaze3-weight-clock40-20261111-a1/route/transport-properties.txt)
and [physical phase counts](../artifacts/pblaze3-weight-clock40-20261111-a1/cycle-profile.json).

If a wider datapath halved the *entire* matrix interval and every other
interval stayed fixed, the measured workload would reach 0.471 tokens/s.
This is an end-to-end sensitivity estimate. In the existing deterministic
K=1,024 bridge test, eight and sixteen outstanding read credits both
delivered the same 2 KiB row-major stripe in 87 cycles with a 16-cycle
first-beat latency. Increasing credits alone did not improve that case.
[Test configuration](../validation/pblaze3_axi/stream_wbtest.mbt)
and [regression results](../artifacts/pblaze3-weight-clock40-20261111-a1/chip-suite.log).

## Where the bandwidth limits come from

The board configuration uses 64 data pins and a 1,250 ps DDR clock period.
Two transfers per clock give 12.8 GB/s in decimal units. The 200 MHz MIG
user interface needs 512 bits per beat to represent that rate. The earlier
256-bit configuration limited that interface to 6.4 GB/s. The 25 and 40 MHz
compute clocks came from the inference clock recipe. In the 256-bit, 40 MHz
image the compute port limited useful traffic to 1.28 GB/s. Its measured
886 MB/s of matrix weights corresponded to 69.23% of the compute port and
6.92% of the pin rate. Neither fraction measures DDR command or bus occupancy.
[Effective DDR configuration](../artifacts/pblaze3-inference512-20261111-a1/route/mig-effective.prj),
[routed clocks](../artifacts/pblaze3-inference512-20261111-a1/route/diagnostic-routed.txt)
and [baseline bandwidth denominators](../artifacts/pblaze3-inference512-20261111-a1/denominator-regression.json).

The 512-bit image widens both AXI interfaces, pairs them with 32 ordered
row-major products per issue edge and maintains the existing packed-16
layout. At 40 MHz the compute port can carry 2.56 GB/s, or 20% of the pin
rate, if it transfers every cycle. The memory crossbar accepts eight reads
at its accelerator input and issues eight at its MIG output. Each row uses
two 64-byte beats per 128-byte burst. [Implemented bus widths](../artifacts/pblaze3-inference512-20261111-a1/route/transport-properties.txt)
and [generated crossbar credits](../artifacts/pblaze3-inference512-20261111-a1/routed-read-credits.txt).

The routed design occupies 106,933 of 203,800 LUTs, 70,031 of 407,600
flip-flops, 70 of 445 RAMB36 tiles and 53 of 840 DSP48E1s. The 256-bit
image occupied 60,918 LUTs, 38,585 flip-flops, 70 RAMB36 tiles and 37
DSP48E1s. These counts measure allocated hardware. The wider core's
worst same-clock setup path has 3.598 ns of slack at a 25 ns period,
including 14.075 ns of routing delay. A higher clock needs a new routed
timing result. [Whole-device utilization](../artifacts/pblaze3-inference512-20261111-a1/route/utilization.rpt),
[routed timing](../artifacts/pblaze3-inference512-20261111-a1/route/timing.rpt),
[AMD CLB capacities](https://docs.amd.com/r/en-US/ug474_7Series_CLB/7-Series-FPGA-CLB-Resources)
and [AMD device overview](https://docs.amd.com/api/khub/documents/2LByHkO~nSZXcei2D55fTg/content).

## The 25 MHz comparison

The baseline is the November 11 vector image. Its LunaFlux short-context
batch-one run measured 0.25743 tokens/s overall and 0.25082 tokens/s for
decode. The core accepted 37,249,024 weight beats per output. Each beat
holds 16 BF16 weights. The program issued 234 matrix descriptors, covering
31,000 groups of 16 rows and 582,016 stripes of 2 KiB. The instruction
bytes at each of the four output positions specify row-major weights.
[Baseline trial counters](../artifacts/pblaze3-profile-optimized-20261111-a1/cycle-profile.json)
and [decoded shape frequencies](../artifacts/pblaze3-weight-clock40-20261111-a1/prefetch25.json).

| What the core observed while blocked on a full stripe | Cycles/output |
|---|---:|
| A weight beat arrived on the response channel | 9,868,915 |
| Waiting for the first response beat of an owned request | 528,087 |
| Gap between response beats of an owned request | 7,486 |
| Controller did not own a wide response | 62,000 |
| Total exposed weight wait | 10,466,488 |

The 25 MHz core waits for an entire bank before issuing its next 64 matrix
cycles. A beat arriving during that wait contributes to useful bandwidth
and still counts as an exposed stall. Hiding every one of these stalls
would save 0.41866 seconds/output. With the baseline's other measured costs
fixed, this puts the ceiling for that change at 0.28852 tokens/s.

## What the existing prefetch can recover

The packed-16 layout reads consecutive rows' 64-weight slices in storage
order and prefetches across 16-row group boundaries. The row-major mode
restarts the loader at these boundaries. On the physical 25 MHz image we
tested both modes at all seven matrix shapes in the four real token
programs. Each shape used three paired trials with alternating order,
readback-verified weights, identical logical operands and a check of every
FP32 result. The hardware counters independently checked the product,
packet, stripe-admission and issue counts.

Weighting the row-major results by actual descriptor counts predicts
10,465,034 exposed cycles/output, within 1,454 cycles (0.014%) of the full
model measurement. Packed-16 predicts 7,927,245, a saving of **2,537,789
cycles/output (0.10151 s)**. Keeping other costs fixed gives **0.26433
tokens/s**. This is a projection from board-measured matrices. The timed
full-model A/B uses the original row-major checkpoint on both images.

The two largest contributions are the 56 descriptors with 3,072 rows of
depth 1,024 (883,269 cycles/output) and the 37 descriptors with 4,096 rows
of depth 1,024 (778,776). Together they account for 65.5% of the projected
saving. The latter shape includes slices of the vocabulary projection.

Of the projected 7,927,245 remaining wait edges with packed weights,
7,922,781 already carry a weight beat. About 3,978 precede the first beat,
19 are gaps between beats and 468 fall outside an owned response. Further
reductions of this wait would have to bring these data beats forward or
let arithmetic start before a complete bank has arrived. Eliminating only
the measured gaps between beats would save about 19 cycles/output.

A separate K=64, N=1,024 control has identical weight bytes and the same
row offsets in both modes. The two buffers on the 25 MHz image start
16 MiB apart. Across 64 row groups the mean exposed wait fell from 5,327
cycles to 85 when the following group could start early. At the model's
K=1,024, 2,048 and 3,072, both the physical
weight access order and the group prefetch change. Their combined measured
gain is included above. [Raw board measurements](../artifacts/pblaze3-weight-clock40-20261111-a1/shapes25/obs/profile.tsv)
and [weighted estimates](../artifacts/pblaze3-weight-clock40-20261111-a1/prefetch25.json).

We repeated the same matrix experiment on the qualified **40 MHz** image
after its full-model run. The weighted row-major probe measured 12,573,286
exposed cycles/output, within 0.023% of the full model's 12,570,512.
Packed-16 reduced the weighted wait to 10,001,291. Its incremental saving
at this clock is **2,571,996 cycles/output, or 64.30 ms**. Holding the
rest of the measured run fixed projects **0.36604 tokens/s** (+2.35%).
Actual full-model throughput on the deployed row-major checkpoint is
0.35763 tokens/s. Nearly all the remaining packed stall edges (9,995,844
per output) already carried data. In the separate identical-address K=64
control, cross-group prefetch reduced the mean wait from 5,532 to 213
cycles. [40 MHz paired observations](../artifacts/pblaze3-weight-clock40-20261111-a1/shapes40/obs/profile.tsv)
and [weighted estimates](../artifacts/pblaze3-weight-clock40-20261111-a1/prefetch40.json).

## Why the clock changed first

The 25 MHz timing report showed **16.016 ns** of intra-core setup slack
on a 40 ns period. A new 25 ns period targets 40 MHz. The clock generator
also drives the instruction loader, AXI master and the compute side of the
DDR clock converter. MIG stays at 200 MHz, the AXI datapath at 256 bits
and JTAG at 30 MHz. The independent peak rates of the compute AXI port
are 800 MB/s and 1,280 MB/s.

At 40 MHz the 37,249,024 matrix issue edges alone take 0.559 s less per
output. A scenario that holds all other wall times fixed gives 0.30067
tokens/s. Scaling all core and loader cycles while retaining baseline host
time gives 0.37624 tokens/s. Both scenarios assume particular stall
behavior. The same-board full-model benchmark measured the additional
core-clock edges required by the fixed-speed memory path.
[Baseline routed timing](../artifacts/pblaze3-profile-optimized-20261111-a1/route/timing.rpt).

## Reproducing the clock and matrix measurements

From the LunaChip root, export the vector core and generate the JTAG image
inputs in fresh directories. The current digital export selects 40 MHz.
The optional final argument to the build script selects 25 or 40 MHz;
historical exports that omit the JTAG clock field default to 25 MHz.

```sh
moon run --target native --release cmd/pblaze3 -- export-inference-256 /tmp/pblaze3-vector-digital
moon run scripts/pblaze3-jtag-inference-build.mbtx -- /tmp/pblaze3-vector-digital /tmp/pblaze3-vector-input
```

Keep the routed `diagnostic-routed.txt` next to the bitstream on the
Vivado bridge. Its clock check covers the core, loader and AXI bridge
registers. The bridge reports the active JTAG cable frequency and the
compute clock to LunaFlux. The optional last argument below checks the
client's copy of the physical report against that reply.

```sh
lunachip_qwen benchmark-fast "$contract" "$model_dir" "$association_label" "$new_result_dir" Hello 4 "$loopback_endpoint" "$qualification_json" "$routed_clock_report"
```

For the separate matrix experiment, generate the probe from the same
transport used for inference and invoke it through Vivado in attach mode
after the resident inference measurements. The probe uses the scratch
region starting at `0x60000000` and checks every output word of each shape.
The report reads the four real token programs to obtain descriptor frequencies.

```sh
moon run scripts/pblaze3-weight-shapes.mbtx -- "$transport_tcl" "$new_probe_tcl"
mkdir "$new_probe_dir"
PBLAZE3_CYCLE_PROFILE=1 vivado -mode batch -notrace -source "$new_probe_tcl" \
  -tclargs "$bit" "$ltx" "$model_safetensors" "$new_probe_dir/obs" 23511 30000000 attach \
  > "$new_probe_dir/vivado.stdout" 2> "$new_probe_dir/vivado.stderr"
echo "$?" > "$new_probe_dir/vivado.exit"
moon run scripts/pblaze3-weight-prefetch-report.mbtx -- "$new_result_dir" "$new_probe_dir" "$new_report_json" "$deployed_input_dir/job.json"
```

## Separate ordered MAC clock

The `export-inference-ordered-array` target uses a 75 MHz row scheduler, a
64-lane BF16-weight × FP32-activation array with its own clock, and the
512-bit 200 MHz MIG interface. The 1024-bit scheduler port transfers up to
one 128-byte weight vector per scheduler edge. BRAM holds two stripes. Each
stripe contains up to 512 rows by 256 columns, or 16 rows by 64 columns for
the packed layout. On each accepted command the scheduler writes the 32-bit
activation and 1,024 weight bits together to a 64-entry dual-clock RAM. A
32-entry asynchronous FIFO carries the payload address, row slot, phase,
and first/final-column flags. The MAC clock reads the payload at the head
address every edge. A phase match issues that payload exactly once. The
ring has room for the FIFO's 32 entries and its prefetched output words
even when the write pointer wraps. Earlier bitstreams carried the whole
command through the asynchronous FIFO.

The ordered FP32 adder returns to a given row every 18 array edges. The
scheduler assigns one, two, four or eight phases based on the row group and
preserves column order across stripes. Each lane rounds its product and sum
separately. Each stripe returns only its final-column words over a second
asynchronous FIFO. Completion of the final slot permits the bank exchange
and, after the last stripe, ordered scratch writeback.

The integrated build requests 400 MHz on the fractional MMCM output.
`pblaze3-ordered-system-clock.mbtx` generates the fixed-route physical divider
sweep. The accepted image must meet setup, hold and pulse width across the
full system, preserve the MIG and scheduler clocks, and pass the production
bitstream checks. Performance counters use the routed scheduler frequency.
The profiling script reconciles matrix bytes and handoffs against the actual
resident instructions and reports FIFO-credit wait separately from accepted
matrix issues. [System campaign](../artifacts/pblaze3-ordered-system-20261116-a1/RESULTS.md)

The optional fast-scheduler target stages each scratch write into one of
eight groups before filling the bridge's burst buffer. It accepts one word
per scheduler edge. Its clock experiment targets a 100 MHz scheduler,
300 MHz array, and 200 MHz registered AXI interface at the MIG. Produce
the Vivado inputs in new directories from the repository root.

```sh
moon run --target native --release cmd/pblaze3 -- export-inference-ordered-array-fast-scheduler "$digital"
moon run scripts/pblaze3-jtag-inference-build.mbtx -- "$digital" "$bundle" 100 registered-ui 300
moon run scripts/pblaze3-ordered-system-clock.mbtx -- "$sweep_tcl"
```

Run the bundle's `build.tcl` in Vivado 2026.1, then pass the absolute bundle,
completed implementation directory, a new output directory and `joint` to
the sweep recipe. That mode tests physical scheduler dividers from 100 MHz
down to 75 MHz with the MIG and debug frequencies fixed. It then sweeps
the MAC divider on the resulting route. The accepted image records both
clock domains in `diagnostic-routed.txt`. Runtime counters and loader
cycles use the scheduler clock; MAC edges run in a separate domain.

The `staged-add-group32` option on the fast-scheduler export enables 32 KiB
matrix reads for the three Qwen row pitches and registers the operands of
the vector FP32 adder. Each request transfers 64 row slices of 512 bytes.
Up to 16 native AXI read bursts can be outstanding. The original row-major
weights and resident programs work with either reader. The
`staged-add-group32-unary` option also stages the operands of the shared
nonlinear adder. Its micro-op retirement still takes three scheduler edges.

```sh
moon run --target native --release cmd/pblaze3 -- export-inference-ordered-array-fast-scheduler "$digital" staged-add-group32-unary
moon run scripts/pblaze3-jtag-inference-build.mbtx -- "$digital" "$bundle" 100 registered-ui 300
```

Use `staged-reduction` for the same 32 KiB reader with the SUM operand
selected before the third multiplier register. Use `staged-add-stripe512`
for 32 rows of 1 KiB each when the original row-major base is 1 KiB-aligned,
the row count is divisible by 64 and the row pitch is 2, 4 or 6 KiB.
Other shapes use the established readers. Each expanded weight bank holds
4,096 32-bit words. These variants accept the same LunaFlux resident programs
and checkpoint. Route and board results identify the scheduler and MAC clocks
individually. [Integrated measurements and full-logit checks](../artifacts/pblaze3-ordered-system-20261116-a1/RESULTS.md)

Use `staged-reduction-stripe512` to combine the registered reduction term
with the 1 KiB reader in one image. The matched 100 MHz comparison uses
`PBLAZE3_ALIGN_MATRIX_1K=1` in the same LunaFlux client during installation
and warm attachment, and the compact-layout 100 MHz image as its baseline.

On the PCIe PBlaze3, aligned 1 KiB reads with 512-row lookahead raised
Qwen3-0.6B from 5.7702 to 6.1663 tokens/s relative to aligned 32-row
groups. Both images used a 100 MHz scheduler, 282.353 MHz ordered array
and 200 MHz MIG. Exposed weight wait fell from 36.069 to 24.587 ms per
output, with 24 complete FP32 logit buffers checked per image.
[Matched PCIe results, bitstreams and counters](../artifacts/pblaze3-pcie-command-ram-20261118-c1/RESULTS.md)

The `staged-reduction-stripe512-writeback` and
`staged-reduction-stripe512-prefetch-writeback` exports use the existing
registered scalar ADD normalization and write the final streaming reduction
from its accumulator. The last retirement captures the rounded FP32 value
and enters the scratch write state. Scratch consumes that register on its
usual edge, including when a multi-row DOT advances to its next row. The
two profiles differ in weight lookahead.
They are timing experiments. The deployed PCIe comparison above uses the
original reduction writeback in both images.

The 2026-11-19 overlap audit separates the candidate's 123.593 ms matrix
phase into 93.123 ms of useful weight responses, 22.051 ms of reader
ownership without a response, and 8.420 ms without reader ownership.
Of the 24.587 ms exposed bank wait, 19.334 ms already receives data while
waiting for the complete bank. Nine exact-bridge simulations confirm zero
receive backpressure with an always-ready consumer, including gapped input.
Real MIG backpressure remains unmeasured. Instrument MIG handshakes and
outstanding reads before assigning the remaining gaps to a particular stage.
[Counter audit, readiness constraints and simulation evidence](../artifacts/pblaze3-memory-overlap-20261119-a1/RESULTS.md)
