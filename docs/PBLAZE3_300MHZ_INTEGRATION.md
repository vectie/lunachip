# PBlaze3 300 MHz array integration

The installed `owner120-map109` image runs a 120 MHz scheduler, 300 MHz
64-lane MAC and 200 MHz MIG with 1 KiB weight bursts. It passes whole-system
timing (+0.006 ns setup, +0.001 ns hold) and full Qwen3-0.6B execution on `.191`.
DDR bank interleaving raises measured throughput to **6.730568 tokens/s**,
**9.1509%** above the original 6.166295 baseline. All 36 checked complete logits
match bit for bit. MIG pending-read return gaps fall from 21.625 to 9.077 ms/token.
The new image and resident model remain on the board. Results were completed
on 2026-11-20 Asia/Shanghai; the implementation history below is retained.

## Completed evidence

`owner150-inspect76` reads the completed `owner150-route74/initial-route.dcp`:

| Clock domain | MHz | Setup slack, ns | Hold slack, ns |
|---|---:|---:|---:|
| Scheduler | 150 | −1.258 | +0.054 |
| MAC array | 300 | +0.096 | +0.051 |
| MIG UI | 200 | −0.023 | +0.052 |
| PCIe AXI | 250 | −0.200 | +0.051 |

The checkpoint is fully routed; SHA256 is
`5a01975e3aae3d67bcbb1bab2e5d230c7708dacaf9a5ae0adc181ac7f621ead4`.
The table lists the four inspected domains; global signoff also covers other
generated clocks, including PCIe's internal 500 MHz clock.
[Inspection and reports](../artifacts/pblaze3-mig-profile-20261119-b1/frequency150-physical/owner150-inspect76-initial-route/inspection.txt).

The scheduler's longest routed path starts at loop counter `i`, traverses
the remaining-count/burst/protocol logic, and ends at controller register
`lc_n887`'s enable: 24 logic levels, 7.659 ns data delay, 75.571% routing.
The worst MAC path is exception metadata into a delay SRL: four LUT levels,
2.865 ns data delay, 86.213% routing. These are measured paths in this
implementation, not the FPGA's universal frequency limits.

## Same RTL at 120 MHz scheduler / 300 MHz MAC

`owner120-eco77` reuses that route and changes the actual scheduler MMCM divider
from 8 to 10 at a 1200 MHz VCO. Readback verifies 120 MHz scheduler and 300 MHz
MAC. Other MMCM settings and netlist topology remain unchanged at the clock
change. Core, controller and bridge RTL/IR are identical in the two bundles;
the alternative changes clock configuration and frequency metadata.

After physical optimization, ECO77 still fails global setup by 0.051 ns;
global hold is +0.015 ns. Its worst path is the PCIe internal 500 MHz hard
block to TX BRAM `DIBDI[15]`, with zero combinational logic levels. PCIe AXI
has −0.014 ns and the worst MIG UI path has −0.011 ns. The image was rejected.
[Retained rejected reports](../artifacts/pblaze3-mig-profile-20261119-b1/frequency150-physical/owner120-eco77-rejected/worst-setup.rpt).

`owner120-route78` improved total negative slack to−0.263ns, but the worst
path remains−0.051ns. It was rejected. `owner120-clock80` also ended at−0.051ns
after clock-skew optimization, with no clock period or waveform changes.
`owner120-place81` now starts fresh placement from the existing opt72 checkpoint,
setting the actual scheduler divider to120MHz before placement. Both frequency
source inventories are verified; the RTL and completed functional validation
are reused, with no new synthesis. Acceptance still requires all
setup/hold paths, complete routing, reset boundaries, source-bound owner27
guards, CDC review, DRC and the original build's finalization checks. No timing
exceptions are added to hide failing paths.

