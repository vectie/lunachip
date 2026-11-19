# First FPGA target recommendation

The separate [PBlaze3 2 GiB port](PBLAZE3_PORT.md) now has accepted smoke and
accelerator bitstreams for an XC7K325T PCIe card. Its [arrival runbook](PBLAZE3_BRINGUP.md) covers the
provisional memory profile, reproducible build, DDR qualification and Qwen
reference-layer tests. Real-board PBlaze3 results are pending and do not replace
the measured PRX100 evidence below.

The approved first bring-up target is **PRX100-D**, using UART and4KiB on-chip
memory. Its [board contract](PRX100_BOARD_CONTRACT.md),
[MoonBit shell](../targets/prx100/README.mbt.md) and generated build recipe
keep the portable accelerator unchanged. Both smoke and Array8 pass actual
Vivado2025.2 placement/routing and timing at50MHz with BRAM inference; the
[build ledger](evidence/prx100-vivado-build-20261015.md) records exact resources,
inputs and bitstreams. The [physical UART/BRAM smoke test](evidence/prx100-uart-bram-20261016.md)
passes29 transactions. The [first signed matrix workloads](evidence/prx100-signed-matrix-20261016.md)
also pass on the1x1/K2 smoke accelerator. The
[physical Array8/K16 workload](evidence/prx100-array8-matrix-20261016.md)
passes all64 signed results through241 checked UART exchanges. The
[broader campaign](evidence/prx100-broad-matrix-20261016.md) adds40 signed
edge/seeded/repeated cases, a synthetic K1024 projection and measured UART
versus compute-counter timing. The
[real W8A8 Qwen projection](evidence/prx100-qwen-projection-20261016.md)
passes all1536 partials and24 final outputs for eight real output channels
on three normalized token embeddings, with CPU references and timings. The
[Qwen3-0.6B assessment](PRX100_QWEN_FEASIBILITY.md) rules
out full-model inference as a practical goal for this initial target.

The [DDR-to-core continuation](evidence/prx100-ddr-projection-20261016.md)
connects qualified DDR through BRAM staging and a target-side sequencer and
INT32 accumulator. All20 physical jobs pass, including18 full projections,
1536 real partial checks and160 final sums across smokes/repeats. Full-job
latency is median2.36871ms versus177us for the same scalar CPU integer reference.
The routed image passes setup+0.956ns and hold+0.047ns. The portable core and
its emitted RTL remain byte-identical. JTAG word loading, burst DDR movement
and core data loading remain performance work; Ethernet is still unqualified.

The later [target optimization](evidence/prx100-ddr-optimization-20261016.md)
adds a DDR read-line cache and sparse descriptor updates. All20 jobs pass again;
full-job median falls to1.76730ms,25.39% lower, with setup+0.901ns/hold+0.036ns.
DDR wait falls to0.49702ms; unchanged core service remains1.22880ms. The fresh
scalar CPU takes183us and resident JTAG launch/observation15ms. This improves
FPGA job time while bulk host loading and broader product gates remain open.

The [loading pipeline](evidence/prx100-core-loading-20261016.md) then overlaps
next-tile BRAM staging with core service and removes partial-write advance
states. All20 jobs pass, with median1.37524ms (22.18% below1.76730ms),
setup+0.488ns/hold+0.057ns,1146 strict native tests and exact original core
IR/RTL. Core service remains1.22880ms; CPU median182us and JTAG observation15ms.
Target register version1.1 distinguishes the now-overlapping timing counters.

The [descriptor publication pipeline](evidence/prx100-publication-20261017.md)
then publishes one tile ahead after consumer release and continues tile work
during result collection. All20 jobs pass at median1.12750ms,18.01% below1.1,
with1163 strict native tests,8234 independently replayed controller edges,
setup+0.958ns/hold+0.019ns and unchanged portable core/bridge/clocks. Fresh
scalar CPU176us and resident JTAG observation16ms remain separate measurements.
Target1.2 changes activity-window overlap; core-wait is not standalone core
service time. Full Phase7 remains open.

