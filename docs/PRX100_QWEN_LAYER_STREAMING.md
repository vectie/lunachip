# PRX100 interleaved DDR responses for the BF16/FP32 Qwen layer

The opt-in `streaming_bridge()` profile changes only the target DDR response
path. The integer core, sixteen-lane BF16/FP32 arithmetic core, controller,
descriptor layout, clocks and JTAG host policy retain their exact identities.
All first-party hardware construction remains MoonBit -> LunaWire canonical
IR -> emitted SystemVerilog -> Vivado -> physical PRX100-D.

The previous four-word response join inserted a reservation bubble after
every packet. The new path alternates two banks, each containing four checked
32-entry asynchronous FIFOs. Each bank retains registered all-ready/all-valid
reservations. An inactive bank reserves its next packet while the other bank
transfers. Source and destination bank selectors advance only on transfers;
they preserve order across ordinary reads/writes, four-row batches and resets.
Logical capacity stays 64 packets. No representative FIFO flag substitutes
for the conjunction, and no wider canonical FIFO primitive is introduced.

Native tests deliberately alternate two/three synchronizer stages across
lanes, checking unequal flag arrival, atomic packet transfers, pointer wrap,
held responses, fault drainage and coordinated reset. Production retains two
stages throughout. Consecutive source-edge packets are checked after filling.
The exact emitted physical bridge agrees with LunaWave for over110,000
atomic events at3:1 clocks, without output masking. Pinned Yosys checks all
three modules and the actual digital composition, with zero combinational
SCCs. BMC128 retains the existing bridge properties and adds bank-local atomic
transfer/pointer equality and reservation safety for all eight FIFOs. The
calibration negative has a complete failing witness. These are bounded
digital checks; no analog CDC or unbounded full-device proof is claimed.

## Why the previous lane/clock change gained only9.6%

Actual108-section profiles reconstruct the same complete four-token program
and match every raw counter and all88stage/KV tensors. In the four-lane25MHz
image, matrices used793.444ms and the remaining work132.841ms. In the prior
sixteen-lane100/3MHz image, matrices used613.866ms but remaining work rose to
201.770ms. SiLU's block rose37.399->90.349ms because its deeper nonlinear
pipeline commits micro-ops every five edges. About68.930ms of scalar overhead
erased part of179.578ms of matrix savings. The old response join still left
matrices at75.3%of the new kernel. Host launch/poll/readback further limited
resident gains. Section counters include inserted HALT/fetch overhead of
about0.1ms; independent unsplit campaigns measure full resident latency.

## Reproduction

Build `cmd/prx100_layer` for native, then use `export-streaming NEW_INPUTS`.
`bridge-replay-streaming`, `bridge-formal-streaming` and
`bridge-formal-negative-streaming` emit the changed bridge evidence. Existing
throughput/legacy exports remain byte-identical. The standard pinned
`scripts/prx100-layer-build.mbtx` accepts the recorded input inventory and
33333333clock selection. Require nonnegative routed setup/hold/pulse-width,
zero failing endpoints, strict DRC and source/bit/debug-clock identity before
programming. Use the unchanged resident board runner and independent audit,
then `scripts/prx100-layer-streaming-audit.mbtx` for matched comparison.

The workload remains Qwen3-0.6B layer0, three-token prefill followed by cached
position3decode, context4 and KV capacity8. Five complete-layer and five cached
decode samples per profile include launch, polling, counters, actual final
readback and CPU checks. Upload, full intermediate/KV diagnostics and program
switching stay outside resident samples and are retained separately. The CPU
release timing is compute-only. This is one complete fixed transformer layer;
full-model token generation remains open.

## Physical measurement,2026-10-19

|Metric (microseconds)|Previous16-lane bridge|Interleaved bridge|
|---|---:|---:|
|Four-token resident median|1008053|868122|
|Four-token hardware kernel median|815527.89|648204.99|
|Cached position3decode resident median|268882|269962|

Resident speedup 1.1611881740124084x. All422,848FP32words/profile across292tensors pass CPU tolerance (maximum absolute error 0.000030517578125) and are bit-exact to the ordered operation model;346cross-profile data files match. All1,264native tests pass;199integer source inputs and the BF16/FP32 core retain exact identities. Routed setup/hold slack +0.101/+0.045ns;zero failing endpoints. Qualified bit SHA256 `72d7287b1077a4ba9b65e5eee0137bc2dc5b33e4b03dc166330b0a809cb6183d`. Flash and host OS unchanged.

Evidence: [benchmark](../artifacts/prx100-layer-bottleneck-20261019/benchmark.json).

The subsequent [host completion polling change](PRX100_QWEN_LAYER_POLLING.md) retains this exact qualified bitstream and lowers paired resident layer/cached-decode latency by10.5%/20.6%, with hardware kernel times unchanged.