The failed PCIe path is specifically `PCIE_2_1/MIMTXWDATA[52]` into
`RAMB36_X4Y30/DIBDI[15]`. The generated AMD PCIe XDC fixes that BRAM's
location. Its measured 1.431 ns data path contains 0.506 ns hard-block
clock-to-output delay and 0.925 ns wire delay. The accepted 6.166 tokens/s
image's checkpoint is retained with SHA256
`3259143552bf1d54a0e552295bf808204a377eb5be3c70b51e0ed14b55c66a15`.
Read-only audits 84/85 verify identical endpoints and fixed BRAM location:
the accepted reference has setup/hold +0.157/+0.113 ns, while clock80 has
−0.051/+0.154 ns. The current path uses 13 route nodes versus nine in the
reference. This suggests a physical routing fix; node counts alone do not
prove delay. `owner120-pcie86` checks that the reference route's resources are
unoccupied, applies only that net's route and rechecks both timing margins.
Any remaining paths still require complete global signoff. The old accepted
route is not automatically valid under the new design's clock distribution.
[Reference route](../artifacts/pblaze3-mig-profile-20261119-b1/frequency150-physical/pcie52-reference84-audit/routes.txt).

Preflight86 found TX data bit38 occupying the route; no net was modified.
Preflight87 additionally found array `weights_stage[275]` on the route and
also stopped before modifying nets. `owner120-pcie88` allows bounded rerouting
of the conflicting internal data nets, excluding clock/reset, fixed routes
and synchronizer drivers. It preserves driver/endpoint identity and rechecks
all timing domains, including the displaced array data. This is a physical
routing experiment on a checkpoint, not a programmed or accepted image.

The pcie88 local repair succeeded: TX52 setup/hold became +0.157/+0.113 ns;
rerouted TX38 is +0.285/+0.040 ns and array weights_stage275 is
+1.663/+0.506 ns. Exactly those two conflicting data nets were rerouted;
connectivity and complete routing were checked. At this intermediate checkpoint,
global setup improves from −0.051 to −0.014 ns; global hold remains +0.015 ns.
The remaining worst path is PCIe 250 MHz flow control into `tready_thrtl_reg`.
Further physical cleanup is running, so this is not complete image acceptance.

Critical placement89 did not improve the −0.014 ns global setup result.
Branch reroute90 now targets the two measured interconnect delays: PCIe
1.752 ns and MIG 2.975 ns. Router-only goals of 1700/2900 ps do not change
design timing constraints. In the separate fresh placement81, a clock-routing
adjustment improved PCIe250 setup from −0.192 to −0.058 ns. This motivates
clock91 on pcie88, after fixing the formerly limiting PCIe500 data path.
Clock periods and waveforms must remain unchanged, with full timing acceptance
still required. No new board image or inference result has been accepted.

Fresh placement81 ultimately finished with global setup −0.010 ns and hold
+0.001 ns, and was rejected. The remaining worst endpoint is specifically
`MIMRXWDATA[40]` to `RAMB36_X4Y33/DIBDI[4]`, not RX45. Its refined checkpoint
is `5d11fecee2c7c977d5207f33b51c66173e893f4c75e7979e967f736468d9d88a`.
An RX45 reuse script was prepared but never run; the endpoint check prevented
using that unrelated historical route. Audit93 reads the exact RX40 reference
from the accepted baseline. Branch90 stopped on the router's minimum-delay
argument check; branch92 corrects that router-only hint to its required 1 ps.

## Functional validation

The individual RX40 reference repair94 passed for RX40 (+0.147 ns setup,
+0.085 ns hold), but displaced RX47 and RX58 into setup/hold violations.
Automatic hold repair worsened global setup to −0.649 ns. That result was
rejected; the unchanged −0.010 ns placement81 remains the best input.
Read-only audit95 has captured all 64 RX routes from the accepted baseline,
including endpoint/site identities and positive setup/hold margins. The next
repair applies the transitive set of conflicting RX reference routes together,
then timing-aware reroutes bounded ordinary data nets displaced outside it.

Preflight96 stopped on an overly broad `S` pin rule; preflight97 confirms the
actual sinks are MUXF7 data-select pins, not sequential reset/set pins. Its
next bound counted transitive logic endpoints instead of direct wire sinks.
Run98 corrects that physical fanout measurement, logs both counts, and retains
clock/reset/fixed-route protection, unchanged-connectivity checks, and all
global timing/finalization gates. Run98 measured 156 direct sinks and 208
transitive endpoints on a non-fixed DDR calibration data-selection net, then
stopped at the exploratory 128-sink bound. Run99 expands that bound to 256;
it is a repair-script scope limit, not a device limit. These preflight failures
did not modify the input checkpoint.

