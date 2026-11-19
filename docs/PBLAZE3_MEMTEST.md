# PBlaze3 memory test through JTAG

**Measured on 2026-10-29: the entire 2 GiB window passed two complete
write-all/read-all rounds on the attached PBlaze3.** Every byte in
0x00000000–0x7fffffff was checked twice, with address-dependent data and its
complement. The host independently audited 189 progress snapshots and
567 successful JTAG status transactions. The final two snapshots both read
`status0=0xb8000000` and `status1=0x80000000`.
See the [hardware evidence](../artifacts/pblaze3-memtest-builds-20261029-a1/README.md).

This diagnostic works with the powered baseboard and Digilent JTAG cable; PCIe
is not required. The tested profile is eight 256 MiB x8 parts, 2 GiB total.
The result establishes at least 2 GiB of working address space under this
profile; chip markings and any capacity above 2 GiB remain unverified.
No additional DDR address pin is driven.

There are two independent images:

| Image | DDR owner | Measurement |
|---|---|---|
| `jtag-ddr-2g` | JTAG AXI through vendor width/clock conversion | Two write-all/read-all passes over 2,150 sampled words, including each MiB and address-bit/end-point probes |
| `jtag-memtest-2g` | Canonical LunaWire controller and existing PBlaze3 AXI bridge | Two complete write-all/read-all rounds over all 134,217,728 16-byte lines |

The first image is described in [PBLAZE3_JTAG_DDR.md](PBLAZE3_JTAG_DDR.md).
It helps identify transport problems and common capacity aliasing. The second
image moves and checks data inside the FPGA, avoiding a 2 GiB transfer over JTAG.
Both overwrite DDR, configure the FPGA only temporarily, and leave SPI flash
untouched. A full pass establishes at least the tested 2 GiB window. It does
not exclude additional soldered memory outside the configured aperture.

## Autonomous controller

`targets/pblaze3_memtest` owns the canonical finite-state controller. Each round
writes the entire aperture before reading it. The four 32-bit words in each
line contain address-dependent patterns with different lane salts; the second
round complements all words. Keeping all writes ahead of all reads exposes
aliased locations instead of hiding aliasing with immediate write/read pairs.

The controller and unchanged `targets/pblaze3_axi` bridge run at 50 MHz. Their
128-bit AXI port crosses through the vendor interconnect to MIG's 200 MHz UI.
All accesses are aligned, full-strobe, single-beat transfers. The wrapper supplies
constant transaction IDs of zero; only one transaction can be outstanding.
The physical profile retains the accepted MIG XML byte-for-byte.

Calibration is synchronized into 50 MHz. Loss of calibration or bridge health,
bad response shape, a nonzero response fault, or a data mismatch ends the test
with a sticky failure. The controller stops issuing requests and continues
accepting responses so the bridge can drain. A coordinated reset starts a fresh
run. It is never used to clear a failure while preserving a pass claim.

JTAG owns a separate interconnect with access only to read-only GPIO:

| Address | Contents |
|---|---|
| `0x80000000` | `status0`: phase bits31:29, round bit28, completed line count bits27:0 |
| `0x80000008` | `status1`: current line address or first failing word address |

Phases are 0 waiting, 1 write issue, 2 write response, 3 read issue, 4 read
responses, 5 pass, 6 failure. Full completion requires exactly
`status0=0xb8000000`, `status1=0x80000000`. The host reader requires two
consecutive matching final snapshots, successful AXI completions with fresh data and
nondecreasing progress. A timeout, missing records, reset during an observed run,
or incomplete terminal count cannot produce a pass receipt.

## Software evidence

The reduced fixtures cover both base zero and a window ending at `0x80000000`.
They exercise independent AW/W stalls, two complete rounds, half-capacity
aliasing, corruption in every lane of the final line, SLVERR/DECERR, missing
RLAST, calibration loss, outstanding-response drainage and reset recovery.

- [Low-window LunaWave/Verilator replay](../artifacts/pblaze3-memtest-replay-low-20261029-a1/receipt.json):
  every observed output matches pinned Verilator 5.050.
- [Highest-window replay](../artifacts/pblaze3-memtest-replay-high-20261029-a1/receipt.json):
  same checks at the top of the 2 GiB aperture.
