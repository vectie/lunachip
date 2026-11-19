# PBlaze3 Qwen3-0.6B cycle attribution

The comparison uses the resident LunaFlux batch-one benchmark, the raw prompt
`Hello`, one warm-up token and three four-token trials. The 25 MHz core and
30 MHz JTAG match the November 11 streaming-image run. The metric previously
reported as 40.6% divides logical DDR payload by all active core seconds and
the 800 MB/s compute-side AXI ceiling. The instruction loader has a separate
counter and runs while the core is idle.

## Physical A/B result

The vector image generated **0.25743 tokens/s** end to end and **0.25082
tokens/s** after the first output. The instrumented baseline measured
0.21980 and 0.21366 tokens/s respectively. The deployment command is
`moon run --target native --release cmd/pblaze3 -- export-inference NEW_DIRECTORY`.
Its output matches the tested image's digital inputs byte for byte.
[Image comparison](../artifacts/pblaze3-profile-optimized-20261111-a1/comparison.json)
and [default export check](../artifacts/pblaze3-profile-optimized-20261111-a1/default-export.log).

| Measurement | Instrumented baseline | Optimized |
|---|---:|---:|
| Generation time, 12 outputs | 54.595 s | 46.615 s |
| Core cycles/output | 91,891,034 | 75,989,183 |
| Instruction-loader cycles/output | 5,791,235 | 5,791,231 |
| Core + loader cycles/output | 97,682,269 | 81,780,415 |
| Exposed weight wait, cycles/output | 10,465,643 | 10,466,488 |
| Matrix issue, cycles/output | 37,249,024 | 37,249,024 |
| Nonlinear execution, cycles/output | 10,472,401 | 3,869,004 |
| Other compute/control, cycles/output | 16,992,785 | 7,697,377 |
| Scalar DDR request and response, cycles/output | 12,107,780 | 12,103,889 |
| Matrix weight MB/s during matrix phases | 576.36 | 576.35 |
| Useful DDR MB/s over all core-active time | 324.97 | 392.97 |
| Fraction of the 800 MB/s compute port | 40.62% | 49.12% |

The core saved 15,901,851 cycles/output. Shorter nonlinear and other
compute/control phases account for 15,898,805 of them. Across the four
elementwise add/multiply/sign-setting/conditional-multiply opcodes, execution
fell from 10,609,808 to 2,709,032 cycles/output. The matrix phases now occupy
68.04% of core time. Weight delivery during those phases remained within
0.01 MB/s of baseline. The program loader still stages the identical
resident instruction windows into BRAM. [Measured phase deltas](../artifacts/pblaze3-profile-optimized-20261111-a1/phase-comparison.json).

| Output position | Token ID | Baseline core cycles | Optimized core cycles | Optimized loader cycles | Optimized host seconds |
|---:|---:|---:|---:|---:|---:|
| 0 | 21806 | 85,856,786 | 71,045,732 | 4,930,590 | 3.578 |
| 1 | 0 | 89,881,890 | 74,346,849 | 5,504,344 | 3.794 |
| 2 | 358 | 93,902,836 | 77,647,827 | 6,078,113 | 3.978 |
| 3 | 2776 | 97,922,625 | 80,916,326 | 6,651,878 | 4.189 |

The table averages three real trials per position. On the optimized image
36.475 seconds of the generation timer were core execution, 2.780 seconds
were instruction staging, and 7.361 seconds were host dispatch, JTAG and
polling. All 114 timed launches used resident programs. Cold weight transfer
and verification took 4,351.468 seconds of transport time. Deferred full-logit
reads took 16.319 seconds outside generation. The client, model, device
contract, programs and constants matched across images. Every one of the
12 output vectors matched the baseline and ISA replay byte for byte across
151,936 FP32 logits. The independent equation reference agreed on every
token, with maximum absolute logit error 0.00009071827. An additional
untimed four-token replay captured the individual phase counts and verified
the full logits again. [Timed token samples](../artifacts/pblaze3-profile-optimized-20261111-a1/per-token-cycles.csv),
[per-position phase replay](../artifacts/pblaze3-profile-optimized-20261111-a1/phase-per-token.csv),
[input identities](../artifacts/pblaze3-profile-optimized-20261111-a1/inputs-comparison.log)
and [reference checks](../artifacts/pblaze3-profile-optimized-20261111-a1/remote/run/benchmark/validation-progress.json).

