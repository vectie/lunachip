# PRX100 DDR streaming and descriptor staging

Target ABI1.7 retains the exact portable word-read core and its command/memory
contract. Its target-only bridge accepts an aligned128-byte read request with
`request_line=1`, `request_burst=1`, `request_write=0`. The request owns32 ordered
32-bit responses; only response31 has `last=1`. Existing word portal reads,
four-word line reads and four-word line writes retain their protocol.

The request FIFO header uses bit62 for the burst flag, bit61 for line mode,
bit60 for write, bits59:32 for byte address and bits31:0 for data0. Bit63 is
reserved zero. The source captures all request fields at acceptance. The fast
side issues eight consecutive native128-bit reads, one at a time. It captures
each unstallable MIG return in four registers and drains those registers through
the existing credit-gated response FIFO before issuing the next native read.
The address is the captured base plus16 times a three-bit line index. No native
read response can overwrite an undrained line. This removes seven source/DDR
round trips per tile without adding multiple outstanding native reads.

Burst requests require128-byte alignment and read/line mode. Invalid requests
return a fault without a native command. A refused line burst still drains its
32-beat source owner. Calibration loss and malformed native responses poison
the bridge until coordinated reset; later lines drain faults and issue no new
native commands. A burst never installs the ordinary portal cache. Reset
clears both FIFO endpoints and all ownership together, as before.

The sequencer requests one activation line and one eight-line weight stream
per tile: two front-end reads, nine native reads,36 staged words. It checks
`last` at activation beat3 and weight beat31 and refuses publication after a
malformed/faulted prefix. Descriptor patching can begin as soon as the reader
releases the old ring image. Incoming DDR words have priority on the staging
write port; the descriptor index advances only on an actual descriptor write.
Publication requires both complete descriptor patching and complete operands.

Result collection uses its independent synchronous BRAM port. An edge capturing
C[n] also reads C[n+1], so consecutive captures preserve the explicit one-edge
latency. The redundant intermediate wait state is no longer entered. Partial
and final DDR write batching remains two16-byte writes per tile plus two final
writes. Core arithmetic, tagged memory traffic, operand layouts, DDR geometry,
clock frequencies and vendor boundaries remain unchanged.

Qualification requires native signed jobs and stall/fault/reset regressions,
pinned independent RTL replay and synthesis for all three generated modules,
named bounded controller/bridge checks and sensitivity controls, routed timing,
then a fresh1.6/1.7 board comparison using the same pinned Qwen3-0.6B fixture
and independent CPU reference. These checks pass for the measured target1.7 campaign linked below. Neither a full-model inference claim nor an unbounded
device/analog CDC claim follows from this target change.

Physical qualification and the fresh A/B campaign pass; see [the measured evidence](evidence/prx100-stream-20261017.md). Median0.45630→0.41775ms,8.45% lower; all40 jobs match the CPU. The portable core remains exact.
