# PBlaze3 2 GiB arrival runbook

Prepared 2026-10-26 for **eight 256 MiB DDR3 parts**. Start with the
[port contract](PBLAZE3_PORT.md) and the [physical profile](../boards/pblaze3/README.md).
Run repository commands from the LunaChip root. Output paths must be new;
replace example run IDs for each attempt. No command below writes SPI flash.

Before the equipment arrives, use the [software preparation guide](PBLAZE3_SOFTWARE_PREPARATION.md)
for offline host tooling and failure-path validation.
The [ILA diagnostic guide](PBLAZE3_ILA.md) describes the separate status and
AXI observation profiles. The two accepted images below contain no ILA.

The [first physical status verification on 2026-10-29](../artifacts/pblaze3-board-verification-20261029-a1/README.md)
passes JTAG configuration and status-ILA capture, with DDR calibration complete
in two snapshots. The card currently has power and JTAG only. PCIe and full
2 GiB memory integrity remain arrival gates; the status result does not replace
the tests below.

Both images pass final physical-build acceptance and independent routed
reset/CDC review. Neither has been programmed or tested on the real board.
Confirm the FPGA, DDR and electrical assumptions below before loading either.

| Image | Accepted bitstream | Setup / hold slack |
|---|---|---|
| DDR/PCIe smoke | [pblaze3.bit](../artifacts/pblaze3-finalized-smoke-20261026-a1/probes/smoke-finalization/outputs/pblaze3.bit) | +0.013 / +0.014 ns |
| ABI 1.1 accelerator | [pblaze3.bit](../artifacts/pblaze3-finalized-accelerator-20261026-a1/probes/accelerator-finalization/outputs/pblaze3.bit) | +0.004 / +0.015 ns |

The [smoke receipt](../artifacts/pblaze3-finalized-smoke-20261026-a1/attempts.json)
pins SHA256 `8e710d9cb577c68a7ebdf73e243a47d60197dbe98d0b6973b7622d6254eafbb5`;
the [accelerator receipt](../artifacts/pblaze3-finalized-accelerator-20261026-a1/attempts.json)
pins SHA256 `36d03e54018b30836079e5bb7e6b7a04c382e3ed04e7d7edbd13850f621819ae`.
These are small positive timing margins, not measurements of board operation.
The [reviewed CDC findings](evidence/pblaze3-supervisor-review-20261026-2026-1-a3/review.md)
include intentional reset boundaries and vendor structures; CDC is not reported
as clean, and encrypted vendor FIFO internals remain outside independent proof.

The [latest reproduction inputs, a6](../artifacts/pblaze3-ready-inputs-20261026-2026-1-a6/README.txt)
contain `smoke/` and `accelerator/`. Their [final recipe validation](../artifacts/pblaze3-final-generator-delta-20261026-a1/attempts.json)
covers the proven reset replicas, post-bitstream checks and isolated MIG working
copy with exact source/effective XML validation. Both fresh Vivado prepare runs
pass and preserve the original bundle inventories. The accepted images were
finalized from the unchanged a5 routed checkpoints; a6 changes verification and
input handling, with identical hardware RTL and source XDC. It does not claim
another full routed build. Earlier rejected attempts remain in the port ledger.

## Recreate the digital and physical inputs

```sh
moon run --target native cmd/pblaze3 -- export /tmp/pblaze3-digital-new
moon run --target native cmd/pblaze3_board -- export accelerator boards/pblaze3/vendor /tmp/pblaze3-board-new --vivado-release 2026.1
moon run scripts/pblaze3-build.mbtx -- assemble /tmp/pblaze3-board-new /tmp/pblaze3-digital-new /tmp/pblaze3-combined-new
moon run scripts/pblaze3-build.mbtx -- verify /tmp/pblaze3-combined-new
```

For the first DDR/PCIe image, export `ddr-smoke` instead. This image has
GPIO control and DMA access, without the accelerator ABI. Do not use the
accelerator's `status` command to identify that image.

