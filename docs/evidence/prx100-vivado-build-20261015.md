# PRX100 UART + BRAM implementation, 2026-10-15

Both the smoke1x1/K2 and Array8/K16 profiles pass actual Vivado2025.2
synthesis, placement/routing, timing checks and bitstream generation for
`xc7a100tfgg676-2` at50MHz. The portable accelerator, canonical IR and general
SystemVerilog backend remain unchanged. This establishes implementation fit
and routed timing for these inputs, with no FPGA workload execution claim.
Phase6 and the physical Phase7 acceptance gate remain open.

## Memory failure and target-only correction

The previous [installation ledger](prx100-vivado-install-20261015.md) retains
the four unsuccessful vendor attempts. Fifteen bounded isolation probes now
identify Vivado's expansion of the conservative equality helper as the cause.
The original32-bit equality alone aborts at the8GiB address-space limit,
exit134, peak RSS7,847,252KiB. The same comparison written `(a == b)` passes
at2,060,724KiB. Rewriting shell equality helpers alone passes at2,093,692KiB
and maps its4KiB aperture to one RAMB36. Replacing memory enables, known-bit
tests, arithmetic or ordering comparisons did not solve the original shell.

`targets/prx100/equality.mbt` derives required helper widths from canonical
Equal nodes, checks backend/header/signature/multiplicity, and replaces only
their bodies with standard four-state logical equality. The target records
`explicit-input-wire-native-equality-v2`, retaining the prior explicit input
net annotation. No synthesis-only semantic branch is introduced. Restoring
the original helpers and removing that annotation reproduces ordinary RTL
byte-for-byte. Known mismatch takes precedence over unknown bits in both
forms; an otherwise ambiguous comparison remains unknown.

The protected portable-source inventory still matches all325 files. Array8
canonical core SHA256 remains
`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`.

## Actual vendor results

Both builds use clean guest source commit
`8a4faa2c00d41ce2389b058586bd65a55beaa5e8`, Vivado2025.2 SW6299465,
IP6300035, SharedData6298862, and the retained launcher/version pin. The
Ubuntu22.04 guest has8vCPUs,40GiB RAM and16GiB swap; neither build swapped.

| Result | Smoke1x1/K2 | Array8/K16 |
| --- | --- | --- |
| Guest build under `/work/builds/` | `prx100-smoke-vivado-20261015-a5` | `prx100-array8-vivado-20261015-a1` |
| Setup WNS | +1.008ns | +1.310ns |
| Hold WHS | +0.048ns | +0.047ns |
| Routed total LUTs | 3,886 | 12,731 |
| Routed FFs | 3,795 | 7,297 |
| RAMB36 / RAMB18 | 1 / 0 | 1 / 2 |
| DSP blocks | 11 | 11 |
| Whole-run peak RSS | 3,626,260KiB | 4,568,580KiB |
| Wall time | 5m54.02s | 14m57.06s |
| Runner exit | 0 | 0 |

Both timing reports state all user specified constraints are met. Build Tcl
checks negative-slack paths, timing coverage and DRC, and emits a CDC report,
before writing the bitstream and `BUILD_COMPLETE`. Both CDC reports show one
safe crossing, zero unsafe/unknown crossings and no missing ASYNC_REG. The
RAMB36 belongs to the independent shell
aperture; the Array8 RAMB18 pair belongs to the portable core. These are
measured vendor allocations, separate from generic Yosys cell counts.

Bitstream SHA256:

- Smoke: `203908ac91ad52c1b4cf77cc31667c5f392acb9aef8c5f89acca8858d275386a`
- Array8: `3e575862fa4520ddbd23fab02e516d46560584715db1b6667152b4bbbc66f55b`

Smoke input-inventory SHA256 is
`23617b56995f2127029d4752f44e5f1087dd4be86c96ac6f946ce494ade6bd08`;
the Mac and Linux exports match. The runner records source identity, exact
command, input/output inventories and tool version. This is a reproducible
recipe and frozen local qualification, not a claim of identical bitstreams
across tool installations or independent hosts.

## Digital validation

- Mac `moon info`, formatting, strict native checking and full native tests:
  1,062passed,0failed. Target package tests also pass on the Linux guest.
- Pinned Verilator5.050: strict lint/build/execute and typed differential
  comparison pass for the3,655-cycle composed byte-interface replay, including
  signed−7×9=−63, busy, bounds and reset behavior.
- Pinned Yosys0.68 generic synthesis and `check -assert` pass for the normalized
  smoke composition. The vendor startup primitive is outside that fixture.
- XSim2025.2 compares the actual old/new helper bodies across all65,536
  four-state pairs of4-bit inputs, plus32-bit ambiguous and known-mismatch
  cases: PASS.
- Direct helper conformance uses the locked SBYv0.68/Bitwuzla0.9.1 image.
  Binary equivalence passes for all12 actual widths, including64bits. The
  deliberately inverted4-bit assertion fails with a retained counterexample.
  This exact-RTL helper probe is separate from the canonical Phase4 formal
  gate. That typed gate correctly refused this raw miter; it was not weakened.
- A separate real-RTL UART fixture runs1,316,662cycles at divisor434. Six
  complete CRC-checked replies pass: Identify, write/read `0x89abcdef`, logical
  reset, persistence read, and address4096 refusal. It exercises the actual
  RX synchronizer, RX/TX logic and composed core/shell, with explicit top
  reset. It is protocol validation, not a LunaWave cycle differential or a
  physical startup/board test. The first audit's expected CLI display format
  was wrong; corrected fixturev2 preserves the RTL/stimulus and passes.

The guest's global native suite stops in the unrelated pre-existing
`cmd/sim-bench/allocation_probe.c`: glibc's `RTLD_DEFAULT` is unavailable under
the chosen strictC99 feature macros. Its failure is retained; no portable
source was changed to repair it. The complete strict suite passes on the Mac.

## CPU_TAG identification and remaining physical work

The host detects FTDI0403:6010, Digilent serial `ME10E06D1010`. After a clean
guest shutdown, the same isolated VM was restarted with an xHCI controller;
only that USB device was passed into it. Vivado identifies target
`localhost:3121/xilinx_tcf/Digilent/ME10E06D1010A`, device `xc7a100t_0`,
IDCODE `0x13631093`, at1MHz JTAG. The read-only scan exits0 and closes the
target. No programming command, bitstream assignment or flash write occurs.
The onboard JTAG path is usable; an external programmer is unnecessary for
this observed connection. JTAG identifies the FPGA family, not PCB revision,
package, speed grade or IO-bank voltages. Verify those against the board
contract before programming.

CPU_TAG's FTDI interfaces are distinct from the CP2102 UART on L17/L18. The
CP2102 was absent in the latest USB inventory: connect `USB TO UART` as well
for packet tests. No new physical UART result follows from the digital fixture.
The host USB node's temporary access change was restored to root:root0664.
No host package, service, repository, firewall or bridge change was made.

## Retention

Current unique inputs, isolation failures, exact RTL/helpers, tool pins,
source bundle, reports, bitstreams, proof models/counterexample, UART traces
and validation logs are retained in
`artifacts/prx100-vivado-build-20261015`. Its SHA256 inventory and `SEAL` bind
the contents. Large text results use deterministic gzip with complete expanded
byte comparison. Compiler, Verilator, Vivado and XSim caches stay outside the
archive; credentials and authentication-token contents are excluded. Previous
sealed archives remain unchanged. Working originals are preserved.
`TRANSPORT_RETENTION.json` records eight small Docker input/output volumes
kept for recovery; no working path or volume was removed in this campaign.
