# PRX100 standalone DDR3 qualification, 2026-10-16

The PRX100-D passed three volatile configuration/calibration cycles through
CPU_TAG, each followed by the complete256MiB campaign. All54 cases passed
their expected outcome, with **zero unexpected mismatching beats**. All207
protected production/interface identities remain unchanged, including the
portable accelerator, Device ABI, canonical IR, simulator, general emitter
and existing UART target.

The current FPGA image is the standalone DDR diagnostic target, idle after
a clean full-memory reverse read. It contains no FluxTile accelerator or UART
service. The prior Array8 bitstream remains available for recovery. No flash,
host OS, host network or VM configuration was changed.

## Physical configuration

| Item | Qualified value |
| --- | --- |
| FPGA | `xc7a100tfgg676-2`, IDCODE13631093 |
| CPU_TAG | Digilent/FT2232 `ME10E06D1010A`, JTAG1MHz |
| DRAM | MT41J128M16HA-125, one128Meg×16 component,256MiB |
| Rate |800MT/s, CK400MHz, UI100MHz, native128-bit BL8 |
| Geometry |14 row,10 column,3 bank bits, one rank |
| Clock | External50MHz D18 to MIG; separate200MHz IDELAY reference |
| Board details | CS output disabled; bank13 internal VREF0.750V |
| Tools | Vivado2025.2 lin64 build6299465; MIG4.2, Clocking Wizard6.0, JTAG-to-AXI1.2 |
| Routed slack | Setup **+0.482ns**, hold **+0.031ns**; TNS/THS zero |
| DRC | Zero error or critical violations; vendor warnings retained |
| Resources |6741 LUT,6980 FF,2.5 BRAM tiles,0 DSP |

Bitstream SHA256:
`a5cc2832288cc9f242f6384b4827d969b5855e187686c9667a988e7eb74ccba7`.
Canonical tester IR SHA256:
`f347b9f477a8264fcbf73f3b8c35ac0fa3e1b4e925853196257e0b705385e402`.

The first implementation missed setup by0.316ns in the tester's first-error
snapshot enable path; its bitstream gate correctly refused it. Post-route
`phys_opt_design -directive AggressiveExplore` and `route_design -directive
Explore` closed timing without changing RTL or clock constraints. The first
MIG generation also warned about an unsupported DQS setting; the qualified
second generation uses the accepted setting. Both attempts and their exact
inputs/logs remain retained. No critical/error DRC was waived. See
`guest/route-a1/{timing,drc,clocks,ui-clock}.txt` for actual reports.

## Coverage and checking

Each full case covers16,777,216 distinct16-byte beats, byte addresses
`0x00000000..0x0fffffff`. Command and write-data acceptances, issued reads and
checked responses are counted independently. Separate write and verify phases
expose aliases. Native addresses count16-bit words, so BL8 increments by8;
the extra native rank bit is held zero.

Each calibration cycle runs a64KiB address-pattern check, then full-memory
zeros, ones, both checkerboards, address/seed-dependent words and their
inverse; both complementary byte masks; reverse reads; three more pattern
seeds;5-second masked-data and10-second address-data idle checks; two
deliberate wrong-seed read-only checks; and a correct-seed full reverse read.

Each intentional negative reports exactly16,777,216 bad beats. The forward
first error is byte0 and the reverse first error is `0x0ffffff0`. An independent
CPU xorshift implementation verifies all four actual and expected32-bit words
at both endpoints. These negatives change the checker seed, not DRAM contents,
and are excluded from successful-byte and bandwidth statistics.

Across all three campaigns:

- Successful comparisons: **12,079,792,128 bytes**,11.25GiB plus192KiB.
- Deliberate negative comparisons:1,610,612,736 bytes,1.5GiB.
- Useful written bytes excluding masked bytes:8,858,566,656,8.25GiB plus192KiB.

This demonstrates full address coverage with bounded pattern/repetition/idle
tests. Power cycling, temperature/voltage sweeps, long soak, exhaustive March
testing and random mixed traffic remain outside this qualification.

## Measured bandwidth

Rates use64-bit FPGA phase counters at the routed100MHz UI clock. MB/s is
decimal. Statistics include full-memory unmasked positive cases only.