Run99 successfully restored RX38/40/47/58 together and rerouted 11 neighboring
data nets. All four RX routes have positive setup/hold margins. Timing-aware
routing left one −0.103 ns hold violation; ordinary hold repair removed it
without worsening setup. The completed post-route reports now show global
**setup +0.006 ns, hold +0.001 ns**, at unchanged 120/300/200 MHz. Logical
connectivity and full routing checks passed. Final source/reset/CDC/DRC checks
and bitstream generation completed successfully at 15:15:41 UTC, with zero
critical warnings/errors. The accepted DCP SHA256 is
`ecb8e9220e955874f30f136c782811c858f519af0ab1a2a09e391f3dc17c96cb`;
bitstream SHA256 is
`1e6b1b85c95780f854016ae8dd50668284119eeed794caa413fa627434e9256e`.
The additional monitor physical audit passed. The image was programmed through
30 MHz JTAG and PCIe re-enumerated at Gen2 ×8. The immediate post-program JTAG
refresh did not see `health_ila`; waveform retrieval has not been requalified
on this image. PCIe inference and the MIG MMIO observer are separately verified.

The frozen owner27 source passed `moon info`, `moon fmt`, native checking with
warnings denied, and all **1,421 native tests**, with zero failures. The final
receipt rechecks all 35 frozen source files. Both the 150/300 and 120/300
configurations passed all 25 complete-system checks with original AMD
simulation libraries, including exact arithmetic, stalls and in-flight reset.
Simulated periods are rounded to integer picoseconds and drift relative phase;
hardware frequencies come from actual MMCM readback.
[Source-bound validation receipt](../artifacts/pblaze3-mig-profile-20261119-b1/OWNER27_VALIDATION_COMPLETE.json).

Verilator, pinned Yosys and the scoped arithmetic/control refinement proofs are
recorded in [the MIG profile implementation history](PBLAZE3_MIG_PROFILE.md).
These checks do not replace complete-model hardware logits validation.

## Performance status

The installed image is `owner120-map109`, scheduler120/MAC300/MIG200 MHz.
Each of control99 and map109 was measured in two independent processes, each
running three four-token warm trials with prompt `Hello`, positions 0–3.
Each image also ran a separate 12-output MIG diagnostic. All **72** complete
151,936-entry FP32 logits vectors across the two campaigns match the qualified
baseline byte for byte. The 24 headline outputs for each image exclude
diagnostic MMIO, reference computation, validation and model loading from timing.
All warm and diagnostic processes uploaded **zero weight bytes**.
[Original baseline](../artifacts/pblaze3-pcie-command-ram-20261118-c1/performance.json),
[final source-bound comparison](evidence/pblaze3-owner120-map-20261120/owner120-map-summary.json).

| Measurement | 100 / 282.353 MHz baseline | 120 / 300 MHz control99 | 120 / 300 MHz map109 |
|---|---:|---:|---:|
| End-to-end tokens/s | 6.166295 | 6.231188 | **6.730568** |
| START-to-DONE cycles/token | 15,903,077.58 | 18,860,069.58 | 17,355,170.71 |
| FPGA time/token | 159.031 ms | 157.167 ms | **144.626 ms** |
| Exposed weight wait/token | 24.587 ms | 39.567 ms | 27.024 ms |
| Matrix weight bandwidth | 9.644 GB/s | 9.756 GB/s | **10.872 GB/s** |
| Matrix share of 12.8 GB/s peak | 75.346% | 76.220% | **84.939%** |
| Wall-time share of peak | 57.422% | 58.026% | **62.677%** |

