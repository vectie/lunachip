# PRX100 FPDDR1.2 arithmetic contract

FPDDR1.2 adds a separate `fast_banked_dot_product()` core and `prx100_fpa`
target. Existing integer and floating-point profiles remain unchanged. The
FPDDR1.1 banked-load interface, memory capacity, DDR layout, bridge, host bursts,
batch scheduling, ownership and fault/reset rules are retained. The MMIO magic
is0x46504433 and version is0x00010002.

The BF16 multiplier keeps its three registered stages. The accumulator combines
magnitude ordering and alignment into its first registered stage; add/subtract,
normalization and round/pack occupy the next three stages. The arithmetic
expressions, canonical NaN, signed-zero, gradual-underflow and FP32 RNE rules
are identical to FPDDR1.1. Each BF16 product is rounded before addition;
accumulation remains non-fused and follows increasing K order with one running
FP32 sum per lane. No reassociation or partial-sum tree is introduced.

All eight lanes issue one product every four cycles. The first synchronous
operand read occurs on active cycle1; the unchanged multiplier produces it for
issue on cycle5. Later reads and issues overlap every four cycles. Three delayed
issue pulses commit the corresponding fourth accumulator stage. A sum commits
before the next issue reads it. Completion drains the last operation, giving
exactly4*K+4 active cycles for K1..1024:4,100 cycles /82.00 µs at50 MHz for
K1024. Loads during busy are ignored, simultaneous idle START/load is invalid,
and reset cancels all pipeline and control state. Reload operands after reset.

The target expects4*K+4 core cycles per completed job and reports those at0x48.
BRAM packing remains1,025 cycles/job at0x40; logical core words remain8,192/job
at0x58. DDR transfers and all other counter boundaries retain FPDDR1.1 rules.

Qualification uses finite and exceptional streaming CPU arithmetic tests,
repeated and boundary-length core jobs, coupled Qwen CPU/native tests, actual
emitted core/controller RTL replay, pinned synthesis, scoped control/helper
formal checks, and routed50 MHz/100 MHz timing and bus-skew checks. Physical
old/new performance uses identical idle-CAD campaigns on the same board and
fixture. Report hardware compute, packing, DDR and host timing separately.