```sh
moon run --target native cmd/pblaze3_board -- export ddr-smoke boards/pblaze3/vendor /tmp/pblaze3-ddr-new --vivado-release 2026.1
moon run scripts/pblaze3-build.mbtx -- verify /tmp/pblaze3-ddr-new
```

On the Linux Vivado host, pin the actual launcher and version, generate IP,
then build with the checked timing/DRC recipe. Work caches stay outside evidence.
Base 2026.1 is installed separately with a free BASIC certificate, valid
through 2027-10-26. Actual XC7K325T synthesis and both pulse-width gate probes
pass. The exporter retains 2025.2 as its default; select `--vivado-release
2026.1` explicitly, as above, to use the new tool. The generated bundle's
required release must match its pin. [License and installation records](PBLAZE3_VIVADO_LICENSE.md)
include the completed installation and certificate checks.

```sh
moon run scripts/pblaze3-build.mbtx -- pin /tools/amd-2026.1/2026.1/Vivado/bin/vivado /tmp/pblaze3-vivado-pin-new.json
moon run scripts/pblaze3-build.mbtx -- build /tmp/pblaze3-combined-new /tmp/pblaze3-vivado-pin-new.json /tmp/pblaze3-work-new /tmp/pblaze3-prepare-new prepare
moon run scripts/pblaze3-build.mbtx -- build /tmp/pblaze3-combined-new /tmp/pblaze3-vivado-pin-new.json /tmp/pblaze3-route-work-new /tmp/pblaze3-route-new implement
```

The existing remote relay is automated by `scripts/pblaze3-remote.mbtx`;
the [board guide](../boards/pblaze3/README.md) records its environment and the
private AMD authentication procedure. A successful build must retain its source
and tool identities, timing/coverage/DRC/CDC reports and bitstream hash.
Review the CDC report before using a newly built image.
The corrected recipe checks completed child-run logs before advancing;
Vivado's `100%` run progress alone is insufficient. It also verifies both
primary-clock periods and rejects timing coverage, setup/hold, pulse-width
or DRC failures before writing a bitstream.

The existing VM already has `/work/builds/vivado-2026.1-pin.json`. To use it
from this Mac through the configured relay, select that pin explicitly:

```sh
moon run scripts/pblaze3-remote.mbtx implement /tmp/pblaze3-ddr-new arrival-smoke-a1 /tmp/pblaze3-smoke-evidence-new --pin /work/builds/vivado-2026.1-pin.json
moon run scripts/pblaze3-remote.mbtx implement /tmp/pblaze3-combined-new arrival-accelerator-a1 /tmp/pblaze3-accelerator-evidence-new --pin /work/builds/vivado-2026.1-pin.json
```

Run IDs accept only lowercase letters, digits and hyphens; choose fresh IDs
for subsequent attempts. The remote helper rejects an existing run/evidence
directory and verifies the transferred input inventory before invoking Vivado. The two examples build
images only; actual programming is a separate arrival step below.

## Repeat the offline gates

These commands need no FPGA. The EDA gate uses the pinned Verilator/Yosys
container images and the `colima-lunachip-validation` Docker context. Evidence
and compiler work directories must be distinct fresh absolute paths.

```sh
moon info
moon fmt
moon check --target native --deny-warn --warn-list +73
moon test --target native --deny-warn
moon run scripts/pblaze3-verify.mbtx -- run /tmp/pblaze3-evidence-new /tmp/pblaze3-compiler-new /tmp/pblaze3-digital-new
moon build --target native cmd/pblaze3_host --deny-warn
moon run scripts/pblaze3-host-test.mbtx -- /tmp/pblaze3-host-tests-new
```

The EDA gate checks deterministic regeneration, adapter replay, integrated
canonical and production-RTL replay, synthesis, bounded safety and an intentional
negative control. Its success marker does not substitute for a physical build
or DDR test. The [native gate notes](../artifacts/pblaze3-preparation-20261026/native/README.md)
record the installed compiler and existing shell boundary-checker limitations.

