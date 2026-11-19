# PRX100 DDR/staging optimization, 2026-10-16

The optimized image passes20 physical jobs and an independent CPU/raw-JTAG
audit. Median full-block FPGA latency falls from2.36871 to**1.76730ms**:
**25.39% lower latency,1.3403x speedup**. The comparison uses the same pinned
Qwen3-0.6B layer0 q_proj channels0..7, K1024, three normalized embeddings and
W8A8 integer arithmetic. No full model or token generation is claimed.

## Change and comparison boundary

The target bridge retains one16-byte read line in the50MHz source domain.
A native read supplies all four words, serialized as four34-bit FIFO flits;
three subsequent word reads can complete locally. Writes retain their original
native masked-word acceptance acknowledgment and invalidate the read cache.
Health loss, errors and coordinated physical reset also invalidate it.
Only one source word transaction is owned, and held responses remain stable.
The existing checked FIFO payload limit stays unchanged.

The first tile of each START writes the complete descriptor image. Later tiles
write only four IDs and four slot fields, reducing descriptor staging writes
from2048 to536 for64 tiles. Core writes are checked against the eight-word C
aperture, preserving the descriptor and operand image. Quiescent ownership,
operand packing, logical word counters, clocks and workload remain unchanged.

The portable-core canonical IR and normalized RTL remain exactly
`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8` and
`045722cdac03bb3cff358e193e2bbaa9648576e4f6710cb4c30d30467027c744`.
Three observation-only source/interface files changed in independent commit
ef1dce5 since the earlier campaign; this task edits none of them. A fresh
207-file source guard protects the optimization campaign, and the physical
core identity remains equal to the original board image.

The prior [sealed campaign](prx100-ddr-projection-20261016.md) is immutable.
Its18 full jobs have complete FPGA latency min2.36706ms, median2.36871ms,
max2.36940ms. Median DDR wait is1.06819ms; core publish/execute/drain is
1.22880ms; descriptor/operand staging is1.01549ms and overlaps DDR wait.
The same guest's scalar integer CPU reference took median177us per projection.
The optimized comparison must retain START through final native write acceptance
as the FPGA interval and report host upload/readback/checking separately.

## Gates and physical measurement

The final boundary passes `moon info`, `moon fmt`, strict native checking and
**1137/1137** native tests, including16 target tests. They cover cache lanes,
write invalidation, held responses/source ownership, a calibration-loss pulse
entirely between slow edges, reset during a partial four-flit line fill,
descriptor reuse/reinitialization, protected staging writes and signed jobs.
An early native draft rejected an aggregate exceeding the checked64-bit FIFO
payload limit; the final design uses the existing34-bit response FIFO instead.

Pinned Verilator5.050 agrees with LunaWave over5559 controller edges and411
atomic bridge events. Controller replay uses the real unchanged core; the
bridge uses an independent masked128-bit DDR model. Pinned Yosys0.68 passes
both components. The final controller RTL SHA256 is
`603c26c203003c6a6f300851ed7e8645325f899589b606aa21a586e675eed409`;
bridge RTL is
`c6a9ec4449308d54f67ab745ad6f6e80c2c807060c037f5c5260b8dac07a6dd1`.

Controller safety passes32 edges with only initial reset assumed and free
core/AXI/DDR inputs. Bridge safety passes64 global steps with the retained2:1
clock schedule and coordinated boot reset. The controller health-bypass control
fails `p_memory_gate` at step4; the final bridge calibration bypass fails the
new `p_calibration_loss_sticky` assertion at global step13. Full traces are
retained. These are bounded prefix checks, not unbounded/full-job/analog proofs.

The intermediate bridge also passed its original64-step safety task and
calibration-bypass sensitivity control. Review then identified that calibration
loss while the native FSM was idle needed sticky poisoning to prevent a short
pulse from escaping cache invalidation. The first vendor build was intentionally
stopped after checking its exact process group and working directories; it was
never programmed. The corrected bridge adds a calibrated-once latch and the
new native/RTL/formal checks above. Controller, core, clocks and MIG stay equal.

