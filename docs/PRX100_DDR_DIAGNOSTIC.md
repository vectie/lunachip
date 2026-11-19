# Standalone PRX100 DDR3 diagnostic target

Physical acceptance completed2026-10-16: three calibrations,54 expected case
outcomes, full256MiB coverage and zero unexpected errors. Median rates are
1354.957MB/s write ingress and1037.835MB/s read/verify. See the
[qualification ledger](evidence/prx100-ddr-memory-20261016.md) for exact scope,
raw captures, timing, reproducible commands and remaining integration work.

This target contains no FluxTile accelerator. It preserves the portable core,
UART target and Device ABI, and uses separate source/build/bitstream identities.
It connects MIG7Series native128-bit BL8 transactions to a MoonBit/LunaWire
memory tester. CPU_TAG drives a32-bit AXI4-Lite register interface through
JTAG-to-AXI. Both digital interfaces use MIG's nominal100MHz UI clock.
The tester models a native beat as four explicit32-bit lanes; the structural
vendor wrapper packs/unpacks the128-bit MIG bus. No value-width extension to
portable LunaWire/LunaWave semantics is introduced.
The physical wrapper owns the external50MHz input buffer,200MHz reference,
configuration startup and button reset. Vendor memory/clock/debug IP remains
outside canonical LunaWire semantics.

## Memory and test contract

The populated MT41J128M16HA-125 is256MiB x16, with14 row,10 column and3 bank
address bits. One native user beat transfers16 bytes. MIG native addresses
count16-bit memory words; sequential BL8 commands therefore increment by8,
not16. For beat index i, byte address=16*i and native command address=8*i.
Confirm these parameters and100MHz `ui_clk` against generated/routed reports
before hardware execution. Physical pins are in the [board investigation](PRX100_DDR_DATA_PATH.md).

Each test covers a configured count of16-byte beats, from byte0 upward;
16777216 beats is the complete256MiB. Writing and reading are separate phases,
so address aliases cannot pass by reading immediately after every write.
Command and write-data handshakes are independently held until accepted.
Reads permit at most16 outstanding beats and verify every returned bit in
ordered responses. Optional reverse reads check the same expected address
pattern in descending order. Calibration loss, invalid geometry and malformed
response sequencing fail the test. Reset abandons work and does not clear DRAM.

Pattern modes:0=zeros,1=ones,2=AAAA checkerboard,3=5555 checkerboard,
4=address/seed-dependent invertible xorshift words,5=inverted mode4,
6=mode4 with odd byte lanes masked,7=mode4 with even byte lanes masked.
Mode6 requires a preceding complete zero write; its read expectation is zero
on preserved odd bytes. Mode7 follows mode6 with the same seed and expects
the complete mode4 pattern. This tests both physical DM lanes over the full
memory. All command inputs are latched at start and stable through the run.

Write cycles count from entering the write phase through acceptance of the
last command and data beat. This is controller ingress timing; buffered
physical writes may drain afterward. Read cycles include command issuance,
response latency and final comparison. Full-memory sustained rates amortize
bounded MIG queues; neither is a JTAG transfer rate or a line-rate claim.
Counters are64-bit UI cycles and are stable after completion. Count actual
accepted write commands/data and issued reads/checked responses independently.

## AXI4-Lite registers

Addresses are aligned byte offsets. Only full32-bit writes are accepted;
unknown addresses, partial writes, configuration writes while busy and invalid
START requests return SLVERR. AW and W may arrive in either order and are
latched independently. B/R payloads remain stable under backpressure. Reads
capture one register value at AR acceptance; read counters after completion
for a coherent multiword snapshot. No burst or out-of-window alias is allowed.

| Offset | Register |
| --- | --- |
|00| Signature44445233 |
|04| Diagnostic version00010000 |
|08| Flags: bit0 calibrated,1 busy,2 done,3 error |
|0C| Test error code:0 none,1 invalid start,2 calibration loss,3 response protocol |
|10| Command: bit0 START,1 read-only,2 write-only,3 reverse read; other bits zero |
|14| Seed32 |
|18| Beat count25, valid1..16777216 |
|1C| Pattern mode0..7 |
|20| Accepted write commands |
|24| Issued reads |
|28| Checked responses |
|2C| Mismatching128-bit beats |
|30,34| Write cycles low/high |
|38,3C| Read cycles low/high |
|40| First mismatch byte address |
|44..50| First expected128-bit data, low word first |
|54..60| First observed128-bit data, low word first |
|64| Nominal UI frequency100000000Hz, qualified against routed report |
|68| Maximum outstanding reads16 |
|6C| Accepted write data beats |

Additional dedicated observation pins in the canonical test module may expose
the FSM/counters to the independent simulation harness; they are not new core
ports. Test success requires done, no error/mismatch, exact accepted counts
and checked responses, and positive completed-phase cycle counts. FPGA DONE
alone is never memory-test success.

## Physical qualification

Qualify the MoonBit controller with independent behavioral memory/AXI models,
randomized command/data readiness and response timing, held AXI responses,
fault injection and reset. Check emitted RTL with pinned independent tools.
Generate exact MIG/clock/JTAG configs, close setup/hold timing and relevant
pin/clock DRC before volatile programming through the identified CPU_TAG cable.
Retain all failed attempts and exact physical captures. Keep the previously
qualified Array8 bitstream available for recovery; do not program flash.

On hardware, first establish calibration and a small diagnostic range, then
run every full-memory pattern, both byte-mask phases, descending-address reads,
idle/retention reads and repeat runs. Report actual checked bytes and errors,
clock/data rate and separate write/read/combined measured bandwidth. A failed
calibration or test is retained and investigated rather than labeled a pass.
