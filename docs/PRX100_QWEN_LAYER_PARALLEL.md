# PRX100 pipelined four-lane Qwen3 layer

Status: physically validated on2026-10-18. Four-token kernel median improves
15.358207→3.461384 seconds (4.437×); warm diagnostic end-to-end median improves
22.178887→10.043216 seconds (2.208×). All656,960 readback words are bit-identical
to the scalar FPGA and pass the unchanged CPU tolerance. The integer core is
unchanged. All1,235 native tests pass. See the [measured report](evidence/prx100-layer-parallel-20261018.md).

This opt-in variant keeps the complete layer's descriptor ABI, BF16 checkpoint
weights, FP32 activations, separate RNE products and ordered FP32 sums. The
integer core and the previous projection targets are unchanged. The scalar
complete-layer bitstream remains the physical baseline.

`parallel_layer_machine()` selects the new hardware. `cmd/prx100_layer`
provides `export-parallel`, `replay-parallel`, `pipeline-replay` and
`core-formal-parallel`; existing commands retain their scalar selection.

Four independent lanes compute four output rows of a DDR GEMV together. Each
lane has a separate 32-word packed BF16 weight-line BRAM, three registered FP32
multiplier stages and a one-edge ordered FP32 accumulator. One synchronous
scratch activation read is broadcast to all lanes. The multiplier accepts new
operands every edge; accumulator feedback preserves the original row's k-order
without interleaved partial sums or fused arithmetic.

A stripe loads four 128-byte DDR lines, issues 64 products per lane, drains the
read/multiply/accumulate pipeline, and advances to the next k-chunk. At the end
of a four-row group, four results are written through the existing single
scratch write port. The implementation serializes DDR requests and row writes;
it does not claim simultaneous DDR staging and computation.

The fast path requires opcode4, an output count divisible by four, and disjoint
input/output scratch spans. Other shapes and overlapping spans use the scalar
path, preserving in-place semantics. Normal descriptor checks still validate
all dimensions, strides, memory spans, reserved words and DDR alignment before
either path starts. DDR errors and malformed LAST fault the job. Reset clears
pipeline valid state and accumulator/control state; scratch/program memory
retention remains unchanged.

States18/19 issue/fill a weight line;20 issues scratch/weight reads;21 drains
the pipeline;22 advances the stripe;23 serializes output writes. Main-product
counters add four only when four valid products are accumulated. DDR response,
instruction and active-cycle counters retain their original meanings.

The physical memory adapter accepts the scalar design's three memories or the
parallel design's seven memories. Every preserved RAM leaf is generated in
LunaWire with the same synchronous ReadOld/HoldLast semantics. RTL replay
source files must concatenate byte-for-byte to physical CAD's `core.sv`.

Acceptance uses the unchanged four-token workload: three-token causal prefill
and one cached decode, including every intermediate tensor and KV readback.
The CPU tolerance remains `1e-4 + 1e-4*abs(reference)`; the separate operation
model must match every readback byte exactly. Input/program readback, poisoning,
six layer launches, all diagnostics, cold transfers and three warm repetitions
remain enabled. Hardware and warm end-to-end medians are compared with a fresh
physical scalar run; cold latency and host overhead are reported separately.

Digital validation includes signed/cancelling matrices, multiple row groups
and k-chunks, warm starts, scalar tails, overlapping spans, DDR stalls/errors,
malformed LAST and reset during issue. Arithmetic tests cover raw FP32 bit
patterns, subnormals, signed zeros, infinities and canonical NaNs. Formal bounds
and the distinction between bounded checks and full-layer proof are retained.
