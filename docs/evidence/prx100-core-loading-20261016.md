# PRX100 target loading pipeline — 2026-10-16

The same real Qwen3-0.6B W8A8 block passes20 physical jobs after target-only
operand staging and control changes. Full FPGA latency falls from median
**1.76730 to1.37524ms:22.184% lower,1.2851x faster**. All1560 captured partial
words and160 final sums match the independent CPU reference. Portable core
and DDR bridge IR/RTL remain byte-identical, at the same50/100MHz clocks.

The new volatile image remains on PRX100-D, calibrated and quiescent in DONE
after the final vector2/K1024 job. Producer=consumer=retired256; no fault.
The campaign's temporary hardware server is closed. No flash was programmed.

## Scope and target change

The workload is the original pinned
`Qwen/Qwen3-0.6B@c1899de289a04d12100db370d81485cdf75e47ca`, layer0
`self_attn.q_proj.weight`, output channels0..7, K1024, on normalized embedding
token IDs42,100,1000. Per-channel W8 and per-vector A8 scales, host
dequantization and FP64 comparisons are unchanged. Fixture SHA256 is
`409ca5210ca8a10a2799f66590ab0ccee51f1cc501d8dc738a1334a71dfe225e`.
This remains one eight-output arithmetic block, not a full layer/model or
generated-token demonstration.

[Target1.1](../PRX100_LOADING_PIPELINE.md) uses the unused staging region:
A256/2304 and B512/2560 alternate; descriptors remain0..127 and C1024..1055.
The next36 operand words prefetch while the current core tile runs. BRAM can
read current operands and write inactive operands on the same edge. Core
writes yield to prefetch writes; held tagged responses remain stable.
All four ordered completions, successful prefetch and quiescence precede
descriptor reuse. Later tiles update ID/base/slot fields, twelve words.
Partial DDR acknowledgments advance the channel directly, eliminating512
separate advance edges per full job.

The portable byte-memory arbiter still consumes its existing per-request
schedule. Its measured service cost remains1.22880ms. The gain comes mainly
from hiding staging under that service interval, plus a small control saving;
it does not establish faster core arithmetic or a wider core memory port.

## Physical performance

| Measurement | Previous cache target | Loading pipeline |
|---|---:|---:|
|Complete FPGA job,18 samples, median|1.76730ms|1.37524ms|
|Complete FPGA min..max|1.76696..1.76758ms|1.37518..1.37536ms|
|Resident FPGA job,15 samples, median|1.76722ms|1.37524ms|
|DDR-wait counter, median|0.49702ms|0.49690ms|
|Core publication/service/drain counter|1.22880ms|1.22880ms|
|Descriptor/operand staging counter, median|0.40352ms|0.40865ms|
|Existing compute counter, full job|30.72us|30.72us|
|Scalar CPU INT32,5x1000 iterations, median|183us|182us|
|Scalar CPU FP64, median|179us|179us|
|Resident JTAG launch through observed DONE, median|15ms|15ms|

Target register version is now00010001. DDR-wait and operand-staging counters
overlap core-wait in this revision; adding them would misstate latency.
Core-wait also includes a late-prefetch join if DDR finishes last. All18
measured full jobs have exactly61440 core-wait cycles, so that join does not
extend these measurements.

The exact state schedule gives1814 nonoverlapping control cycles:
788 descriptor writes +1024 C-read/latch edges +2 reset/config edges.
The previous image had2074:536 descriptors +1536 result/channel edges +2.
Eliminating512 advance states offsets252 extra base-field writes, saving
260cycles or5.20us. From total/DDR/core counters and this schedule, inferred
DDR/core overlap is median0.38674ms, range0.38614..0.38740ms. Initial operand
fill outside the core interval is median6.14us. These are schedule-derived
intersections, not dedicated hardware overlap counters. All18 raw full-job
counter profiles were checked independently.

Full-job logical traffic is unchanged:2304 reads/staged words,520 writes,
64 completed tiles,256 retired completions and512 partial writes. Native read
commands remain schedule-derived576, with1728 word-cache hits; no new native
command counter is claimed. Useful logical traffic11296B/job divided by total
latency is8.214MB/s; this is not raw DDR bandwidth.

The refreshed scalar reference uses MoonBit loops in moonrun/Wasm on the
Ubuntu22.04 KVM guest,8 vCPUs exposing an Intel i7-13700. It is not optimized
BLAS or an inference-runtime benchmark. Integer batches take187,182,182,182,
183ms per1000 projections; FP64 batches179,180,179,179,178ms. CAD processes
had exited before timing. The complete FPGA interval remains7.56x slower
than the182us scalar integer reference.

JTAG stays at1MHz. Uploading11264B takes16.826s and readback19.719s. The
20-job diagnostic workload takes96.073s, excluding programming and CPU fixture
preparation; eighteen full-job campaign time is35.409s. Launch/observation
range is11..20ms, median15ms. These timings remain dominated by host/JTAG
transactions; no host acceleration claim follows from the FPGA improvement.

## Correctness and qualification

The identical campaign contains K16/K32 smokes, three distinct full K1024
vectors with all512 partials each, and15 resident full repeats. It checks
1560 partial words (1536 real +24 smoke) and160 final words. Across20 jobs,
1155 tiles and4620 ordered fault-free completions retire. Every full job has
the expected counters above and healthy+DONE flags with zero error.
Operands are verified before and after work; all11264 bytes, twelve guard
words and both DDR aperture endpoints remain intact.

