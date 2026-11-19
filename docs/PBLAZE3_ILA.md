# PBlaze3 ILA diagnostic images

The accepted October 26 smoke and accelerator images contain no ILA. The
October 28 diagnostic work adds explicit profiles for first-board diagnosis.
These profiles are separate builds; they do not replace the accepted production
images or establish that the physical card works. All four diagnostic images
have passed their actual tool, independent review and pairing gates. Actual
linked synthesis rejected multiple ILA instances under the installed BASIC
license. Each supported profile therefore contains one ILA. The final native
suite passes 1,358 tests. On 2026-10-29, the status-only image passed physical
volatile programming and two actual ILA acquisitions on `xc7k325t`, IDCODE
`43651093`. All 1024 samples in each capture were `0x197`: source/MIG clocks
locked, DDR UI reset released and calibration complete. The card had power
and JTAG only; PCIe link and XDMA reset release were low. The
[physical verification record](../artifacts/pblaze3-board-verification-20261029-a1/README.md)
retains raw captures and limits: this is not a DDR capacity/integrity test.
Physical capture of the MIG, XDMA and core profiles remains untested.

## Accepted image artifacts

The status-only image has passed synthesis, routing, checked timing coverage,
setup/hold/pulse-width, DRC, bus-skew and final debug-core checks in Vivado
2026.1. Worst setup slack is +0.018 ns and hold slack +0.015 ns, with no failing
endpoints and zero final errors/critical warnings. Its ten ordinary tool
warnings and the reviewed CDC findings remain in the evidence.

- [Status bitstream](../artifacts/pblaze3-ila-finalized-status-20261028-a1/probes/status-finalization/outputs/pblaze3.bit):
  SHA256 `27e80840530db40c8eaeec98d7ec7041eeaafa5aabf92907f6d50c2e4eaefacb`.
- [Matching status probes](../artifacts/pblaze3-ila-finalized-status-20261028-a1/probes/status-finalization/outputs/pblaze3.ltx):
  SHA256 `07e3506bdfd84a12332aa1e041a71867e4cce8dff93e796e47f1e470fa47ba84`.
- [Pairing receipt](../artifacts/pblaze3-ila-pair-status-20261028-a1/receipt.json)
  binds the exact original layout, routed UUID/probe rows and checked-build marker.
- [Build history](../artifacts/pblaze3-ila-finalized-status-20261028-a1/attempts.json)
  preserves the initial project-context debug-query rejection and the successful
  standalone finalization of the same hash-pinned routed checkpoint.
- [Independent final review](evidence/pblaze3-ila-status-final-review-20261028-a1/README.md)
  checks the completed image against the original routed timing, reset and CDC
  evidence, including the preserved diagnostic-only CDC finding described below.

The final single-domain recipes and 23 targeted test results are retained in
[the ready-input inventory](../artifacts/pblaze3-ila-ready-inputs-20261028-a2/manifest.json),
which references the unchanged earlier status and combined-profile inputs.
The accepted status image keeps its original exported layout as provenance;
later additive layout annotations are not substituted into its pairing record.

The MIG, XDMA and accelerator-core images also pass checked timing coverage,
setup/hold/pulse width, DRC, bus-skew, routed probe mapping and final bitstream generation.
Each pairing receipt binds the exact bitstream, LTX, layout and routed guards:

