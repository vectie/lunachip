# PBlaze3 board inputs and preparation

The current PBlaze3 is on workstation `QaQ` at `192.168.2.191`. Its
build guest, storage locations and connection commands are documented in
[the workstation guide](../../docs/PBLAZE3_WORKSTATION_191.md).

The first target is **8 × 256MiB = 2GiB**, as instructed by the user on
2026-10-26. This directory contains three exact, small source inputs from the
user's archive, a SHA256 provenance manifest, and this guide. No original
schematic or physical component marking has been verified. No FPGA has been
programmed by this preparation work.

## Input provenance

`vendor/provenance.json` pins the outer archive, inner `xdma_ddr.7z`, original
member paths, and exact retained bytes. The active block design selects the
MIG directory with suffix `_1`; the archive also contains an older sibling.
The source is Vivado 2024.2, `xc7k325tffg900-2`, XDMA Gen2 ×8, 128-bit DMA at
250MHz, and 64-bit DDR3 without ECC, with 128-bit AXI at 200MHz. Its DDR input
selects `MT41K512M8XX-125` and 4GiB. The original AXI-Lite BAR is already 1MiB;
the block design maps only 64KiB of it to GPIO at AXI address `0x40000000`.

The supplied README reports occasional errors. The supplied routed timing
report also has 72 `no_clock` and 56 unconstrained internal endpoints. Neither
the error cause nor the vendor bitstream's reliability has been established.
Recreating inputs does not resolve those physical observations.

Third-party source ownership is retained. Redistribution permission for the
user-supplied inputs is not established; do not assume the repository's
first-party license relicenses these files.

## Build modes

| Mode | Geometry | Release | Purpose |
|---|---|---|---|
| `vendor-baseline` | Original 4GiB MIG input | 2024.2 | Clean reconstruction of original IP geometry for comparison |
| `ddr-smoke` | Provisional 2GiB | 2025.2 default; explicit 2026.1 | XDMA memory tests and GPIO before accelerator integration |
| `accelerator` | Provisional 2GiB | 2025.2 default; explicit 2026.1 | Qwen core, AXI bridge and 1MiB control aperture |

The inspected 2025.2 and 2026.1 catalogs provide XDMA 4.2, while the 2024.2 vendor source
uses XDMA 4.1. The generator pins the corresponding version per build mode;
it does not choose an arbitrary latest IP revision. MIG remains 4.2.

`vendor-baseline` retains the MIG geometry, but uses the new clock/reset
recipe; it is **not** a byte-identical reproduction of the original bitstream.
For the original-project control experiment, extract the pinned inner archive
to a disposable working directory, open the original `.xpr` with Vivado
2024.2, regenerate products there, and retain its fresh reports. Do not copy
that archive's generated caches into this repository or an evidence archive.

The retained MIG source has a corrupt three-byte prefix `EF BB 3F`. The
exporter verifies its exact original hash, removes only that known prefix,
and generates valid XML without changing the retained vendor input. This
normalization also applies to `vendor-baseline`; output bytes therefore
differ from the archived malformed file.

The provisional 2GiB model assumes eight x8 2Gbit components compatible with
`MT41K256M8XX-125`: 15 row, 10 column and 3 bank address bits; 1.5V DDR3;
1600MT/s; 31-bit byte address. These are engineering assumptions, not a
physical identity claim. The generator updates part, row count, capacity,
AXI address width and `tRFC` together and removes A15 and inactive ninth-byte
DQ/DM/DQS pin entries. All active pin assignments preserve source provenance.
Accelerator mode uses five MIG AXI ID bits: the two-master AXI interconnect
prefixes one master-index bit to XDMA's four-bit transaction ID. Smoke and
vendor-baseline modes retain four ID bits.
Vivado catalog acceptance, actual speed grade, voltage and memory marking
still require verification. Change the profile if the physical parts differ.

## Clock, reset and transport contract

- D27 is the source's 50MHz oscillator, LVCMOS18. A clock wizard creates
  200MHz for MIG, 33.333MHz (30ns) for the initial accelerator, and a separate
  50MHz output for transport-reset supervision. The wizard itself has no
  transport-reset feedback.