## Counter semantics

`cmd/pblaze3 export-profile` enables cumulative, read-only 32-bit counters
in the PBlaze3 AXI-Lite controller. The block begins at local offset `0x100`
with magic `0x50465231`. An accepted-launch sequence number precedes and
follows the counters. The collector reads the block while the device is idle
using a noncacheable 164-byte AXI burst. Subtracting the before and after
samples modulo 2^32 gives the counts across one trial. Each trial is shorter
than one counter wrap at the maximum rate of one increment per core edge.

| Edges or events | Physical meaning |
|---|---|
| Core busy | Same active edges as the existing per-launch 64-bit core counter |
| Bank, handoff | Matrix state 18 waits for or admits a complete 2 KiB stripe. Each successful 18 → 20 transition accounts for one admission edge. Bank minus handoff counts exposed weight stalls |
| Issue, drain, advance, row write | Matrix states 20, 21, 22 and 23. Issue advances 16 ordered products every edge on this image |
| Descriptor | Instruction RAM fetch, decode and retirement, states 1, 2, 3 and 13 |
| Data request, data response | States 9 and 10 for non-overlapped DDR operations, including load and store |
| Unary, other | Dedicated nonlinear states and the remaining active states, respectively |
| Weight packet, packet during issue | Wide packets returned to the core. Each contains eight logical words. The second count measures simultaneous weight delivery and arithmetic issue |
| First wait, gap wait | Controller edges with a wide read issued and no data response, before the first packet or between packets. The bank-qualified versions count only those edges exposed in state 18 |
| Loader request, response, launch | DDR instruction-staging states 1, 2 and 3. Their sum matches the existing per-launch loader cycle count |
| Opcode 0 through 15 | Scalar execution by opcode. Excludes descriptor and parallel matrix states. Its sum must match data request, data response, unary and other |

The bridge collector samples before the host starts a trial timer and on the
first deferred full-logit read after the timer stops. These reads issue no
extra transactions in the timed token path. A separate diagnostic can replay
the same resident programs and capture the hardware counters per token.

## Baseline in normal inference

Three four-token trials on the instrumented streaming image generated 12
outputs in 54.595 s (0.21980 tokens/s, decode 0.21366 tokens/s). Core and
loader execution took 44.108 s and 2.780 s. The other 7.707 s includes normal
host dispatch, JTAG transactions and polling. The target ran the same
resident programs at 25 MHz with a 30 MHz cable. [Physical benchmark](../artifacts/pblaze3-cycle-profile-20261111-a1/performance-summary.json).

| Exclusive hardware phase | Mean cycles/output |
|---|---:|
| Matrix issue, 16 products/edge | 37,249,024 |
| Exposed wait for a complete weight stripe | 10,465,643 |
| Bank handoff, arithmetic drain, advance and row writes | 3,988,096 |
| Instruction RAM fetch, decode and retirement | 615,306 |
| Scalar DDR request and response | 625,280 + 11,482,500 |
| Nonlinear execution | 10,472,401 |
| Other core work, including scratch arithmetic and scalar operand handling | 16,992,785 |
| Resident instruction staging, outside core-busy time | 5,791,235 |

The core accepted 37,249,024 weight packets per output. Of these, 24,625,758
(66.11%) arrived on an arithmetic issue edge. Another 9,868,186 arrived
while the matrix engine waited for its next full stripe. That accounts for
94.29% of the exposed weight wait. Waiting in that state for the first
packet took 528,071 cycles, and gaps after the first packet took 7,386.
Measured during matrix execution, the weight payload reached **576.36 MB/s**.
Including all core phases brings useful throughput down to about **325 MB/s**
on a port capable of 800 MB/s. [Raw phase totals](../artifacts/pblaze3-cycle-profile-20261111-a1/cycle-profile.json).

The matrix phases occupy 56.2653% of core time. Within those phases the
weight payload consumes 72.0446% of the 32-byte-per-edge capacity. Their
product accounts for 40.5361 percentage points over the whole run. Vector
loads and stores add 0.0851 points, giving the measured 40.6211%. A matrix
issue edge processes 16 BF16 weights, exactly 32 bytes. Even perfectly
continuous matrix issue would need the entire port at that issue rate.