- [Pinned Yosys and bounded formal](../artifacts/pblaze3-memtest-formal-20261029-a3/receipt.json):
  physical digital wrapper synthesis; 40-edge controller safety at the highest
  line; the deliberately false 256 MiB bound produces a retained counterexample.
- [Host evidence checks](../artifacts/pblaze3-memtest-status-tests-20261029-a3/receipt.json):
  20 status cases in each of MoonBit and Tcl, 11 reader cases, and 12 evidence
  acceptance and rejection cases.
- The target-only RTL adapter uses explicit input net kinds and native equality,
  following the existing PBlaze3 emitter adapter. Canonical RTL is retained next
  to the adapted files. The adapted low and highest-window fixtures also match
  their canonical LunaWave traces:
  [low](../artifacts/pblaze3-memtest-normalized-low-20261029-a2/receipt.json),
  [high](../artifacts/pblaze3-memtest-normalized-high-20261029-a1/receipt.json).
  [Pinned Yosys](../artifacts/pblaze3-memtest-normalized-synthesis-20261029-a3/status.txt)
  accepts the complete adapted digital wrapper. This is a physical target
  translation, not a change to the canonical four-state simulator.

These software fixtures do not simulate every line of a 2 GiB device and do not
constitute a physical memory result.

On the attached core, Vivado 2026.1 preserves the previous DONE flag after
`reset_hw_axi`, both before and after a refresh. The host performs that reset
once at initialization, checks both BUSY flags before each command, validates
the complete command properties, and runs one transaction synchronously.
Every new read object is initialized with an invalid sentinel before execution.
It must return fresh data with DONE set, BUSY clear and an OKAY response.
The sparse reader uses the expected word's complement; the status reader uses
`ffffffff`, which is invalid for both status registers. Sticky DONE alone
cannot certify completion. Software cases reject an unchanged poisoned read,
an ignored poison assignment, a command error and bad completion status.

## Reproduction

Run exports from the repository root, using fresh absolute output directories:

~~~sh
moon run --target native --release cmd/pblaze3_memtest -- export digital /tmp/pblaze3-memtest-digital-NEW
moon run scripts/pblaze3-memtest-build.mbtx /tmp/verified-jtag-ddr-shell /tmp/pblaze3-memtest-digital-NEW /tmp/pblaze3-memtest-inputs-NEW
moon run scripts/pblaze3-remote.mbtx implement /tmp/pblaze3-memtest-inputs-NEW memtest-build-new /tmp/pblaze3-memtest-evidence-NEW --pin /work/builds/vivado-2026.1-pin.json
~~~

Review the generated address map, reset/clock connectivity, CDC, timing and DRC.
Use `scripts/pblaze3-jtag.mbtx` to obtain a fresh identity probe and program the
exact accepted bitstream hash into cable `261020153153`, device `xc7k325t_0`,
IDCODE `43651093`. The original PRX100 is outside this diagnostic.

On the build guest, from a directory containing the retained `scripts` sources:

~~~sh
moon run scripts/pblaze3-memtest-status.mbtx run /tools/amd-2026.1/2026.1/Vivado/bin/vivado /work/builds/pblaze3-memory-observation-NEW
~~~

The reader permits up to 30 minutes for completion. Retain the exact
bitstream/programming receipt alongside its command, source identity,
transactions, progress samples and independently audited `complete.json`.
Restore temporary USB permissions and stop only the hardware server started
for this test.

The [2026-10-29 sparse hardware run](../artifacts/pblaze3-jtag-ddr-20261029-a1/README.md)
passed both rounds and all 8,606 transactions, including address 0x7ffffffc.
The subsequent full-window run also passed. The observation period was
194,876 ms, after the autonomous test had already started during programming;
this is not the complete test duration or a bandwidth benchmark.
The accepted full-window bitstream SHA256 is
`defba20db52d1a994d57d5bd614d4fe38f5684441aea9245c5a2378dd69216b3`.
Programming, physical implementation review and exact test receipts are bound
in the linked evidence archive. Temporary USB ownership was restored and the
owned hardware server stopped. The image remains volatile; SPI was not written.
