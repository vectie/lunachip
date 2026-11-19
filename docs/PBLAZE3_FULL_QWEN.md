# Full Qwen3-0.6B on PBlaze3

## November 16, sustained 4.45 tokens/s on BF16 Qwen3-0.6B

Two independent LunaFlux invocations on the powered XC7K325T generated **4.450 and 4.453 tokens/s**. Each ran the same one-token `Hello` prompt three times, with four generated tokens per trial. Across all six trials the wall-clock rate was **4.452 tokens/s** including the first output and **4.384 tokens/s** on the subsequent 18 decode positions. The board ran at 75 MHz with a 200 MHz MIG and 30 MHz JTAG. Each token required one FPGA START. Both invocations uploaded and read back zero weight bytes. All 24 complete 151,936-entry FP32 logit vectors matched the frozen reference byte for byte after timing. [Matched board measurements](../artifacts/pblaze3-bf16-clock-target-20261115-a1/physical-comparison.json) · [First logit hashes](../artifacts/pblaze3-bf16-clock-target-20261115-a1/attention75/logits.sha256) · [Repeat logit hashes](../artifacts/pblaze3-bf16-clock-target-20261115-a1/attention75-repeat/logits.sha256)

The two runs averaged **14,266,602 FPGA cycles**, **190.22 ms** from START to DONE and **34.42 ms** outside FPGA execution per output. Useful DDR payload across wall time reached **5.313 GB/s**, or **41.50%** of the 12.8 GB/s MIG pin peak. The matrix still issued 9,312,256 ordered groups of 64 BF16-weight products per output. Exposed matrix weight waits fell from 3,971,034 cycles on the 60 MHz resident-input design to about 937,198 cycles. The wider read gathers sixteen 1,024-column stripes at a time. LunaFlux also combines adjacent Q/K/V projections and batches independent RoPE, head normalization and attention operations. [FPGA counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/attention75/cycles.json) · [Routed clocks](../artifacts/pblaze3-bf16-clock-target-20261115-a1/route-strided75/diagnostic-routed.txt) · [Tested 75 MHz bitstream](../artifacts/pblaze3-bf16-clock-target-20261115-a1/route-strided75/pblaze3.bit)

The same 75 MHz image also completed three eight-output trials from `Hello`. Across 24 outputs it generated **4.306 tokens/s** overall and **4.255 tokens/s** on the 21 subsequent decode positions. Each output averaged **15,094,528 FPGA cycles**. All 24 full logit vectors matched the eight-position reference produced by the earlier ISA simulator and program. [Eight-token measurement](../artifacts/pblaze3-bf16-clock-target-20261115-a1/eight-token-comparison.json) · [Independent reference hashes](../artifacts/pblaze3-bf16-clock-target-20261115-a1/control8-offline/emulator.sha256)

## November 16, BF16 clock and memory experiments

With the 60 MHz paired-row image, shared scratch reads and resident BF16 embedding lookup, LunaFlux generated **3.094 tokens/s** over the host interval and **3.069 tokens/s** after the first output. Each token used one START and averaged 17,455,463 cycles, 323.17 ms of wall time and 3.693 GB/s of useful DDR traffic (28.85% of pin peak). Returning the selected token with the completion snapshot reduced the measured host time outside execution to 32.25 ms. On the same image, a separate token read measured 2.975 tokens/s with a four-byte embedding pointer and 2.931 with a host-supplied embedding row. Each variant passed all twelve complete FP32 logit comparisons. [Same-image comparison](../artifacts/pblaze3-bf16-clock-target-20261115-a1/embedding-dispatch60-comparison.json) · [Physical counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/embed60-greedy/cycles.json)

At **60 MHz**, the ordered-reduction image generated **2.689 tokens/s**, with **2.674 tokens/s** on the nine subsequent decode positions. The board averaged 18,578,898 START-to-DONE cycles and 309.65 ms per token. The measured host interval was 371.89 ms per token. Useful DDR payload reached 3.209 GB/s, or 25.07% of the MIG peak. Each of the twelve full FP32 logit vectors matched. [Clock comparison](../artifacts/pblaze3-bf16-clock-target-20261115-a1/reduction60-comparison.json) · [Hardware counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/reduce60/cycles.json)

Streaming sum, sum of squares and scratch dot products in their original FP32 order raised the measured rate to **2.418 tokens/s**, including **2.384 tokens/s** after the first output. At the same 50 MHz core clock the change saved 2,440,869 FPGA cycles per output, taking the average to 17,925,657 cycles. Useful traffic reached 2.886 GB/s over the host interval, or 22.55% of the 200 MHz MIG interface peak. All 12 complete logit vectors passed. [Matched measurements](../artifacts/pblaze3-bf16-clock-target-20261115-a1/reduction50-comparison.json) · [Counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/reduce50/cycles.json)

With the staged descriptor decoder, the 50 MHz PBlaze3 generated **2.153 tokens/s** across three four-output trials. Decode after the first token ran at **2.103 tokens/s**. The same 30 MHz JTAG dispatch at 40 MHz generated 1.822 tokens/s. At 50 MHz each token averaged 20,366,526 FPGA cycles and 464.56 ms of host time. Useful DDR traffic divided by wall time was 2.569 GB/s, or 20.07% of the 12.8 GB/s pin peak. All twelve complete logit vectors matched the 40 MHz run byte for byte. [Matched clocks and stage timings](../artifacts/pblaze3-bf16-clock-target-20261115-a1/stage50-comparison.json) · [Full-model hardware counters](../artifacts/pblaze3-bf16-clock-target-20261115-a1/stage50/cycles.json)

## November 15, BF16 single-stream throughput