Across the four positions the exposed weight wait stays near 10.466 M cycles.
Scalar DDR response time grows from 8.205 M to 14.757 M cycles as each
position loads more KV data. Other core execution grows from 14.551 M to
19.434 M. The separate diagnostic re-executed every position on the board
and compared its full logits against the timed run. [Per-position phases](../artifacts/pblaze3-cycle-profile-20261111-a1/phase-per-token.csv).

## First optimization

Nonlinear execution and the remaining scalar compute/control states account
for 27.465 M core cycles/output. The elementwise add, multiply, sign-setting
and conditional-multiply opcodes alone account for 10.610 M. The vector
candidate alternates two reads on the existing synchronous scratch port and
issues one independent element every two edges. Writes retire in order, and
a descriptor drains before its successor reads scratch. Partial overlaps,
overwritten broadcast inputs and short vectors use the scalar schedule.
Independent nonlinear values use the existing four-context FP32 unit.
Matrix shape, BF16 weights, FP32 operation order and program bytes are shared
by both images. The explicit `export-vector-profile` alias and the standard
`export-inference` command generate the same measured design.

The integrated AXI fixture checked eligible, aliased and short descriptors,
including signed zero, a subnormal and NaN. LunaWave and pinned Verilator
agreed at all 6,981 sampled boundaries. A 26-edge bounded proof checked the
new scheduler from a legal post-decode COPY or MUL, for lengths four through
seven and arbitrary RAM return data. It checked operand issue counts, four
drain edges, product counts, retirement and absence of DDR activity or a
fault. Forbidding retirement produced a witness at edge 16. The numeric
checks use the complete implementation. [Differential replay](../artifacts/pblaze3-profile-optimized-20261111-a1/verilator/actual.tsv),
[proof](../artifacts/pblaze3-profile-optimized-20261111-a1/proof-control-slice/output/result/status)
and [negative-control trace](../artifacts/pblaze3-profile-optimized-20261111-a1/proof-control-slice-negative/output/result/engine_0/trace.vcd).

Pinned Yosys mapped the emitted compute core for XC7 and reported zero
structural problems. Vivado routed the whole board using 60,910 LUTs,
38,578 registers, 70 RAMB36 and 37 DSPs. The instrumented baseline used
58,458 LUTs, 37,423 registers, 70 RAMB36 and 35 DSPs. The vector image has
0.083 ns worst setup slack and 0.044 ns worst hold slack. Its standard route
used the synthesis checkpoint after the optional incremental implementation
attempt encountered a license restriction. [Independent synthesis](../artifacts/pblaze3-profile-optimized-20261111-a1/yosys-batch/yosys.log),
[routed utilization](../artifacts/pblaze3-profile-optimized-20261111-a1/route/utilization.rpt)
and [routed timing](../artifacts/pblaze3-profile-optimized-20261111-a1/route/timing.rpt).

## Independent prefill measurement

The original streaming image ran all 28 layers and the output head using the
resident weights. Each group of consecutive instructions of the same class
ran as a separate window. Their original order and scratch contents were
preserved. The final 151,936 FP32 logits matched the preceding unsplit board
run byte for byte.

| Prefill instruction class | Windows | Measured core cycles |
|---|---:|---:|
| External BF16 matrix | 150 | 51,715,839 |
| Nonlinear | 1,681 | 11,921,773 |
| Remaining scratch arithmetic | 2,777 | 11,740,356 |
| FP32 vector load from DDR | 1,009 | 5,233,184 |
| FP32 vector store to DDR | 66 | 5,446,654 |

Each split window fetches an extra HALT. These numbers include descriptor
handling and apply to position zero. The matrix groups read 1,191,968,768
weight bytes in 2.069 seconds of core time, or 576.2 MB/s. Across the
original three four-token trials, the actual instruction bytes specify
14,303,625,216 bytes of matrix weights, 19,968,000 bytes of vector loads and
10,045,440 bytes of vector stores. The core's logical DDR word counters
independently agree with their sum at each position. Instruction staging
contributes a separate 13,898,880 bytes. [Segment counters](../artifacts/pblaze3-cycle-profile-20261111-a1/operators/sections.tsv).
