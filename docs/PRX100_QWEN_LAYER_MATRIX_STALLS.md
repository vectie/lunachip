# PRX100 matrix stalls and contiguous weight stripes

This continuation preserves the integer core and the qualified sixteen-row
profile. The first fresh physical profile measures the unchanged complete
layer in 108 sections with inserted HALTs. Each of its 28 external matrices
uses the sixteen-lane K64 path. Physical cycle counters can therefore be
partitioned into fixed instruction, issue, feedback-gap, drain, bank-transition
and result-write cycles, with the residual attributed to waiting for a full
weight stripe. Independent LunaWave pre-edge state histograms must validate
this partition. It is derived attribution, not a new physical stall counter;
it cannot distinguish MIG, CDC and controller waits within the residual.

The 2026-10-22 baseline records 282.242 ms in external matrices: 117.965 ms
issue cycles, 116.122 ms required ordered-accumulation gaps, 33.722 ms waiting
for stripes, 9.216 ms draining, 3.686 ms bank transitions, 1.475 ms result writes
and 0.056 ms instruction control. The feedback gaps preserve the existing
two-edge FP32 dependency; sixteen lanes match the eight-BF16-per-edge feed.
Removing those gaps alone would require both a different feedback design and
more sustained feed bandwidth. Stripe waiting is the largest remaining
avoidable matrix bubble in this measured schedule.

The opt-in profile supports a packed weight layout for external
matrix opcode 4, flags 1. Flags 0 retains ordinary row-major data. Packed
matrices require n divisible by 16, k divisible by 64 and nonoverlapping
activation/output scratch extents. Unsupported packed shapes fault before
any memory request; they must never silently take the scalar fallback.

For row r and column c, packed BF16 element index is
`(r / 16) * (16 * k) + (c / 64) * 1024 + (r % 16) * 64 + c % 64`.
Every 16-row/K64 stripe is thus contiguous. Its existing sixteen-row DDR
request has byte stride 128; its start is
`base + 2 * (row_group_start * k + 16 * chunk_start)`.
The bridge, controller, bank geometry, clocks, arithmetic, accumulation order,
logical bytes and number of requests remain unchanged. Repacking is a
byte permutation of the original BF16 weights; all other fixture assets and
CPU/ordered-reference outputs retain their exact identities.

The first packing-only image passed the complete physical numerical audit but
did not improve matrix execution. Its segmented matrix total was 282.673 ms,
including 34.153 ms of residual stripe wait. Five alternating pairs on the
same image gave full-layer resident medians of 513.769 ms row-major and
515.124 ms packed; device medians were 461.499 and 461.932 ms. Cached-decode
resident medians were 143.918 and 141.816 ms, a host-side fluctuation that does
not establish a compute gain. Every sample, including the first use, is kept.
This packing-only experiment is rejected as a performance optimization.

The second candidate uses the same packed layout and two weight banks to
prefetch the following row group's first stripe at the start of the current
group's final stripe. Result writes preserve the in-flight loader's state,
address, lane and bank ownership; the next group flips to the prefetched bank
only through the existing full-stripe admission gate. The final group does
not request another stripe. Flags 0 retain the original row-group schedule.
No extra bank, DDR request, arithmetic lane or clock change is introduced.
Tests cover odd and even stripe counts, three row groups, reset and response
faults during next-group prefetch, and reject invalid packed descriptors before
any external request. The earlier sixteen-row export remains byte-exact.

The paired host audit also distinguishes the first cached-decode count change
from warm count reuse. It checks the actual count write and readback before
that START, then requires nineteen verified cache hits. All polling and
completion snapshots remain tied to physical transactions. Four deliberate
trace corruptions are rejected, and the previous paired-control audit remains
valid. This correction changes audit expectations, not the board runtime or
any recorded timing.

Qualification requires successful source/native gates, legacy export identity,
actual RTL differential and synthesis checks, named bounded core safety and
negative controls, unchanged transport qualification, routed timing and DRC,
and actual complete-layer/cached-decode CPU comparisons. Measure a fresh
baseline and candidate with the same selected snapshot host policy. Preserve
all samples and failed attempts. The next-row-group prefetch candidate passes these gates and physical measurements.

| Median resident end-to-end, five alternating pairs | Original row-group schedule | Packed + row-group prefetch | Reduction |
|---|---:|---:|---:|
| Complete four-token layer | 527.772 ms | 501.797 ms | 4.92% |
| Cached position-3 decode | 143.316 ms | 141.914 ms | 0.98% |

Physical per-instruction counters and independently checked state schedules identify 33.722 ms of full-stripe wait in 282.242 ms of external matrix work. Packing alone fails to improve execution. The opt-in MoonBit packed path now prefetches the next row group's first stripe during the current group's final computation, preserving loader ownership through result writes. Matrix wait becomes 20.881 ms and matrix total 269.401 ms. Five alternating same-image pairs measure resident complete four-token layer latency **527.772 → 501.797 ms** (4.92% lower) and cached position-3 decode **143.316 → 141.914 ms** (0.98% lower). Final readback, file writes and CPU checks remain inside these timers; uploads, program switching and full diagnostics are separate. All 448,448 FP32 words pass CPU tolerance and match the ordered operation model, with 54,272 actual checker words independently rechecked. All 1,287 strict native tests, actual RTL replay, full digital synthesis, fresh bounded core safety and negative witness, and strict physical timing/clock/DRC/skew gates pass. Controller, bridge, arithmetic, clock constraints and all 199 integer inputs remain unchanged. The earlier sixteen-row export is byte-identical. [Measured evidence](evidence/prx100-layer-matrix-stalls-20261022.md) retains all pairs and the rejected packing-only experiment. This is one complete fixed layer0/context4 and cached decode; full-model inference and Phase7/8 closure remain open. FPGA execution decreases 461.497→448.657 ms for the full layer and 117.336→114.125 ms for decode (about 2.8% each). End-to-end medians also reflect host timing variation; the small cached-decode gain is below the observed run-to-run spread. All five pairs per workload, including losing pairs, are retained.

Reproduction uses the explicit `export-contiguous` CLI profile, `prx100-layer-packed-weights.mbtx`, `prx100-layer-packed-profile.mbtx`, `prx100-layer-matrix-board.mbtx` and the independent resident, completion, packing and matrix auditors. Exact pinned commands, fresh-output paths, source identities and all qualification drivers are retained in the measured archive. Keep sealed archives immutable.