The powered 40 MHz board generated **1.822 tokens/s** with a one-token `Hello` prompt and four outputs, compared with **1.740** in the matched control. Sharing historical K/V between grouped query heads saved 504,647 FPGA cycles per token. Combining the input embedding, logits address and launch configuration into one verified JTAG batch then saved 15.90 ms of host time outside the FPGA counter. All twelve full FP32 logit vectors matched the prior implementation byte for byte. Both runs used 30 MHz JTAG and one START per position. Weight and program uploads during generation were zero. [Measurements, clock experiments and validation](../artifacts/pblaze3-bf16-clock-target-20261115-a1/README.md)

## November 15, shorter JTAG dispatch on the powered board

The full model generated **1.734 tokens/s**, up from **1.639 tokens/s** in the paired control. Both bridges used the same programmed image, 40 MHz core, 30 MHz JTAG, resident BF16 weights and one START per output. Queuing the two configuration writes, checking their readbacks together and polling a single completion snapshot recovered 33.38 ms of wall time per token. FPGA execution remained at 20.392 million cycles. The useful DDR payload divided by generation time rose from 1.958 to 2.071 GB/s, or 15.29% to 16.18% of the 12.8 GB/s MIG peak. The four independent client sessions uploaded and read back zero weight bytes. All 48 complete FP32 logit vectors passed after timing. [Physical comparison](../artifacts/pblaze3-warm-dispatch-20261115-a1/README.md) · [Run on the powered board](../artifacts/pblaze3-warm-dispatch-20261115-a1/RUN.md)

A separate LunaWave experiment compared the current weight layout with packets containing 64 rows for each input column. On a 384 × 1,024 GEMV at a simulated 16-cycle DDR latency, this advanced the first MAC issue from cycle 344 to 24. The complete matrix took 8,645 cycles with the current layout, 8,709 with direct column packets and 8,388 with column packets and an 8 KiB FIFO. The board measurements above use the current weight layout. [All simulated latencies and FIFO sizes](../artifacts/pblaze3-warm-dispatch-20261115-a1/layout.log)

## November 15, streaming exp and reciprocal at 40 MHz

On PBlaze3 the complete Qwen3-0.6B workload generated **1.61152 tokens/s**, up from **1.43371** on the earlier image and **1.44546** on the same image with legacy unary execution. Core cycles fell from 23.655 million to 20.089 million per output. Streaming exp and reciprocal saved 3.566 million cycles. The state counters accounted for all 6.448 million cycles in the previous `other` bucket. Host-time useful bandwidth reached 15.04% of the MIG peak. All twelve full logit vectors passed, at 40 MHz, 30 MHz JTAG and one START per output. Three fresh generation clients reused the model with zero weight upload or readback. Cold write-only transfer of the BF16 weights took 30.12 minutes. [Physical evidence and cycle breakdown](../artifacts/pblaze3-unary-stream64-20261115-a1/README.md) · [Cross-process residency](../artifacts/pblaze3-unary-stream64-20261115-a1/residency-report.json)

### Where the 620.53 ms per generated token goes

Each of the twelve timed outputs has a recorded range of four bridge requests. Joining those ranges to the transport log and converting its FPGA START-to-DONE counter at 40 MHz gives the following non-overlapping averages. The clock starts with the embedding update and includes the selected token read. Full logits are read after the timer stops. [Timed outputs](../artifacts/pblaze3-unary-stream64-20261115-a1/remote/run/benchmark/measurements.json) · [Bridge transactions](../artifacts/pblaze3-unary-stream64-20261115-a1/remote/run/transport/transport.tsv)

| Work per generated token | Mean ms |
|---|---:|
| FPGA START to DONE, 20,391,540 cycles | 509.79 |
| Remaining time inside the bridge launch command, including setup, polling tail and completion snapshot | 67.98 |
| Write the 4,096-byte FP32 input embedding and read it back | 23.37 |
| Arm the logits address and read it back | 10.91 |
| Read the 4-byte greedy token ID | 7.44 |
| Remaining client and transport time | 1.06 |

The board accounts for 82.15% of elapsed time. At the measured FPGA cycle count, zero host and transport overhead would yield 1.962 tokens/s, compared with the measured 1.612. This upper bound applies to the one-token prompt and four output positions tested. The bridge log measures an entire launch command. Timing its register operations separately would identify how much of the 67.98 ms can be recovered by batching setup or reducing the delay between DONE and the last poll.

External weight GEMV takes 309.83 ms per output. Of this, 59.16 ms (2,366,518 cycles) are spent waiting for a weight buffer to become ready. Weight packets already arrive in 83.89% of those stalled cycles. The existing loader fills a whole stripe before handing it to the 64 compute lanes. A candidate to test in simulation is a weight layout that places the 64 rows for a single input column together in one 128-byte response. Measure when computation can start, how many stalls disappear over a complete matrix, and whether the supply rate is sustained. Preserve ordered accumulation and check full logits before attributing an end-to-end gain to the layout. [Hardware stall counters](../artifacts/pblaze3-unary-stream64-20261115-a1/cycle-profile.json) · [Weight loader](../designs/qwen_layer/overlap.mbt)

## November 15, burst instruction reads at 40 MHz

On the same routed board image, changing only the resident program loader from scalar to burst reads increased end-to-end generation from **1.17269 to 1.43371 tokens/s (+22.26%)**. Program loading fell from **6,094,121 to 302,161 cycles/token (−95.04%)**. Total FPGA cycles from one START to DONE fell from 29,749,849 to 23,957,952. Useful DDR payload divided by wall time and MIG peak rose from **10.94% to 13.38%**; subsequent decode alone reached **1.39468 tokens/s**. All twelve full 151,936-entry FP32 vectors matched the same-image scalar mode, the previous chained run and the ISA reference; independent equation checks passed. Weights and programs were resident, JTAG ran at 30 MHz, and every timed output required one START.

