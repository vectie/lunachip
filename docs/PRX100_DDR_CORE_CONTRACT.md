# PRX100 DDR-to-core projection target

The current1.7 image adds [eight-line weight streaming and descriptor/fill overlap](PRX100_DDR_STREAMING.md). The [DDR streaming and descriptor staging continuation](evidence/prx100-stream-20261017.md) passes40 fresh A/B jobs: **0.45630→0.41775ms median**, **8.45% lower** (1.092×), with the exact portable core and clocks. Front-end reads fall576→128/full block; native traffic is unchanged. Scalar CPU183µs remains faster; host/JTAG and full-model integration remain open.

The preceding1.6 image adds [four-word result batching](PRX100_DDR_RESULT_WRITES.md) to the existing word core and operand line staging. The [batched DDR result writes](evidence/prx100-results-20261017.md) pass a fresh20-job campaign per image: **0.48054→0.45618ms median**, **5.07% lower** (1.053×). All40 jobs match the signed CPU reference; writes fall520→130 per full block, with the same portable core and clocks. The scalar CPU is183µs; the new FPGA remains2.49 times slower. Host/JTAG transfers remain dominant; full-model inference remains separate work.

The preceding1.5 image combines the [portable word-read core](PHASE6_WORD_MEMORY.md)
and [matching staging adapter](PRX100_WORD_MEMORY.md) with
[streamed DDR line staging](PRX100_DDR_STAGING.md). Its
[fresh physical A/B](evidence/prx100-staging-20261017.md) passes20 jobs per image:
1.4 median0.53596ms versus1.5 median0.48102ms,10.25% lower. The portable core
retains its exact identities, and arithmetic and clocks remain unchanged.
The target bridge and sequencer change. Earlier1.3→1.4 results remain in their
[separate receipt](evidence/prx100-word-20261017.md).

## Target optimization revisions

The [physical comparison](evidence/prx100-ddr-optimization-20261016.md) passes
20 jobs and lowers full-block median latency from2.36871 to1.76730ms.

The cache revision preserved the word portal, job register/counter meanings,
portable core and descriptor encoding. A single 16-byte read line is cached in
the 50MHz bridge domain. A miss returns all four native words as four ordered
34-bit flits through the checked response FIFO; subsequent aligned reads of
that line avoid both CDC crossings and native commands. Only one source
transaction is owned.
Every accepted write invalidates the line, including writes to another line;
fault, lost synchronized health and physical reset also invalidate it.
After calibration has first succeeded, even a one-UI-clock calibration-loss
pulse poisons the bridge until physical reset; this cannot disappear between
slow clock edges. Cached responses remain registered and held through
backpressure. External DDR writers
are excluded by the existing sole-owner contract. Logical job read/write counts
continue to count word requests, not native beats or cache misses.

Staging writes all 32 descriptor words for the first tile of every START.
The qualified1.0 image updates eight words on later tiles. The1.1
[loading pipeline](PRX100_LOADING_PIPELINE.md) updates ID, base and slot fields
(twelve words) because operand staging alternates between two regions. Its
[physical qualification](evidence/prx100-core-loading-20261016.md) passes20
jobs at median1.37524ms,22.18% below1.76730ms. Version1.1 explicitly changes
phase-counter overlap semantics below. The staging adapter accepts
core writes only in aligned result windows:1024..1052 for1.1 and additionally
3072..3100 for1.2..1.7. Descriptor/operand mutation attempts return a bounds fault.
Version1.2 releases descriptor storage on consumer advancement and publishes
one tile ahead;1.1 retains its quiescent reuse rule. A fresh START rebuilds the entire
descriptor image.
Comparison uses the same 1x1024 by1024x8 work and all partials/final sums;
the original 2.36871ms median is retained as the physical baseline.

This separate target integrates an Array8/K16 fetched concurrent core with
a4KiB synchronous BRAM staging aperture and autonomous projection sequencer.
Revisions1.0..1.3 used the original byte-read core. Revisions1.4..1.7 use its opt-in
word-read transport extension; the old Device ABI1.0 capability manifest does
not negotiate that extension. Descriptor0.2 and arithmetic retain their rules.
Its first workload is the pinned Qwen W8A8 block:1x1024 by1024x8,64 K16 tiles.
It is not a full projection/layer/model or a token generator.

## Clocks and transport