All six actual formal runs are sealed in `formal` (229 inventoried files,
seal `9227caaf42ccccb68c6e4bfd8f6a5bc4b2c81ac72b03ec471b6244ac0f961bc0`).
The twelve owned transport volumes were re-copied and fully byte-compared before
removal; the exact recovery paths are in
[the cleanup map](prx100-optimization-transport-cleanup-20261016.json).
The original eight protected volumes remain unchanged. Two superseded native
boundary runs were stopped and retained; only the final1137-test run is claimed.

The corrected vendor build completes synthesis; implementation peak memory
is4809.6MB as reported by Vivado.
Its first route has setup+0.775ns and hold−0.134ns across31 failing endpoints,
so the bitstream gate refuses it. The worst hold path is the response FIFO's
100→50MHz write-gray pointer entering its first synchronizer stage. A separate
post-route hold repair inserts16 buffers on14 nets, followed by Explore routing.
Final setup is**+0.901ns**, hold**+0.036ns**, with zero failing endpoints/TNS/THS.
The original source/checkpoint identity and clock constraints are preserved.

The qualified target uses19795 LUTs,14368 registers,4.5 BRAM tiles and11 DSPs.
Core/staging remain50MHz, MIG UI100MHz. DRC has zero errors/critical violations.
CDC retains twelve synchronized-bit info rows, three synchronized-reset info
rows and one unsuppressed vendor MIG IDELAY-reset advisory. The retained review
checks its generated15-stage reset synchronizer and both Clean, fully timed
50/100MHz interaction rows. No new CDC waiver or clock-group exception is added.

The programmed volatile bitstream SHA256 is
`0446d3478d0ed38e9a37b61db7ffc8af1755c7b094e4a6ff908935e6e75b5fde`.
CPU_TAG serial is ME10E06D1010A, FPGA ID13631093, JTAG1MHz. The final board
remains calibrated and quiescent after vector2: DONE, zero fault,
producer=consumer=retired256. The temporary hardware server is closed.

## Physical results and measured improvement

The same pinned fixture
`409ca5210ca8a10a2799f66590ab0ccee51f1cc501d8dc738a1334a71dfe225e`
comes from Qwen/Qwen3-0.6B revision
`c1899de289a04d12100db370d81485cdf75e47ca`, layer0 q_proj channels0..7,
with normalized embeddings for token IDs42,100,1000. All20 jobs pass:
two K16/K32 smokes, three full K1024 projections with complete partial readback,
and15 resident full repeats. Independent Int64 dots from original row-major
codes verify1560 partial words and160 final sums. All12392 raw JTAG transactions,
11264 operand bytes before/after jobs,12 guards and both DDR endpoints pass.
All1155 tiles retire4620 ordered fault-free completions. Every full job still
reports2304 logical reads/staged words,520 writes and1536 compute cycles.

The independent audit rejects a consistently corrupted partial across the raw
RPC line, transaction JSON and partial JSON at the CPU DDR comparison. The Mac
replay produces a byte-identical audit to the guest. Final integer outputs and
original/dequantized FP64 errors are identical to the baseline fixture.

| Measurement | Baseline median | Optimized median | Optimized min..max |
| --- | ---: | ---: | ---: |
| Complete FPGA job,18 samples |2.36871ms|**1.76730ms**|1.76696..1.76758ms|
| Resident FPGA job,15 samples |2.36876ms|1.76722ms|1.76696..1.76758ms|
| DDR wait,18 samples |1.06819ms|0.49702ms|0.49668..0.49730ms|
| Core publish/execute/drain,18 samples |1.22880ms|1.22880ms|constant|
| Descriptor/operand staging,18 samples |1.01549ms|0.40352ms|0.40310..0.40376ms|
| Resident host launch through observed DONE,15 samples |14ms|15ms|12..20ms|
| Scalar CPU integer,5 batches of1000 |177us|183us|182..183us|
| Scalar CPU FP64,5 batches of1000 |179us|179us|178..179us|

