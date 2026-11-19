# PRX100-D UART + BRAM target, transport0.1

This target is Phase7 work; Phase6 remains in progress. The smoke and Array8
profiles have passed Vivado2025.2 implementation at50MHz with BRAM mapping;
see the [build ledger](evidence/prx100-vivado-build-20261015.md). Export alone
does not establish those results. The [physical UART/BRAM test](evidence/prx100-uart-bram-20261016.md)
passes29 transactions. The [signed matrix smoke workloads](evidence/prx100-signed-matrix-20261016.md)
also pass on the1x1/K2 accelerator. The
[physical Array8/K16 workload](evidence/prx100-array8-matrix-20261016.md)
passes all64 signed results, four fault-free completions and guard checks.
The [broader campaign](evidence/prx100-broad-matrix-20261016.md) also passes40
edge/seeded/repeated cases and a host-accumulated synthetic K1024 projection,
with timing boundaries recorded separately for compute counters and UART.
The [real Qwen W8A8 projection block](evidence/prx100-qwen-projection-20261016.md)
also passes exact integer and checked dequantized outputs for three real
normalized embeddings. It does not execute the full language model.
The portable FluxTile generator, logical Device ABI1.0 and descriptor0.2 are
unchanged. Board framing is independently versioned.

The follow-on [DDR3 and bulk data path investigation](PRX100_DDR_DATA_PATH.md)
selects Ethernet plus DDR staging and a target sequencer, with CPU_TAG
JTAG-to-AXI for memory diagnostics. Installed-IP/pin discovery passes; DDR
calibration and Ethernet hardware operation remain unqualified. That proposal
does not extend this UART version1 contract or alter its portable core.

## Hardware identity and boundary

Target part: `xc7a100tfgg676-2`, industrial temperature grade recorded as board
identity. Source schematic: PRX100 DDRV1.0, dated2021-07-05; reference guideV1.2.
The exact physical PCB revision must be checked before programming.

| Top port | Package pin | Role |
| --- | --- | --- |
| clk50 | D18 | 50MHz input,20ns clock constraint |
| uart_rx | L17 | CP2102 TXD / TTL_TX -> FPGA input |
| uart_tx | L18 | FPGA output -> CP2102 RXD / TTL_RX |
| reset_n | M4 | Active-low MENU user button, not configuration reset |

All listed IO uses3.3V banks and LVCMOS33, to be checked against the actual PCB.
Do not copy the lab manual's SRAM pinout. Do not use the camera/expansion
connector as PC PCIe. JTAG connector/jumper labels conflict between documents;
verify schematic nets and PCB labels. The UART USB-B is distinct from FPGA
JTAG and CPU-debug connections. The DDRV1.0 schematic also shows FT2232HL
channelA routed through the internal/external selector to FPGA JTAG, with
channelB for CPU debug. Check this onboard path through `CPU_TAG` before
requiring an external programmer; PCB population and cable recognition must
be verified. No DDR3, Ethernet, CPU, flash programming or
programming-cable automation belongs to this first target.

The digital control shell is elaborated in MoonBit. A generated structural
SystemVerilog wrapper connects its explicit ports to the separately emitted,
unchanged accelerator; current construction APIs have no module-instance API.
No portable IR/emitter change is made to add board hierarchy. The physical
wrapper owns configuration-startup reset and asynchronous button assertion /
synchronous reset release. UART RX uses a declared two-stage bit synchronizer.
These digital models do not establish analog metastability behavior.

The target records RTL normalization `explicit-input-wire-native-equality-v2`.
Input ports are declared `input wire logic` for Vivado's `default_nettype none`
handling. Equal-node helpers use standard logical equality `(a == b)` in place
of the conservative backend's mismatch/unknown loop, which causes excessive
Vivado synthesis expansion. Both forms preserve known-mismatch precedence and
unknown results for ambiguous comparisons. The original helper bodies and
normalized helpers are checked with actual four-state simulation and binary
equivalence fixtures. Restoring those bodies and removing explicit input net
kinds reproduces ordinary emitted RTL byte-for-byte. Arithmetic, registers,
memories, the general backend and canonical core/shell IR remain unchanged.

Default profile:8x8/K16, two A/B/C slots,4096-byte host aperture, ring4, queue3.
A1x1/K2 smoke profile is separately identified. One shared32-bit-word BRAM
aperture implements synchronous reads, byte extraction and acknowledged writes;
it is distinct from accelerator scratchpads. Memory contents survive logical
reset and are unspecified at configuration until the host writes them.

## Wire framing

