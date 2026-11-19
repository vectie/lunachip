# PRX100 BF16/FP32 layer throughput profile

This opt-in MoonBit hardware profile targets sixteen independent output-row
lanes and a core clock above the qualified four-lane 25 MHz baseline. The
integer core and existing scalar/four-lane generators must retain their exact
exported identities. Separate FP32 RNE multiplication/addition and each row's
accumulation order remain unchanged; no FMA or reassociation is introduced.

Sixteen lanes consume four existing four-row DDR batch requests per stripe.
The controller/bridge packet formats, four-word response, sixteen-entry host
queues and DDR UI at 100 MHz remain unchanged. Each batch still owns exactly
32 ordered packets and LAST on its last packet. The inactive weight bank
becomes usable only after all four batches arrive. Any response fault, malformed
LAST, reset or unhealthy memory invalidates the operation without resurrection.
Dimensions unsuitable for sixteen rows use the scalar fallback.

The adder captures its aligned sum before normalization/RNE packing. Each row
accumulates one product every two clocks,retaining exact K order rather than
interleaving or reassociating partial sums. Sixteen lanes offset that feedback
latency. Scalar operations capture after the synchronous operand reads,wait for
the three-edge multiplier/two-edge adder,and commit once. The public two-edge
adder receives raw-bit CPU tests and a reset-initialized bounded comparison
against the original adder delayed two edges,with a negative control.

The clock target must be selected from actual routed setup/hold/pulse-width
and strict DRC results. No failing-clock image may be programmed. The current
scalar FP32 accumulator path is about 40 ns; the new profile may calculate
normalization's shift count first and subtract the exponent once in both
adders and multipliers. Its nonlinear microcode may use a one-hot operand
selection network instead of a cascaded multiplexer. The micro-op selectors
are disjoint by mode/index. The nonlinear unit captures operands and metadata,
uses the existing three-edge FP32 multiplier and an equally delayed FP32 sum,
then commits one micro-op every five edges. This cuts selection/multiply paths
while retaining operation order and rounding. A microprogram has at most 23
micro-ops (115 edges in this profile). Existing profiles retain their original
graph and latency. Qualify the new multiplier for arbitrary raw inputs, compare
original/pipelined nonlinear result words exactly, and exercise reset at every
pipeline phase before accepting a routed image.

Qualification requires targeted and complete native MoonBit phase gates,
legacy export identities, exact-production LunaWave/Verilator differential
checks, pinned synthesis, named bounded formal checks and retained negative
counterexamples. The DDR clock ratio used in digital qualification must cover
the selected physical clock rather than assume the old 4:1 ratio. This is a
bounded digital qualification, not an analog CDC or unbounded device proof.

The physical campaign must use the unchanged Qwen3-0.6B layer-0 fixture and
operation-model reference: three-token prefill and cached position-3 decode,
context four, KV capacity eight. Resident timing includes launch, polling,
status/counters, actual final-output readback and CPU checks. Setup/program
switching and full intermediate/KV diagnostic snapshots stay separate and
must be reported. Run a fresh baseline and candidate with the same host
policy and selected supported JTAG rate. Report every result, counter, clock,
source/bit identity, timing failure and performance outcome; retain unique
inputs/logs and keep compiler/CAD caches outside sealed evidence.

Qualified on 2026-10-19: sixteen ordered BF16/FP32 row lanes with MAC interval two,core clock100/3MHz (30ns),DDR UI100MHz and JTAG10MHz. Fresh same-policy four-token resident layer median 1.081552s → 0.978091s (1.1057785011824053×);hardware kernel 0.9261454s → 0.81552675s;cached position3decode 0.371109s → 0.265903s. All422848FP32words/profile across292tensors pass CPU tolerance (maximum absolute error 0.000030517578125) and are bit-exact to the ordered operation model;346cross-profile data files are identical. Integer199source inputs unchanged;1262native tests pass. Routed setup/hold slack+0.050/+0.048ns,zero failing endpoints. Resident samples include launch/poll/counters/final reads/CPU checks;setup,upload,integrity and full diagnostics are separate. One fixed complete transformer layer,not full-model generation.

Measured evidence: [benchmark](../artifacts/prx100-layer-throughput-20261019/benchmark.json).

PRX100 interleaved DDR response banks: fresh matched16-lane100/3MHz resident four-token median 1008053->868122us (1.1611881740124084x);kernel 815527.89->648204.99us. All422848FP32words/profile are CPU-checked and ordered-model bit-exact;1264native tests pass. Integer199inputs and BF16/FP32 core unchanged. Actual stage profiles identify prior scalar/nonlinear regressions that erased68.930ms of matrix savings. See [streaming contract and results](PRX100_QWEN_LAYER_STREAMING.md). One complete layer,not full-model inference.