| Profile | Bitstream and matching probes | Setup / hold slack | Pairing and independent review |
| --- | --- | --- | --- |
| `ddr-mig-ila` | [bit](../artifacts/pblaze3-ila-finalized-mig-20261028-a1/build/outputs/pblaze3.bit), [LTX](../artifacts/pblaze3-ila-finalized-mig-20261028-a1/build/outputs/pblaze3.ltx) | +0.024 / +0.015 ns | [pair](../artifacts/pblaze3-ila-pair-mig-20261028-a1/receipt.json), [review](evidence/pblaze3-ila-mig-final-review-20261028-a1/README.md) |
| `ddr-xdma-ila` | [bit](../artifacts/pblaze3-ila-finalized-xdma-20261028-a1/build/pblaze3.bit), [LTX](../artifacts/pblaze3-ila-finalized-xdma-20261028-a1/build/pblaze3.ltx) | +0.047 / +0.013 ns | [pair](../artifacts/pblaze3-ila-pair-xdma-20261028-a1/receipt.json), [review](evidence/pblaze3-ila-xdma-final-review-20261028-a1/README.md) |
| `accelerator-core-ila` | [bit](../artifacts/pblaze3-ila-finalized-core-20261028-a1/build/pblaze3.bit), [LTX](../artifacts/pblaze3-ila-finalized-core-20261028-a1/build/pblaze3.ltx) | +0.010 / +0.016 ns | [pair](../artifacts/pblaze3-ila-pair-core-20261028-a1/receipt.json), [review](evidence/pblaze3-ila-core-final-review-20261028-a1/README.md) |

MIG's default route missed setup timing by 0.017 ns. Post-route physical
optimization made no changes and did not close timing. The accepted image
comes from rerouting the same placed design with `route_design -unroute` and
`route_design -directive Explore`, with unchanged clock and timing constraints.
The original failure and unsuccessful recovery remain sealed in the
[rejected build](../artifacts/pblaze3-ila-mig-rejected-20261028-a1/manifest.json)
and [physical-optimization attempt](../artifacts/pblaze3-ila-mig-physopt-rejected-20261028-a1/manifest.json).
The accepted [recovery driver](../artifacts/pblaze3-ila-finalized-mig-20261028-a1/build/runner.mbtx)
and [build record](../artifacts/pblaze3-ila-finalized-mig-20261028-a1/manifest.json)
retain the original checkpoint identities and restoration locations. This is
an accepted checkpoint recovery; it does not establish that a fresh default
route from the current recipe will close timing. Its pairing uses the original
a7 layout. The current a8 MIG export changes only explanatory limitations text,
and must not be substituted into that pairing record. XDMA and accelerator-core
passed fresh builds without checkpoint recovery.

The MIG and XDMA reviews preserve all 52 production-smoke CDC rows. Their
additional findings lie inside the vendor ILA/debug-hub hierarchy, including
critical categories with hidden implementation details. These are retained
review limitations, not a clean CDC report. Final fresh-checkpoint CDC rows
match each image's final report. MIG's final report is not byte-for-byte or
endpoint-name identical to its rejected route: one vendor-hidden CDC-3 source
hierarchy changes while the reported clock pair, destination, severity and
synchronizer depth remain the same. Each accepted image has zero final tool
errors or critical warnings; ordinary warnings and CDC findings are retained
separately in its independent review.

The accelerator-core review accounts for all 88 production-accelerator CDC
rows: 83 match exactly; five refer to the original XDMA reset register where
the production report names its fanout replica. The retained reset proof
establishes that specific replica's origin, register type, initial value and
identical control/data nets. Only those five exact substitutions are applied.
Its 70 additional rows lie within the vendor ILA/debug hub, including two
hidden CDC-10 control crossings. The review retains these findings and the
unchanged accelerator DSP pipelining warnings; it does not claim CDC cleanliness.

## Profiles and clocks

| Profile | Intended observation | Debug clocks |
| --- | --- | --- |
| `ddr-status-ila` | PCIe reset, source/MMCM status, DDR calibration and reset supervision | Raw board 50 MHz only |
| `ddr-mig-ila` | Host-to-DDR traffic at the MIG interface | MIG UI 200 MHz; hub at raw 50 MHz |
| `ddr-xdma-ila` | PCIe DMA/control traffic at XDMA | XDMA AXI 250 MHz; hub at raw 50 MHz |
| `accelerator-core-ila` | Accelerator memory/control traffic | Core 33.333 MHz; hub at raw 50 MHz |

