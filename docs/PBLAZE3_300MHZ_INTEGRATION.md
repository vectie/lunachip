# PBlaze3 300 MHz array integration

The 64-lane MAC array has passed setup and hold timing inside a fully routed
whole-system design at 300 MHz. This is stronger evidence than a standalone
array estimate, but the complete image is not yet timing-qualified. No new
bitstream has been programmed and no new Qwen3-0.6B throughput is claimed.

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
did not modify the input checkpoint. Run99 has not yet been accepted or
programmed.

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

The accepted board image remains scheduler100/MAC282.353/MIG200 MHz, with the
previous **6.166 tokens/s** baseline. A faster image must be measured through
PCIe after one fresh model installation, followed by resident warm trials.
Reference work and complete 151,936-entry logits comparisons stay outside
the timer. MIG diagnostic runs remain separate from headline timing runs.
[Accepted baseline measurements](../artifacts/pblaze3-pcie-command-ram-20261118-c1/performance.json).

Comparisons will report actual clock frequency, START-to-DONE cycles and time,
host tokens/s, exposed weight wait, matrix bandwidth and wall-time bandwidth.
A faster 1024-bit scheduler interface has idle receive cycles even when the
512-bit, 200 MHz MIG interface is saturated; raw scheduler wait cycles alone
must not be interpreted as removable DDR latency. Pending-read and handshake
counters at the MIG clock are needed to attribute the remaining gaps.
