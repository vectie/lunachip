# PRX100 physical smoke programming, 2026-10-15

Follow-up: the [2026-10-16 physical UART/BRAM test](prx100-uart-bram-20261016.md)
passes all29 transactions after the second USB cable was connected. The
programming checkpoint below records the earlier state.

The user authorized programming the smoke bitstream through CPU_TAG and
running the UART + BRAM test. Volatile FPGA programming completed successfully:
Vivado reports configuration DONE asserted internally and on the pin, with
CRC_ERROR clear. Flash was not programmed. The UART test remains pending
because the separate CP2102 USB-UART device is absent from both host and guest
USB inventories. CPU_TAG remains connected and usable.

## Exact configuration and observed result

- Bitstream: the previously qualified
  `/work/builds/prx100-smoke-vivado-20261015-a5/output/prx100.bit`.
- SHA256: `203908ac91ad52c1b4cf77cc31667c5f392acb9aef8c5f89acca8858d275386a`.
  The runner verifies it before and after programming, together with the
  existing Vivado launcher hash and exact version pin.
- Vivado2025.2, CPU_TAG Digilent `ME10E06D1010A`, JTAG1MHz, one device
  `xc7a100t_0`, IDCODE `0x13631093`.
- Actual `program_hw_devices` succeeds. Refresh reports
  `REGISTER.CONFIG_STATUS.BIT13_DONE_INTERNAL_SIGNAL_STATUS=1`,
  `BIT14_DONE_PIN=1`, and `BIT00_CRC_ERROR=0`.
- The batch session exits0 at2026-10-15 13:00:56UTC /21:00:56 China time.
  `PROGRAM_COMPLETE` records the successful physical configuration.

This is physical programming evidence for the smoke image, not a physical
UART, BRAM data-integrity or accelerator workload result. The previous
[implementation ledger](prx100-vivado-build-20261015.md) retains the bitstream,
source snapshot, routed50MHz timing and digital tests. The portable core and
the bitstream have not been changed in this campaign.

## Prepared UART test and missing connection

[`scripts/prx100-board-smoke.mbtx`](../../scripts/prx100-board-smoke.mbtx)
contains a repeatable29-transaction test at115200baud,8N1, no flow control:
Identify; eight patterned word writes across addresses0..4092; eight reads;
logical reset; eight persistence reads; and three bounds/alignment refusals.
Every response is checked by the existing MoonBit CRC/envelope decoder, then
compared for opcode, sequence, status and all five result words. Raw request
and reply files, serial traffic and per-transaction receipts will be retained.
The script stops on failure and refuses existing UART outputs to prevent
blind replay of mutating commands.

Connect the board's **USB TO UART** socket to the Linux server using a second
USB data cable, leaving CPU_TAG connected. The CP2102 bridge should appear as
USB `10c4:ea60`; its FTDI CPU_TAG interfaces are not the UART wired to L17/L18.
After identifying that device, pass only it into the existing guest, then run:

```text
MOON_HOME=/tools/moon-baseline PATH=/tools/moon-baseline/bin:$PATH moon run /work/prx100-board-smoke.mbtx -- uart /work/builds/prx100-board-smoke-20261015-a1 /dev/serial/by-id/usb-Silicon_Labs_CP2102_DISCOVERED_ID
```

Use the actual discovered by-id path, not the placeholder above. The isolated
guest now has socat1.7.4.1 for serial IO; no host package was installed.

## Checks and retained evidence

The standalone driver compiles and its help path passes; formatting of that
driver, warning-strict target checking and all five target tests pass. A
read-only full-project formatting/check attempt sees unrelated concurrent
Phase6 work in `validation/formal/fetched_retirement_view.mbt` and
`designs/flux_tile/ring_concurrent.mbt`; those files were not changed here.
No claim is made that the current shared working tree passes the global gate.

Programming Tcl, exact as-run driver, identities, Vivado stdout/stderr,
configuration properties and USB inventory are retained in
`artifacts/prx100-board-program-20261015`, with SHA256 inventory and seal.
The original bitstream remains in the previous sealed build archive; its
hash binds this configuration. Caches stay outside the archive. Originals and
previous sealed archives are preserved, and no task files were removed.
