# PRX100 DDR3/data-path investigation, 2026-10-16

The PRX100-D has256MiB x16 DDR3 and an RTL8211E-VB Gigabit RGMII Ethernet
PHY. The recommended follow-on is Ethernet bulk transfers to DDR, with burst
buffering, BRAM staging and a target-only tile sequencer around the unchanged
Array8/K16 core. Existing CPU_TAG JTAG-to-AXI is the intermediate debug route.
The [integration proposal](../PRX100_DDR_DATA_PATH.md) contains complete pin
tables, timing/ownership requirements and ordered acceptance tests.

**Achieved scope:** source-document review, device-database pin checks,
installed-IP/customization/license discovery, analytical storage/traffic
budget and source protection. **Not achieved:** a PRX100 MIG `.prj`, generated
memory-controller outputs, synthesis/placement/routing of that controller,
DDR calibration or memory testing, Ethernet packets or new throughput results.
No board was programmed and no host OS/network/VM configuration was changed.

## Reproducible headless discovery

The isolated Ubuntu22.04 guest uses the existing Vivado2025.2 installation
under `/tools/amd/2025.2`. The executable and exact version output are checked
against `/work/builds/vivado-2025.2-pin.json`, with launcher SHA256
`3b15c02533ef5b5bab4a09617086bd431b14aa296e6ea5a29811fe269cf8deb5`.
Version: Vivado2025.2, lin64, build6299465.

Copy the repository `scripts/prx100-ddr-probe.mbtx` to
`/work/prx100-ddr-probe.mbtx` in that guest, then run:

```text
MOON_HOME=/tools/moon-baseline PATH=/tools/moon-baseline/bin:$PATH moon run /work/prx100-ddr-probe.mbtx -- run /work/builds/prx100-ddr-probe-NEW_ID
```

The output root must be fresh. The driver writes the exact script and Tcl,
limits Vivado to one thread with a240-second process timeout, queries the
package and creates IP customizations without generating implementation
outputs. It restores RTL project mode after closing its IO-planning design.
The final Tcl contains no hardware-manager/programming commands.

| Attempt | Guest root suffix | Result |
| --- | --- | --- |
| a1 | `20261016-a1` | Failed: IP commands invalid while the project remained in PinPlanning mode. |
| a2 | `20261016-a2` | Failed: `create_ip -dir ip` requires the directory to exist. |
| a3 | `20261016-a3` | Passed device-pin and MIG/JTAG/TEMAC catalog/customization discovery. |
| a4 | `20261016-a4` | Passed the same probe plus Clocking Wizard200/125MHz parameter acceptance from50MHz. |

All four exact inputs/logs/results are retained. Neither unsuccessful probe
reached hardware. The installed catalog emits repeated unknown-architecture
warnings during IP scanning; they remain in the raw logs. Those warnings did
not prevent a3/a4 from exiting0 with `PRX100_DDR_IP_DISCOVERY_COMPLETE`.

The independent audit confirms all47 connected DDR package pins in bank13,
all15 listed Ethernet signals in bank15, D18 as bank16 MRCC at IOB_X0Y176,
the two byte-group DQS pads, W18's VREF role and K21's MRCC role. The observed
DDR pads occupy T0/T1 for data and T2/T3 for address/control. These checks do
not substitute for MIG pin validation or routed clock DRC.

| Customization | Installed version/revision | Reported license |
| --- | --- | --- |
| MIG7Series |4.2 rev2| Included |
| JTAG-to-AXI Master |1.2 rev23| Included |
| Clocking Wizard |6.0 rev17| Included |
| Tri-Mode Ethernet MAC |9.0 rev39| Design_Linking |

`CONFIG.XML_INPUT_FILE` remains empty in the MIG probe. Thus `create_ip`
success is not acceptance of the PRX100 pinout, memory timings or input clock.
The selected installed memory-catalog entry supports MT41J128M16HA-125 at
1.5V, and component metadata permits `DDR3_USE_CS_PORT=0`. The exact source
metadata identities and relevant snippets are retained without copying the
vendor IP library. A usable hardware TEMAC license has not been established.

Clocking Wizard accepts50MHz input and200MHz/125MHz outputs, using multiply20,
input divide1 and output divides5/8. This is a reference/Ethernet-clock
candidate, not permission to use a generated clock as MIG's system clock.
The board-specific DDR system-clock candidate remains the external50MHz
oscillator with a legal MIG PLL/backbone topology; it has not been generated
or routed. See the proposal's primary AMD references for clock/VREF/rate and
IP-license limits.

## Document and capacity review

The schematic DDRV1.0 and hardware guideV1.2 were extracted with Poppler.
Complete relevant schematic pages were rendered and visually reviewed:
PDF7 bank13/14, PDF14 Ethernet and PDF23 DDR3. The review catches the tied-low
CS#, W18/VREF reuse,1.5V memory bank, PHY straps and separate JTAG/UART wiring.
Document SHA256 identities, extracted text and these page images are retained.
Older SRAM examples in the lab manual are not treated as DDR pin evidence.

`scripts/prx100-data-path-budget.mbtx` reproduces the analytical bounds:

```text
moon run scripts/prx100-data-path-budget.mbtx -- report /absolute/new-budget.json
```

The current real Qwen block uses6272 steady exchanges/301056 framed bytes
per vector, with a26.133s UART wire floor. A proposed autonomous target could
exchange9248 code/result bytes for its first vector and1056 for later vectors
with weights resident, excluding metadata/framing/internal traffic. That
requires a new sequencer/accumulator; these are not measured bulk transfers.
The candidate DDR raw1.6GB/s and Ethernet raw125MB/s are theoretical ceilings.
The50MB/s Ethernet goal and resulting5.37s DDR upload are unmeasured targets.

The independent capacity audit reads the previously retained checkpoint
header, checks its exact SHA256 and sums tensor shapes:751632384 serialized
BF16 elements including separate embedding/output matrices. Honoring the
configured tied matrix gives596049920 logical elements. Even that compact
ideal INT4 layout needs284.21875MiB, exceeding256MiB before scales/KV/workspace.
Full serialized matrix equality was not checked. The proposal explicitly
states the tied-storage assumption and keeps host-assisted streaming as the
next model milestone. No full-model performance or quality claim is made.

## Core protection and validation

The existing core IR digest remains
`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`;
the previously qualified Array8 bitstream remains
`3e575862fa4520ddbd23fab02e516d46560584715db1b6667152b4bbbc66f55b`.
No portable generator, IR, emitter, simulator, core ABI or target production
implementation was edited. The before/after identity audit passes for207
production source/interface files. Existing unrelated Phase6 work is preserved.

Standalone new scripts pass warning-strict checks. `moon info`, `moon fmt`
and `moon check --target native --deny-warn` pass. Full native regression
passes1094/1094 tests with `--deny-warn`; the complete log is retained in
compressed form with a byte-for-byte decompression comparison.

This investigation introduces no new RTL behavior, so its discovery result
is not promoted to an emission/differential/formal or physical DDR/Ethernet
gate. The follow-on acceptance work requires those scoped gates explicitly.

## Retention

Guest evidence: `/work/builds/prx100-ddr-evidence-20261016`,74 inventoried
files plus SHA256SUMS/SEAL, including failed attempts. Local evidence:
`artifacts/prx100-ddr-investigation-20261016`. Each retained copy is checked
against its checksum inventory before sealing read-only. `.Xil`, compiler
caches and regenerable project outputs are excluded. No old regression
archive or bitstream is copied into this investigation archive; identities
and original recovery locations are referenced instead. Originals and all
earlier sealed archives remain intact.