UART:50MHz /434 clocks per bit,8N1, nominal115200baud. One request at a time;
wait for the complete response before the next request. No unsolicited output.
Frames have fixed sizes, little-endian numeric fields and CRC-8/ATM
(polynomial07, initial0, non-reflected, xor-out0). Physical framing errors and
an inter-byte timeout discard a partial request. Bytes during command/reply
processing are not queued. Never blindly retry a mutating command after a
lost response; reset/reinitialize the session when acceptance is uncertain.

Request16 bytes:

| Offset | Field |
| --- | --- |
| 0..1 | A5 5A synchronization |
| 2 | Version1 |
| 3 | Opcode |
| 4..5 | UInt16 sequence echoed in reply |
| 6..9 | UInt32 argument |
| 10..13 | UInt32 data |
| 14 | CRC over bytes2..13 |
| 15 | 0D terminator |

Reply32 bytes: A5 5A, version1, opcode OR80, echoed sequence at4..5,
status at6, zero at7, five UInt32 result words at8..27, zero at28..29,
CRC over2..29 at30, terminator0D at31.

| Opcode | Operation | Argument/data | Result words |
| --- | --- | --- | --- |
| 0 | Identify | Both zero | Board signature, framing version, aperture, shape, K capacity |
| 1 | Write32 | Byte address / word | Zero |
| 2 | Read32 | Byte address / zero | Word |
| 3 | Configure | Ring base / origin | Zero |
| 4 | Publish | Absolute producer / zero | Zero |
| 5 | Completion | Both zero | ID, command fault, acknowledged bytes, fault address, zero |
| 6 | Status | Both zero | Flags, producer, consumer, retired, queue occupancy |
| 7 | Counters | Both zero | Elapsed low/high, active low/high, accepted steps + capture count |
| 8 | Reset | Both zero | Zero |
| 9 | Diagnostics | Both zero | Ring fault code/address, transport fault address, stall low/high |

Status0=OK,1=bad frame/version/CRC,2=unsupported opcode or nonzero unused
field,3=address/alignment,4=busy/not ready,5=no held completion.
Counter command atomically latches all its words; counters retain their ABI
meaning (latest issued MatMul, not per-retirement counters).
Status flags bits0..5 are configured, ring-fault-valid, halted,
transport-halted, completion-valid and quiescent; higher bits are zero.
Identify shape is `(rows << 8) | columns`. Counter result word4 stores accepted
steps in bits0..15 and capture count in16..31. Inter-byte timeout is1024 bit
periods. Configure/Publish assert valid only on an eligible ready edge;
otherwise they return busy without starting a hardware transaction.

Write32 and Read32 require a four-byte-aligned address in0..4092. Full32-bit
bounds are checked before narrowing. Memory/configure/publish access is
restricted to quiescent batches: producer equals the shell's retired count,
and no held completion. This first transport supports at most one ring's work
per batch. Upload four descriptors (LoadA,LoadB,MatMul,StoreC), configure and
publish them, retrieve all four completions, then read C. Fence can run in a
following batch. Reuse descriptors only after retirement. This is a transport
restriction, not a change to core concurrency or ABI.

The shell acknowledges writes after commit and reports config/publication
success only for the selected acceptance edge. A completion is acknowledged only
when its entire payload has been latched for a reply; a stalled host therefore
backpressures retirement. An empty Completion command does not consume later
work. Reset remains callable while a batch is active: it suppresses core
handshakes, clears local transaction/ownership state, flushes pending local
memory responses and leaves SRAM bytes intact. Reset invalidates slots and
does not manufacture completions or undo writes. Physical reset additionally
abandons any partial UART frame/reply. A reset reply is a new-session boundary.

## Build and acceptance

Export canonical core/shell IR, both emitted sources and name maps, structural
and physical wrappers, XDC, Vivado Tcl, capabilities and a SHA256 inventory.
Use one native build cache outside evidence. The POSIX runner targets a
supported x86-64 Linux host. Vivado release2025.2 is selected;
the build runner requires an explicit executable SHA256 pin, checks its
version and records full identity. The runner never installs tools or programs
a board. Build output must be fresh and outside source/evidence inputs.

One-thread synthesis/implementation uses explicit directives, checks setup /
hold timing and DRC, and writes a bitstream only after all gates pass. Export
is deterministic; byte-identical vendor bitstreams across hosts are not yet
qualified. Retain source hashes, physical PCB identity, tools, constraints,
reports and bitstream digest with eventual board captures. Native tests and
independent RTL/synthesis/formal evidence have separately stated scopes.

The separate [standalone DDR diagnostic target](PRX100_DDR_DIAGNOSTIC.md)
now qualifies256MiB memory through CPU_TAG/JTAG-to-AXI. It preserves this UART
contract and portable core; its image exposes JTAG diagnostics and contains no
accelerator. See its [physical results](evidence/prx100-ddr-memory-20261016.md).
