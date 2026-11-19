# PBlaze3 arrival: JTAG discovery and volatile configuration

The runner is [`scripts/pblaze3-jtag.mbtx`](../scripts/pblaze3-jtag.mbtx).
It prepares or executes Vivado Hardware Manager commands for the expected
`xc7k325t`. Its Tcl generation, selection checks and failure paths have been
tested with offline stubs. Physical read-only discovery and volatile programming
of the accepted status-ILA image passed on 2026-10-29. Both DONE indications
were asserted and the configuration CRC-error bit was clear; the
[physical status record](../artifacts/pblaze3-board-verification-20261029-a1/README.md)
retains the programming receipt and real ILA captures. Full DDR memory tests
and PCIe qualification remain open.

The arrival scan identified one device, `xc7k325t_0` / `xc7k325t`, with
IDCODE `43651093`, on
`localhost:3121/xilinx_tcf/Digilent/261020153153`. The USB cable is a Digilent
FT232H (`0403:6014`), serial `261020153153`. The successful inventory and
completion receipt are retained in
[`pblaze3-arrival-detection-20261029-a1`](../artifacts/pblaze3-arrival-detection-20261029-a1/probes/pblaze3-jtag-probe-arrival-20261029-a3/complete.json).
Temporary USB ownership was restored to `root:root` with mode `0664` on both
the Linux host and Vivado guest. This scan did not program the FPGA or access
application registers; DDR capacity and calibration remain unverified. Run
fresh discovery before subsequent configuration, since cable and server state
may change.

Run from the LunaChip checkout root on the machine with Vivado and access to the
chosen `hw_server`. An already running server is required; the runner does not
start a server or request elevated privileges. The examples use the installed
PBlaze3 tool at `/tools/amd-2026.1/2026.1/Vivado/bin/vivado`; substitute the
actual installed path and server URL, and choose evidence paths on that host.
Every output directory must be new.
Keep the MoonBit cache outside evidence directories.

## 1. Read-only discovery

With the board powered and the identified JTAG connection attached, run:

```sh
moon run --target-dir _build/pblaze3-jtag \
  scripts/pblaze3-jtag.mbtx probe \
  /tools/amd-2026.1/2026.1/Vivado/bin/vivado localhost:3121 \
  /work/builds/pblaze3-jtag-probe-arrival-a1
```

`probe` opens each available target, reads device names, `PART` and
`IDCODE_HEX`, then closes the connection. It does not configure the FPGA,
change JTAG frequency or access application registers. Inspect
`inventory.tsv` and the Vivado logs. A successful discovery also has
`complete.json`; a partial inventory from a failed probe is unusable.

The inventory columns are `target`, `device`, `part`, `idcode`. Copy the
**complete target and device strings** for the physical PBlaze3 connection.
Multiple cables may appear. The selected cable must contain exactly one
device, and its part must be `xc7k325t`; ambiguous chains are rejected.
The runner compares exact strings, without interpreting wildcard patterns.
JTAG's die identity does not confirm the FFG900 package, speed grade, board
revision, DDR markings or capacity. Check those against the arrival checklist
in [PBLAZE3_BRINGUP.md](PBLAZE3_BRINGUP.md).

To generate the same discovery command and Tcl without invoking Vivado or
accessing hardware, replace `probe` with `plan-probe` and choose another new
directory. A plan has no completion receipt and cannot serve as discovery.

## 2. Select a build and prepare the programming command

Use the `pblaze3.bit` from an accepted Vivado build: require exit zero,
`BUILD_COMPLETE`, passing physical gates and a recorded CDC/reset review.
The JTAG runner authenticates the selected bytes and device; it does not
establish those build results. Select the expected SHA256 from the accepted
build's retained evidence; the runner requires all
64 lowercase hex digits and checks the source bytes before starting Vivado.
The initial DDR smoke image and accelerator image have different purposes;
follow the staged order in [PBLAZE3_BRINGUP.md](PBLAZE3_BRINGUP.md).

Generate a concrete plan with these explicit values:

```sh
moon run --target-dir _build/pblaze3-jtag \
  scripts/pblaze3-jtag.mbtx plan-program \
  /work/builds/pblaze3-jtag-probe-arrival-a1 \
  'EXACT_TARGET_FROM_INVENTORY' 'EXACT_DEVICE_FROM_INVENTORY' \
  /absolute/path/to/completed-build/pblaze3.bit \
  EXPECTED_64_LOWERCASE_HEX_SHA256 \
  /work/builds/pblaze3-jtag-program-plan-arrival-a1
```