The [byte-memory port isolation](evidence/prx100-byte-20261017.md) adds an
independent synchronous result-read port and collection lookahead. Both fresh
20-job A/B campaigns pass against the CPU reference. FPGA median falls only
1.12747→1.12710ms (0.033%); serialized byte transactions remain dominant.
The same1163 strict native tests and8234 controller RTL replay edges pass.
Routed setup+0.829ns/hold+0.064ns and all12 vendor bus-skew constraints pass;
total resources are19797LUT/14347FF/5.5BRAM/11DSP. Core, bridge and clocks
retain their exact identities. Fresh scalar CPU184us remains faster.

The subsequent [portable word-read core](evidence/prx100-word-20261017.md)
extends the core transport while preserving the legacy generator's identities.
Fresh target1.3→1.4 A/B passes20 jobs per image at1.12710→0.53526ms median,
52.51% lower (2.11× faster). Core requests fall280→76 per tile; arithmetic,
bridge and50/100MHz clocks retain their meanings. All1176 native tests and
3947-cycle core/controller RTL replays pass. Setup/hold are+0.125/+0.047ns;
20125LUT/14490FF/5.5BRAM/11DSP and all12 bus-skew constraints pass. Scalar
CPU183µs remains2.93 times faster. Bounded local formal checks pass;
unbounded new-core closure and the full Phase7 gate remain open.

The [DDR line-staging continuation](evidence/prx100-staging-20261017.md) keeps
that exact portable core and clocks, while forwarding four words per owned
DDR line request into BRAM. Fresh1.4→1.5 A/B passes20 jobs per image at
0.53596→0.48102ms median,10.25% lower (1.11× faster); staging activity falls
27.21%. Front-end read requests fall36→9 per tile, with the same native bytes.
All1180 native tests,3552-cycle core/controller replays,587 atomic bridge
events and three syntheses pass. Scoped bounded formal/sensitivity tasks pass;
setup/hold are+0.958/+0.059ns and all12 bus-skew constraints pass. Resources
are20189LUT/14494FF/5.5BRAM/11DSP. Scalar CPU183µs remains2.63 times faster;
the host workload stays about97s because JTAG transfers dominate. Full Phase7,
long soak, bulk host transport and full-model integration remain open.

[Vivado2025.2 is installed](evidence/prx100-vivado-install-20261015.md) in an
isolated Ubuntu22.04 guest under the Linux server's `/data`; the host OS and
package inventory remain unchanged. The exact FPGA part query passes.

The earlier procurement recommendation was the Digilent Arty A7-100T,
subject to board budget, software access and target-specific implementation.
The goal is a reproducible signed 8x8 workload on a real board, not production
LLM serving. This recommendation does not change the unfinished Phase 6 gate
or authorize a purchase, vendor installation or physical deployment.

## Board choice

Vendor-listed prices below were checked on 2026-10-07. They are not delivered
regional quotes or confirmation of immediate stock.
The Arty listing was rechecked on 2026-10-08; the price remains US$322.

| Board | Compute and memory | Listed price | Project role |
| --- | --- | --- | --- |
| Arty A7-100T | Artix-7 XC7A100T, 240 DSP slices, 4,860 Kbits block RAM, 256 MB DDR3L; USB-JTAG and USB-UART | US$322 | First target; bring up without a processor boot stack |
| Nexys A7-100T | Same FPGA resource class, 240 DSP slices, 4,860 Kbits block RAM, 128 MiB DDR2; USB-JTAG/UART and more teaching peripherals | US$349 | Substitute if easier to procure; no additional compute capacity |

