# PRX100 nonlinear operation scheduling

The opt-in `short_unary_layer_machine()` retains the sixteen ordered BF16/FP32
rows and matched eight-row DDR transport. It shortens the reciprocal, reciprocal
square root and exponential micro-operations without changing their arithmetic
programs, FP32 rounding, approximation constants or evaluation order. The integer
core is outside this change.

The legacy engine captures operands, waits for a three-edge result, and commits
on edge five for both additions and multiplies. The new engine issues directly
into the existing arithmetic pipelines. It captures operation and destination
metadata once, commits the one-edge adder's result on edge two, and commits the
three-edge multiplier's result on edge four. It waits for each commit before
issuing a dependent operation. Reset, busy ownership, clipping and invalid-input
handling retain their contracts.

| Unit | Legacy fast cycles | Short schedule cycles |
|---|---:|---:|
| Reciprocal | 60 | 40 |
| Reciprocal square root | 85 | 60 |
| Exponential | 115 | 76 |

These are simulation-checked cycles after accepting a valid input. Clipped or
invalid inputs use the existing immediate completion path. The regression checks
raw FP32 equality across scalar, legacy pipelined and short schedules, numerical
error bounds, invalid inputs, clipping, resets and repeated operations.

Use the pinned native toolchain recorded with the target evidence:

```sh
moon run --target native cmd/prx100_layer -- export-short-unary-aligned /work/builds/prx100-layer-inputs-NEW
```

This emits the complete fifteen-file canonical/RTL input set and `SHA256SUMS`.
The matching eight-row controller, system wrapper, physical wrapper and
constraints are byte-identical to `export-eight-row`. Both `export-eight-row`
and the earlier `export-short-unary` retain their complete byte-identical
fifteen-file exports. The aligned profile specializes only the bridge's extent
arithmetic; packet encoding, ownership, clock/reset, FIFO geometry, fault
handling and cycle contract remain the same. Standalone nonlinear elaboration uses
`unary_operator(fast=true, short=true)`; `short` requires `fast`.

The original bridge's request-FIFO-to-UI validation path failed physical timing
after the arithmetic schedule changed placement. Routing-only attempts remain
retained and unprogrammed. The aligned profile makes the address check smaller
in MoonBit: valid addresses and strides have seven zero alignment bits, checked
by the unchanged full header predicate. In 128-byte units, the eight-row extent
is `address21 + 7 * stride21`, which fits in 24 bits, and is valid through
`0x1fffff`. This replaces the 31-bit byte sum including the final `+127` only
inside the extent arithmetic. All shape, reserved-bit, alignment and zero-stride
checks remain explicit, including malformed and overflowing headers.

`aligned_eight_row_bridge()` selects this profile.
`address_validation_equivalence()` exposes the actual canonical full-header
predicate miter. Its positive formal job must pass all 64 input bits in one
symbolic frame; the negative changes the extent comparison from `>` to `>=`
and must produce a last-valid-line witness. Fresh bridge RTL replay, all 83
original bridge assertions over 128 frames, negative calibration, full digital
synthesis, native phase and physical signoff are required. The unchanged core's
actual RTL replay and fresh core proof remain bound to its exact emitted bytes.

Build the complete export with `scripts/prx100-layer-build.mbtx`, the recorded
inventory digest, qualified MIG project, fresh build directory and frequency
`33333333`. The physical core period is exactly 30 ns (100 MHz / 3). Every
rebuilt image requires its own timing, DRC, clock and numerical qualification.
The initial physical baseline profile has 313.112 ms in matrix sections,
90.349 ms in SiLU sections and 111.068 ms elsewhere. These are segmented kernel
counters, with inserted HALTs and no host gaps, rather than resident end-to-end
latency. The fresh baseline resident medians are 582.576 ms for four tokens and
168.649 ms for cached position-3 decode. The candidate passes physical and numerical qualification.

| Resident median | Fresh eight-row baseline | Short nonlinear schedule | Reduction |
|---|---:|---:|---:|
| Four-token layer | 582.576 ms | 563.787 ms | 3.23% |
| Cached position-3 decode | 168.649 ms | 164.214 ms | 2.63% |

The opt-in MoonBit nonlinear engine commits additions in two edges and multiplies in four, preserving the ordered FP32 operations and approximations. On the PRX100, resident four-token layer latency improves from **582.576 to 563.787 ms** (3.23%), and cached position-3 decode from **168.649 to 164.214 ms** (2.63%). Timers include launch, completion, actual final-output reads, file writing and CPU comparisons. Upload, program installation, integrity sweeps and full diagnostics are separate. All 845,696 paired FP32 words pass CPU tolerance and match the ordered model bit for bit. All 199 integer inputs and FP32 primitives remain unchanged. Controller, wrappers and source timing constraints are byte-identical. The bridge uses equivalent 24-bit aligned extent validation with the same packet and cycle contract. All 1,278 strict native tests, actual core RTL replay, zero-SCC composition, fresh 48-frame core safety checks, all 83 original bridge assertions over 128 global frames, actual 64-bit header equivalence in one frame, complete negative witnesses, and strict timing/clock/DRC/bus-skew gates pass. Routed setup/hold slack is 0.386 / 0.001 ns. [Measured evidence](../artifacts/prx100-layer-short-unary-20261020/report.md) retains every observation and failed attempt. This is one complete fixed layer at context four; full-model inference and broader phase closure remain open.

Selected bitstream SHA256:
`1994aacbcada66016212f1204a4d06af36c21fa70345fa9785f0f27958e7cf48`.