## Physical identification and recovery

Record board revision, FPGA marking/JTAG ID, all eight DDR markings, power
input and DDR I/O voltage. Compare with the provisional profile before loading
it: x8 parts, 15 row bits, 10 column bits, 3 bank bits, 1.5 V and DDR3-1600
are assumptions awaiting physical confirmation. Reconfigure MIG if they differ.
Keep a known JTAG recovery path and start with a volatile image.

The [JTAG runbook and runner](PBLAZE3_JTAG.md) provide read-only discovery,
concrete programming plans and explicit volatile configuration. They require
the exact discovered cable/device, matching FPGA identity and a pinned bitstream
SHA256, then check DONE and CRC status. Their offline stubs pass; actual JTAG
discovery and status-image configuration also passed on 2026-10-29.

Use a Linux PCIe host with the upstream XDMA driver and tools. The tested
userspace command contract is pinned in the [host guide](../targets/pblaze3_host/README.mbt.md).
Record the driver revision, kernel, tool hashes, `lspci -vv` negotiated speed
and width, physical card identity and loaded bitstream digest. Select the
actual `/dev/xdmaN` prefix after each reprogramming or reboot.

The final host runtime has also passed native Linux x86_64 checks, all
22 host mocks, five fixture campaigns and seven register-output parser
regressions on the Ubuntu 22.04 build VM. The
[executable receipt](../artifacts/pblaze3-linux-host-preparation-20261026-a3/linux/executable-receipt.json)
records the ready release CLI path and SHA256. Set `PBLAZE3_HOST_EXE` to that
absolute VM path when using it with the scripts below. Its tested runtime is
glibc 2.35; build the CLI on another Linux host if its environment differs.
The [Linux preparation evidence](../artifacts/pblaze3-linux-host-preparation-20261026-a3/README.md)
also records actual official-tool read/write, high-address transfer and
short-read tests against ordinary files. Use the current host script: it fixes
the earlier mock's mismatch with the official `reg_rw` output format.

The three official XDMA userspace tools are already built in the VM at
`/work/builds/pblaze3-host-linux-20261026-a1/xdma-userspace/dma_ip_drivers/XDMA/linux-kernel/tools`.
Their [ready-tool receipt](../artifacts/pblaze3-xdma-userspace-preparation-20261026/ready-tools.json)
pins the upstream revision and executable hashes. Substitute that directory
for `/opt/dma_ip_drivers/XDMA/linux-kernel/tools` in the examples when using
this VM. The kernel driver still needs installation on the actual card host.

## DDR-only image acceptance

For power-base plus JTAG operation without PCIe, use the separate
[JTAG memory diagnostic](PBLAZE3_MEMTEST.md). On 2026-10-29 it verified the
entire configured 2 GiB window with two full write-all/read-all rounds on
cable 261020153153. That result validates DDR under the tested profile;
PCIe/XDMA integration remains a separate check.

Build the native host CLI once. The examples assume `/dev/xdma0` is this card
and upstream tools are in `/opt/dma_ip_drivers/XDMA/linux-kernel/tools`.

```sh
moon build --target native cmd/pblaze3_host --deny-warn
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-probe /dev/xdma0
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-status /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-ddr-status-new
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-ddr-smoke-new smoke 42
moon run scripts/pblaze3-host.mbtx -- ddr-smoke-memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-ddr-full-new full 42
```

These memory tests overwrite their selected DDR regions. Run before loading
weights, with one host process owning the card. Smoke writes ten 4 KiB regions
around the former 256 MiB, 512 MiB, 1 GiB and 2 GiB boundaries. Full mode
writes every byte of 2 GiB before reading any chunk back, detecting address
aliases rather than allowing each write to mask a previous one. Retain the
seed and first mismatching address/expected/actual bytes on failure.