The core, staging memory, sequencer and JTAG AXI4-Lite run at external50MHz.
The qualified MIG geometry/pins/clocks remain800MT/s with100MHz UI. Two checked
depth4 asynchronous FIFOs carry64-bit requests and34-bit responses between
domains. Only one DDR transaction is outstanding at the source. A request
contains aligned28-bit byte address, write bit and32-bit little-endian data.
MIG read misses transfer128 bits and return four ordered34-bit response flits
to the slow-domain line cache. Writes repeat their word and enable only its
four bytes through the16-bit native mask, returning one response flit.
For host portal reads, the source collects all four flits, caches the line
and returns its selected word; cache hits return a registered local response.
Revision1.5 job reads set `request_line`, require16-byte alignment, and expose
all four words directly as ordered response beats. `response_last` marks only
the fourth accepted beat. Data/fault/last remain held through backpressure,
and the controller retains ownership until that beat. Writes and portal
reads still return a single last-marked response. A malformed last fails the
job with error7 before incomplete operands can be published. A physical reset
flushes any failed stream. Previous native streaming BIST bandwidth does not
describe this path; native read traffic is unchanged from1.4's line cache.

Revision1.6 adds [four-word result writes](PRX100_DDR_RESULT_WRITES.md).
Job writes set `request_line` and provide four explicit32-bit words. The bridge
latches the entire payload at source acceptance and sends four64-bit FIFO
flits (header/word0, then words1..3). It gathers them before native issue,
then emits one128-bit WDF beat with mask0 and one write command. Invalid line
addresses drain all four flits and return a fault without native issue.
Both word and line writes return one held, last-marked ACK. Host portal
writes retain their selected four-byte mask. A batch ACK means acceptance
of all16 bytes at MIG, not physical DRAM drain or atomicity during reset.

Native command and WDF readiness are independent. One response acknowledges
each complete write acceptance or validated read result. Held requests and
responses remain stable. Unowned/malformed responses or calibration loss
poison the bridge until physical reset; no stale FIFO response can be reused.
The physical reset coordinates both FIFO endpoints and MIG. Starting a job
resets only the idle portable core and job counters, without resetting FIFOs
or erasing DRAM. Reset release is synchronized in each domain.
Initial traffic uses coordinated idle reset. A physical reset during work
explicitly flushes/loses that work and the MIG session; no lossless delivery
is claimed across it. Portal selection is latched before DDR acceptance, so
a later request on the other AXI channel cannot replace a stalled request.
Calibration loss before acceptance cancels that portal access with SLVERR;
an accepted transaction waits for its owned bridge response.

## Memory and ownership

AXI addresses0x10000000..0x1fffffff map to the256MiB DDR byte aperture.
Only aligned full32-bit accesses are accepted; AXI write acknowledgment follows
native command/data acceptance, and reads follow the DDR response. Aperture
access while a job owns DDR is rejected. Control/status remain accessible.
The upload must be read back and compared before START. AXI channels accept
AW/W in either order and hold B/R payloads through backpressure.

Four configured DDR bases are aligned to64KiB, within28 bits, and occupy
distinct64KiB regions. Maximum extents are weights8192, activations1024,
partials2048 and sums32 bytes, so no accepted job aliases buffers or crosses
the DDR boundary. Recommended bases:0x00100000,0x00200000,0x00300000,0x00400000.
Weights are tile-major B[k,j],128 bytes per K16 tile, channel j=0..7.
Activation tiles contain16 contiguous signed bytes. Partial offset is
tile*32+channel*4; final sums contain eight signed32-bit words.

The1.5..1.7 sequencer retains1.2's alternating A at256/2304, B at512/2560 and C at1024/3072.
It writes four32-byte descriptors at0 on the first tile, then patches twelve
ID/base/slot words after consumer advancement past all four current packets.
Successful next36-word operand prefetch (nine line requests in1.5/1.6; two requests in1.7) is also required before the next
four-entry publication. Consumer advancement releases host ring storage before
execution/retirement; the core retains ownership of copied packets. The
publication cursor stays at most one tile ahead of collection.

Four exact ordered IDs/fault/byte counts complete each tile. Its eight C words
are read and accumulated, then written as partials to DDR. Revision1.3 gives
collection its own synchronous ReadOld/HoldLast port. Held tagged core data
remains stable while collection reads, and new core acceptance remains open.
C[0] is read at the retirement join; C[channel+1] is read while the current
partial's DDR request/ACK is pending. State10 latches the previous edge's word.
Revision1.2's single-port wait remains documented in its historical contract.
Core work continues during partial DDR transfers. Host writes
exclude core writes; independent core reads may share descriptor/prefetch
writes. An operand/result bank is recycled only after its old tile's four
completions and all eight partial acknowledgments. Younger completions remain
held until collection advances. Original retirement capacity constrains younger
store admission. Revision1.1's completion-before-publication schedule remains
documented in its historical loading contract.

Partial DDR acknowledgments advance the channel directly. Final sums are stored
after the last tile. Accepted tile counts1..64 bound the
signed INT8 sum well inside INT32; no unbounded accumulation is permitted.

