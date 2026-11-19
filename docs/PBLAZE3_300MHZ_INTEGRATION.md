# PBlaze3 300 MHz array integration

The 120 MHz scheduler / 300 MHz 64-lane MAC / 200 MHz MIG image has passed
whole-system timing (+0.006 ns setup, +0.001 ns hold) and full Qwen3-0.6B
execution on `.191`. It measures **6.231188 tokens/s**, a **1.0524%** gain;
all 36 checked complete logits match bit for bit. MIG counters locate the
largest return gap at accepted reads awaiting data, with zero scoped return
backpressure. A bank-interleaved mapping is now undergoing physical evaluation.
The following implementation history leads to the measurements below.

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

The accepted board image is now scheduler120/MAC300/MIG200 MHz (`owner120-rx99`).
Two independent processes, each running three four-token warm trials, measured
**6.231188 tokens/s**, only **1.0524%** above the previous 6.166295 baseline.
The model was installed once after programming; both headline processes and
the separate diagnostic process uploaded zero weight bytes. Reference work
and complete 151,936-entry logits comparisons stayed outside the timer.
All **36** outputs (24 headline + 12 diagnostic) matched the qualified baseline
byte for byte. Diagnostic MMIO reads are excluded from headline measurements.
[Accepted baseline measurements](../artifacts/pblaze3-pcie-command-ram-20261118-c1/performance.json).

| Measurement | 100 / 282.353 MHz baseline | 120 / 300 MHz control99 |
|---|---:|---:|
| End-to-end tokens/s | 6.166295 | 6.231188 |
| START-to-DONE cycles/token | 15,903,077.58 | 18,860,069.58 |
| FPGA time/token | 159.031 ms | 157.167 ms |
| Exposed weight wait/token | 24.587 ms | 39.567 ms |
| Matrix weight bandwidth | 9.644 GB/s | 9.756 GB/s |
| Matrix share of 12.8 GB/s peak | 75.346% | 76.220% |
| Wall-time share of peak | 57.422% | 58.026% |

Matrix issue time fell by 15.520 ms/token, but exposed weight wait rose by
14.980 ms/token: faster computation mostly exposed the unchanged memory
service time. Cycle totals across different clocks must be converted to time.
[Full-logit performance report](evidence/pblaze3-owner120-20261119/owner120-performance.json),
[source-bound comparison and 36-output check](evidence/pblaze3-owner120-20261119/owner120-control-summary.json).

Comparisons will report actual clock frequency, START-to-DONE cycles and time,
host tokens/s, exposed weight wait, matrix bandwidth and wall-time bandwidth.
A faster 1024-bit scheduler interface has idle receive cycles even when the
512-bit, 200 MHz MIG interface is saturated; raw scheduler wait cycles alone
must not be interpreted as removable DDR latency. Pending-read and handshake
counters at the MIG clock now attribute the remaining gaps. During the measured
weight-owned scope, MIG returned payload for 93.123 ms/token, had pending reads
without RVALID for **21.625 ms**, and had no pending read for **0.395 ms**.
Return-channel backpressure was **zero** during that scope. Pending requests
usually numbered 2–4; the lifetime peak was 8. ARVALID without ARREADY occupied
96.337 ms and overlaps these categories; it must not be added to them.
The MIG weight-owned utilization was **80.876%**, a different denominator from
the complete matrix phase and end-to-end figures above. These are measured AXI
states, not a direct breakdown of DRAM activate/precharge/refresh commands.
[MIG handshake/outstanding report](evidence/pblaze3-owner120-20261119/owner120-mig-profile.json).

The observation selects the previously proved `ROW_BANK_COLUMN` alternative
for physical evaluation. `owner120-bank-map106` preserves the datapath and
clocks, changes only the vendor memory-map configuration, and is implemented
by the proved 18-address-pin permutation. `owner120-map107` starts from accepted
control99; full timing and physical guards remain mandatory. The mapped image
has not yet been accepted or measured. A fresh model/program upload and full
weight readback will be required after changing the mapping.

The first mapping attempt107 was stopped after `Route 35-19` pin-mapping
errors, retaining its mapped, unrouted checkpoint. Source inspection confirmed
that the proof's vendor UI command RTL is byte-identical to the generated
module used by control99. Attempt109 additionally permutes the18 flop
placements to preserve their original input-site affinity, verifies all other
primitive placements unchanged, and reroutes before full acceptance checks.
The installed tool documents `finalize_eco` as Advanced-Flow-only; it is not
used in this Kintex-7 placement repair.