A post-timing diagnostic measured 34,033 cycles in the first segment and 268,138 across all subsequent loads per token. Perfect next-segment overlap could recover only about **6.70 ms/token, or 0.97%**; no second program bank was added. [Physical report, exact timing conditions and prefetch decision](../artifacts/pblaze3-program-burst64-20261115-a1/README.md) · [Per-token measurements](../artifacts/pblaze3-program-burst64-20261115-a1/results/per-token.csv) · [Loader counters and overlap analysis](../artifacts/pblaze3-program-burst64-20261115-a1/program-burst-report.json)

## November 14, one host START per token at 40 MHz

On the same PBlaze3 image and resident weights, executing all program segments from one JTAG START increased generation from **0.68757 to 1.18630 tokens/s**. Subsequent decode rose from **0.65315 to 1.15494 tokens/s**. The twelve outputs required 12 host starts and completed all 114 FPGA segments. Chained dispatch overhead averaged **57.91 ms/token**, saving 579.73 ms (90.92%) against the historical 637.64 ms baseline and 607.46 ms (91.30%) against the same-session segmented control. The FPGA measured 29,798,376 START-to-DONE cycles per token. End-to-end useful DDR utilization rose from 6.42% to 11.07% of 12.8 GB/s, while matrix weight throughput measured 3.834 GB/s in both paired modes. Each of the twelve full 151,936-entry FP32 vectors matched the segmented run and the ISA emulator byte for byte. [Physical results and timing definitions](../artifacts/pblaze3-token-chain64-20261114-a1/README.md) · [Per-token measurements](../artifacts/pblaze3-token-chain64-20261114-a1/results/per-token.csv)

## November 13, coalesced FP32 writes on 64 lanes

On PBlaze3 the isolated logits-write stream fell from 2,279,041 to 37,984 FPGA response cycles per output (98.33% fewer). End-to-end generation moved from 0.66134 to 0.70419 tokens/s, and core plus instruction-loader time fell from 34,340,281 to 29,749,939 cycles per output. The complete logits matched for all twelve outputs. [Measurement and implementation](../artifacts/pblaze3-store-burst64-20261113-a1/README.md) and [per-token cycles](../artifacts/pblaze3-store-burst64-20261113-a1/per-token-cycles.csv).

## Coalesced FP32 vector loads on 64 lanes

Coalescing contiguous FP32 LOADs reduced measured scalar DDR response time from 11,504,480 to 3,400,720 cycles per output (70.44% fewer). Generation reached 0.66134 tokens/s versus 0.59049 (12.00% faster), and subsequent decode reached 0.63286 versus 0.56108 tokens/s. The FPGA averaged 28,239,440 core and 6,100,841 instruction-loader cycles per output. The same PBlaze3, LunaFlux binary, BF16 checkpoint, resident programs, raw `Hello` prompt, 40 MHz compute clock, 200 MHz MIG and 30 MHz JTAG were used. One warm-up preceded three four-output trials. Individual generation trials spanned 0.57802–0.59723 tokens/s before and 0.65728–0.66568 after. The timed loop read the four-byte FPGA argmax. Checkpoint transfer and independent reference validation ran outside timing. The twelve complete 151,936-entry FP32 logit vectors matched the baseline byte for byte. [Full-model A/B](../artifacts/pblaze3-scalar-load64-20261112-a1/comparison.json), [timed per-token cycles](../artifacts/pblaze3-scalar-load64-20261112-a1/per-token-cycles.csv), [scalar counters](../artifacts/pblaze3-scalar-load64-20261112-a1/scalar-profile.json) and [routed bitstream](../artifacts/pblaze3-scalar-load64-20261112-a1/route/pblaze3.bit).

## November 12, long weight bursts on 64 lanes

Each output waited 2,392,309 cycles for matrix weights, down from 30,952,100 (92.27% fewer). The 40 MHz core saved 713.99 ms per output in that stall alone. Measured generation changed from 0.40605 to 0.59049 tokens/s (45.42% faster). The nine subsequent decode positions reached 0.56108 tokens/s. Each output averaged 36,730,267 compute cycles and 6,141,245 loader cycles, totaling 42,871,512 at 40 MHz. One warm-up preceded three four-output trials from the raw prompt `Hello`. Trial generation rates ranged from 0.39923–0.41617 tokens/s on the previous image and 0.57802–0.59723 on the new image. The same LunaFlux executable verified 1,192,099,840 bytes of BF16 weights and installed 6,078,080 program bytes before timing. The timer includes FPGA argmax and the four-byte result over 30 MHz JTAG. All twelve full FP32 logit vectors matched the baseline byte for byte. Reading these logits took 15.70 s outside the timers, and the independent reference also ran outside them. [Board A/B](../artifacts/pblaze3-mig-prefetch64-20261112-a1/comparison.json), [phase counters](../artifacts/pblaze3-mig-prefetch64-20261112-a1/cycle-profile.json), [per-output timings](../artifacts/pblaze3-mig-prefetch64-20261112-a1/per-token-cycles.csv), [trial log](../artifacts/pblaze3-mig-prefetch64-20261112-a1/remote/run/benchmark/benchmark-result.json) and [routed clocks and interfaces](../artifacts/pblaze3-mig-prefetch64-20261112-a1/route/diagnostic-routed.txt).

## November 12, banked 64-lane inference

The banked 64-lane FPGA generated 12 tokens in **29.5531 seconds**
(**0.40605 tokens/s** overall, **0.39166 tokens/s** for nine subsequent
decode positions). Each output averaged 67,371,000 compute cycles and
6,771,168 instruction-loader cycles at 40 MHz. The 32-lane image generated
0.40721 tokens/s. Its three-trial range overlaps the banked image's range.
The 64-lane change saved 16.18 ms/output on the FPGA. Time outside the
compute and loader counters rose by 23.20 ms/output in this run.
[Full-model A/B](../artifacts/pblaze3-banked64-20261111-a1/comparison.json)
and [per-output timing](../artifacts/pblaze3-banked64-20261111-a1/per-token-cycles.csv).

