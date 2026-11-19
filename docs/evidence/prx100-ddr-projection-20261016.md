# PRX100 DDR-to-core Qwen projection, 2026-10-16

The target-specific MoonBit controller connects the qualified DDR3 interface
to the unchanged Array8/K16 core through a4KiB synchronous staging memory.
It sequences LoadA, LoadB, MatMul and StoreC descriptors, drains completions,
stores every partial in DDR and accumulates eight INT32 final sums. The host
uploads operands, starts a complete job and checks its results; it no longer
publishes each individual K16 tile. The normative register, packing, ownership,
reset and measurement rules are in the
[target contract](../PRX100_DDR_CORE_CONTRACT.md).

The physical campaign passes **20/20 jobs**, including18 full-K1024 eight-channel blocks,
with1536 real-projection partials,24 smoke partials and160 final sums checked.
An independent original-fixture/raw-transaction audit passes all12392 accesses.
Median complete FPGA job latency is **2.36871ms**, versus **177us** for the
same scalar integer CPU reference. This proves autonomous data flow and exact
arithmetic; the current complete FPGA path is13.4 times slower than that CPU
reference. All207 protected production/interface files remain unchanged.

The board remains calibrated and quiescent in the volatile projection image,
after the last token1000 input: DONE, no fault, producer=consumer=retired256.
The temporary hardware server is closed. The earlier UART Array8 and standalone
DDR recovery images remain available. Host OS, network and VM settings are
unchanged.

## Source and digital qualification

All207 protected production/interface identities remain byte-identical to the
pre-task snapshot: portable accelerator, device contract, canonical IR,
simulation, general emission and existing UART target. Core IR SHA256 is
`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`;
normalized core SystemVerilog SHA256 is
`045722cdac03bb3cff358e193e2bbaa9648576e4f6710cb4c30d30467027c744`,
also identical to the previously programmed Array8 design.

The final complete phase boundary passes `moon info`, `moon fmt`,
`moon check --target native --deny-warn` and **1120/1120** strict native tests.
The ten new target tests cover signed/repeated jobs, simultaneous AXI channels,
held grants/responses, portal bounds and ownership, independent MIG command/data
stalls, all word lanes/masks, malformed responses, calibration loss and reset.

Pinned Verilator5.050 replays all5628 controller clock edges and333 atomic
dual-clock bridge events against LunaWave. Pinned Yosys0.68 synthesizes both
new components with passing structural checks. Controller stimulus includes
captured feedback from the unchanged core's simulation; the bridge uses an
independent masked native-DDR model. Observation export is tested to
leave production IR unchanged; formal instrumentation only exposes existing
nodes and is mechanically stripped back to the exact production RTL.

| Actual formal attempt | Result and scope |
| --- | --- |
| Original unlocked arbiter | Request-stability assertion fails at step4; complete counterexample retained |
| Corrected controller,48 edges |300-second timeout; no completed48-edge claim |
| Corrected controller,32 edges | PASS with only initial reset assumed; core, AXI and DDR inputs free |
| Controller health bypass | Named memory-gating assertion fails at step4 |
| Bridge,64 global steps | PASS at fixed2:1 clocks with coincident rising edges and coordinated boot reset |
| Bridge calibration bypass | Named calibration-gating assertion fails at global step19 |

The controller fix locks the DDR owner before acceptance and keeps the grant
and payload stable until its response. A concurrent AXI request can no longer
preempt a blocked request. A dedicated native regression exercises both channel
orders. The timeout and every failed/successful formal attempt remain retained.
These bounded properties do not establish unbounded liveness, full-job formal
correctness or analog CDC behavior; complete jobs have separate native, emitted
RTL and physical gates.

An initial repository-wide boundary encountered old sealed evidence source
packages during package discovery. It was interrupted and retained. The
idempotent `scripts/prx100-evidence-boundary.mbtx` creates a nested module fence
in the unsealed `artifacts` parent, excluding evidence from root source discovery.
No sealed archive was changed; the prior standalone DDR archive's seal and all
364 inventory entries independently reverify. The subsequent complete native
boundary passes without archive rewrite diagnostics.

The six formal attempts are sealed before transport cleanup. Every removed
input/output volume was re-copied and fully directory/byte-compared against the
verified archive; the exact twelve removed volumes and recovery paths are in
[the cleanup map](prx100-projection-transport-cleanup-20261016.json). The eight
protected earlier recovery volumes are untouched.

## Workload and timing scope

The first vendor attempt failed before synthesis because the copied Tcl recipe
still named the earlier top. The second was stopped after the arbiter defect
was identified, preserving its inputs and logs. The third used corrected RTL
but remained CPU-active in synthesis timing optimization after46 minutes and
was explicitly stopped. Its exact process group, including identified Vivado
helpers, was checked against the build directory before termination. The next
attempt reuses the historically successful Array8 `-flatten_hierarchy none`
and default synthesis directive. RTL, clocks, MIG and portable-core identities
remain identical; no OOM or synthesis failure is inferred from that stop.