Frequency alone improved throughput by 1.0524%: issue time fell 15.520 ms/token,
but exposed weight wait rose 14.980 ms. Bank interleaving then saved another
**1,504,898.875 scheduler cycles / 12.541 ms per token**, raising throughput
8.0142% over control99 and 9.1509% over the original baseline. Cycle counts at
different scheduler frequencies must be converted to time. The faster 1024-bit
scheduler interface has receive-idle cycles even with a saturated 512-bit,
200 MHz MIG; raw scheduler gaps are not all removable memory stalls.
[Control performance](evidence/pblaze3-owner120-20261119/owner120-performance.json),
[mapped performance](evidence/pblaze3-owner120-map-20261120/owner120-map-performance.json).

| MIG weight-owned scope per token | Control99 | Map109 |
|---|---:|---:|
| Accepted reads pending, no RVALID | 21.625 ms | **9.077 ms** |
| No accepted read pending, no RVALID | 0.395 ms | 0.397 ms |
| RVALID blocked by RREADY | 0 ms | 0 ms |
| Payload return time | 93.123 ms | 93.123 ms |
| Weight-owned utilization of peak | 80.876% | **90.766%** |

The pending-read gap shrank **58.026%**, saving 12.548 ms/token. The new
distribution spends 61.902 ms with 2–4 pending requests and 40.054 ms with 5–8;
the lifetime pending peak remains 8. ARVALID without ARREADY occupies 83.870 ms
and overlaps these categories; it must not be added to them. These are AXI UI
states, not a direct measurement of DDR activate/precharge/refresh commands.
The controlled mapping change demonstrates its benefit without claiming a
command-level breakdown. Weight-owned, complete-matrix and wall-time bandwidths
use different denominators. The six short warm trials do not establish
long-context throughput or a universal frequency limit.
[Control MIG report](evidence/pblaze3-owner120-20261119/owner120-mig-profile.json),
[mapped MIG report](evidence/pblaze3-owner120-map-20261120/owner120-map-mig-profile.json).

## Accepted bank-interleaved implementation

`owner120-bank-map106` preserves arithmetic, the 1 KiB bursts and clocks, and
implements the vendor `ROW_BANK_COLUMN` map with the proved 29-bit native
address permutation `{addr[28], addr[12:10], addr[27:13], addr[9:0]}`. Eighteen
register D inputs change. The all-output sequential proof covers arbitrary
inputs, stalls and reset; its vendor source is byte-identical to the generated
UI-command module used by control99.

Attempt107 stopped after `Route 35-19` pin-mapping errors and retained its
mapped, unrouted checkpoint. Attempt109 also permutes the 18 flop placements
to preserve input-site affinity, checks every other primitive location
unchanged, and reroutes. It passes complete routing, source/owner/reset/clock
guards, CDC review, DRC and global setup/hold, with zero critical warnings or
errors. The installed `finalize_eco` is Advanced-Flow-only and was not used.
The separate monitor physical audit110 passes.

Build109 completed at 2026-11-19 15:49:18 UTC. Accepted DCP SHA256:
`0f2e6192f95a578d418f390feacfe08bd5aba157e6c6f34d957226b182fd44dc`.
Bitstream SHA256:
`a3df920d20552c504ebc0fb5c301de9516825936f34c695011721176f37edda4`.
Source bundle inventory SHA256:
`25b58a8d1f187ce2a385201d1e4bf9d081d9ada407f29a6633ae01eaf7992086`.
[Physical reports](../artifacts/pblaze3-mig-profile-20261119-b1/frequency150-physical/owner120-map109-accepted/timing.rpt).

The board was programmed at 15:53:49 UTC through 30 MHz JTAG; DONE=1, CRC error=0,
and PCIe returned at Gen2 ×8. No SPI flash was changed. Because the memory map
changed, install112 freshly uploaded **1,192,099,840 bytes** of weights and read
every byte back. Upload plus verification took **5.984 s**; this is weight
transfer time, not total process startup. Programs were also freshly installed.
Warm113/114 and diagnostic115 then reused resident data. All 538 captured input
files were rechecked against their inventories before the final comparison.
ILA waveform retrieval remains unqualified on this image; PCIe inference and
the MIG MMIO counters are separately verified. No build or benchmark is left
running. The new image and resident model are left available on `.191`.