| Phase | Samples | Min MB/s | Median MB/s | Max MB/s |
| --- | ---: | ---: | ---: | ---: |
| Write ingress |30|1354.955|**1354.957**|1354.961|
| Read and verify |36|1037.834|**1037.835**|1037.836|
| Sequential write plus read |30|1175.381|**1175.382**|1175.383|

For example, a1's full address case took19,811,382 write cycles and25,864,945
read cycles:198.114ms and258.649ms for256MiB each way. Write timing ends at
final MIG command/data acceptance; buffered physical writes can drain later.
Read timing includes final comparison. Combined rate divides total write/read
bytes by the sum of the separate phase durations; it is not simultaneous
traffic. JTAG carries commands/counter snapshots, not the full test payload.
These results establish neither host upload nor Ethernet bandwidth. Masked
bus-byte rates are retained separately in the raw report.

## Digital gates and reproduction

First-party construction/control is MoonBit/LunaWire in `targets/prx100_ddr`.
Four32-bit lanes model a native beat, with128-bit packing only in the physical
vendor wrapper. `validation/prx100_ddr` tests independent command/data stalls,
delayed reads, AXI ordering/backpressure/bounds, byte masks, reset/calibration
loss, malformed read-end, upper-lane corruption and address aliases.

The complete strict native regression passed **1103/1103 tests**, including
the five new DDR validation cases. Final `moon info`, `moon fmt` and
`moon check --target native --deny-warn` gates pass. Target automation scripts
are separately formatted and checked. A premature full run was interrupted
for CLI corrections; another caught an unrelated concurrently edited formal
test before it was complete. Both attempts are retained; the final complete
run has zero failures.

Pinned Verilator matched27 observed outputs over2078 cycles. Pinned Yosys
synthesis passed structural checks. A32-clock bounded formal run passed six
digital safety properties with initial reset assumed and free AXI/MIG inputs.
The calibration-bypass negative failed its named gate at step7 with retained
counterexample. This is bounded control proof, not an analog DDR model. Initial
formal output-permission and replay name/header/TSV formatting failures remain
retained with their corrected runs.

The three physical captures have tabbed headers and single-space rows from
Tcl's original default join separator. The independent auditor accepts the
exact retained format; the current driver explicitly emits tabs. Captures
were not edited. Scripts and as-run drivers both remain archived.

Copy the scripts to `/work` in the existing guest, use
`MOON_HOME=/tools/moon-baseline` with its `bin` in PATH, and fresh outputs:

```text
moon run /work/prx100-ddr-config.mbtx -- generate /work/builds/prx100-ddr-ip-NEW
moon run /work/prx100-ddr-build.mbtx -- build INPUT_BUNDLE MIG_ROOT /work/builds/prx100-ddr-vivado-NEW
moon run /work/prx100-ddr-route.mbtx -- repair VIVADO_ROOT /work/builds/prx100-ddr-route-NEW
moon run /work/prx100-ddr-board.mbtx -- run QUALIFIED_ROUTE /work/builds/prx100-ddr-board-NEW
moon run /work/prx100-ddr-audit.mbtx -- audit /work/builds/prx100-ddr-board-20261016- NEW_REPORT_JSON
```

The config driver requires the retained `schema-example.prj` at
`/work/prx100-ddr-schema-example.prj`; it replaces all timings/geometry/pins with
PRX100 values. Export physical/replay/formal bundles using `cmd/prx100_ddr`.
Drivers enforce tool/source inventories, FPGA/cable identity, timing/DRC and
DONE/CRC. The auditor independently checks all54 row counts/flags/errors,
endpoint words and rates. See the [diagnostic contract](../PRX100_DDR_DIAGNOSTIC.md).

Sealed evidence: `artifacts/prx100-ddr-memory-20261016`; guest subset:
`/work/builds/prx100-ddr-memory-evidence-20261016`. Both retain SHA256SUMS/SEAL,
unique inputs, exact scripts/RTL/configs, reports, raw results and the qualified
bitstream. Compiler/Verilator/vendor implementation/DCP caches remain outside.
Existing sealed archives are unchanged.

DDR is now a qualified standalone building block. BRAM staging, a target tile
sequencer, faster host transport and the pinned Qwen projection over DDR remain
separate integration work. No full-model or tokens/s claim follows from this test.
