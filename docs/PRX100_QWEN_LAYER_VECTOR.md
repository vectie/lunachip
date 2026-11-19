# PRX100 scalar and nonlinear throughput experiment

The baseline is the qualified sixteen-lane ordered FP32 feedback image with
256-bit weight delivery (`prx100-layer-feedback-20261022`). Profile the same
complete layer-0/context-four and cached position-3 workload before selecting
the change. The existing segmented profile assigns about 151.7 ms to external
matrices and about 179 ms to the remaining scalar, nonlinear and transfer work.
The SiLU section contributes about 68.6 ms across four tokens. Refresh those
physical counters before claiming the bottleneck or an improvement.

The first candidate interleaves independent nonlinear elements through one
FP32 arithmetic pipeline. Each element retains the exact reciprocal, rsqrt and
exponential microprogram, FP32 rounding, constants and operation order. No new
approximation, reassociation or precision reduction is permitted. This is an
explicit opt-in hardware profile; existing generators must retain byte-exact
exports. The integer core and its 199 protected inputs remain unchanged.

Scratch memory remains synchronous with its existing single read/write ports.
Disjoint buffers and exact in-place vectors may use batching. Other overlaps
retain scalar element ordering and its alias effects. Results retire in element order;
an invalid element must preserve the original fault code and exact prefix of
committed writes. Reset, health loss, program bounds and host ownership remain
explicit. Interleaving must not allow a delayed result to revive a fault.

Require targeted operation/alias/fault/reset tests, strict pinned-native
info/fmt/check/test gates, actual emitted RTL replay, pinned digital synthesis,
fresh affected safety/equivalence checks and complete negative controls, and
strict routed timing/DRC/clock/skew checks before programming a new image.
Reuse unchanged gates only by complete input identity and sealed evidence.

Compare fresh baseline and candidate campaigns against the original CPU and
ordered operation-model references. Report all resident end-to-end samples,
including launch, polling, final readback, file writes and CPU checking.
Uploads, program switching and full diagnostic sweeps are measured separately.
The experiment remains one complete fixed layer and cached decode; it does not
establish full-model inference or a faster-than-CPU claim.

Keep large compiler/vendor caches and unique evidence on the existing isolated
Ubuntu `/data` storage. Sealed historical archives remain immutable. Any local
duplicate removal requires complete comparison and an explicit recovery map.

The completed physical result and every sample are recorded in
[evidence/prx100-layer-vector-20261023.md](evidence/prx100-layer-vector-20261023.md).