Before timing, the same LunaFlux client verified all 1,192,099,840 weight
bytes over 30 MHz JTAG and installed 6,078,080 program bytes. Timed
generation returned a four-byte FPGA argmax per output. Full-logit reads
(16.04 s) and independent reference checks ran outside the timers. All
twelve 151,936-entry FP32 logit vectors matched the 32-lane run byte for
byte. The default export remains 32 lanes. Reproduce the qualified 64-lane
image with `export-inference-64-banked`.
[Resident programs](../artifacts/pblaze3-banked64-20261111-a1/residency.json),
[timing scope](../artifacts/pblaze3-banked64-20261111-a1/performance-summary.json)
and [routed resources and matrix stalls](PBLAZE3_WEIGHT_CLOCK.md).

## November 11, 32-lane inference

The 32-lane, 512-bit image measured **0.40721 tokens/s overall** and
**0.39653 tokens/s in decode**. Each token averaged 68,018,265 core
cycles plus 6,771,163 FPGA instruction-loader cycles. The batch-one run
used resident BF16 weights and programs, real 30 MHz JTAG and a 40 MHz
core. Reference execution and logit readback ran outside the timer.
The same twelve output logit vectors matched the 16-lane image byte for
byte. Reproduce the wide image with `export-inference-512` and the
16-lane baseline with `export-inference-256`.
[Measured comparison](../artifacts/pblaze3-inference512-20261111-a1/comparison.json)
and [weight stalls, bandwidth and resource counts](PBLAZE3_WEIGHT_CLOCK.md).

## November 11 40 MHz compute image

The 16-lane 256-bit inference export reaches **0.35763 tokens/s overall** and
**0.34696 tokens/s in decode** with resident BF16 weights, programs and
30 MHz JTAG. The 25 MHz vector image on the same card reached 0.25743 and
0.25082 tokens/s. Each output now takes 79,545,315 core cycles and
6,771,174 loader cycles on average, or 2.158 s of combined FPGA activity.
The matrix consumes 886.10 MB/s of weights, 69.23% of the 1,280 MB/s
compute-side peak. All twelve output logit vectors matched the 25 MHz run
byte for byte. [Matrix measurements and reproduction](PBLAZE3_WEIGHT_CLOCK.md)
and [full-model comparison](../artifacts/pblaze3-weight-clock40-20261111-a1/comparison.json).

## November 11 profiled vector image

The 25 MHz vector image generated 12 tokens in
46.615 seconds on the XC7K325T. LunaFlux measured **0.25743 tokens/s**
including the first output and **0.25082 tokens/s** for subsequent decode.
The same-board instrumented streaming baseline measured 0.21980 and
0.21366 tokens/s. Each output now averages **75,989,183 core cycles** plus
**5,791,231 instruction-loader cycles** at 25 MHz. Both runs used 30 MHz
JTAG, resident BF16 weights and resident programs. All twelve full FP32
logit vectors matched byte for byte. [Phase breakdown and reproduction](PBLAZE3_QWEN_CYCLE_PROFILE.md)
and [physical A/B results](../artifacts/pblaze3-profile-optimized-20261111-a1/comparison.json).

## November 11 streaming memory path

The XC7K325T generated **0.22054 tokens/s**, a **12.11×** improvement over
the serialized master on the same board. After the first token, decode reached
**0.21481 tokens/s**. Both measurements used the same LunaFlux executable,
Qwen3-0.6B checkpoint, raw `Hello` prompt, batch size one, FPGA argmax, 25 MHz
core and 30 MHz JTAG. After one warm-up token, three independent trials each
generated four tokens. [Measured comparison](../artifacts/pblaze3-bandwidth-20261111-a1/comparison.json).

| Physical measurement | Serialized 128-bit master | Streaming 256-bit master |
|---|---:|---:|
| 12 tokens including first output | 658.930 s | 54.412 s |
| Mean seconds per output | 54.911 | 4.534 |
| Mean time to first output | 54.530 s | 4.172 s |
| Decode throughput, 9 tokens | 0.01817 tokens/s | 0.21481 tokens/s |
| Mean FPGA core cycles per output | 1,351,697,441 | 91,916,158 |
| Mean FPGA loader cycles per output | 5,791,234 | 5,791,245 |
| Useful DDR payload per second of core execution | 22.09 MB/s | 324.88 MB/s |
| Useful payload as a fraction of the compute AXI port's peak | 5.52% | 40.61% |
| Arithmetic products per core cycle | 0.442 | 6.497 |

The hardware counted the same 7,165,653,036 products and 3,583,409,664
logical 32-bit DDR words across the two runs. Payload bandwidth divides these
bytes by core-active time, including memory stalls and arithmetic. It measures
application throughput. Actual DDR pin occupancy requires separate counters.
Across the new trials the core ran for 44.120 s, the instruction loader for
2.780 s, and host dispatch, transfers and polling accounted for the remaining
7.512 s. [Counters and timing](../artifacts/pblaze3-bandwidth-20261111-a1/performance-summary.json).

| Output position | Token ID | Mean core cycles | Mean loader cycles |
|---:|---:|---:|---:|
| 0 | 21806 | 85,870,370 | 4,930,593 |
| 1 | 0 | 89,902,430 | 5,504,366 |
| 2 | 358 | 93,929,570 | 6,078,122 |
| 3 | 2776 | 97,962,263 | 6,651,901 |

