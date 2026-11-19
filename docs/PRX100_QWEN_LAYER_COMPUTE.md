# PRX100 BF16/FP32 matrix compute continuation

The candidate is an opt-in MoonBit hardware profile with 32 independent output
rows. Each row retains the existing two-cycle ordered FP32 accumulator, with
separately rounded FP32 products and sums in original K order. There is no FMA
or partial-sum reassociation. Scalar fallback, nonlinear operations, descriptor
ABI, controller, streaming DDR bridge and host policy retain their behavior.
All integer source inputs must remain unchanged.

The matrix multiplier specializes its weight operand to the actual BF16 input
format. Its exact unsigned significand product is 24 by 8 bits, extended with
16 known low zero bits before the existing full-width normalization, gradual
underflow and RNE pack stages. Sign, exponent and exceptional-value behavior
remain those of multiplying the BF16 value promoted exactly to FP32. This
reduces hardware needed per row without converting the computation to integer
quantization. Existing scalar, four-lane and sixteen-lane exported designs
must retain their identities.

The 16-row image uses 134.5 of 135 BRAM tiles. The 32-row emission therefore
maps its small weight and scalar-cache banks to distributed RAM while keeping large program
and scratch memories in BRAM. This is a deterministic target mapping attribute;
the canonical IR memory sizes, read latency, ReadOld collision policy and
HoldLast behavior do not change. Legacy emissions retain their original bytes.

Eight existing four-row batch requests fill each 32-row stripe. Requests and
responses retain their old packet format, ordered lanes and checked LAST.
Only complete inactive banks become active; reset, health loss and malformed
responses remain terminal. Nonmultiples of 32 and overlapping scratch ranges
use the existing scalar fallback.

Qualification requires raw-bit native multiplication tests, an arbitrary-input
reset-initialized multiplier equivalence miter with a retained negative case,
core arithmetic/fallback/fault/reset tests, actual-core LunaWave/Verilator
differential simulation, pinned Yosys synthesis and the named bounded core
gates. No unbounded or analog CDC claim follows. Both legacy exported graphs
and protected integer source hashes are checked independently.

Vivado must close routed timing, hold and pulse-width checks with no failing
endpoints, and pass strict DRC before any candidate programming. The initial
clock target is the current 100/3 MHz core clock, with DDR UI at 100 MHz and
JTAG at 10 MHz. Failed build attempts remain in the evidence.

The physical comparison uses the same complete Qwen3-0.6B layer-0 fixture,
aligned final-output pages and persistent MoonBit CPU checker: five four-token
layer samples, one three-token prefill and five repeated cached position-3
decode samples. Every final and diagnostic tensor must pass CPU tolerance and
match the unchanged ordered operation model bit for bit. Resident end-to-end
timing includes launch, polling, counters, actual readback and CPU checks;
initial weight upload, integrity checks, program installation and complete
diagnostics are recorded separately. All observations are retained.

## Physical result, 2026-10-20

The 32-row MoonBit design was timing-qualified and programmed through CPU_TAG.
Both profiles used the same 100/3 MHz core clock, 100 MHz DDR UI, 10 MHz JTAG,
2 ms polling, aligned final pages, programs, weights and CPU checker.

| Median resident end-to-end latency | Fresh 16-row baseline | 32-row candidate | Reduction |
|---|---:|---:|---:|
| Complete four-token layer | 720.992 ms | 704.851 ms | 2.24% |
| Cached position-3 decode | 199.429 ms | 194.455 ms | 2.49% |

FPGA kernel latency changes 648.207 → 641.950 ms for the full layer and
164.041 → 162.477 ms for decode: only 0.97% and 0.95% lower. End-to-end savings
also contain launch/readback variation. Doubling arithmetic rows has limited
benefit with the existing DDR packet path and unchanged scalar/nonlinear work;
these measurements do not establish a new detailed stall attribution. All five
observations per workload/profile are retained, without a confidence claim.

All 845,696 FP32 words pass CPU tolerance and match the ordered operation model
bit for bit; all 346 cross-profile tensor/input payloads are identical. Maximum
stage/final CPU absolute errors remain 3.0517578125e-5 / 2.86102294921875e-6.
Weights, intermediates and KV stay resident. Initial upload, preparation,
program switching, input integrity and full diagnostics are separate costs.
This remains one fixed complete layer with context four, rather than full-model
inference.

The design uses 60,373/63,400 LUTs, 70/135 BRAM tiles and 51/240 DSPs. Routed
setup/hold slack is +0.030/+0.062 ns, with no failing endpoints. Earlier resource
and timing failures remain in the evidence. All 1,267 strict pinned native tests
pass. Actual physical RTL differential simulation covers 107,786 cycles and
2,479,078 output words; exact-composition Yosys synthesis has no combinational
SCCs. Full bounded core (48 frames) and multiplier (6 frames) checks pass, with
retained negative witnesses and no assertion deletion or input abstraction.
All 199 protected integer inputs remain unchanged, and the legacy 16-row export
remains byte-identical. Fresh CPU reference reproduces all 108 fixture binaries.

See the [measured report](../artifacts/prx100-layer-compute-20261020/report.md),
[samples and phase timings](../artifacts/prx100-layer-compute-20261020/benchmark.json),
and [attempt ledger](../artifacts/prx100-layer-compute-20261020/attempts.md).