DDR wait falls53.47%. The nonoverlapping partition `total-DDRwait-corewait`
is independently checked in all18 full jobs in both campaigns:3586 cycles
before,2074 after. The1512-cycle difference is exactly the descriptor staging
saving,**30.24us** at50MHz. Together with571.17us less median DDR wait, this
explains the complete601.41us median job reduction. Staging overlaps DDR wait;
its611.97us reduction must not be added to these nonoverlapping savings.

For this fixed sequential word schedule, native read commands are derived to
fall from2304 to576, with1728 local cache hits. This is a schedule-derived
count, verified at line level in native/RTL tests, not a new measured hardware
counter. Logical counters retain their original word meanings. Useful traffic
per full job stays9216 read bytes plus2080 write bytes; dividing by complete job
latency gives6.3917MB/s, not standalone DDR bus bandwidth.

The CPU comparison uses the same scalar MoonBit/Wasm loops in the same8-vCPU
Ubuntu22.04 KVM guest on an i7-13700, after CAD processes exit. Five integer
batch times are183,182,182,183,183ms; FP64 times179,179,179,178,178ms. This is
not an optimized BLAS/inference-runtime comparison. The optimized FPGA remains
**9.66 times slower** than the fresh scalar integer CPU reference. Existing
core service/control time now accounts for about69.5% of complete FPGA latency;
the portable core and its byte-wide transport remain unchanged.

Host diagnostics do not improve: upload11264 bytes takes17.988s, initial
readback20.226s, first-three verified campaign23.512s, all18 full jobs/checks
35.684s and the complete20-job workload98.235s, versus97.175s before. Summed
RPC time is87.550s. These intervals include the same per-word JTAG calls,
sentinels, checking and post-job readback; programming/CPU preparation are
excluded. Bulk host transport remains separate work.

## Reproduction and retained evidence

Export with `moon run --target native cmd/prx100_projection -- export NEW_ROOT`.
Pinned digital runners and the source-bound qualification are retained under
`digital`; all six actual formal attempts are under `formal`. In the guest,
the unchanged build/route/fixture/audit entry points remain those of the
[baseline campaign](prx100-ddr-projection-20261016.md). The board runner now
also accepts an explicit qualification JSON as its final optional argument:

```text
moon run /work/prx100-projection-board.mbtx -- run QUALIFIED_BUILD FIXTURE NEW_BOARD_ROOT QUALIFICATION_JSON
```

This run uses inputs/build/route/fixture/board roots ending in20261016-opt-a2.
Qualification is `/work/builds/prx100-projection-qualification-20261016-opt-a2.json`.
All scripts and actual inputs are retained; fresh runs require fresh paths.
Host OS, network and VM settings stay unchanged. The machine STATUS preserves
the baseline receipts/configuration alongside the optimized audit/comparison.

Guest evidence is sealed at
`/work/builds/prx100-projection-optimization-evidence-20261016-a2`,205 files,
seal `29400351c61e8848c9bfdc11f2795865eff92a82d113c8a0b93b19d9d4a3a36e`.
Its tar SHA256 is
`fa385878a9f95704d56114d960188ee8509167d3ea407ffa36daac9890816931`,
verified across guest, Linux host and Mac, then against every extracted file.
The first packaging attempt correctly refused a `.Xil` cache. Its driver/error
logs are retained, and its unsealed staging directory remains on the guest;
the corrected selection copies flat board evidence without weakening the cache
guard. Compiler/Verilator caches, DCPs and generated vendor libraries stay
outside evidence. The complete local archive is
`artifacts/prx100-ddr-optimization-20261016`, also retained on the Linux host.

This measured target experiment does not close the broader Phase6 or Phase7
gates and does not establish full-model inference, token throughput or power.