The upper-case values are placeholders; the runner rejects them. This command
checks discovery integrity, device selection, the Vivado launcher hash and
bitstream hash. It saves the verified bytes as `selected.bit` and writes
`identity.json`, `command.json` and `hardware.tcl`. It invokes neither Vivado
nor the server. `command.json` records executable, individual arguments and
working directory; Tcl receives data through `argv`, without string evaluation.

## 3. Configure the FPGA's volatile memory

Repeat the same explicit arguments with `program` and a **new** evidence
directory:

```sh
moon run --target-dir _build/pblaze3-jtag \
  scripts/pblaze3-jtag.mbtx program \
  /work/builds/pblaze3-jtag-probe-arrival-a1 \
  'EXACT_TARGET_FROM_INVENTORY' 'EXACT_DEVICE_FROM_INVENTORY' \
  /absolute/path/to/completed-build/pblaze3.bit \
  EXPECTED_64_LOWERCASE_HEX_SHA256 \
  /work/builds/pblaze3-jtag-program-arrival-a1
```

This explicitly executes volatile FPGA configuration. It replaces the current
FPGA design and can interrupt the existing PCIe function. The runner rechecks
the exact discovered target/device, singleton chain, `xc7k325t` part, recorded
IDCODE and Vivado version, sets JTAG to 1 MHz, and programs the verified
`selected.bit` snapshot. It then refreshes the device and requires internal
DONE, the DONE pin and a clear configuration CRC-error bit. A successful
configuration produces `complete.json`; the full device property report is
in `stdout.log`. There is no SPI flash programming operation in this runner.

A successful JTAG receipt establishes configuration status only. Continue
with PCIe enumeration, DDR readiness, memory integrity checks and the prepared
LunaChip smoke fixtures. The operating system may need its normal PCIe
rediscovery/reboot procedure after changing the FPGA image. Those actions
are separate from this JTAG command.

## Evidence and failure handling

Each operation retains the generated Tcl, structured command, driver identity,
resolved Vivado launcher path/hash, selected board identity, logs and exit
status. Successful discovery adds the inventory, full Vivado version string
and hashes binding them to its identity file. Programming retains the selected
bitstream bytes, original source path/hash and discovery reference. The
launcher hash and version identify the invoked installation; they do not hash
the entire Vivado installation or independently identify a remote server.

The runner has a five-minute Vivado timeout and does not retry programming.
An exit code of zero also requires exactly one complete
`PBLAZE3_JTAG_COMPLETE=probe` or `PBLAZE3_JTAG_COMPLETE=program` line for the
requested operation. CRLF is accepted; embedded text, suffixes and duplicate
markers do not establish completion. Partial child output remains in the logs
on timeout, but output still buffered inside the child cannot be recovered.
On failure retain the output directory and inspect its logs; an interrupted
programming attempt may already have changed FPGA configuration. Use a fresh
discovery after changing cables, device chains or Vivado. Never reuse a failed
or completed evidence directory for another operation.

## Repeatable offline check

From the repository root, with `/usr/bin/tclsh` available:

```sh
moon run --target-dir _build/pblaze3-jtag \
  --deny-warn --warn-list +73 scripts/pblaze3-jtag.mbtx self-test \
  /work/builds/pblaze3-jtag-offline-a1
```

This invokes only Tcl stubs. It checks successful discovery and programming,
four invalid inventory selections, missing/duplicate targets, changed device
chains, wrong part/IDCODE, literal wildcard rejection, version mismatch,
missing input, DONE/CRC failures, concrete plan generation, SHA256 mismatch,
missing source and existing-output rejection. Stub calls confirm that identity
failures never reach programming. The test's dummy bitstream and identities
are offline fixtures and must not be used to configure a board.

The separate process harness exercises the actual MoonBit runner with a native
fake Vivado launcher, including a real five-minute timeout, unsuccessful exits,
missing evidence, malformed completion markers and discovery/launcher tampering:

```sh
moon build scripts/pblaze3-jtag-fixture.mbtx --target native --target-dir _build --deny-warn
moon run scripts/pblaze3-jtag-process-test.mbtx -- \
  /tmp/pblaze3-jtag-process-evidence-new \
  /tmp/pblaze3-jtag-process-work-new full
```

Both directories must be fresh and absolute. The fake launcher never invokes
Vivado or accesses JTAG. Its executable stays in the working cache outside the
evidence directory; its source and identities are retained with the results.
