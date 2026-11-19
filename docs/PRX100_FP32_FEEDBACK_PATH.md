# PRX100 FP32 feedback path experiment

The qualified 40 MHz baseline spends 129.050 ms in external matrices and
250.073 ms in the uninterrupted four-token layer kernel. Sixteen ordered
accumulators already accept one product per edge. Routed timing identifies
the FP32 feedback adder as the limiting path: 24.721 ns of data delay through
41 logic levels, from accumulator `lc_n72` back to itself.

This experiment shortens serial dependencies in the MoonBit adder. Exponent
ordering selects alignment without waiting for a full 31-bit magnitude
comparison. The close subtraction path calculates both signs in parallel and
selects the absolute difference. Cancellation normalization retains its
already shifted value instead of passing it through a second variable shifter;
the gradual-underflow shift is calculated separately.

The contract remains binary32 round-to-nearest-even, gradual underflow,
signed zero, infinities and canonical quiet NaNs. Products stay separately
rounded, and every matrix row retains its original K order. No precision or
CPU tolerance changes are permitted. The integer core is unchanged.

Qualification requires native raw-bit CPU arithmetic tests, an unrestricted
combinational equivalence miter with a negative control, emitted-RTL replay,
pinned synthesis and affected bounded safety gates. A faster target clock
requires fresh placement/routing, setup/hold/pulse-width checks, and the
existing bounded FIFO CDC audit. Rejected attempts remain retained.

The first complete 50 MHz build exposed an overly specific CDC source-name
guard. The pinned bridge defines each Gray-pointer MSB equal to its binary
MSB; synthesis can retain either register. The guard now inspects the actual
direct Q-to-D connection and accepts only those two exact MSB identities.
Every lower bit still requires its exact Gray register. Register type, width,
domain, synchronizer stages and timing bounds remain checked. A synthesized
netlist regression covers both legal forms and rejects unrelated registers,
wrong bit indices and a binary register on a lower Gray bit.

Physical comparison uses the same complete layer0/context4 and cached
position3 workload, weights, programs and host policy. Report five resident
samples per image, including actual launch, polling, readback and CPU checks.
Record uploads and program switching separately. The baseline remains
recoverable from `prx100-layer-matrix2-20261023`.

The selected physical recipe preserves the completed 44.444 MHz placement
and routing, then configures the reference MMCM for a 24 ns core period.
Its feedback multiplier changes from 16 to 20, the DDR reference divider
from 4 to 5, and the core divider from 18 to 24. The DDR reference remains
200 MHz and the DDR UI remains 100 MHz. Vivado re-derives the clocks and
rechecks timing, pulse widths, routing, DRC and skew; a separate checkpoint
reload checks the clock configuration and FIFO CDC bounds. The parent
checkpoint identity and executable MoonBit recipe are retained with the
evidence. No timing-failing image is programmed.

Status: the 41.667 MHz candidate passed physical/digital qualification and matched complete-layer/cached-decode CPU campaigns. See [the measured report](evidence/prx100-layer-add2-20261023.md). All199 integer inputs remain unchanged.