The generated DDR smoke image exposes read-only GPIO channel 2 at BAR offset
`0x8`: bit 0 is MIG calibration complete, bit 1 PCIe link up and bit 2 UI reset
released. These independent status bits cross through three synchronizer stages
into the XDMA clock domain. The smoke memory test requires all three bits before
writing. This register identifies health, not the accelerator ABI or the loaded
image hash; record the actual programmed image separately. `ddr-raw-memtest`
exists for an explicitly selected older vendor image without that register and
does not establish calibration status.

Repeat full tests with another seed, repeated reset and cold starts, then
sustained transfers. A single passing sweep is an initial acceptance step.

## Accelerator image acceptance

Load the accelerator image only after DDR checks succeed. Validate ABI and
memory readiness, then repeat the same smoke and full diagnostics through the
strict accelerator path:

The host requires control ABI 1.1. It verifies instruction-count readback and
the accepted-launch sequence at `0x38` before accepting DONE; an earlier job's
DONE cannot satisfy a new run. A fast job may complete between polls without
the host observing BUSY.

```sh
moon run scripts/pblaze3-host.mbtx -- status /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-status-new
moon run scripts/pblaze3-host.mbtx -- memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-accel-smoke-new smoke 42
moon run scripts/pblaze3-host.mbtx -- memtest /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 artifacts/pblaze3-accel-full-new full 42
```

Run the prepared `scalar-high-memory` and `packed-matrix-upper-bound` fixtures
first. Their [jobs.json](../artifacts/pblaze3-host-preparation-20261026/arrival-fixtures/jobs.json)
supplies each directory and exact manifest SHA256.
The scalar case performs high-address load/add/store; the matrix case checks
sixteen outputs and weight reads ending at the top of the 2 GiB aperture.

```sh
moon run scripts/pblaze3-campaign.mbtx -- plan FIXTURE_DIRECTORY MANIFEST_SHA256 artifacts/pblaze3-plan-new
moon run scripts/pblaze3-campaign.mbtx -- run /opt/dma_ip_drivers/XDMA/linux-kernel/tools /dev/xdma0 FIXTURE_DIRECTORY MANIFEST_SHA256 artifacts/pblaze3-job-new
```

Then use the existing complete-layer fixture at
`artifacts/prx100-layer-20261018/fixture`, whose manifest SHA256 is
`24ef729d9eada00f624dc75c36a874c2e4dbe35d2396d49e3c82d34129e81a98`.
Its 2025 descriptors fit the 2048-instruction program memory. The campaign
checks all asset/reference hashes, uploads and reads back input/program data,
executes the instruction count, compares every declared tensor using the
original `1e-4 + 1e-4 * abs(reference)` tolerance and rechecks input assets.
It reports nonfinite values, mismatches, hardware faults and timeouts.
The default compute completion deadline is 30 seconds. For an initial full-layer
run, set `PBLAZE3_RUN_TIMEOUT_MS=120000`; the checked range is 1000..600000 ms.
This changes only the bounded wait, not the expected result or error handling.

Program/scratch loading currently uses word MMIO and may take substantial time.
Keep upload, program loading, compute cycles, result transfer and CPU comparison
times separate. This is an executable single-layer reference; it does not run
the complete Qwen3-0.6B model. Compare speed with PRX100 only after both images
pass the same workloads and actual routed clocks are known.

## Failure and evidence handling

On a timeout, unexpected AXI error, calibration loss or mismatching data, stop
the campaign and retain its logs. Software timeouts do not prove a transaction
was canceled. Recover with a coordinated transport reset/reload that resets
the core, bridge, converters, XDMA and MIG AXI state together. A local compute
reset must not discard half-completed AXI writes or pending responses.

For each accepted run retain the image hash, board/DRAM identity, clock and
link settings, tool/driver identities, source/fixture pins, raw results and
comparison logs. Evidence archives contain unique inputs/logs/traces, with
regenerable compilation and vendor caches kept outside them. Earlier failures
and sealed PRX100 evidence remain immutable.