The hierarchy-preserving build completes synthesis in10m18s, with peak4779MiB.
Its first route passes setup(+0.686ns) but has four hold endpoints failing,
worst−0.106ns, on the fully timed100→50MHz FIFO pointer crossings. The bitstream
gate refuses it. A separate post-route `phys_opt_design -hold_fix` inserts five
delay buffers, followed by `route_design -directive Explore`. This closes setup
at **+0.956ns** and hold at **+0.047ns**, with zero TNS/THS and no failing endpoints.
No clocks, RTL, timing exceptions or original checkpoints are changed.

The final routed target uses19668 LUTs,14051 registers,4.5 BRAM tiles and11 DSPs.
The synthesis report explicitly identifies the projection staging memory as a
block RAM. Core/staging run50MHz; MIG UI is100MHz. DRC has zero error/critical
violations; retained warning reports remain part of the evidence.

CDC reports retain twelve synchronized-bit and three synchronized-reset info
rows, plus one unsuppressed vendor CDC-10 advisory. That advisory is the common
startup/reference-lock reset request entering MIG's IDELAY reset synchronizer.
The generated vendor RTL explicitly uses asynchronous assertion and15-stage
synchronized release. The source hash and exact excerpt are retained in
`qualified-route/cdc-review.txt`. Both50/100MHz clock interaction rows are Clean
and stay timed. No new clock-group false path or CDC waiver is added. This is
a structural/reset review, not an analog MTBF measurement.

Final bitstream SHA256 is
`c20c9fcdeffd1bfdc4b56d2d7b92edb8b6051d088fe7aad9b2f4f3e60f5a2d78`.

The workload reuses Qwen/Qwen3-0.6B revision
`c1899de289a04d12100db370d81485cdf75e47ca`, layer0 `q_proj` channels0..7,
full reduction K1024 and normalized embedding inputs for token IDs42,100,1000.
The original fixture SHA256 is
`409ca5210ca8a10a2799f66590ab0ccee51f1cc501d8dc738a1334a71dfe225e`.
This is an eight-output block from a real model projection; no full layer,
model, attention, KV cache or generated token is implied.

Each full job reads9216 useful DDR bytes and writes2080:8192 weight-code
bytes,1024 activation-code bytes,512 partial words and8 final words. The
serialized word bridge transfers a128-bit native beat for each32-bit word.
The previous streaming BIST rates do not describe this path. The core stays
at50MHz, MIG UI at100MHz and DRAM at800MT/s.

The campaign checks K16/K32 smoke jobs, all1536 real projection partials and24
final sums, then15 resident full projections, for20 total jobs and160 checked
final words. All1155 tiles retire4620 ordered fault-free completions. Each full
job reports64 completed tiles,256 retired descriptors,512 partial writes,
2304 staged/read words,520 DDR writes and1536 existing compute-counter cycles.
Upload/readback and post-job checking cover all11264 operand bytes, plus12
adjacent guard words and both DDR endpoints. Every input and guard is preserved.

The independent MoonBit audit recomputes signed dots using Int64 from the
original row-major codes, independently recomputes original FP64 dots, and binds
results to raw OKAY JTAG transactions, job sequence ranges, counters and recorded
outputs. A sensitivity fixture changes one partial consistently in the raw RPC
line, transaction JSON and partial JSON. The audit rejects it specifically at
the independent CPU DDR comparison; the actual board capture is untouched.
Replaying the audit on the Mac produces a byte-identical report to the Linux
guest. The final strict native check and target automation formatting checks pass.

| Token ID | Exact signed full-K1024 results, channels0..7 |
| --- | --- |
|42|8756,13785,−12344,6958,8277,24542,6348,17217|
|100|33633,20707,−26431,−35708,−30498,38848,26458,−10697|
|1000|26671,31770,27315,−25737,5502,23851,−4307,−3116|

All repeated sums match these values. Host dequantization matches the quantized
CPU reference within1e−9. Maximum absolute error against original FP64 is
0.00281449,0.00424659 and0.00498970 respectively; relative L2 errors are
0.0263487,0.00923302 and0.0169166. These are unchanged quantization errors from
the same fixture.

## Measured performance

| Measurement | Samples | Min | Median | Max |
| --- | ---: | ---: | ---: | ---: |
| Complete FPGA job,ms |18|2.36706|**2.36871**|2.36940|
| Resident FPGA job,ms |15|2.36706|2.36876|2.36940|
| Resident host launch→observed DONE,ms |15|11|14|23|
| Scalar CPU integer,us/projection |5 batches of1000|176|**177**|179|
| Scalar CPU FP64,us/projection |5 batches of1000|178|179|180|

Median DDR-wait time is1.06819ms; core publish/execute/drain is1.22880ms.
Descriptor/operand staging is1.01549ms and overlaps DDR wait. Existing compute
counter time is only0.03072ms per full job. Thus serialized word transfers and
core data loading/control dominate, with arithmetic-counter time about1.3% of
complete job time. Useful DDR traffic divided by complete job latency is about
4.769MB/s; this denominator includes the complete sequencer/core job and is
not a standalone DDR bus-bandwidth measurement.

