# PRX100 FP32 feedback and weight delivery experiment

The qualified packed-stripe prefetch image is the baseline. Its sixteen
ordered FP32 accumulators accept one product per two core edges. The first
candidate separates close cancellation from far FP32 addition so an ordered
sum may complete within one core period. It must retain round-to-nearest-even,
gradual underflow, signed zeros, infinities and canonical quiet NaNs. No
reassociation, partial sums, FMA or precision reduction is authorized by this
experimental contract. The integer core and all existing generators remain
unchanged; new behavior uses an explicit opt-in profile.

Weight delivery must keep pace with faster feedback. Measure the new core
first, then widen or restructure the target path only when its measured supply
rate limits useful issue. Memory mapping must fit the existing Artix-7 and its
135 block RAM tiles; no failing image may be programmed. Preserve explicit
CDC reservations, ordered packets, bounds, reset, health and fault behavior.

The matched delivery candidate groups two 128-bit native lines into one
256-bit response, supplying sixteen BF16 weights per core edge. The sixteen-row
request still owns all 128 native lines. Publication waits for both constituent
lines; the two CDC banks each reserve all eight data FIFOs together. Core
weight storage uses eight independent 32-bit banks per row instead of four.
The existing distributed-memory lowering handles the resulting 256 shallow
weight banks; program and scratch storage remain block RAM. Logical byte
counters, packed weight order, host register ABI and external pins are unchanged.
The arithmetic-only profile remains available to isolate weight-delivery gains.

The first full synthesis exceeded the LUT budget. Its bridge used 30,001 LUTs:
eight independent selectors each covered the entire 512-word return buffer.
The revised delivery path uses the packet's eight-word alignment to select
eight fixed word banks with one shared packet index. It retains the original
scalar selector, all buffer registers and reservations. A new formal assertion
checks packet alignment alongside availability and every existing property.
No precision, memory capacity or request concurrency is reduced.

The positive ownership proof exposed a separate error-path defect in the first
wide-delivery implementation. A rejected wide read still produced one fault
packet per native line, while the source consumed each packet as two lines.
Surplus packets could be mistaken for a following write's completion. The
corrected serial fault path advances by two lines for an eight-word packet and
ends at the final pair. Single-stripe and batched rejection followed immediately
by two valid line writes are required native and actual RTL regression sequences.
The failing routed image was not programmed. Unchanged core/controller proofs
may be reused within this task only after every RTL, harness, bound and witness
input byte matches; all corrected bridge properties must be checked afresh.

Before board execution, require targeted arithmetic and matrix tests, strict
native phase gates, actual RTL differential replay, pinned digital synthesis,
named bounded formal checks and negative controls, and strict routed timing,
DRC, clock and bus-skew checks. Existing exported profiles must remain exact.
Preserve unique inputs, every failed attempt and raw evidence; reuse working
caches outside sealed archives. Use the pinned Linux formatter and compiler.

Compare the same complete Qwen3-0.6B layer-0/context-four and cached position-3
decode against the original CPU and ordered operation-model references. Use
fresh baseline and candidate samples with equal host policy. Resident
end-to-end latency includes launch, polling, counters, final readback, file
writes and CPU checks. Uploads, program switching and full diagnostics remain
separately measured. Retain every sample, including outliers and losing runs.
Report actual results without extrapolating to full-model inference.

The completed physical result and every sample are recorded in
[evidence/prx100-layer-feedback-20261022.md](evidence/prx100-layer-feedback-20261022.md).
