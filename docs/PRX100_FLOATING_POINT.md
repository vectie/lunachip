# PRX100 floating-point experiment

This is a separate experimental BF16-input, FP32-accumulation core. The
existing INT8 FluxTile core, integer command ABI and DDR projection target
remain unchanged. The user authorized floating-point work on 2026-10-17.

Hardware is constructed in MoonBit in `designs/floating_point`, lowered by
LunaWire to canonical IR, simulated by LunaWave and emitted to SystemVerilog.
The numerical datapath contains no vendor floating-point IP or host-side
integer dequantization. Vivado owns synthesis and physical implementation.

## Numerical contract

- BF16 operands have one sign bit, eight exponent bits and seven fraction
  bits, with exponent bias127. FP32 sums have one sign bit, eight exponent
  bits and23 fraction bits, bias127.
- Each product is rounded to FP32, then added to the FP32 accumulator with
  round-to-nearest, ties-to-even. This is a **non-fused** multiply/add.
  Products in the ordinary exponent range fit FP32 exactly; overflow and
  underflow still require explicit treatment.
- Input and output subnormals are supported with gradual underflow. There
  is no flush-to-zero policy. Signed zeros and infinities are supported.
  NaN inputs and invalid operations return canonical quiet NaN `7fc00000`.
  NaN payload propagation, exception flags and other rounding modes are
  outside this experimental interface. It is not a complete IEEE754 FPU.
- Exact opposite-sign cancellation produces+0; -0+-0 preserves -0.
  Every dot starts at+0 and accumulates in increasing reduction-index order.
- Host fixture conversion first rounds the original value to FP32, then
  rounds FP32 to BF16 with RNE. CPU checking uses the resulting BF16 bit
  patterns and native FP32 multiplication and addition, not integer scaling.

BF16 retains FP32's exponent range while reducing significand precision.
This format choice preserves range, not full FP32 accuracy. See the
[Intel floating-point encoding reference](https://www.intel.com/content/www/us/en/developer/articles/technical/floating-point-reference-sheet-for-intel-architecture.html)
and [SoftFloat rounding documentation](https://www.jhauser.us/arithmetic/SoftFloat-3/doc/SoftFloat.html)
for format and rounding context; neither source establishes correctness of
this implementation.

## Small scalar architecture

One1024×32 synchronous operand BRAM stores two BF16 operands per word.
Bits15:0 hold A; bits31:16 hold B. The compute sequence has four cycles per
product: synchronous BRAM read, registered BF16 multiply, FP32 add, advance.
The captured reduction length is1..1024. Each accepted start clears the sum
and counter. Busy writes and starts are ignored by the portable experiment;
the physical AXI control shell rejects them with SLVERR. Synchronous reset
cancels the job and clears control/results, but does not initialize BRAM.
The physical asynchronous reset may invalidate BRAM contents; preservation
across a physical reset is not part of this profile. Software must reload
every operand word used by a job after reset. In particular, no job may reuse
resident operands across a reset or MMCM lock loss.

The `cycles` counter covers active compute edges, excluding the start edge,
host upload, register access, JTAG, and result readback. It is exactly4K for
a completed dot. The physical profile targets25MHz with a real clock-wizard
output. K1024 is4096cycles or163.84µs at this frequency.
Eight sequential channels therefore sum to1310.72µs of engine activity;
this arithmetic total is not a single measured eight-output job latency.

This first profile uses BRAM and CPU_TAG/JTAG-to-AXI. DDR and the integer
tile sequencer are not connected to it. The separately qualified
[FP1.1 pipeline](PRX100_FLOATING_POINT_PIPELINE.md) adds eight lanes at 50 MHz
and completes the same eight-output K1024 block in 102.48 µs, with all 320
board results CPU exact. DDR integration, bulk loading, normalization,
attention, KV cache and full-model execution remain open. The scalar FP1.0
contract and recovery bitstream remain unchanged.

## Separate physical register ABI

All accesses are32-bit, naturally aligned. Writes require all four strobes.

|Byte address|Read|Write|
|---|---|---|
|0|Magic `46504231`|SLVERR|
|4|Version `00010000`|SLVERR|
|8|bit0busy, bit1sticky DONE, bit2error|SLVERR|
|12|Configured reduction length|1..1024 while idle|
|16|SLVERR|1 starts a configured job while idle|
|20|FP32 result bits|SLVERR|
|24|Compute cycles|SLVERR|
|1000..1ffc hex|SLVERR|1024 packed operand words while idle|

Unmapped/misaligned accesses, invalid lengths and busy writes return SLVERR.
AW and W may arrive independently. B/R responses remain stable while held.
DONE persists until an accepted start. The physical shell validates lengths
before starting; the portable experiment additionally reports invalid starts
through its error output.

## Reproduction

```sh
moon test --target native --deny-warn designs/floating_point
moon test --target native --deny-warn targets/prx100_fp
moon run --target native cmd/prx100_fp -- export NEW_INPUT_ROOT
moon run --target native cmd/prx100_fp -- replay PINNED_FIXTURE NEW_REPLAY_ROOT
moon run scripts/prx100-fp-prepare.mbtx -- INPUT_ROOT REPLAY_ROOT NEW_PHYSICAL_ROOT NEW_PHYSICAL_REPLAY_ROOT
moon run scripts/prx100-fp-clock25.mbtx -- PHYSICAL_ROOT NEW_25MHZ_INPUT_ROOT
```

The preparation step preserves ordinary emitted RTL and records a separate
two-state synthesis normalization of equality, signed/unsigned comparisons,
and modular add/sub helpers. Native arithmetic permits FPGA carry-chain
inference. The26 actual helper functions are separately checked for
combinational equivalence over unconstrained two-state operands. Canonical IR
and its unknown-value semantics are unchanged.
Independent RTL replay must use the exact normalized source that enters CAD.
Physical builds use pinned Vivado2025.2 on `xc7a100tfgg676-2` through
`scripts/prx100-fp-build.mbtx`; board campaigns require a passing source-bound
digital qualification before `scripts/prx100-fp-board.mbtx` programs volatile
configuration. Flash programming is outside this workflow.
