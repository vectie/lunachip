# PRX100 FPDDR1.3 overlap contract

FPDDR1.3 adds a separate `buffered_dot_product()` constructor and `prx100_fpo`
target. Integer and existing FP profiles remain unchanged. The multiplier,
accumulator expressions, increasing-K order and FP32 RNE behavior are the
FPDDR1.2 arithmetic, with the same `4*K+4` active compute cycles. MMIO magic is
0x46504433; version is 0x00010003. Core/UI clocks remain 50/100 MHz.

Each lane now has two 1,024-word operand banks. `start_bank` is captured at
accepted START; `active_bank` reports it. `write_bank` selects the load bank.
Loads to the active bank while busy are ignored. Opposite-bank loads may run
during computation, including a simultaneous START targeting the other bank.
Same-bank START/load conflicts reject START and the conflicting load. Lengths
remain 1..1024; reset cancels control/pipelines and requires operands to reload.

The feeder fills the unchanged weight and activation caches, waits for a free
operand bank, then packs all eight lanes in 1,025 cycles. After packing, the
activation cache can receive the next vector. Prepared-minus-retired never
exceeds two; a bank becomes reusable only after its result has been captured.
The executor starts prepared jobs in order. A held eight-word result permits
the next computation to run while the previous result is written to DDR. If
writeback stalls, completion capture waits until that held result is published.
No result is overwritten, and arithmetic order within a job is unchanged.

One DDR transaction owner arbitrates weight reads, activation prefetch and
result writes, with result priority between accepted transactions. Request
address/data/type are captured at allocation and held through backpressure.
The existing bridge and malformed-LAST drain rules are retained. Health,
protocol, core and watchdog faults suppress requests, load and START, reset the
FP core, poison the weight cache and require physical-reset recovery.

DDR layout and transfer counts are unchanged. The old stage counters become
inclusive: 0x3c DDR activity, 0x40 packing, 0x44 executor ownership (including
completion waiting), 0x48 completed arithmetic cycles. Added counters are
0x70 DDR/executor overlap, 0x74 packing/executor overlap, 0x78 DDR/packing
overlap, 0x7c triple overlap, and 0xa0 cycles where no stage is active. Thus:

`total = DDR + packing + executor - overlap70 - overlap74 - overlap78 + triple + gap`.

Executor ownership can include a held completion. To guarantee overlap with
actual arithmetic, audits subtract `(executor_cycles - arithmetic_cycles)`
from each stage/executor intersection as a conservative lower bound. Both
lower bounds must be positive for multi-job K1024 campaigns.

0xa4 reports feeder state, 0xa8 prepared jobs, 0xac started jobs, 0xb0 captured
results, and 0xb4 held-result occupancy. At successful completion these job
counts equal the requested count, occupancy is zero, and feeder is idle. The
0x30/0x60 diagnostics retain final publication index/vector meanings, and
0x80..0x9c mirror the final captured result. Core words remain 8,192 per job.
The host reads 34 consecutive counter/result words at 0x30, versus 16 in
FPDDR1.2; host timing comparisons must disclose this extra diagnostic readback.

Qualification includes bank-conflict, simultaneous START/load, stalled held
result, overlapping health fault, exact activity inclusion/exclusion and real
nonzero DDR/packing overlap tests; full native gates; actual core/controller RTL
traces and CPU references; pinned synthesis; scoped control/helper formal checks;
and routed timing/clock/bus-skew checks. Physical comparisons use identical
Qwen inputs and job batches with CAD idle. Pipeline filling and draining remain
visible: throughput gains depend on batch size, and single-job latency is a
separate measurement. No full-model inference claim follows from this target.
