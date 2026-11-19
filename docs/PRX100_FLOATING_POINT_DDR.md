# PRX100 floating-point DDR target contract

This FPDDR1.0 target connects the unchanged eight-lane BF16/FP32 core to the
unchanged PRX100 projection DDR bridge and qualified 256 MiB MIG geometry.
First-party sequencing and control are MoonBit hardware. Vendor IP supplies
MIG, reference clocking, JTAG AXI4 and AXI4-to-AXI4-Lite conversion. The existing
integer core, integer target, and FP1.1 BRAM profile remain unchanged.

## Storage and autonomous execution

Three independent, 64 KiB-aligned, 28-bit DDR base addresses select weights,
activations and results. They must be distinct. Weights are eight channel-major
rows of 1024 BF16 values (16 KiB). Adjacent values occupy the low and high halves
of a 32-bit word. One activation vector is 1024 BF16 values (2 KiB); up to three
vectors occupy consecutive 2 KiB regions. Results occupy 32 bytes per job, with
eight FP32 words in channel order. Up to 48 jobs fit in one batch. Vector index
cycles through the configured one to three vectors.

Each START loads all weights into a separate 16 KiB synchronous BRAM cache if
the cache is invalid, then loads each job's 2 KiB activation vector. DDR reads
use aligned 128-byte streams through the existing bridge. A pipelined BRAM
loader combines one BF16 activation and weight per cycle into the FP core's
eight operand banks. It issues 8192 packed words, with explicit one-edge BRAM
read latency, before starting the unchanged FP core. The requested reduction
length is 1..1024; the storage layout and staging extents are fixed.

Each lane retains the FP1.1 sequential FP32 RNE order and special-value policy.
The core still takes 5*K+4 cycles. Two 16-byte writes publish the eight results
to DDR before the next job. DONE means the final write's MIG acceptance has
returned through the bridge. Subsequent readback establishes visibility.

The weight cache remains valid across successful batches. Any accepted host
DDR write, weight-base configuration write or explicit invalidation command
invalidates it conservatively. Reads do not invalidate it. Reset, memory health
loss or protocol/core/watchdog faults invalidate the cache and cancel work.
There is no resident-data preservation claim across physical reset.

## Ownership and failures

The DDR portal is available only while idle or DONE and memory is healthy.
START and configuration require no portal owner or pending portal read.
AW/W may arrive independently; AXI responses remain stable under backpressure.
Requests and streamed responses retain ownership until the expected final beat.
Malformed last markers, unowned responses and nonzero faults fail closed; an
accepted stream is drained where possible. No younger job or result is
published after failure. Recovery from a job/protocol/health/watchdog fault
requires coordinated physical reset. Invalid configuration accesses return
SLVERR without starting work.

The existing 50/100 MHz bridge, FIFO reset coordination, captured request
payloads and native MIG command/WDF ownership are reused without modification.

## Control ABI

All offsets below are byte addresses; writes must be aligned with all strobes.
Read counters after DONE for a coherent snapshot.

|Offset|Meaning|
|---|---|
|0x00 /0x04|Magic 0x46504433 /version 0x00010000|
|0x08|Flags: bit0 healthy, bit1 busy, bit2 done, bit3 fault|
|0x0c|Error: 0 none; 2 health; 3 DDR fault; 4 protocol; 5 FP core; 6 watchdog|
|0x10|Write1 START, write2 invalidate cache while idle|
|0x14 /0x18 /0x1c|DDR byte bases: weights /activations /results|
|0x20|Reduction length 1..1024|
|0x24|Batch job count 1..48|
|0x28|Vector count 1..3, no greater than batch job count|
|0x30 /0x34|Current job index /completed jobs|
|0x38|Total batch cycles, START acceptance through final result ACK|
|0x3c|Cycles in DDR request/response states|
|0x40|Cycles packing BRAM operands into the FP core|
|0x44|Cycles waiting for FP completion|
|0x48|Sum of FP core compute-cycle counters|
|0x4c /0x50|Accepted streamed DDR reads /result-line writes|
|0x54 /0x58|Staged DDR words /packed core words|
|0x5c /0x60|Sequencer state /current vector index|
|0x64 /0x68|Core frequency 50 MHz /MIG UI frequency 100 MHz|
|0x6c|Weight-cache valid|
|0x80..0x9c|Last job's eight FP32 result bits|

The DDR portal is 0x10000000..0x1fffffff. Only aligned full 32-bit accesses
reach the custom controller. Vendor protocol conversion splits AXI4 bursts
into these accesses. Host software uses at most 256 INCR beats without crossing
4 KiB boundaries and verifies payload word ordering and complete readback.
Burst transport does not turn the AXI-Lite portal into an atomic transaction.

## Qualification and measurement

Before programming: targeted and full native gates, exact FP/bridge/integer
identities, randomized DDR/AXI stalls and faults, actual emitted RTL replay,
pinned synthesis and scoped control/formal sensitivity checks, then pinned
Vivado/MIG, routed clock/timing, CDC and DRC qualification.

Physical acceptance requires fresh FP1.1 baseline comparison, DDR calibration,
bulk upload and complete readback of all inputs and guards, exact CPU FP32
comparison for every output across short/cold/warm/batched jobs, and independent
raw-traffic audit with a corrupted-result negative control. Report upload,
readback, hardware staging/compute/write completion, launch/poll/readback and
whole-campaign times separately. Engine time and host time are different
measurements. This remains the same selected eight-channel Qwen projection;
full-model execution and a general model-serving runtime are outside this task.

Vendor burst semantics are described in AMD's
[JTAG transaction command](https://docs.amd.com/r/2025.1-English/ug835-vivado-tcl-commands/create_hw_axi_txn)
and [AXI4-Lite conversion](https://docs.amd.com/r/en-US/pg059-axi-interconnect/Conversion-to-AXI4-Lite).

The [2026-10-17 qualification](evidence/prx100-fpd-20261017.md) records848
CPU-exact board outputs,307.133 µs warm hardware completion, a350.75× reduction
in three-vector upload time, and46.39× lower amortized host time in one48-job
batch. The existing integer and floating-point cores remain unchanged.
