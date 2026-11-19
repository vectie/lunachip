# PBlaze3 JTAG-only DDR aperture diagnostic

This separate `jtag-ddr-2g` image accesses DDR through the FPGA's JTAG port.
It needs the powered baseboard and JTAG cable, with no PCIe connection. Existing
production and ILA profiles are unchanged. A successful build is not a capacity
measurement; recorded board transactions establish the measured result.

The first image has one AXI4 JTAG master, 32-bit addresses/data and four ID bits.
A vendor AXI Interconnect connects it to the existing 128-bit MIG interface and
a read-only GPIO. The interconnect performs width conversion and the 50 MHz to
200 MHz clock crossing. The raw board oscillator passes through one IBUF and
one BUFG; it clocks JTAG, GPIO and the debug hub. A `No_buffer` clock wizard
generates the MIG reference clock. There are no PCIe reference clock, PERST,
XDMA, link or transceiver ports, and no ILA in this image.

| Interface | Byte address | Meaning |
|---|---:|---|
| DDR | `0x00000000`–`0x7fffffff` | Configured 2 GiB aperture |
| GPIO data | `0x80000000` | Read-only four-bit health value |
| GPIO bit 0 | — | MIG calibration complete |
| GPIO bit 1 | — | MIG UI reset released |
| GPIO bit 2 | — | MIG MMCM locked |
| GPIO bit 3 | — | Source clock wizard locked |

Each status flag passes through a three-stage XPM synchronizer into raw50.
The healthy value is exactly `0x0000000f`; upper bits must be zero. These are
independent sampled levels, not a coherent event log. Short transitions can be
missed. Select the single `hw_axi` object belonging to the identity-checked
target device rather than assuming an instance name assigned by Hardware Manager.

Source-clock lock drives MIG's active-low physical reset. MIG UI reset, source
lock and MIG lock also feed reset controllers in the raw50 and UI domains;
these reset the JTAG transaction owner, both interconnect sides and MIG AXI
together, with synchronous release in each clock domain. Calibration does not
gate any clock or reset. GPIO remains readable during calibration while UI reset
is released. When UI reset remains asserted, the transport and GPIO are
unavailable; this is not evidence of zero memory. The accepted
[`ddr-status-ila` image](PBLAZE3_ILA.md) is the independent startup fallback.
After any transport reset or lost transaction, restart the test from initialization.

The generator pins the exact previously accepted 2 GiB MIG XML, oscillator
wrapper and vendor provenance under
`artifacts/pblaze3-ila-ready-inputs-20261028-a1/ddr-status-ila`.
It retains the XML byte-for-byte, including
`C0_S_AXI_SUPPORTS_NARROW_BURST=0`: DDR64, row15/column10/bank3,
AXI address31/data128/ID4, ECC disabled. The first attempted recipe enabled narrow
bursts, but actual Vivado propagation restored zero because the JTAG master has
fixed `SUPPORTS_NARROW_BURST=0`. The test therefore requires explicit `CACHE=3`,
`INCR` and 32-bit command size. With the modifiable cache bit set, the vendor
upsizer packs these transfers to the full 128-bit MI width. Nonmodifiable narrow
commands are outside this diagnostic contract. Generated converter parameters
and RTL must be reviewed before programming. See AMD's
[AXI upsizer description](https://docs.amd.com/r/en-US/pg059-axi-interconnect/AXI-Upsizer).
The component marking remains a provisional profile; no A15 output or 4 GiB
profile is added.

Generate a fresh bundle from the repository root:

```sh
moon run --deny-warn --warn-list +73 scripts/pblaze3-jtag-ddr-build.mbtx selftest
moon run --deny-warn --warn-list +73 scripts/pblaze3-jtag-ddr-build.mbtx export /tmp/lunachip-pblaze3-jtag-ddr-inputs-NEW
```

The exporter does not run Vivado or access hardware. Its output works with the
existing build/transfer runners. Use unique lowercase run IDs and fresh output
paths; select the separate 2026.1 pin explicitly:

```sh
moon run scripts/pblaze3-remote.mbtx prepare /tmp/lunachip-pblaze3-jtag-ddr-inputs-NEW arrival-jtag-ddr-prepare-a1 /tmp/lunachip-pblaze3-jtag-ddr-prepare-NEW --pin /work/builds/vivado-2026.1-pin.json
moon run scripts/pblaze3-remote.mbtx implement /tmp/lunachip-pblaze3-jtag-ddr-inputs-NEW arrival-jtag-ddr-build-a1 /tmp/lunachip-pblaze3-jtag-ddr-build-NEW --pin /work/builds/vivado-2026.1-pin.json
```

The recipe uses a fresh isolated MIG working copy and rejects any further XML
mutation. It asserts interface widths, exact address regions, bus peers, reset
connections and clock sources. Child synthesis/route logs must complete without
errors or critical warnings. Setup, hold, timing coverage, pulse width, bus skew
and DRC must pass before bitstream generation; final message counts and nonempty
bit/LTX outputs are checked again. CDC reports are retained for independent
review; producing a report alone does not establish CDC safety. Source and
effective XML hashes are retained separately. No cache reuse is enabled for this
new shell.

Sparse unique-pattern writes followed by reads across address-bit and endpoint
probes can detect common address aliasing and demonstrate distinct sampled
locations across the configured aperture. They do not test every byte, prove
retention, or establish the exact total amount of soldered memory. Full-aperture
write/read coverage requires the separate on-FPGA BIST effort. A 4 GiB claim
requires a reviewed wider address path and physical A15 evidence first.

The full-aperture controller, independent simulation evidence and JTAG status
reader are documented in [PBLAZE3_MEMTEST.md](PBLAZE3_MEMTEST.md).

The actual 2026.1 core retains DONE across `reset_hw_axi`. The host initializes
the core once, requires idle BUSY flags before each synchronous command, and
poisons every new read object's DATA with the expected word's complement.
Completion requires the exact readback plus DONE=1, BUSY=0 and OKAY; a previous
DONE flag or an unchanged read object is insufficient. The
[host regression](../artifacts/pblaze3-jtag-ddr-host-tests-20261029-a4/receipt.json)
models sticky DONE and rejects stale reads, ignored initialization, aliasing,
lost writes, failed health, response errors and incomplete evidence.