An independent auditor rebuilds packed operands and Int64 dot products from
the original row-major fixture, checking all12392 raw OKAY JTAG transactions,
their JSON records, job ranges, counters, partials and sums. It passes in the
guest and independently on the Mac with byte-identical reports. A consistent
offline one-bit partial corruption in raw RPC/transaction/partial records
fails the independent CPU check; no hardware is changed by that sensitivity
test. Dequantized/original-FP64 errors are identical to the prior campaign.

Native gates pass `moon info`, `moon fmt`, strict native check and **1146/1146
tests** at checkpoint`adb9831` plus the frozen target changes. Protected207
production/interface file hashes remain unchanged. Eighteen target tests
include both operand-region parities, repeated START, prefetch stalled after
core completion, simultaneous nonaliasing BRAM access, held byte response,
ownership/backpressure, faults and reset. Pinned Verilator agrees on9244
controller replay cycles:two repeated four-tile jobs,216 prefetch reads and75
simultaneous BRAM read/write edges. Pinned Yosys synthesis passes.

The actual32-edge controller BMC passes; the intentional memory-health bypass
fails `p_memory_gate` at step4 with complete traces. This is prefix safety:
the bound cannot reach completed36-word fill/prefetch states. Deep pipeline
behavior is finite native/RTL/board evidence, not a full-job or unbounded
formal proof. Unchanged bridge evidence is reused by exact IR/RTL comparison
against the sealed previous qualification, including its64-step clocked
prefix and calibration-loss sensitivity. Phase6/full Phase7 remain open.

## Vivado and identities

Vivado2025.2 build6299465, part`xc7a100tfgg676-2`, keeps50MHz core/sequencer,
100MHz MIG UI and800MT/s DDR. Synthesis uses `-flatten_hierarchy none` and
one tool thread. Both failed timing attempts are retained and withheld from
programming:

| Attempt | Setup | Hold | Failing hold endpoints |
|---|---:|---:|---:|
|Initial route|+0.371ns|−0.096ns|24|
|First hold repair/Explore|+0.488ns|−0.112ns|1|
|Second hold repair/Explore|+0.488ns|+0.057ns|0|

Final TNS/THS are zero. Resources are19817 LUTs,14370 registers,4.5 BRAM tiles,
11 DSPs:22 LUTs and two registers above the previous image, with unchanged
BRAM/DSP counts. DRC has zero errors/critical warnings. CDC retains12 CDC-3
and three CDC-9 information rows plus the same single unsuppressed CDC-10
critical vendor IDELAY-reset advisory. Its exact15-stage async-assert/sync-
release vendor reset and both Clean, fully timed50/100MHz interaction rows
are reviewed. No clock-group false paths or CDC waivers were added. This is
not analog CDC/MTBF evidence.

CPU_TAG cable is`ME10E06D1010A`, FPGA ID13631093. Programming verifies DONE=1,
CRC_ERROR=0 and target register version00010001.

| Artifact | SHA256 |
|---|---|
|Portable core IR|37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8|
|Portable normalized RTL|045722cdac03bb3cff358e193e2bbaa9648576e4f6710cb4c30d30467027c744|
|Controller RTL|35899eeccf65ff06bb07dec71302e74c4eb8ab3222647ba01ba1c318a40798d6|
|Unchanged bridge RTL|c6a9ec4449308d54f67ab745ad6f6e80c2c807060c037f5c5260b8dac07a6dd1|
|Programmed bitstream|d82e3192670433f0dea590e5cd6690ef667c3bd8f01c4a6d7dcccc1111d5cb38|

Qualified guest route:
`/work/builds/prx100-projection-route-20261016-loading-a2`.
Board/fixture roots end`20261016-loading-a1`. Every functional qualified
input file matches the local export byte-for-byte. The original input tar
also carried19 identical AppleDouble metadata records; those literal files
are retained and verified separately, not treated as synthesis sources.

## Retention

Full local evidence is under`artifacts/prx100-core-loading-20261016`, with
source snapshots, canonical IR/RTL, native logs, pinned tool outputs, both
formal runs and counterexamples, all current vendor attempts, programmed bit,
raw board/CPU records, independent audits, comparison and automation. Compiler,
Verilator, .Xil, DCP and regenerable vendor-library caches are excluded.
The previous sealed archives are referenced by identity and left unchanged.

The guest subset is
`/work/builds/prx100-projection-loading-evidence-20261016-a1`,261 inventory
files, seal`24d4dd075e2c88202f50529ceb1463816cdf839281683532ffbe55110b4ce20b`.
Its tar SHA256 is
`2e823e99d18597d07b6b2ff833daac550e69976cd9afd8392a4477299419751a`,
verified on guest, Linux host and Mac. Default Mac tar extraction merges some
literal AppleDouble files into attributes; those incomplete copies were
rejected by the unchanged checksum gate and left untouched. Direct recursive
SCP preserves the complete sealed tree, whose inventory then passes on Mac.
All eighteen functional inputs and all nineteen metadata records are checked.

Two actual formal runs retain77 inventory files, seal
`e9ba86fa688ce2a8eebbb0b5039b7b10740d78c71bbc1c4082f6b3ac1671f0ca`.
Only four owned formal volumes were removed, after sealed-inventory checks
and complete recopy/directory/byte comparisons. The exact eight protected
volume inventory is unchanged; the [cleanup map](prx100-loading-transport-cleanup-20261016.json)
records recovery paths. The current project STATUS preserves all earlier
receipts and the previous FPGA configuration.