The status, MIG and XDMA profiles retain the DDR smoke image's GPIO/control
map; they do not expose the accelerator ABI. Use `accelerator-core-ila` for an
accelerator host campaign and the smoke workflow for the other profiles.
AXI-only images contain no raw-50-MHz status ILA or unused status synchronizer;
their probe layouts include the existing local-domain status fields.
MIG `probe0` includes calibration complete, UI reset and AXI reset release;
XDMA `probe0` includes AXI reset release and link up; core `probe0` includes
core reset and memory healthy. The XDMA/core images also capture their local
AXI-Lite control channels. Exact offsets are in each image's paired layout.
The core's `memory_healthy` field is the existing three-stage synchronized
calibration-complete level used by the accelerator. It is delayed telemetry,
not a separate test of PCIe link health or successful DDR transactions.
Sampling these flags with the local AXI clock does not make every status edge
synchronous: reset assertion may be asynchronous. Treat them as sampled levels,
not a coherent transaction snapshot or a guaranteed record of short pulses.

The original `ddr-smoke-ila` and `accelerator-ila` combined modes retain their
original meaning, but are not accepted with the installed BASIC license.
Actual linked synthesis reports `Chipscope 16-620` for multiple ILA instances,
even though each ILA's separate synthesis succeeds. The one-domain profiles
avoid that unsupported configuration without changing AXI sampling clocks.
The [retained multi-core attempts](../artifacts/pblaze3-ila-multicore-rejected-20261028-a1/attempts.json)
distinguish the smoke design's actual license rejection from the accelerator
design's intentional stop before its top-level synthesis.

Start with the status-only profile when DDR or PCIe clocks are unavailable.
The diagnostic input wrapper shares an explicit IBUF and BUFG between the
50 MHz debug clock and the Clocking Wizard configured with `No_buffer`.
The debug hub and status ILA therefore do not depend on that MMCM, MIG
calibration or XDMA reset release. The production reset supervisor is unchanged.
The board oscillator and working JTAG connection are still prerequisites.

AXI signals are captured synchronously in their own domains. A stopped domain
cannot provide an AXI waveform, and a free-running hub alone does not establish
communication with an ILA whose sampling clock is stopped. This is the reason
for a separate status-only image. AMD requires stable debug clocks and advises
meeting timing after instrumentation; see
[UG908 timing considerations](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/ILA-Core-and-Timing-Considerations)
and [debug clock requirements](https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Debug-Core-Clocks).

AXI observation uses passive Monitor interfaces joined to the existing
interface nets. Direct scalar connections were rejected after actual Vivado
generation showed that they could replace implicit interface wiring. The
[passive-monitor proof](evidence/pblaze3-ila-passive-monitor-20261028-a1/README.md)
checks all 37 AXI4 and 19 AXI-Lite signals across their master, slave and monitor
endpoints, with five disconnected-signal negative controls. That fixture proves
the connection method; each full diagnostic profile still needs its own
generated-net and implementation checks.