Every trial produced `[21806, 0, 358, 2776]`. All 151,936 FP32 logits at
each of the twelve measured outputs matched both the earlier board run and
the ISA replay byte for byte. The independent equation reference chose the
same tokens. Maximum absolute logit error was 0.00009071827. Full logit
reads (16.224 s) and reference checks ran outside the generation timers.
The cold JTAG upload and readback of 1,192,099,840 weight bytes took
4,394.020 s. The client also verified 6,078,080 program bytes. All 114 timed
launches used resident programs, with zero timed weight or program uploads.
These results cover short-context, batch-one inference.
[Per-token samples](../artifacts/pblaze3-bandwidth-20261111-a1/per-token-cycles.csv),
[residency audit](../artifacts/pblaze3-bandwidth-20261111-a1/residency.json)
and [numerical checks](../artifacts/pblaze3-bandwidth-20261111-a1/remote/run/benchmark/validation-progress.json).

The inference image uses a 256-bit AXI master at 25 MHz, a 256-bit MIG AXI
port at 200 MHz, and the board's 64-bit DDR3-1600 bus. Their respective
one-direction ceilings are **800 MB/s**, **6.4 GB/s** and **12.8 GB/s**.
The 30 MHz JTAG link is used for setup, launch and readback. During a
resident decode the accelerator reads the weights directly from DDR.
[Routed clocks](../artifacts/pblaze3-bandwidth-20261111-a1/route/diagnostic-routed.txt),
[AXI properties](../artifacts/pblaze3-bandwidth-20261111-a1/route/transport-properties.txt)
and [MIG configuration](../artifacts/pblaze3-bandwidth-20261111-a1/route/mig-effective.prj).

Previously the master waited for each 16-byte response before sending the
next address. It now issues one four-beat incrementing burst per 128-byte
weight row. The bridge tracks up to sixteen rows and the deployed crossbar
accepts up to eight reads in flight. Each accepted data beat supplies eight
32-bit words to the existing compute core. A 2,048-byte K=1024 strided test
returned identical words in 87 simulated core cycles with the deployed
eight-credit setting, down from 2,761 cycles. This test applies a sixteen-cycle
first-response delay and address-channel stalls.
[Crossbar configuration](../artifacts/pblaze3-bandwidth-20261111-a1/route/crossbar-credits.txt)
and [cycle comparison](../artifacts/pblaze3-bandwidth-20261111-a1/credit-bridge-test.log).

To reproduce the inference input bundle, use two fresh directories. The
existing PCIe bring-up target has its own export.

```sh
moon run --target native --release cmd/pblaze3 -- export-streaming-baseline /tmp/pblaze3-stream-digital
moon run scripts/pblaze3-jtag-inference-build.mbtx -- /tmp/pblaze3-stream-digital /tmp/pblaze3-stream-input
```

## November 11 physical baseline

LunaFlux ran the complete 28-layer Qwen3-0.6B model and output head on the
PBlaze3 XC7K325T using the November 10 bitstream. The physical target reported
30,000,000 Hz JTAG TCK for inference. The FPGA core and its instruction loader
ran at 25 MHz. The Linux client used the local Vivado bridge and a monotonic
host timer. Batch size was one. The raw prompt `Hello` encoded to token 9707.
After one warm-up token, all three trials generated `[21806, 0, 358, 2776]`,
which decodes to `" Answer! I'm"`.

| Metric | Measured result |
|---|---:|
| Generation including first token | 12 tokens in 658.930111 s, **0.01821134 tokens/s** |
| Decode after the first token | 9 tokens in 495.341000 s, **0.01816930 tokens/s** |
| Mean time to first token with resident weights and programs | 54.529700 s |
| Elapsed time for four generated tokens, by trial | 219.752078 s, 219.613247 s, 219.564785 s |
| FPGA core execution, all 114 timed launches | 16,220,369,296 cycles, 648.814772 s |
| FPGA instruction loading, all timed launches | 69,494,811 cycles, 2.779792 s |

The table below gives the **exact sum of core and loader cycles** for each
physical token. Each sequence covers its packed instruction windows. Core-only
cycles, loader cycles, host times and token IDs for each sample are available
in the [per-token CSV](../artifacts/pblaze3-fast-physical-20261111-a1/per-token-cycles.csv).

| Position | Phase | Output ID | Launches | Trial 1 | Trial 2 | Trial 3 |
|---:|---|---:|---:|---:|---:|---:|
| 0 | Prefill / first output | 21806 | 8 | 1,350,593,297 | 1,350,593,384 | 1,350,593,385 |
| 1 | Decode | 0 | 9 | 1,355,193,573 | 1,355,193,660 | 1,355,193,526 |
| 2 | Decode | 358 | 10 | 1,359,787,104 | 1,359,787,183 | 1,359,786,842 |
| 3 | Decode | 2776 | 11 | 1,364,380,760 | 1,364,380,716 | 1,364,380,677 |

Core execution including DDR stalls accounted for 98.46% of elapsed
generation time. Instruction loading took another 0.42%. The remaining
7.336 s across 12 tokens includes host work, JTAG dispatch and polling gaps.
The counters cover time spent inside completed FPGA launches. The tokens/s
figures use elapsed host time including the embedding transfer, argmax setup,
all launches and polling, and the four-byte token-ID read.

Before warm-up, the client uploaded and read back 1,192,099,840 bytes of
weights in 4,387.129 s of wall time. It also uploaded and verified 6,078,080
bytes of packed instructions and preloaded the per-position RoPE constants.
The trace shows zero weight or instruction uploads inside the three trials.
The programs stayed in DDR and the FPGA loaded each window into instruction
RAM. All 114 launch addresses and sequence-bracketed counter snapshots matched
the resident plan. [Transport audit](../artifacts/pblaze3-fast-physical-20261111-a1/performance-summary.json)
and [program residency audit](../artifacts/pblaze3-fast-physical-20261111-a1/residency.json).

