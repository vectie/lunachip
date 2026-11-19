# PRX100 descriptor publication pipeline, 2026-10-17

The same real Qwen3-0.6B eight-channel W8A8 block passes on target1.2 with
median FPGA time **1.12750ms**, down from **1.37524ms**: **18.01% lower latency,
1.220x speedup**. The original portable core, bridge, workload and50/100MHz
clocks are unchanged. All20 jobs and both independent CPU/raw-JTAG audits pass.
The volatile image remains programmed, calibrated and quiescent after the final
vector2 K1024 job, with producer=consumer=retired256 and zero fault.

## Change and ownership

The [publication contract](../PRX100_PUBLICATION_PIPELINE.md) replaces the1.1
completion-before-publication barrier with consumer-released ring reuse.
After the next36 operand words are staged and all four current descriptors
have been atomically accepted by the core, the target patches twelve fields
and publishes the next four commands. It stays at most one tile ahead.
Current completion retirement and result collection continue independently.

A/B staging regions alternate as before; C now alternates1024/3072 in the same
4KiB BRAM. A bank is recycled only after its old tile's four ordered
completions and eight acknowledged partial writes. Completion ACK pauses
between groups; younger completions stay with the unchanged core. Store
admission remains constrained by its existing retirement capacity.

The shared synchronous BRAM read port blocks new core requests during a host
result read and waits for an existing tagged response to retire before changing
the read address. The following edge latches C. Core reads can share host
prefetch/descriptor writes; core writes yield to host writes. Only the two
aligned eight-word C windows accept core writes.

## Correctness and measured timing

The fixture is unchanged:
`Qwen/Qwen3-0.6B@c1899de289a04d12100db370d81485cdf75e47ca`, layer0
`model.layers.0.self_attn.q_proj.weight`, output channels0..7, K1024, normalized
embedding IDs42/100/1000, symmetric per-channel/per-vector W8A8. Fixture SHA256
is `409ca5210ca8a10a2799f66590ab0ccee51f1cc501d8dc738a1334a71dfe225e`.
This is one eight-output arithmetic block, not a full projection/layer/model
or token generation.

All20 jobs pass: two K16/K32 prefix smokes, three full vectors with every partial
read back, and fifteen resident repeats (five rounds per vector) checking final
sums and counters. Totals:1155 tiles,4620 ordered fault-free completions,
1560 captured partial words (1536 full-vector plus24 smoke), and160 final sums.
The repeat runs do not reread every partial. All11264 operand bytes are read
back before and after work; twelve guards and both DDR aperture endpoints remain
intact. Independent Int64 CPU arithmetic is rebuilt from original row-major
weights. All12392 raw JTAG transactions, sequence ranges and OKAY responses are
audited. Mac and Linux audit JSON are byte-identical.

| Measurement | Qualified1.1 | Publication1.2 |
| --- | ---: | ---: |
| Full FPGA job median,18 runs |1.37524ms|1.12750ms|
| Full FPGA job minimum/maximum |1.37518/1.37536ms|1.12734/1.12766ms|
| Resident FPGA median,15 repeats |1.37524ms|1.12750ms|
| Existing compute-counter sum/job |0.03072ms|0.03072ms|
| DDR-wait median |0.49690ms|0.49758ms|
| Core-wait activity median |1.22880ms|0.99597ms|
| Staging activity median |0.40865ms|0.40907ms|
| Fresh scalar integer CPU median |182us|176us|
| Resident host launch to observed DONE median |15ms|16ms|

FPGA time is START acceptance through final MIG command/WDF acceptance at the
nominal50MHz clock; subsequent readback proves visibility. The248us reduction
is whole-job latency. Core/staging/DDR counters overlap. In1.2 actual core work
also occurs during collection outside the core-wait window, so its decrease is
not a standalone core-service speedup or a disjoint latency partition.
Logical work remains2304 DDR reads,520 writes,788 descriptor words,256
completions,512 partial writes and1536 compute-counter cycles per full job.

After all CAD processes exited, CPU integer samples were179/176/176/177/176ms
for five1000-iteration batches; FP64 samples179/179/180/179/179ms. These are
scalar MoonBit/Wasm guest loops, not optimized BLAS or an inference runtime.
The complete FPGA job remains6.41 times slower than the scalar integer CPU.
Quantized integer results and original-FP64 error statistics are unchanged.

Host timing remains separate: operand upload18.080s, initial readback19.203s,
all18 full jobs36.991s including transfers/checks, total20-job workload97.394s.
Resident launch-to-observed-DONE spans13..24ms; it excludes result transfer.
Programming and CPU preparation are excluded. No host acceleration is claimed.

## Independent and physical gates

Full `moon info`, `moon fmt`, strict native check and strict native test pass
**1163/1163** at recorded HEAD`d9b89a8ed289f002412e3024ed526bccbaf8c3f5`.
All207 protected production/interface identities remain unchanged.
The twenty target regressions include repeated four-tile jobs, packet/operand
ownership, held tagged BRAM responses, partial-DDR stalls, faults and reset.

