# PRX100 target

MoonBit generates the UART/control and independent4KiB memory shell. The
portable accelerator is emitted separately, with no core changes. See
[board contract](../../docs/PRX100_BOARD_CONTRACT.md) and
[Qwen feasibility](../../docs/PRX100_QWEN_FEASIBILITY.md).

The [DDR3/bulk follow-on plan](../../docs/PRX100_DDR_DATA_PATH.md) records
verified board pins, installed-IP/license discovery, clock constraints and
the staged Ethernet/DDR/sequencer architecture. `scripts/prx100-ddr-probe.mbtx`
performs headless device/IP discovery without hardware access;
`scripts/prx100-data-path-budget.mbtx` calculates explicit traffic/storage
bounds. These do not build or qualify a DDR/Ethernet image.

The [physical smoke test](../../docs/evidence/prx100-uart-bram-20261016.md)
passes29 UART/BRAM transactions, including reset persistence and bounds checks.
The repeatable host diagnostic is `scripts/prx100-board-smoke.mbtx`.
The [first signed matrix workloads](../../docs/evidence/prx100-signed-matrix-20261016.md)
also pass on the1x1/K2 smoke image; `scripts/prx100-signed-matrix.mbtx` uploads
the descriptor ring and verifies−83,255 and0 through the complete accelerator.
The [physical Array8/K16 workload](../../docs/evidence/prx100-array8-matrix-20261016.md)
passes all64 results of signed8x16 by16x8 multiplication. The corresponding
host scripts are `scripts/prx100-array8-program.mbtx` and
`scripts/prx100-array8-matrix.mbtx`; the portable core is unchanged.
The [broader matrix campaign](../../docs/evidence/prx100-broad-matrix-20261016.md)
passes40 directed/seeded/repeated cases and a synthetic K1024 tiled projection.
`scripts/prx100-matrix-suite.mbtx` provides `run` and `linear` modes with
persistent UART, packed raw transcripts and per-command/per-case timing.
The [real Qwen projection campaign](../../docs/evidence/prx100-qwen-projection-20261016.md)
uses `scripts/prx100-qwen-source.mbtx`, `scripts/prx100-qwen-quantize.mbtx` and
`scripts/prx100-qwen-projection.mbtx` for pinned model slices, explicit W8A8
quantization and UART/CPU comparison. All1536 partials and24 final outputs
pass with unchanged hardware; this is an eight-channel projection block.

```mbt check
///|
test {
  assert_eq(@prx100.Profile::Array8.rows(), 8)
  assert_eq(@prx100.Profile::Smoke.reduction(), 2)
  let request = @prx100.request(0, 42, 0U, 0U)
  assert_eq(request.length(), 16)
  assert_eq(@prx100.crc8(request[2:14]), request[14])
}
```

Export without vendor tools:

```text
moon run --target native --release cmd/prx100 -- export smoke /absolute/new-inputs
moon run --target native --release cmd/prx100 -- export array8 /absolute/new-array8-inputs
```

On a supported x86-64 Linux Vivado2025.2 host, pin the chosen installation
and run this POSIX build recipe:

```text
moon run scripts/prx100-build.mbtx -- pin /absolute/Vivado/2025.2/bin/vivado /absolute/new-vivado-pin.json
moon run scripts/prx100-build.mbtx -- build /absolute/new-vivado-pin.json smoke /absolute/new-build-root
```

The pin binds launcher bytes and exact version output, not every installation
file. Freeze the installer/full installation separately for cross-host
qualification. Smoke and Array8 both pass the actual pinned2025.2 recipe at
50MHz; reports, bitstreams and qualification limits are retained in the
[build ledger](../../docs/evidence/prx100-vivado-build-20261015.md).
The runner refuses changed identities, existing outputs, input hash drift,
failed tools and absent reports/bitstream. It never programs hardware.
`selftest NEW_ROOT` checks inventory acceptance/refusal;
`recipe-selftest EXPORTED_INPUTS NEW_ROOT` checks generated Tcl using explicit
test doubles. These checks do not qualify Vivado or produce a real bitstream.

The CLI also encodes request files and validates reply files. Numeric request
arguments are unsigned decimal:

```text
moon run --target native cmd/prx100 -- request 0 42 0 0 /absolute/request.bin
moon run --target native cmd/prx100 -- reply /absolute/reply.bin
```

These files can be sent/read by a serial terminal configured per the contract;
the CLI does not yet open serial devices itself. Initialize all descriptor and
operand bytes before publication. Upload LoadA/LoadB/MatMul/StoreC as one
four-entry batch; drain each completion before reading results. User software
owns recovery after an uncertain/lost response.

## Connecting the board

Use the hardware reference guide's power section (PDF pages8 and11), FPGA
JTAG section (page33), and USB-UART section (page35). Confirm the physical
PCB revision before programming: the guide disagrees with itself about some
JTAG connector numbers. Follow the actual PCB labels and schematic nets.

1. Switch power off before moving jumpers. For the supplied12V adapter, select
   `EXT_5V` to `PWR_5V` on `PWR_SEL` (J23 in the guide), then connect that
   adapter. The alternative USB power path is through `CPU_TAG`, with
   `USB_5V` to `PWR_5V`. Power selection and JTAG path selection are separate.
2. Keep the relevant IO bank selectors at3.3V for this target's LVCMOS33
   signals. Verify their positions against the physical board.
3. Connect the USB-B socket labelled `USB TO UART` to the computer that will
   exchange packets. Its CP2102 bridge is separate from FPGA JTAG and CPU
   debug. On Linux, inspect `lsusb` and `/dev/serial/by-id/` for the new device;
   it commonly appears as `/dev/ttyUSB0`, but use the discovered path.
4. Check the onboard programmer before buying an external one. The DDRV1.0
   schematic's USB_2_UART sheet (PDF page20) has an FT2232HL: channelA's
   `F_TCK_SK`, `F_TDI_MOSI`, `F_TDO_MISO`, and `F_TMS_CS` connect through the
   JTAG selector on PDF page6 to FPGA JTAG. ChannelB serves CPU debug. Connect
   a second USB data cable to `CPU_TAG` and check for the FTDI USB device.
   With power off, verify the PCB's selector labels: the guide's photo says
   `J6:2-3=INT` for the internal path and `J6:1-2=EXT` for an external cable.
   On2026-10-15 the connected `CPU_TAG` path was verified: FTDI0403:6010,
   Digilent serial `ME10E06D1010`, FPGA `xc7a100t`, IDCODE `0x13631093`.
   This identifies the JTAG device family; physical PCB revision, package and
   IO-bank settings still need checking before programming.
   If using an external Xilinx/Digilent-compatible programmer instead, match
   pin1 and the keyed header orientation and select the external path.
5. Switch the board on. Detect the FPGA through Vivado Hardware Manager or
   its Tcl hardware commands and check that the device is XC7A100T. First
   program volatile FPGA configuration using the verified `.bit` file; defer
   flash programming until the UART smoke test succeeds.
6. Use115200baud,8 data bits, no parity,1 stop bit, and no flow control for
   UART. This shell exchanges binary request/reply frames and emits no boot
   banner. A blank serial terminal is expected; typing text is not a valid
   protocol test. The `MENU` user button resets this shell.

A remote build machine cannot see USB devices attached to another computer
through ordinary SSH. Connect JTAG and UART to an accessible machine. If the
board is attached to the VM host, pass only its identified programmer/UART
devices into the guest after checking their USB identities. A board beside
the Mac needs a separate supported programming path; UART access alone
cannot configure the FPGA.

Digital verification exports use separate identities:

```text
moon run --target native --release cmd/prx100 -- export-byte-replay /absolute/new-byte-replay
moon run --target native --release cmd/prx100 -- export-uart-replay /absolute/new-uart-replay
```

The former composes the real smoke accelerator with the exact control graph
at the UART byte handshake; the latter exercises actual RX/synchronization/TX
at divisor8. Neither substitutes for routed physical target execution at
divisor434. Run the existing digest-pinned Verilator runner and the corresponding
`audit-byte-replay` / `audit-uart-replay` CLI command, passing expected TSV,
actual TSV and the cycle count from `fixture.txt`. The generated board bundle's
`job.json` also works with the unchanged pinned generic Yosys runner; it omits
the explicitly vendor-specific startup wrapper.