After each trial stopped its timer, the host read the full logits for all
four positions. These reads took 15.700 s in total. After all trials, all
151,936 FP32 words at each position matched the ISA replay byte for byte in
all three trials. The independent equation reference selected the same tokens
with maximum absolute logit error 0.00009071827. The first two positions also
matched the archived October board captures byte for byte. This run covers
four generated tokens at short context. [Physical observations](../artifacts/pblaze3-fast-physical-20261111-a1/remote/run/benchmark/benchmark-result.json)
and [reference checks](../artifacts/pblaze3-fast-physical-20261111-a1/remote/run/benchmark/validation-progress.json).

The initial board qualification caught an AXI SLVERR on the 56-byte counter
burst, before model upload. On the same image, single-word reads succeeded
and the complete burst succeeded with ARCache set to zero. The bridge now
uses that setting for the counter mirror and keys its transaction pool by
cache attribute. Both operator qualifications and the repeated 64 KiB
transport check passed before the measured run. The owned hardware server
was stopped and original USB permissions restored on the guest and host.
The board was left powered with the programmed image and DDR contents.

## November 10 resident decode

The XC7K325T build finished at 23:56:59 Asia/Shanghai. The deployable
bitstream, probes and reports are in
`artifacts/pblaze3-qwen-fast-20261110/route/`. The sealed receipt identifies
the matching `inputs-a4` bundle. WNS/WHS/WPWS were +0.177/+0.051/+0.062 ns,
with zero failing endpoints. All 22 bus-skew checks passed. Minimum slack
was +4.254 ns. Board programming and physical token-rate measurement remain
deferred at the user's requested stopping point.

| Measured build interval | October 30 | November 10 |
|---|---:|---:|
| Synthesis, launch to finish | 23 min 17 s | 5 min 6 s in the final warm-cache synthesis test |
| Implementation, launch to finish | 17 min 18 s | 10 min 46 s for the delivered bitstream |
| Start of the synthesis build used for the bitstream to final Vivado exit | 47 min 44 s | 25 min 12 s including a checkpoint resume |

The delivered image used the synthesis checkpoint from `build-a3`. A
post-synthesis IP query failed on the top-level run. The resume rechecked
all synthesis logs and used identical RTL, constraints and routing gates.
The elapsed time from the first November vendor attempt through the final
bitstream, including the earlier cache and license retries, was 41 min 44 s.
VM recovery preceded those attempts. The 5 min 6 s synthesis test used
`inputs-a5`, which has identical RTL and constraints and corrects the shared
cache directory layout. Vivado exported 13 IP instances from cache and ran
the four remaining independent modules and top-level synthesis. The build
phases were measured on two revisions of the controller.

LunaChip's full native release suite passed 1365/1365. LunaFlux passed
5396/5396 in its full native release suite and 28/28 in the final adapter
and diagnostic test run. Verilator matched LunaWave on every retained edge,
pinned Yosys synthesis passed, and the positive/negative bounded formal gates
returned their expected results.

LunaFlux `benchmark-fast` packs consecutive straight-line layer programs into
2047-operation instruction windows with a final HALT. Scratch and KV persist
across window boundaries. The host uploads each position's RoPE constants once.
Each position writes its logits into a separate DDR slot. As stores complete,
the controller selects the first finite FP32 maximum, treating both signed
zeros equally. An incomplete, out-of-order or nonfinite vector invalidates the
result. Timed generation reads the four-byte token ID. After each trial timer
stops the client captures every position's full logits, then performs numerical
reference checking after the three trials.

For `Hello`, the ISA simulator generated tokens 21806 and 0 using eight and
nine launches. The previous plan used 29 launches for each position. Both
151936-word result vectors were byte-identical to the archived October physical
outputs. Use `simulate-fast` for offline execution and `benchmark-fast` for
the image advertising capability 0x94. The earlier image uses `benchmark`.

```sh
lunachip_qwen simulate-fast CONTRACT MODEL_ROOT LABEL_64_HEX NEW_OUTPUT 'Hello' 2
lunachip_qwen benchmark-fast CONTRACT MODEL_ROOT LABEL_64_HEX NEW_OUTPUT 'Hello' 4 127.0.0.1:23511 QUALIFICATION_JSON
```