The coupled LunaWave/controller replay has8234edges for the same two repeated
four-tile jobs (previously9244),216 prefetch reads,87 simultaneous staging/core
read-write edges, eight publications and125 core requests during collection.
All six ahead publications occur with older work unretired: producer advances
to8/12/16 with consumer4/8/12 and retired1/5/9. Pinned Verilator5.050 agrees
on every observed controller output across all8234edges. This is controller
RTL driven by recorded real-core LunaWave inputs, not a fresh core-RTL cosim.
Pinned Yosys0.68 generic synthesis passes.

The production-bound controller32-edge BMC passes (203s); the health-input
bypass fails `p_memory_gate` at step4 as intended (56s). Both complete runs,
models and counterexample are retained in the77-file formal archive. This
prefix cannot reach completed operand prefill or the new pipeline states;
deep ownership/overlap is finite native/RTL/board evidence, not an unbounded
or full-job formal proof. Exact unchanged bridge evidence is reused from the
sealed cache baseline, including its64-global-step fixed2:1-clock check.

Vivado2025.2 build6299465, pinned executable/MIG geometry and default
single-thread hierarchy-preserving synthesis produce the actual image:

| Attempt | Setup | Hold | Failing hold endpoints | Result |
| --- | ---: | ---: | ---: | --- |
| Initial route |+0.958ns|−0.146ns|30|exit1, no bitstream|
| Hold repair a1 |+0.958ns|−0.250ns|1|exit1, no bitstream|
| Hold repair a2 |+0.958ns|+0.019ns|0|exit0, bitstream|

Final resources:19854LUTs,14347FFs,4.5BRAM,11DSP; compared with1.1 this is
+37LUTs/−23FFs with identical BRAM/DSP use. Setup/hold have zero failing
endpoints and DRC has zero errors/critical warnings. CDC retains exactly the
reviewed, unsuppressed vendor MIG IDELAY asynchronous-reset advisory; its
15-stage async-assert/synchronous-release RTL is checked. Both50/100MHz clock
interaction rows are Clean and fully timed. No new waiver or false path exists.
All three actual vendor attempts are retained.

CPU_TAG`ME10E06D1010A` programmed only volatile configuration on
`xc7a100tfgg676-2`; DONE=1/CRC_ERROR=0 and target version00010002 are recorded.
The own temporary hardware server is closed. The first offline corruption
audit correctly rejected the bad word, then its wrapper failed while recording
its own source from a stale filename. That failed recording attempt is sealed
separately (15 files). Fresha2 corrects only the recording path and again
rejects consistently mutated raw/JSON/partial data against the CPU. No hardware
was accessed by either negative audit.

## Identity and retention

| Artifact | SHA256 |
| --- | --- |
| Original core IR |`37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8`|
| Original normalized core RTL |`045722cdac03bb3cff358e193e2bbaa9648576e4f6710cb4c30d30467027c744`|
| New controller IR |`0f0dcab06d68b0c78fabc706a5d94d15836fdf1ee0d5badc2618a74567595b8b`|
| New controller RTL |`dd405b043240c4484020f5993bc03f544b7103c561d07f26db94d6627c7cc9fe`|
| Unchanged bridge RTL |`c6a9ec4449308d54f67ab745ad6f6e80c2c807060c037f5c5260b8dac07a6dd1`|
| Programmed bitstream |`e4bc391a3333439397ad6268b5ea64980988a10f9fb959183393d32b149e5be5`|
| Mac/Linux audit JSON |`825c8e0efd19850aefd6fff95013611d98ae1d77e3f73d060260714f28cd04cf`|

All18 functional export files reexport deterministically and match physical
inputs byte-for-byte, without metadata extras. The full archive is
[`artifacts/prx100-publication-20261017`](../../artifacts/prx100-publication-20261017/SEAL),
with the unchanged board-profile and new target/validation/CLI sources,
qualified IR/RTL, replay, tools, raw board/CPU evidence, failed attempts and
source/tool identities. The226-file guest subset has seal
`ea387e56b7a1026ebe2cd966cea4162e9228f0de5afd1124770b54b80ca12637`.
The formal subset seal is
`7f65bc11a10abbdabe5cab313ff64c6d4fd8b64aaed36e2db621c9aa017021cb`.

Compiler, Verilator, vendor-library and .Xil caches and DCPs stay outside sealed
archives. Four owned formal volumes were fully recopied and byte-compared
before deletion; the eight protected volumes are unchanged. Exact recovery
paths are in the [cleanup map](prx100-publication-transport-cleanup-20261017.json).
Prior sealed archives remain immutable. Full transport verification is recorded
in the adjacent`artifacts/prx100-publication-20261017.transport.json`.

Host project STATUS now has SHA256
`09876e2d5594c72fb9380b1324c14fcea02539372afbc57d38cf80540dfd99b3`;
its prior configuration/receipts and recovery images remain available. Host OS,
VM configuration and networking are unchanged. Bulk host transport, the core's
serialized byte-memory path and larger/model-level execution remain work;
full Phase7 is still open.