In1.6, collection advances through four C words with explicit synchronous
read latency before each batch request. Partial ACKs advance the acknowledged
word count by four. A tile completes after both partial batches; the final
sum phase writes channels0..3 and4..7 as two lines. Operand/result leases,
INT32 accumulation, DDR byte offsets and portable core identities are unchanged.

Revision1.7 keeps those result batches and adds one128-byte weight stream after the16-byte activation line. `request_burst` marks the aligned128-byte read; only weight beat31 is last. The bridge issues nine native reads per tile through two source requests and stages the same36 words. It never installs a burst in the word portal cache. Descriptor patching now runs in DDR response gaps after consumer release, with incoming words taking write-port priority; publication still waits for the complete fill and patch. Result collection captures C[n] while issuing C[n+1], removing six intermediate wait edges per tile without changing one-edge BRAM latency. See [the1.7 contract](PRX100_DDR_STREAMING.md).

No active staging allocation is overwritten during core ownership. DDR
operations, completion identities, bounds and core ring/transport faults are
checked. A bounded job watchdog fails closed. Protocol/core/DDR faults require
physical reset; malformed configuration/START accesses return SLVERR without
publishing work. A later START after successful completion reinitializes the
core and job state while preserving resident DDR weights/activations.

## Measurement and acceptance

Report complete job cycles from START acceptance through acknowledgment of
the final DDR result, alongside operand staging, core wait and DDR wait
counters. Existing core compute counters are reported separately and retain
their original meaning. Measure host upload, readback, launch/poll/result and
whole-campaign wall time separately. Resident-run FPGA latency is not host
end-to-end latency. Compare every partial and final against the same pinned
fixture and an independent CPU integer reference; retain dequantized/original
FP64 comparisons and rerun the scalar CPU benchmark in the same guest.
The final write acknowledgment means MIG command/data acceptance, rather than
physical DRAM write drain. Subsequent readback establishes visibility. Operand
staging cycles include descriptor writes and DDR-fill waits. Revision1.1
prefetch makes both staging and DDR-wait counters overlap core-wait cycles.
Revision1.2 also performs actual core work during collection outside the
core-wait FSM window. Do not sum these counters, interpret core-wait differences
as standalone core speedup, or reuse revision1.0's disjoint partition.

Before hardware: strict native checks; randomized AXI/DDR backpressure and
fault/reset tests; independent emitted-RTL replay; pinned generic synthesis;
named bounded control/CDC safety and sensitivity gates. Before programming:
exact source/core identities, pinned Vivado/MIG configuration, setup/hold,
clock/CDC constraints and DRC must pass. Retain failed attempts unchanged.
Hardware must show calibration, complete DDR upload/readback, correct
autonomous counters and all pinned Qwen partial/final results across repeats.
Ethernet and full-model runtime integration remain separate work.

## AXI control registers

All offsets are byte addresses. Only aligned full32-bit control writes are
accepted. Read completed counters after DONE for a coherent64-bit snapshot.

| Offset | Meaning |
| --- | --- |
|00,04| Signature50524433, target version00010007 (weight streaming/descriptor overlap); historical00010000..00010006 remain distinguishable |
|08| Flags: bit0 memory healthy,1 busy,2 done,3 fault |
|0C| Error:0 none,2 memory health loss,3 DDR response,4 completion identity,5 core fault,6 watchdog,7 unowned response |
|10| Write1 to START; no other command or readback |
|14,18,1C,20| Weight, activation, partial, sum DDR byte bases |
|24| Tile count1..64, each tile has K16 |
|28,2C| Current tile index, completed tiles |
|30,34| Retired completions, acknowledged partial result words (eight/tile, four/ACK since1.6) |
|38,3C| Total job cycles low/high |
|40,44| DDR wait cycles low/high |
|48,4C| Core publish/execute/drain cycles low/high |
|50,54| Descriptor/operand staging cycles low/high |
|58,5C| Sum of existing core elapsed-compute counters low/high |
|60,64,68| Staged operand words (36/tile), accepted front-end DDR reads (2/tile since1.7;9 lines/tile in1.5/1.6;36 words/tile earlier), accepted job DDR writes (2*tiles+2 full lines since1.6;8*tiles+8 words earlier) |
|6C,70| Core producer and consumer counts |
|74| Sequencer state,0 idle,16 done,17 fault |
|78,7C| Core frequency50000000Hz, tile reduction16 |
|80..9C| Eight accumulated32-bit sum registers, channel0 first |
|A0,A4,A8,AC| Accepted core read requests, write requests, byte reads, word reads; START clears all four |

The full256MiB DDR portal occupies0x10000000..0x1fffffff, separately from these
control offsets. This is a target-specific MMIO contract, not a Device ABI change.