- PCIe reference clock positive pin is U8, 100MHz. XDMA supplies 250MHz AXI.
  `axi_interconnect` inserts its configured clock/width conversion between
  XDMA, the core, and the 200MHz MIG AXI domain.
- The source uses PERST_n on V22, LVCMOS33. It resets XDMA and, combined with
  source-clock lock, MIG's active-low `sys_rst`. UI and core reset controllers
  also include XDMA's reset. MIG AXI reset, interconnect interfaces, control
  adapter and core share this coordinated transport-reset event.
- A fault is PERST asserted, source MMCM unlocked, MIG UI reset asserted, or
  MIG MMCM unlocked. It asserts XDMA reset immediately and asynchronously
  resets a three-stage XPM reset synchronizer and the canonical MoonBit hold
  counter. Recovery waits for synchronized healthy status and 128 healthy
  50MHz edges before release. This exceeds the PCIe core's 1500ns minimum
  fundamental-reset pulse. The initial source-MMCM-unlocked condition supplies
  the startup reset; no unreset counter value is assumed. The clock may stop
  during a source fault, but assertion does not require a clock edge, and
  release waits for the independent board clock to resume. The synchronizer
  and hold counter never depend on XDMA's non-free-running AXI clock.
  See AMD's [PCIe system interface](https://docs.amd.com/r/en-US/pg054-7series-pcie/System-Interface),
  [reset contract](https://docs.amd.com/r/en-US/pg054-7series-pcie/Resets), and
  [XDMA clock/reset contract](https://docs.amd.com/r/en-US/pg195-pcie-dma/Clocking-and-Resets).
- Calibration status crosses through `xpm_cdc_single` with three destination
  stages. Losing calibration changes `memory_healthy`; it does **not** reset
  the bridge while accepted AXI responses may still exist. The bridge owns
  poison/drain behavior. Recovery requires coordinated transport reset, not
  a software-only core reset while memory transactions remain outstanding.
- The clock wizard's scoped XDC owns the 20ns oscillator clock. The board XDC
  directly declares the 10ns PCIe reference input clock. After synthesis,
  both primary clocks must exist uniquely with those exact periods.
  Generated clock/CDC constraints belong to vendor IP. No broad internal
  false path or asynchronous-clock-group exception hides unconstrained logic.
  LED output paths are false-pathed because they have no synchronous
  off-chip receiver. The separate reset-boundary audit described below
  addresses the vendor's asynchronous `sys_rst_n` interface explicitly.

`pblaze3_layer_system` is the module reference supplied by the root exporter.
Its interfaces are `S_AXI_CTRL` and `M_AXI_DDR`, with `clock`, active-high
`reset`, and synchronized `memory_healthy` ports. The control window is
`0x40000000..0x400fffff` in AXI space; DDR uses a separate DMA address space
`0x00000000..0x7fffffff`. These spaces may numerically overlap without
aliasing. AXI interconnect rejects addresses outside mapped segments.

The `ddr-smoke` image exposes GPIO channel2 DATA as a read-only health word at
control-BAR offset `0x8` (AXI address `0x40000008`). Bit0 is DDR calibration,
bit1 is PCIe link up, and bit2 is MIG UI reset released; `value & 7 == 7`
means all three conditions are present. An `xpm_cdc_array_single` with three
destination stages synchronizes each independent flag into XDMA's 250MHz
domain. This is a smoke-image register, not the accelerator's `PB30` ABI.
GPIO channel1 still controls three LEDs at offset `0x0`. The vendor-baseline
mode preserves its original single-channel GPIO configuration. Host tools
must select the explicit DDR-smoke commands for this image.

## Preparation commands

Run from the repository root. Each output directory must be fresh.

```sh
moon run --target native cmd/pblaze3_board -- export ddr-smoke boards/pblaze3/vendor /tmp/pblaze3-smoke-inputs
moon run scripts/pblaze3-build.mbtx verify /tmp/pblaze3-smoke-inputs
```

Accelerator mode additionally needs `core.sv`, `controller.sv`, `bridge.sv`,
and `pblaze3_layer_system.sv` from the root PBlaze3 exporter, together with
their inventory entries. `pblaze3_calib_sync.sv` comes from the board exporter.
The runner refuses accelerator bundles missing any required RTL identity.

On the supported Linux Vivado host:

```sh
moon run scripts/pblaze3-build.mbtx pin /tools/amd/2025.2/Vivado/bin/vivado /tmp/pblaze3-vivado-pin.json
moon run scripts/pblaze3-build.mbtx build /tmp/pblaze3-smoke-inputs /tmp/pblaze3-vivado-pin.json /tmp/pblaze3-active-work /tmp/pblaze3-prepare-evidence prepare
```

`prepare` performs actual IP generation and block-design validation.
`implement` additionally runs synthesis and routing, refuses missing clocks,
unconstrained internal endpoints, negative setup/hold slack, and DRC errors or
critical warnings before writing a bitstream. Every completed OOC/top
synthesis child log must contain successful completion and normal exit,
with no Error or Critical Warning, before implementation starts. The
implementation child log receives the same checks before bitstream generation.
Missing, unreadable or truncated logs fail closed. Pulse-width, minimum-period and
maximum-skew checks use `report_pulse_width -warn_on_violation`; the gate
requires a valid zero whole-process Critical Warning count. It retains the
pulse-width report, applied XDC, clock report and detailed CDC
report for review; report generation is not proof that CDC is correct. The
runner requires the exact pinned launcher bytes and version output. Full
installation identity and license availability must still be recorded on
the build host. Neither action connects to hardware or writes flash.

The pulse-width detector was exercised with actual Vivado 2025.2 in separate
Artix test processes: a 20ns clock passed with zero Critical Warnings; a
0.1ns clock produced negative minimum-period/pulse-width slack, one Critical
Warning and a rejected gate. See
`docs/evidence/pblaze3-pulse-gate-20261026-a1`. This verifies the gate mechanism,
not the PBlaze3 design's timing.

Keep the working project/cache outside evidence. Reuse one active work area
after preserving unique inputs/reports; never compile inside sealed evidence.
The runner copies only logs, selected reports and the resulting bitstream.
Do not retain redundant vendor caches or checkpoints as proof inputs.

## Board-arrival gate

1. Record board revision, FPGA marking, all memory markings and power rails.
2. Confirm pin/voltage correspondence; inspect DDR voltage and PERST wiring.
3. Load the smoke design temporarily through JTAG after a successful build.
4. Record calibration and PCIe negotiated speed/width; verify DMA low/high
   addresses, address aliases, all 2GiB, random patterns, repeated resets and
   sustained transfers. Preserve exact failing address/data if any error occurs.
5. Only after DDR integrity passes, load the accelerator and replay the same
   Qwen single-layer fixtures and reference outputs used for PRX100.

Passing software tests or IP generation does not authorize claiming physical
DDR stability, routed frequency, full-model throughput, or board performance.

## 2026-10-26 preparation results

Thirteen strict native board-package tests pass, including 2GiB geometry,
inactive-byte pin removal, unknown-profile rejection and malformed-prefix
normalization, explicit release selection, supported XDC commands and the
DDR-smoke health-register contract. The
generated MIG XML passes `xmllint --noout`.

The first real remote Vivado 2025.2 attempt stopped at `create_project` because
the installation lacked Kintex-7. The user refreshed AMD authentication, and
the supported `--batch Add` command completed successfully in attempt
`20261026-a2`, preserving Artix-7 and disabling license-key acquisition. A new
Vivado process then could not recognize `xc7k325tffg900-2`: its 317-part catalog
contained only Kintex-7 70T and 160T variants. The on-disk Kintex catalog also
contained only those devices. This was an installation-edition limit before
synthesis license checkout, consistent with AMD's
[2025.2 supported-device table](https://docs.amd.com/r/2025.2-English/ug973-vivado-release-notes-install-license/Supported-Devices).
The exact catalog probe is generated by `scripts/pblaze3-catalog-probe.mbtx`.

Enterprise device support resolved that catalog limit. AMD documents edition upgrades through
[Add Design Tools or Devices](https://docs.amd.com/r/2025.2-English/ug973-vivado-release-notes-install-license/Adding-Additional-Tools-and-Devices).
The `relay-enterprise` command uses that Add action with a fresh configuration,
changes only the edition and Kintex selection from the original configuration,
and keeps `Acquire or Manage a License Key:0`. Attempt `20261026-a3` completed
successfully. A fresh Vivado process now lists 527 parts including the exact
`xc7k325tffg900-2`. No license key was acquired.

Actual smoke preparation `20261026-a8` passed BD validation and generated the
IP products, including the provisional 2GiB MIG. Its reported interface is
31-bit byte address, 128-bit data, four ID bits and 200MHz. XDMA reports
128-bit data, four ID bits and 250MHz. The run exposed one ignored assignment
to the read-only `C_EXT_RESET_HIGH` parameter; the recipe now checks inferred
reset polarity after propagation instead of assigning it. Actual tool runs
also corrected external-port creation and the required Verilog classification
of BD module-reference wrappers. Core/controller/bridge sources remain
SystemVerilog. Smoke implementation attempt `20261026-a9` then passed IP
generation and attempted synthesis, which failed at license checkout:
`Common 17-345` reports no valid `Synthesis`/`xc7k325t` license, and
`Common 17-348` says the Synthesis feature could not be found. This 2025.2
attempt did not pass synthesis, route, bitstream or hardware qualification. Private installer
logs contain account identity and are excluded from retained evidence.

Accelerator preparation `20261026-a11` also passed BD validation and generated
all IP. Its two-master memory interconnect needs a fifth downstream ID bit:
XDMA owns IDs 0–15 and the accelerator owns ID 16. The generated crossbar has
`ID_WIDTH=5`, S00 thread width 4/base 0, and S01 thread width 0/base 16. Vivado's
`BD 41-2384` warnings describe explicit padding at the XDMA-side input and
truncation after return routing; the full five bits reach MIG. These warnings
remain visible. Post-generation assertions verify the relevant parameters,
leaf widths, connections and generated coupler passthrough before accepting
an input package. This follows the
[AXI Interconnect ID model](https://docs.amd.com/r/en-US/pg059-axi-interconnect/Use-of-ID-Signals).
The guard's actual Vivado positive case and four negative controls are sealed
in `docs/evidence/pblaze3-id-review-20261026-a11`. Wrong crossbar width, wrong
MIG pin width, wrong route peer and narrowed return-ID passthrough all reject.
The strict generated-RTL assertions describe the reviewed 2025.2 output;
another tool release must pass them or receive a separate reviewed update.

The exact inputs and evidence for attempts `20261026-a2` through `a11`, including
the child synthesis license errors, are sealed at
`artifacts/pblaze3-vivado-attempts-20261026-a1`. No synthesis retry is needed
until the user has configured their existing 2025.2 license. The separate
2026.1 installation described below provides the current build route without
changing the 2025.2 defaults.

Final corrected 2025.2 preparation passed for both accelerator attempt `a12`
and smoke attempt `a13`, with zero Critical Warnings and the accelerator's
`AXI_ID_ROUTING=PASS` report. Their exact inputs and logs are sealed at
`artifacts/pblaze3-vivado-attempts-20261026-a2`. The corresponding ready input
pair is `artifacts/pblaze3-ready-inputs-20261026-a3/{smoke,accelerator}`. Both
archives' checksum inventories and seals were verified. Earlier attempts
remain immutable; these 2025.2 preparation runs do not establish synthesis,
route or bitstream success.

The user can refresh authentication privately in their terminal. Do not put
credentials or token contents in chat, source control, or evidence:

```sh
ssh -t pblaze3-host
ssh -t -i /data/lunachip-prx100/vm/id_ed25519 -o UserKnownHostsFile=/data/lunachip-prx100/vm/known_hosts -p 22240 builder@127.0.0.1
/tools/amd/.xinstall/2025.2/xsetup -b AuthTokenGen
```

From the Mac repository, a fresh attempt adds only Standard-edition Kintex-7 support
while preserving the existing Artix-7 selection and disabling license-key
acquisition. This completed attempt is retained as history and is insufficient
for XC7K325T:

```sh
moon run scripts/pblaze3-add-kintex.mbtx relay 20261026-a2
```

The full catalog upgrade uses a fresh run identifier:

```sh
moon run scripts/pblaze3-add-kintex.mbtx relay-enterprise NEW_RUN_ID
```

After the full device catalog is available, resume actual IP/BD preparation
with the assembled bundle and a fresh evidence path:

```sh
moon run scripts/pblaze3-remote.mbtx prepare /ABSOLUTE/COMBINED_BUNDLE NEW_RUN_ID /ABSOLUTE/NEW_EVIDENCE
```

The remote helper uses the existing launcher pin at
`/work/builds/vivado-2025.2-pin.json`. If device installation changes the
launcher/version, explicitly re-pin and review that change before retrying.
`implement` uses the same command shape and additionally runs the physical
implementation gates. Both commands refuse old working/evidence paths and
perform no FPGA or flash programming.

For a separately installed tool, `pblaze3-catalog-probe.mbtx NEW_EVIDENCE
--vivado ABS_GUEST_EXECUTABLE` records that tool's actual device/IP catalog.
The remote helper accepts `--pin ABS_GUEST_PIN` as an explicit final option.
It never updates a pin or changes a board bundle's required release. The pin
command recognizes 2026.1. Its board profile was enabled only after inspecting
the actual installed part and IP catalog; exact patch releases are rejected.

`pblaze3-remote.mbtx pin ABS_GUEST_EXECUTABLE SAFE_RUN_ID NEW_LOCAL_EVIDENCE
--pin NEW_ABS_GUEST_PIN` creates that separate pin and retains the exact runner
used. Existing pin and evidence paths are refused. The board exporter accepts
`--vivado-release RELEASE`; unsupported mode/release pairs fail before writing
outputs. Without that option, original release defaults remain unchanged.
Remote pin/build runners reuse `/work/builds/pblaze3-moon-cache`; Vivado work
directories remain separate for each attempt. Mac transfers disable AppleDouble
metadata explicitly and reject it from the tar member list before upload.
Existing caches and sealed evidence are not removed by these commands.

The separate 2026.1 installer retry completed with exit zero. The actual
launcher is `/tools/amd-2026.1/2026.1/Vivado/bin/vivado`, SW build 6511674,
IP build 6504888 and SharedData build 6501428. The separate immutable pin is
`/work/builds/vivado-2026.1-pin.json`; the existing 2025.2 installation and pin
remain intact. The new process recognizes `xc7k325tffg900-2` and all selected
IP versions. Its BASIC license was detected, and actual synthesis for this
Kintex part passed in the pulse-gate fixture. The 20ns positive fixture
passes with zero Critical Warnings and +9.650ns pulse slack; the 0.1ns
negative fixture reports a real violation and is rejected. Exact evidence is
`docs/evidence/pblaze3-pulse-gate-20261026-2026-1-a1`. This fixture validates
the installed synthesis capability and gate, not the full board design.

Select 2026.1 explicitly for new board inputs and pass its separate pin:

```sh
moon run --target native cmd/pblaze3_board -- export ddr-smoke boards/pblaze3/vendor /tmp/pblaze3-smoke-20261 --vivado-release 2026.1
moon run scripts/pblaze3-remote.mbtx implement /tmp/pblaze3-smoke-20261 arrival-smoke-a1 /ABSOLUTE/NEW_EVIDENCE --pin /work/builds/vivado-2026.1-pin.json
```

Use `accelerator` with the same explicit release before assembling the root
digital export. Each exact prepared bundle retains its required release, and
the runner rejects a mismatching pin. No certificate, authentication token,
private installer log, or generated vendor cache is part of the evidence.

Run identifiers contain only lowercase letters, digits and hyphens. The board
export retains the canonical reset RTL as `pblaze3_transport_reset_core-ordinary.sv`
and gives only its two module inputs an explicit `wire` net kind in the physical
`pblaze3_transport_reset_core.sv`. This matches the existing target adaptation
required by Vivado with `default_nettype none`; reversing those two declarations
must recover the canonical source byte for byte. The portable emitter is unchanged.

The initial 2026.1 smoke and accelerator IP/core syntheses passed, but their
top synthesis exposed two `Designutils 20-1307` Critical Warnings: XDC does
not support the conditional `if` commands previously used around clock
creation. Those inputs are rejected. Both task-owned implementations were
intentionally interrupted after recording the top-level failure, before any
bitstream. The corrected generator removes the redundant oscillator clock
declaration, directly constrains the PCIe reference input, and checks the
actual primary clocks after synthesis. It also checks child-process logs;
Vivado run objects expose no warning-count property, and parent counters do
not establish that child runs were clean. Actual clean XDMA/MIG logs pass;
the rejected top log, missing/truncated logs and nonzero warning summaries
are negative controls.

For a correction that leaves an IP unchanged, the remote helper optionally
accepts `--reuse-ip-cache ABS_PREVIOUS_WORK` after `--pin`. It uses Vivado's
[native IP cache](https://docs.amd.com/r/en-US/ug896-vivado-ip/Setting-the-IP-Cache)
in read-only mode. The previous tool version must match exactly. Each cached
DCP must have a successful original producer log naming the same cache ID;
all cache files and producer logs receive recorded SHA256 identities. No
cache or DCP is copied into the evidence archive. A missing producer or
changed cache ID is rejected. The actual stopped smoke cache's eight entries
passed these checks. Current full builds remain fresh projects with their
own input inventories and reports; unchanged IPs may receive native cache
hits, while the corrected top is synthesized again.

Vivado's `IP_CACHE_PERMISSIONS=read` still updates native `stats.txt` usage
counters; it does not make the cache filesystem immutable. Post-use checks
for corrected attempts `a4`/`a5` verified all 64/86 payload and producer-log
identities unchanged, with exactly two changed usage-counter files in each
source cache. Their before/after hashes are retained separately. These work
caches are outside sealed evidence. The additive ready revision `a3` makes
producer-key comparison an exact full-token match; a truncated-key negative
control rejects. Actual `a4`/`a5` consume ready revision `a2`, with all eight
smoke and eleven accelerator keys rechecked by the corrected helper in
`docs/evidence/pblaze3-physical-review-20261026-2026-1-a1`.

The next full routes (`a4` smoke and `a5` accelerator) passed corrected XDC
parsing, synthesis child gates and native cache verification. Both then
failed routed timing and were rejected before bitstream generation. Their
exact inputs and reports are sealed in
`artifacts/pblaze3-vivado-attempts-20261026-2026-1-a2`.
Smoke WNS was -2.655ns with seven failing endpoints, all at the vendor PCIe
asynchronous reset boundary. Accelerator WNS was -2.654ns with the same seven
endpoints and two additional genuine PCIe hardblock-to-BRAM failures of
-0.022ns and -0.005ns. Those payload timing checks remain required.

An independent routed-netlist audit traced the complete transport-reset
fanout to exactly seven vendor reset controls: two PIPE asynchronous clears,
three status-register synchronous resets and two user-reset asynchronous
presets. The vendor source and its scoped CDC waivers document the
asynchronous system-reset contract and the link/reset release sequence.
The new supervisor enforces pulse duration. A separately reviewed, exact
seven-endpoint boundary constraint is applied only during implementation,
after a fail-closed linked-netlist guard. Linked synthesis has exactly ten
reset endpoints; the three additional vendor shadow/status registers must
have proven unused output chains. Routed optimization can replicate the
reviewed `user_reset_out_reg`; the final guard accepts only copies with exact
parent/origin, FDPE primitive, initialization and C/CE/D/PRE input-net equality.
The complete fanout must equal the seven reviewed controls plus those proven
copies. Actual smoke/accelerator routes have eight/ten copies respectively.
Vivado propagates the same seven-pin exception to precisely those replica
PRE pins; the source XDC remains unchanged. Wrong origin, changed D input
and unrelated extra fanout are tested rejection cases.
The checks also bind primitive kinds, PIPE synchronizer attributes and
connections, status-source synchronization, and vendor reset release logic.
The supervisor's actual clock must be 20ns with direct primary ancestor
`clk_in1_50M`; a faster or XDMA-derived clock is rejected. This is not a broad
clock-domain exception. Reset-supervisor
preview `a6` passed BD/IP generation only; it does not establish synthesis,
timing closure or physical qualification.

The corrected canonical reset emission is verified in
`artifacts/pblaze3-reset-offline-20261026-a2`: 14,784 replay timestamps,
strict pinned Yosys synthesis, 260-step bounded proof, and a deliberately
wrong 127-edge release counterexample. Its exact emitted core is also bound
to actual Vivado 2026.1 XPM simulation in
`artifacts/pblaze3-vendor-reset-20261026-a7`. That simulation covers each of
the four fault predicates, a 1ns fault pulse, repeated faults, a stopped
50MHz clock, and release only after 131 recovery edges with no XDMA clock.
This verifies digital reset behavior; it does not measure metastability or
qualify the physical board.

The exact boundary guard passed actual 2026.1 linked synthesis and routed
checks on rejected smoke `a4`; wrong fanout and missing primitive controls
rejected. Applying only the seven-pin exception in memory removed its reset
timing failures while leaving structural CDC entries visible. This diagnostic
did not change the saved project, reroute, or generate a bitstream.

Fresh supervisor builds `a9`/`a10` pass routed timing: smoke setup/hold slack
is +0.013/+0.014ns, accelerator +0.004/+0.015ns. Their original strict
seven-endpoint guard rejected the physical replicas, preserving those failed
attempts. Independently reviewed clone-aware finalization then reran all
physical gates against the unchanged project/checkpoint identities and wrote
the accepted bitstreams in `artifacts/pblaze3-finalized-smoke-20261026-a1`
and `artifacts/pblaze3-finalized-accelerator-20261026-a1`. Final acceptance
requires exit0, `BUILD_COMPLETE`, a nonempty bitstream and zero parent-process
errors/Critical Warnings after bitstream generation. Independent CDC/reset
review is retained in
`docs/evidence/pblaze3-supervisor-review-20261026-2026-1-a3`; vendor hidden
FIFO structures remain a stated review limitation. Neither image has run on
the physical board. The small positive timing margin is the measured result,
not evidence of board signal integrity or DDR component identity.

Vivado MIG updates its XML input during AXI capability propagation. In the
accelerator it changes exactly `C0_S_AXI_SUPPORTS_NARROW_BURST` from 0 to 1,
matching the core interface metadata. The original/effective XML, generated
parameters, installed vendor callback, actual BD properties and mapped
full-beat SIZE4/LEN0 traffic are audited in
`docs/evidence/pblaze3-mig-effective-review-20261026-2026-1-a1`.
No DDR geometry, address width, data width or ID width changes. This audit
does not claim two independently synthesized flag values are bit-identical.

Ready revision `artifacts/pblaze3-ready-inputs-20261026-2026-1-a6` integrates
the reviewed guard and final bitstream checks. It copies exported `mig.prj`
to immutable `mig-source.prj` and mutable `mig-effective.prj` in fresh work;
only the latter is given to MIG. Smoke/baseline bytes must stay identical;
accelerator permits only the exact single-tag change above. The build retains
both XML files, hashes, geometry/interface assertions, and rechecks the
original bundle inventory. Fresh actual 2026.1 prepare runs `a11`/`a12`
pass this contract. Latest cache postchecks bind unchanged payload/producer
logs separately from seven/ten changed vendor usage-counter files. Final
source-delta validation is 16 targeted board tests, strict CLI/global checks,
and positive/negative Tcl mutation probes; the preceding full native suite
passed 1,349 tests on its separately recorded frozen baseline.