The JTAG inference build defaults to four concurrent synthesis jobs. The build
VM can set `PBLAZE3_BUILD_JOBS` to 1..8. A previous build supplied through
`--reuse-ip-cache` seeds a private working cache. Vivado checks the current IP
configuration key against the verified cache for its release. The BASIC
license supports ordinary placement and routing. Set `PBLAZE3_INCREMENTAL=1`
on the build VM only when a license covering incremental implementation is
available. The final reports and bitstream come from the open routed design.
See [AMD's IP cache command reference](https://docs.amd.com/r/en-US/ug835-vivado-tcl-commands/config_ip_cache).

For software-only iterations, this command checks the input inventory, pinned
tool identity, output digests and build result against a sealed campaign and
returns the usable bitstream and probes directly.

```sh
moon run scripts/pblaze3-build.mbtx -- reuse ABS_INPUT_BUNDLE EXPECTED_TOOL_PIN SEALED_CAMPAIGN RELATIVE_BUILD_DIR
```

## October 30 build

Resident performance preparation (2026-10-30): the new bitstream was generated
successfully at 01:12 UTC (09:12 Asia/Shanghai). At the user's request this
phase ended before programming: no new image or model was loaded, and there
is no new measured tokens/s or physical 30 MHz qualification. The cable's
advertised frequency list includes 30 MHz. The owned JTAG server was stopped
and temporary USB ownership restored. The board retains its previous image.

The retained bitstream and probes are in
`artifacts/pblaze3-qwen-resident-20261030-a1/remote-evidence/build-a3/`.
Final WNS/WHS/WPWS are +0.177/+0.037/+0.062 ns; all 22 bus-skew checks pass
(minimum +4.467 ns), with no unconstrained internal timing endpoints. The
new controller passes six targeted tests, canonical simulation/Verilator
replay, pinned synthesis and positive/negative bounded formal gates.
LunaFlux passes 19 adapter tests and seven diagnostic tests, including seven
tests on the Linux measurement client. Full LunaChip native checking passed;
the longer full native test suite was interrupted at the requested stopping
point and is not claimed as a completed regression for this image.

Implementation: keep selected weights and
all prepared descriptor programs in DDR. A checked controller loader stages
one DDR program into the existing instruction RAM before starting the unchanged
arithmetic core. ABI 1.1 gains optional capability `0x90 = 1`, a 64-byte-aligned
program DDR base at `0x3c` (zero selects the legacy host-loaded program), and
loader cycles at `0x40`. Accepted START covers loading and execution; BUSY masks
stale DONE during loading, and any loader DDR/health fault poisons the launch.
Program bounds are checked against the complete 2 GiB aperture before START.
No model or descriptor upload belongs in the measured token loop.

Measure monotonic host generation time separately from the sum of FPGA
64-bit execution cycles (`0x24/0x28`, 25 MHz) and loader cycles. Host timing
includes embedding/RoPE transfer, dispatch, output transfer and greedy sampling;
it excludes warm-up, one-time preparation/upload and all reference checking.
Retain every measured logit vector, then run the ISA interpreter and independent
equation reference after timing. Report actual generated tokens/time, prefill
and decode separately, sample counts and context length. Raise JTAG toward
30 MHz only after clock, readback and execution qualification. The previous
two-token run is correctness evidence, not a clean performance baseline.

The new clock recipe preserves the 25 MHz core and 200 MHz MIG UI and adds a
100 MHz MMCM output for the debug hub. AMD requires a debug-hub/JTAG ratio of
at least 2.5 for this architecture; 100/30 satisfies that constraint, whereas
the previous 50 MHz hub did not. See [UG908, Programming the Hardware Device](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Programming-the-Hardware-Device).
Discovery/programming remain at 10 MHz until the new image is loaded, then
the bridge requests and reads back the actual 30 MHz target setting. Physical
readback and numerical execution still decide acceptance in a future on-board
run, with a fresh evidence directory rather than appending to this build record.

The `benchmark` CLI runs on the Linux VM next to the vendor bridge, using a
loopback socket; SSH is only orchestration, outside inference scheduling.
It performs legacy and DDR-resident operator qualification, a repeated
cross-page 64 KiB transport test, one verified model/program upload, one warm-up,
then three measured trials. Every launch returns a stable sequence-bracketed
64-bit core-cycle snapshot and a separate loader-cycle count. The trace audit
requires exactly the embedding and RoPE input writes and a full-logit read per
position; weight or program uploads inside any timed interval fail acceptance.
Raw timings and all three trials' full logits are saved before reference replay.

For a qualified 30 MHz bridge and the resident-loader image, run the release
client on that same Linux machine:

```sh
moon run --target native --release --warn-list '-20-25-29-35-79-92' cmd/lunachip_qwen -- benchmark CONTRACT MODEL_ROOT ASSOCIATION_LABEL_64_HEX NEW_OUTPUT 'Hello' 4 127.0.0.1:23511 QUALIFICATION_JSON
```

Programs remain in DDR and are staged by FPGA into its existing instruction
RAM per launch. Reported host tokens/s includes this staging, dispatch/polling,
the complete 607744-byte logits download and host greedy sampling. The
core-cycle-derived rate excludes those costs and is explicitly a compute-only
equivalent, not the achieved generation rate. This short-context batch-one
test does not establish long-context or concurrent-request throughput.

2026-10-30. Full-model physical diagnostic passed, single agent. The board has
only power and JTAG; PCIe is unavailable. LunaFlux ran all 28 Qwen3-0.6B layers,
the output head and a second decode step on the PBlaze3. Existing DDR BIST and
single-operator evidence remain separate and immutable.

LunaFlux owns the complete 28-layer plan, checkpoint inspection/streaming,
tokenization, session/KV ownership, output-head tiling and greedy generation.
LunaChip owns the unchanged BF16-weight/ordered-FP32 arithmetic core, checked
ISA/device ABI, standalone JTAG hardware composition and physical evidence.
There are no cross-repository package imports or CPU substitutions for device
normalization, attention, softmax, SiLU, residuals or matrix computation.

The target remains batch one, at most 2048 total tokens, BF16 row-major weights
and FP32 activations/KV. All 28 layers and the tied embedding/output matrix
remain resident in the tested 2 GiB DDR aperture. Small norm vectors have FP32
copies. Host-generated RoPE constants are immutable model inputs. Embedding
lookup and sampling are host operations; transformer arithmetic runs on FPGA.

The standalone image uses the physical 50 MHz oscillator for the debug hub,
an explicit conservative 25 MHz compute/JTAG AXI domain, and the existing
200 MHz MIG UI. It has no PCIe clock, reset or link dependency. JTAG maps DDR
at 0..0x7fffffff, status GPIO at 0x80000000 and the unchanged relative control
ABI at 0x80100000. Source lock and MIG UI reset coordinate transaction reset;
calibration is synchronized as readiness, not used to gate clocks.

Implementation and acceptance order:

1. Build the independent JTAG accelerator image and check actual clocks,
   reset/CDC, ID routing, setup/hold/pulse coverage and DRC before programming.
2. Extend checked descriptors for all existing layer operators. Compile
   head-at-a-time attention with DDR-backed KV rather than enlarging the old
   four-token scratch fixture. Preserve ordered reductions across tiles.
3. Reuse the Qwen source binder and complete memory layout. Stream only the
   selected tensor ranges; ignore a redundant tied-head payload. No full
   checkpoint hashing or FP32 expansion of all weights is introduced.
4. Execute the complete plan in an independent numerical simulator, compare
   full logits and greedy tokens with a separately written Qwen reference,
   and use canonical hardware/RTL replays for new operator sequences.
5. Load only this identified PBlaze3 volatile FPGA, qualify the transport with
   known workloads, upload weights, then run real prompt/prefill/decode through
   LunaFlux and compare actual outputs. Keep failed attempts and distinguish
   kernel, transfer and end-to-end times. Never claim physical success from
   host simulation or bitstream generation.

This is an experimental diagnostic deployment, not production serving or
CUDA numerical equivalence. The physical model/capacity, transport ownership
and full-model numerical gates passed for the two-position diagnostic below.

Physical acceptance completed at 2026-10-30 00:11 Asia/Shanghai. All
1,192,099,840 selected BF16 weight bytes were uploaded and independently read
back from DDR. The raw prompt `Hello` (9707) generated ` Answer!` (21806, 0).
Both positions' complete 151936-word logits match the ISA interpreter bit for
bit (303872 words total); greedy tokens match the independent equation
reference. Maximum absolute reference errors are 0.000013828277587890625
and 0.00009071826934814453 respectively. This verifies a complete prefill
position and a subsequent KV-backed decode, not a measured 2048-token run.
Evidence lives under `artifacts/pblaze3-full-qwen-20261029-a1`; actual outputs
and the physical result are in `physical-a1/`.

- LunaFlux now prepares all 28 layers, final RMSNorm and all 151936 tied-head
  rows. The typed plan supports positions 0..2047 and bounded 2048-descriptor
  launches. The diagnostic CLI limits one run to 64 total / 16 new tokens.
- Two real-checkpoint software runs cover eight positions and 1,215,488 full
  logits: `Hello` generates ` Answer!`, and `The capital of France is`
  generates ` Paris.`. Greedy choices agree with the separate equation
  reference; maximum absolute logit error is 0.00009071826934814453.
  This is evidence for the ordered FP32 FPGA profile, not CUDA BF16 equality.
- The transformer fixture passes LunaWave and pinned Verilator 5.050 at all
  5706 edges. The combined BF16/transformer fixture passes all 12291 edges:
  34 descriptors, 484 AXI read beats, 42 output words and 18 guards.
  Its replay reuses the pinned compiled model after checking identical RTL
  and harness logic. Only the embedded trace-header stimulus label differs;
  the raw historical label is retained and current stimulus bound separately.
  Every output sample is compared exactly. Failed attempts remain retained.
- Routed clocks are 25 MHz compute, 200 MHz MIG UI and 50 MHz debug hub.
  WNS/WHS/WPWS are +0.177/+0.052/+0.062 ns; all 22 bus-skew checks pass
  (minimum +4.211 ns). There are no unconstrained internal endpoints or
  critical synthesis/route/DRC diagnostics. Vendor CDC/PHY advisories and
  their scope are recorded in `physical-review.txt`.
- Physical qualification passed GPIO health, ABI 1.1, the 2 GiB aperture,
  all 42 exact FP32 results and 18 guards, followed by the 8192-byte
  asymmetric transport test crossing a 4 KiB boundary. TCK is 10 MHz.
  Observed full write/readback transport costs approximately 5 seconds/MiB;
  this is a startup transfer measurement, not model inference throughput.
- Full strict LunaChip native tests pass 1361/1361. LunaFlux passes 19
  adapter/plan tests and five diagnostic tests, including a fragmented
  full-vocabulary TCP read. Full native checks and formatting/API generation
  pass under the documented LunaFlux migration-warning exclusions. Failed
  attempts and the original running-client source snapshot are retained.

The image was programmed only into Digilent cable 261020153153, FPGA
xc7k325t_0 / IDCODE 43651093. No SPI flash was written and the original PRX100
was not programmed. The test's JTAG services and SSH forwards are stopped;
the temporary USB ownership is restored. FPGA configuration and DDR contents
are volatile: power loss requires image/weight loading again. The diagnostic
CLI performs a fresh checked upload per invocation. No persistent serving
session, PCIe result, long-context physical validation or tokens/s benchmark
is claimed by this first full-model result.

The source is official Qwen/Qwen3-0.6B revision
`c1899de289a04d12100db370d81485cdf75e47ca`. The local and remote source headers
and byte counts are compared; selected tensor ranges are uploaded from the
remote checkpoint and checked by full DDR readback. The full checkpoint is
neither hashed nor archived; retained model inputs include small expanded
normalization vectors. The association label does not authenticate the full
checkpoint.

Reproduce with sibling checkouts and three model files (`config.json`,
`tokenizer.json`, `model.safetensors`). Export the device contract with
`moon run --target native cmd/pblaze3 -- contract`. In LunaFlux, run:

```sh
moon run --target native --release --warn-list '-20-25-29-35-79-92' cmd/lunachip_qwen -- simulate CONTRACT MODEL_ROOT ASSOCIATION_LABEL_64_HEX NEW_OUTPUT 'Hello' 2
moon run --target native --release --warn-list '-20-25-29-35-79-92' cmd/lunachip_qwen -- physical CONTRACT MODEL_ROOT ASSOCIATION_LABEL_64_HEX NEW_OUTPUT 'Hello' 2 127.0.0.1:23511 QUALIFICATION_JSON
```

Physical mode requires the separately reviewed image and a fresh vendor bridge
from `scripts/pblaze3-jtag-inference-server.mbtx`, forwarded through SSH loopback
only. `QUALIFICATION_JSON` is the combined fixture retained above. The bridge
accepts one connection, enforces request sequence and bounded address ranges,
and poisons the session on uncertain I/O. It never reconnects/retries a START
or reuses partially uploaded weights. Keep the host and board powered for the
whole upload and inference. The current session writes no SPI flash.