The profiles directly instantiate ordinary ILA 6.2 in Native mode with AXI
monitoring disabled. They do not use System ILA or automatic debug insertion.
Each supported image has one ILA, at most five probe buses, depth 1,024 and one
input pipeline stage. The published BASIC feature table specifies a five-probe,
1,024-bit-width limit; the additional instance-count restriction was established
by actual linked synthesis. The
[catalog probe](evidence/pblaze3-ila-architecture-probe-20261028-a1/README.md)
also found that leaving AXI monitoring enabled can silently expand the probe
count. See
[UG973 feature availability](https://docs.amd.com/r/en-US/ug973-vivado-release-notes-install-license/Feature-Availability-by-Subscription-Tier).

## Status interpretation

`ila_reset50/probe0` contains nine independently synchronized levels, with
bit 0 at the least significant end:

| Bit | Signal | Healthy operating level |
| --- | --- | --- |
| 0 | PCIe `PERST_N` | 1 |
| 1 | Source Clocking Wizard locked | 1 |
| 2 | MIG MMCM locked | 1 |
| 3 | MIG UI reset | 0 |
| 4 | MIG calibration complete | 1 |
| 5 | XDMA AXI reset released | 1 |
| 6 | PCIe link up | 1 after link training |
| 7 | Raw transport-health conjunction | 1 |
| 8 | Transport supervisor released | 1 after its recovery interval |

These levels pass through three synchronizer stages and the ILA input
pipeline. They are not a coherent multi-bit snapshot and may miss short pulses.
The actual status-image CDC report flags the combinational fan-in of bit 7
(`transport_healthy`) as CDC-10. Its sampled level can reflect input-skew or
glitch transients. It is telemetry, not a fault counter. Routed review verifies
that the synchronized outputs feed only the status ILA input pipeline, with
no feedback into functional control. This reviewed finding does not make the
whole design's CDC report clean.
The [independent routed review](evidence/pblaze3-ila-routed-probe-20261028-a1/README.md)
retains all nine original-source-to-first-stage mappings, ILA-only fanout,
the exact routed LTX and bus-skew gate sensitivity.
The final transport-reset net is deliberately not tapped: its existing exact
endpoint check remains intact. Bits 7 and 8 expose the gate's operands;
their delayed samples cannot reconstruct the exact asynchronous reset edge.

At 50 MHz, 1,024 samples cover approximately 20.48 microseconds. This is not a
record of the entire power-on calibration interval. Use an immediate capture
to inspect current levels, or arm a transition trigger before reproducing a
controlled reset/calibration event. Capturing after calibration has already
completed cannot recover the earlier startup waveform.
With every cycle captured, the same depth spans 5.12 microseconds at MIG's
200 MHz, 4.096 microseconds at XDMA's 250 MHz, or 30.72 microseconds at the
core's 33.333 MHz. Separate images and clocks do not provide an aligned
cross-domain timeline.

## First-board workflow

1. Follow the exact-device discovery and volatile programming procedure in
   [the JTAG guide](PBLAZE3_JTAG.md). Select the diagnostic image explicitly.
2. Use the `.ltx` produced with that exact `.bit`. In Vivado Hardware Manager,
   set the selected device's probes file and refresh it. A production image
   without ILA cannot use a diagnostic probes file.
3. For initial status, select `ila_reset50`, capture immediately, and interpret
   the nine bits above. If an AXI image cannot expose its debug core while its
   sampling clock is stopped, use `ddr-status-ila`.
4. Once clocks are stable, use the AXI profile and arm the relevant ILA before
   starting a small host upload/readback or accelerator job. Count a transfer
   only on a sampled edge where VALID and READY are both one. Stable VALID with
   READY low is a stalled request, not a completed transaction. Inspect address,
   response, LAST and strobe fields alongside the handshake.
5. Save captured `.ila` data and CSV/VCD exports together with the paired image
   hashes, `diagnostic.json`, selected cable/device identity, trigger settings,
   host command logs and the observed failure. Preserve unsuccessful captures.

The exported `diagnostic.json` is the authoritative probe layout: it binds each
core clock, probe width and field bit offset to the wiring generator. Read its
field definitions when selecting AXI triggers; do not guess bit positions.
No physical capture has been performed before card arrival.

The following low-bit positions are common to the three AXI-domain ILAs:

| Probe | Bit 0 | Bit 1 | Other channel control bits |
| --- | --- | --- | --- |
| `probe0` | AWVALID | AWREADY | Address/ID/burst and local status follow |
| `probe1` | WVALID | WREADY | WLAST at bit 2 |
| `probe2` | BVALID | BREADY | BRESP at bits 3:2 |
| `probe3` | ARVALID | ARREADY | Address/ID/burst follow |
| `probe4` | RVALID | RREADY | RLAST at bit 2; RRESP at bits 4:3 |

For example, `probe1[1:0] == 2'b11` marks an accepted write-data beat;
`2'b01` marks VALID with backpressure. A single stalled sample is normal AXI
behavior; correlate sustained stalls with calibration, reset and the other
channel captures. Address, payload and AXI-Lite field offsets vary by domain
and are specified in the paired layout file.

## Probe-file checks

The [pair checker](../scripts/pblaze3-ila-check.mbtx) validates Vivado's actual
LTX representation: exact core names/counts, unique UUIDs and debug locations,
probe widths and packed-bus bit ordering. Its `inspect` operation also works on
an intermediate LTX, but establishes no routed-image acceptance:

```sh
moon run scripts/pblaze3-ila-check.mbtx -- inspect /absolute/diagnostic.json /absolute/pblaze3.ltx
```

For a completed build, `bind` additionally compares the LTX against the routed
core UUID/property/probe rows, requires the routed guard and checked-build
completion markers, and records hashes for the exact `.bit`, `.ltx`, layout and
guard evidence. Supply the expected layout SHA256 from the independently
reviewed build-input inventory, not a newly calculated value from an unknown
layout. Field meanings depend on that trusted exporter and its generated
connectivity checks; an LTX bus alone cannot prove semantic field labels.

```sh
moon run scripts/pblaze3-ila-check.mbtx -- bind /absolute/diagnostic.json EXPECTED_DIAGNOSTIC_SHA256 /absolute/build-outputs /tmp/pblaze3-ila-pair-new
```

The output directory must be new. This pairs recorded artifacts; it does not
parse bitstream configuration semantics or test JTAG hardware communication.
The [checker regression](../artifacts/pblaze3-ila-check-tests-20261028-a4/receipt.json)
passes 89 cases, including the actual status LTX preview, all three exported
single-core layouts, and malformed probe, clock, UUID, trusted-layout identity
and completion-marker controls. Synthetic single-core LTX and pairing fixtures
exercise parser behavior and are not accepted FPGA images or license evidence.
The [actual guard evidence](evidence/pblaze3-ila-guards-20261028-a1/README.md)
includes an optimized-checkpoint preview, 117 accelerator/75 smoke captured
field connections and negative controls. The routed completion marker is
deliberately absent from preview evidence.
The [single-MIG optimized-checkpoint check](evidence/pblaze3-single-mig-ila-opt-20261028-a1/README.md)
also passes on a real five-probe LTX after the one-ILA design's successful
linked synthesis. It checks native 200 MHz capture and the independent raw
50 MHz hub, but remains separate from final routed acceptance.

## Software and tool acceptance

Required checks are deterministic exports, unchanged production-profile
outputs, native regressions, actual Vivado IP/BD validation, synthesis,
implementation, DRC and timing gates, plus matching `.bit`/`.ltx` output.
The routed review must also confirm the raw 50 MHz debug-clock ancestry,
native-domain AXI probes, status synchronizers and unchanged reset endpoints.
Hardware communication and the usefulness of real captured waveforms remain
arrival gates.

The [final native phase](../artifacts/pblaze3-ila-native-20261028-a3/README.md)
passes `moon info`, `moon fmt`, native check with `--deny-warn`, and all
1,358 default native tests with `--deny-warn`. Source/interface snapshots remain
unchanged through the phase. This result covers the final a8 board/CLI sources;
it does not rerun the older release suite or establish physical capture.

To export a diagnostic board profile, use the explicit 2026.1 release:

```sh
moon run --target native cmd/pblaze3_board -- export ddr-status-ila boards/pblaze3/vendor /tmp/pblaze3-status-ila-new --vivado-release 2026.1
moon run scripts/pblaze3-build.mbtx -- verify /tmp/pblaze3-status-ila-new
```

Select `ddr-mig-ila` or `ddr-xdma-ila` for the corresponding host-to-DDR probes.
For `accelerator-core-ila`, also export and assemble the unchanged digital
accelerator using the commands in the
[arrival runbook](PBLAZE3_BRINGUP.md). Keep the diagnostic profile explicit
through export, implementation, pairing and JTAG image selection.