Specifications and prices: [Arty vendor page](https://digilent.com/shop/arty-a7-100t-artix-7-fpga-development-board/)
and [Nexys vendor page](https://digilent.com/shop/nexys-a7-amd-artix-7-fpga-trainer-board-recommended-for-ece-curriculum/).

The Kria KV260 is an alternative if a processor-hosted accelerator platform and
growth capacity matter more than minimal bring-up. Its K26 provides 1,248 DSP
slices, 144 block RAMs and 64 UltraRAM blocks; the kit has 4 GB DDR4. Using the
processor and DDR adds firmware, host-bridge and memory integration work. This
is an engineering tradeoff, not evidence that Arty is faster or cheaper in every
region. [K26 resources](https://docs.amd.com/r/en-US/ds987-k26-som/Programmable-Logic),
[KV260 specifications](https://docs.amd.com/r/en-US/ds986-kv260-starter-kit/Product-Details).

## Capacity and implementation limits

The retained [8x8/K16 synthesis profile](evidence/phase6-synthesis8-20261005.md)
has 32 operand memories of 16x8 bits, two result memories of 64x32 bits and
four descriptor memories of 3x64 bits. Their total logical capacity is
`32*16*8 + 2*64*32 + 4*3*64 = 8,960 bits`. This is not the physical block RAM
allocation: ports, tiny-bank fragmentation, replication and target mapping
can increase resource use or put storage in LUTs/registers.

The array has 64 multiplication sites. Mapping roughly one DSP per site is a
capacity estimate, not a measured synthesis result. Generic Yosys cells are
not FPGA LUT counts. Existing generic synthesis establishes neither board fit
nor routed timing. Start with a small configuration and grow to the frozen
8x8 profile after inspecting target utilization and critical paths.

## Build host and tools

Keep MoonBit development on the Mac, but use a supported x86-64 Windows or
Linux host for vendor implementation. macOS is absent from AMD's supported
Vivado platform list. [Platform requirements](https://docs.amd.com/r/2025.1-English/ug973-vivado-release-notes-install-license/Supported-Operating-Systems).

AMD's current Vivado BASIC tier supports Linux and Windows, 7 Series devices
and Kria SOMs. It costs zero with annual free license renewal. Freeze the exact
release, device support and license prerequisites in the eventual build recipe;
do not rely on old WebPACK branding or assume all debug/IP features are free.
[Current licensing](https://www.amd.com/en/products/software/adaptive-socs-and-fpgas/vivado/vivado-licensing-options.html).

## First board acceptance path

Keep board clocks, reset synchronization, pins and transport in a target shell
outside the portable accelerator. Start with UART-controlled on-chip test
memory backing the public tagged request/response bus. External DDR and
Ethernet are later extensions, not prerequisites for a first signed matrix
self-test. The host diagnostic remains MoonBit; use vendor primitives only
at explicit target boundaries.

Require target synthesis, placement/routing, a recorded clock constraint and
passing timing before assigning an operating frequency. On-board tests compare
exact signed results and exercise request/response backpressure, completion
hold, reset, transfer faults and repeated workloads. Retain board/part identity,
tool versions, bitstream digest and observed results. Only actual board runs
establish FPGA execution; simulator cycle counts remain separate.

## DDR result-write continuation — target1.6

The [batched DDR result writes](evidence/prx100-results-20261017.md) pass a fresh20-job campaign per image: **0.48054→0.45618ms median**, **5.07% lower** (1.053×). All40 jobs match the signed CPU reference; writes fall520→130 per full block, with the same portable core and clocks. The scalar CPU is183µs; the new FPGA remains2.49 times slower. Host/JTAG transfers remain dominant; full-model inference remains separate work.

## DDR streaming continuation — target1.7

The [DDR streaming and descriptor staging continuation](evidence/prx100-stream-20261017.md) passes40 fresh A/B jobs: **0.45630→0.41775ms median**, **8.45% lower** (1.092×), with the exact portable core and clocks. Front-end reads fall576→128/full block; native traffic is unchanged. Scalar CPU183µs remains faster; host/JTAG and full-model integration remain open.

## Floating-point continuation — separate FP1.0 profile

The [BF16-input / FP32-accumulation experiment](evidence/prx100-fp-20261017.md) passes55/55 board jobs at a timing-qualified25MHz, including24 real Qwen outputs and24 repeats. The full target uses2006 LUT/2593 FF/3.5 BRAM/1 DSP/1 MMCM. One K1024 dot takes4096 cycles,163.84µs. This is a separate BRAM/JTAG profile; the integer core and DDR target remain unchanged. Broader phase gates, acceleration and full-model inference remain open.

The [FP1.1 eight-lane pipeline](evidence/prx100-fpp-20261017.md) passes 40 board jobs / 320 CPU-exact outputs at a routed 50 MHz, with 1203 native tests and exact physical RTL replay/synthesis plus scoped formal gates. The same eight-output K1024 block takes 5124 cycles, or 102.48 µs, versus a fresh scalar engine-activity sum of 1310.72 µs: 12.79× faster. The full target uses 8589 LUT / 5989 FF / 10.5 BRAM / 8 DSP, with setup/hold slack +3.308/+0.069 ns. Scalar and integer recovery images remain available; all 209 protected source/interface identities are unchanged. CPU FP32 still takes 68 µs, and JTAG transport, DDR/model integration and broader phase closure remain open.

## Complete floating-point layer — 32-row compute continuation

The [32-row BF16/FP32 profile](PRX100_QWEN_LAYER_COMPUTE.md) is physically qualified at the unchanged 100/3 MHz clock. Same-policy resident medians improve 720.992 → 704.851 ms for four tokens and 199.429 → 194.455 ms for cached decode; kernel savings are only about 1%, demonstrating diminishing returns from extra lanes with the current path. All 845,696 paired FP32 words pass CPU tolerance and ordered-model bit equality. Native 1,267-test, actual RTL differential, synthesis and bounded gates pass; integer 199 inputs and legacy 16-row emission remain exact. The candidate consumes 95.23% of LUTs, 70/135 BRAM tiles and 51/240 DSPs. Detailed samples, failed attempts and qualified bit identity are retained in the linked evidence. Full-model inference remains open.

## Complete floating-point layer — bounded DDR read-ahead

The [measured read-ahead continuation](evidence/prx100-layer-feed-20261020.md) explains the 32-row limit with a fresh 108-section board profile: DDR-backed matrix stages account for 68.6% of board cycles;the interface carries eight BF16 weights/core edge while 32 interval-two lanes require sixteen. Four-row prefetch reduces matrix stages 440.638 → 377.085 ms (14.42%);SiLU stays 90.349 ms. The 32-row read-ahead target failed placement,so the qualified image reuses the exact previous 16-row core and unchanged arithmetic source,controller,host policy and clocks. Resident four-token latency improves **704.242 → 644.422 ms (8.49%)**;cached position-3 decode **195.743 → 187.600 ms (4.16%)**. Kernel medians are 578.398 / 146.589 ms,9.90% / 9.78% lower. All 845,696 paired FP32 words pass CPU tolerance and ordered-model bit equality;all 199 integer inputs remain unchanged. Native 1,270 tests,actual bridge RTL differential/synthesis,all 83 original safety properties over128frames with exact coverage,and strict route/clock gates pass. The design uses40,689 LUT /134.5 BRAM /51 DSP at100/3MHz. The fresh portable CPU reference takes90ms for four tokens,so it remains faster even than the FPGA kernel. This is one fixed complete layer/context four;full-model inference and broader phase closure remain open.

## Complete floating-point layer — eight-row DDR requests

The [eight-row DDR continuation](evidence/prx100-layer-stripe-20261020.md) halves ownership/request handoffs per sixteen-row weight stripe while retaining sixteen BF16/FP32 arithmetic lanes and a 30 ns core period. Resident four-token latency improves **649.402 → 581.413 ms (10.47%)**; cached position-3 decode improves **182.845 → 169.938 ms (7.06%)**. Five samples per workload/profile include launch, completion, final readback and actual CPU checks; upload, program installation, integrity and complete diagnostics are separate. All 845,696 paired FP32 words pass CPU tolerance and ordered-model bit equality. All 199 integer inputs and the FP arithmetic implementation remain unchanged. The matching core loader, controller and bridge reserve 64 native return lines per eight-row owner. All 1,274 strict native tests, actual RTL replays, zero-SCC composition, fresh core/controller bounded checks, all 83 bridge properties over 128 global frames with exact coverage, and strict route/clock gates pass. Utilization is 45,411 LUTs / 134.5 BRAM tiles / 51 DSPs, with +0.056/+0.036 ns setup/hold slack. This is one fixed complete layer at context four; full-model inference and broader phase closure remain open.

## PRX100 short nonlinear schedule — 2026-10-20

The opt-in MoonBit nonlinear engine commits additions in two edges and multiplies in four, preserving the ordered FP32 operations and approximations. On the PRX100, resident four-token layer latency improves from **582.576 to 563.787 ms** (3.23%), and cached position-3 decode from **168.649 to 164.214 ms** (2.63%). Timers include launch, completion, actual final-output reads, file writing and CPU comparisons. Upload, program installation, integrity sweeps and full diagnostics are separate. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 199 integer inputs and FP32 primitives remain unchanged. Controller, wrappers and source timing constraints are byte-identical. The bridge uses equivalent 24-bit aligned extent validation with the same packet and cycle contract. All 1,278 strict native tests, actual core RTL replay, zero-SCC composition, fresh 48-frame core safety checks, all 83 original bridge assertions over 128 global frames, actual 64-bit header equivalence in one frame, complete negative witnesses, and strict timing/clock/DRC/bus-skew gates pass. Routed setup/hold slack is 0.386 / 0.001 ns. [Measured evidence](evidence/prx100-layer-short-unary-20261020.md) retains every observation and failed attempt. This is one complete fixed layer at context four; full-model inference and broader phase closure remain open.

## PRX100 sixteen-row matrix owner — 2026-10-21

The opt-in matched MoonBit core/controller/bridge replaces two eight-row owners with one sixteen-row DDR owner per matrix stripe, retaining sixteen ordered BF16/FP32 lanes, identical arithmetic and clocks. Fresh resident full-layer latency improves from **559.188 to 530.673 ms** (5.10%), while cached position-3 decode rises from **157.923 to 158.436 ms** (0.32% slower). Its FPGA kernel nevertheless improves 6.17%; recorded host/control/readback overhead offsets that saving. Timers include launch, completion, actual final-output reads, file writes and CPU checks; upload, program switching, integrity sweeps and full diagnostics remain separate. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 199 integer inputs and FP arithmetic primitives remain unchanged. Only the internal observe_beat width changes from six to seven bits in each wrapper; all other wrapper bytes, source XDC, host ABI and pins remain exact. All 1,284 strict native tests, fresh RTL replays, zero-SCC composition, core/controller 48-frame safety, all 83 bridge assertions over 128 global frames, 64-bit header equivalence and complete negative calibrations pass. Strict route, clock, DRC and all 12 bus-skew gates pass; setup/hold slack is +0.130/+0.001 ns. The 1,432-input source cohorts preserve 479 pre-existing Mac/Linux variants; all 27 changed inputs and 15 selected canonical/emitted files match across hosts. [Measured evidence](evidence/prx100-layer-sixteen-row-20261021.md) retains all observations and attempts. This is one fixed complete layer 0 at context four and cached decode; full-model inference and Phase 7/8 closure remain open.

## PRX100 checked JTAG control and completion snapshots — 2026-10-22

A fresh same-session comparison alternates the legacy and optimized host paths on the exact same sixteen-row BF16/FP32 image. Five pairs per workload, with order reversed each pair, measure full-layer end-to-end latency **530.920 → 517.736 ms** (2.48% lower) and cached position-3 decode **148.310 → 138.997 ms** (6.28% lower). Warm launches reuse the latest physically validated count under exclusive logged control ownership. The checked two-word DONE poll supplies status and a legal nine-word read revalidates count and captures counters; redundant count/status round trips are removed. Final DDR readback, file writes and CPU comparisons stay in the timer. All 448,448 FP32 words across 317 tensors pass CPU tolerance and match the ordered model; all 54,272 actual checker words are independently rechecked. All 1,284 strict native tests pass. Both complete 1,432-input source cohorts, all 199 integer inputs, FP hardware, programs, clocks and bitstream remain unchanged. Five altered auditor inputs are rejected. Existing physical/digital/formal gates are inherited by exact identity and complete sealed-parent verification. [Measured evidence](evidence/prx100-layer-control-20261022.md) retains every pair and failure. This remains one fixed layer 0/context four and cached decode; full-model inference and Phase 7/8 closure remain open.

## PRX100 matrix stalls and row-group prefetch — 2026-10-22

Physical per-instruction counters and independently checked state schedules identify 33.722 ms of full-stripe wait in 282.242 ms of external matrix work. Packing alone fails to improve execution. The opt-in MoonBit packed path now prefetches the next row group's first stripe during the current group's final computation, preserving loader ownership through result writes. Matrix wait becomes 20.881 ms and matrix total 269.401 ms. Five alternating same-image pairs measure resident complete four-token layer latency **527.772 → 501.797 ms** (4.92% lower) and cached position-3 decode **143.316 → 141.914 ms** (0.98% lower). Final readback, file writes and CPU checks remain inside these timers; uploads, program switching and full diagnostics are separate. All 448,448 FP32 words pass CPU tolerance and match the ordered operation model, with 54,272 actual checker words independently rechecked. All 1,287 strict native tests, actual RTL replay, full digital synthesis, fresh bounded core safety and negative witness, and strict physical timing/clock/DRC/skew gates pass. Controller, bridge, arithmetic, clock constraints and all 199 integer inputs remain unchanged. The earlier sixteen-row export is byte-identical. [Measured evidence](evidence/prx100-layer-matrix-stalls-20261022.md) retains all pairs and the rejected packing-only experiment. This is one complete fixed layer0/context4 and cached decode; full-model inference and Phase7/8 closure remain open. FPGA execution decreases 461.497→448.657 ms for the full layer and 117.336→114.125 ms for decode (about 2.8% each). End-to-end medians also reflect host timing variation; the small cached-decode gain is below the observed run-to-run spread. All five pairs per workload, including losing pairs, are retained.

## PRX100 ordered FP32 feedback and weight delivery — 2026-10-23

The opt-in MoonBit design accepts an ordered FP32 accumulation every core edge and delivers sixteen BF16 weights per edge through a 256-bit target path. The close/far FP32 adder preserves round-to-nearest-even, gradual underflow and the original per-product order; the existing BF16-specialized multiplier reduces unnecessary width. Fresh physical baseline and candidate campaigns measure resident four-token layer latency **510.974 → 390.559 ms (23.566% lower)** and cached position-3 decode **140.466 → 115.450 ms (17.809% lower)**. FPGA execution changes 448.660 → 330.928 ms for the full layer and 114.127 → 84.694 ms for decode. Resident timers include launch, polling, counters, final readback, file writes and CPU checking. Upload, program switching and full diagnostics are separately recorded. All 896,896 checked FP32 words pass the original CPU tolerance and match the ordered operation model; 317 cross-image tensors are byte-identical and 108,544 actual checker words are independently rechecked. All 1,295 strict native tests, actual core/bridge RTL replay, universal feedback-adder equivalence, bounded safety with complete negative controls, zero-SCC synthesis and strict physical timing/clock/DRC/skew gates pass. A protocol proof caught surplus error packets after rejected wide reads; the corrected path and its regression passed before programming. All 199 integer inputs remain unchanged, and legacy exports remain byte-identical. Clocks and host policy are unchanged. Five packed samples per workload and image retain every observation; separate image campaigns still include host timing noise. This is one complete fixed layer 0 at context four and cached decode; full-model inference and Phase 7/8 closure remain open. [Measured evidence](evidence/prx100-layer-feedback-20261022.md) retains the exact source, tool and bitstream identities, raw outputs, failed attempts and every sample.

## PRX100 interleaved nonlinear pipeline — 2026-10-23

Fresh profiling identified 68.600 ms in the SiLU-and-store groups. The opt-in MoonBit core interleaves four nonlinear elements through shared FP32 arithmetic while preserving each element's microprogram, constants, rounding and operation order. Matrix accumulation, weight delivery, clocks and host policy remain unchanged. Fresh physical campaigns measure four-token resident layer latency **385.397 → 353.926 ms (8.166% lower)** and cached position-3 decode **111.483 → 105.826 ms (5.074% lower)**. FPGA execution changes 330.929 → 296.650 ms for the layer and 84.694 → 76.063 ms for decode. Resident timing includes launch, polling, counters, final readback, file writes and CPU checks; uploads, program switches and full diagnostics are recorded separately. All 896,896 checked FP32 words pass the original CPU tolerance and match the ordered operation model; 317 cross-image tensors are byte-identical. Validation includes 1,600 bit-exact nonlinear lane cases, 180 complete-core alias/tail/fault cases, 1,297 strict native tests, 129,142 actual RTL replay cycles, fresh bounded core/unit safety with negative controls, full digital zero-SCC synthesis, and strict routed timing/DRC/clock/skew checks. All 199 integer inputs and all three previous hardware exports remain unchanged. Every sample is retained; separate bitstream campaigns retain host timing noise. The result covers one complete fixed layer 0 at context four and cached decode. Full-model inference and Phase 7/8 closure remain open. [Measured evidence](evidence/prx100-layer-vector-20261023.md) retains raw results, source/tool/bitstream identities and all samples.