The JTAG diagnostic client writes11264 bytes in17.327s and reads them back in
20.171s: about650 and558 useful bytes/s respectively. These timings include
one Vivado RPC per word. All operands are uploaded once before any job; weights
and three activation regions remain resident through the repeats.

The first three complete-verification runs take22.661s, including sentinel
writes and reading every partial. The18-full-job campaign takes34.873s,
including those checks and15 resident runs. The entire20-job diagnostic
workload takes97.175s, including upload, initial/post-job complete operand
readbacks, portal bounds, guards, smokes, configuration, counters and results;
programming and CPU preparation are outside that interval. Summed RPC time is
86.458s. These diagnostic timings are not minimal inference latency.

FPGA job counters cover START through final MIG command/data acceptance.
Subsequent readback proves visibility; the counter does not measure physical
write drain. Operand staging includes descriptor writes and DDR-fill waits,
so it overlaps DDR wait. The existing compute counter remains separate.
Host upload, verification, launch/poll/result and complete workload wall time
are reported separately. The CPU comparison uses the same scalar MoonBit/Wasm
loops as the earlier experiment, with five1000-projection samples; it is not
an optimized BLAS or inference-runtime benchmark.

Next target work should improve burst DDR movement and pipeline BRAM/core
loading, and then qualify a bulk host loader such as the planned Ethernet path.
The current word portal remains a diagnostic transport. Larger/batched real
blocks need their own numerical/performance checks; full-model operators,
weight/KV capacity and runtime integration remain separate.

## Reproduction entry points

On the source checkout, export with
`moon run --target native cmd/prx100_projection -- export NEW_ROOT`.
The same command supports `export-replay`, `export-bridge-replay`,
`export-formal controller|bridge` and calibration-bypass negatives. Independent
RTL checks use the pinned Phase3/4 runners and
`scripts/prx100-projection-formal.mbtx`.

In the isolated Ubuntu22.04 guest with the pinned Vivado2025.2 installation:

```text
moon run /work/prx100-projection-build.mbtx -- build INPUTS QUALIFIED_MIG NEW_BUILD
moon run /work/prx100-projection-route.mbtx -- repair ROUTED_BUILD NEW_ROUTE
moon run /work/prx100-projection-fixture.mbtx -- prepare NEW_FIXTURE
moon run /work/prx100-projection-board.mbtx -- run QUALIFIED_BUILD FIXTURE NEW_BOARD_RUN
moon run /work/prx100-projection-audit.mbtx -- audit BOARD_RUN FIXTURE NEW_REPORT_JSON
```

The board runner requires the passing production-RTL-bound digital
qualification JSON, routed timing/DRC, exact clock qualification, bitstream
hash, original core identity and fixture inventory before programming. CPU_TAG
is identified by serial `ME10E06D1010A` and FPGA ID13631093; JTAG runs at1MHz.
Programming is volatile. The earlier Array8 and standalone DDR images remain
available for recovery. The host OS, network and VM configuration are unchanged.

Fresh builds record their own bitstream digest. The archived `c20c9f…` image
identifies the exact file programmed for this campaign. In this run the source
inputs are `/work/builds/prx100-projection-inputs-20261016-a2`, the qualified
implementation is `/work/builds/prx100-projection-route-20261016-a1`, and the
fixture and board roots end in `prx100-projection-fixture-20261016-a1` and
`prx100-projection-board-20261016-a1` respectively.

## Retained evidence

The local archive is `artifacts/prx100-ddr-projection-20261016`. Its `digital`
tree contains source snapshots, native records, replay inputs/results, pinned
generic synthesis and production-bound qualification. The sealed `formal` tree
retains all six attempts and solver models/counterexamples. The `guest` tree
contains all four build attempts, repaired route/clock/CDC/DRC reports, actual
bitstream, fixture/CPU benchmark, raw board capture and positive/negative audits.
Compiler/Verilator caches, DCPs, `.Xil` and regenerable vendor libraries remain
outside the archive.

The guest subset is sealed at `/work/builds/prx100-projection-evidence-20261016`,
with247 inventoried files and seal
`e55f49c77bafb78439ad85964a6efb01626a736b231bd8004b271b3596296df0`.
Its tar SHA256 is
`48d32e901b5415a36f1bd89daa38eba54cfdcbc52a61e0060a597abc224aacf1`,
verified across guest, Linux host and Mac, followed by extracted-file inventory
verification. The full local archive is also retained on the Linux host under
`/data/lunachip-prx100`.

The host `STATUS.json` now records the actual projection image and audit while
preserving all earlier workload receipts. Its old version is retained as
`STATUS-before-ddr-projection-20261016.json`. The local archive includes both
status snapshots and the update driver. Sealed prior DDR evidence remains
unchanged; this continuation references it rather than copying its regression
archive.
