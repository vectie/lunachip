# PRX100 pipelined floating-point experiment

This separate FP1.1 BRAM profile extends the scalar BF16/FP32 experiment with
eight output lanes. The integer core and integer DDR target remain unchanged.
MoonBit construction produces canonical LunaWire IR and emitted SystemVerilog.

Each lane has a three-stage BF16 multiplier and a five-stage FP32 accumulator.
All operations retain round-to-nearest-even, gradual underflow, signed zeros,
infinities and canonical quiet NaN `0x7fc00000`. Multiplication and addition are
separate operations. Each output accumulates addresses in increasing order;
there is no reassociated partial-sum reduction. One input is issued every five
cycles, so a length-K eight-output job takes `5*K+4` active clock cycles.

The existing scalar FP1.0 export and bitstream remain usable for comparison.
The new `parallel_dot_product()` constructor has eight independent 1024-word
operand banks. Each 32-bit word contains BF16 activation in bits15:0 and BF16
weight in bits31:16. A write selects a bank with `write_lane[2:0]`. Start captures
length1..1024. Writes and starts while busy are ignored by the core and rejected
by the AXI controller. Reset cancels the job, clears every pipeline register and
invalidates resident operands; reload all used words after reset.

The FP1.1 target retains magic `0x46504231` at0 and reports version `0x00010001`
at4. Status8, length12, START16 and cycles24 retain their meanings. Eight FP32
results are readable at `0x20+4*lane`. The operand write aperture is
`0x1000+0x1000*lane+4*k` through `0x8ffc`, with aligned full-word writes only.
Invalid accesses return SLVERR. Result20 from FP1.0 is absent in this ABI.

The physical target runs at50MHz directly from the board oscillator. The first
Vivado2025.2 route uses8589 LUTs,5989 FFs,10.5 BRAM36-equivalent and8 DSP48s,
with setup/hold slack+3.308/+0.069ns. No MMCM or vendor floating-point IP is
needed. The measured K1024 latency is 5124 cycles, or 102.48 µs for all eight
outputs. All 320 results from 40 board jobs match CPU arithmetic. The
[fresh scalar comparison](evidence/prx100-fpp-20261017.md) shows a 12.79×
engine speedup. This remains an eight-channel projection experiment, not
full-model inference.

## Reproduction

Use fresh output roots and the pinned fixture from the evidence archive:

```sh
moon test --target native --deny-warn designs/floating_point
moon test --target native --deny-warn targets/prx100_fp
moon run --target native cmd/prx100_fp -- parallel-export NEW_INPUT_ROOT
moon run --target native cmd/prx100_fp -- parallel-replay PINNED_FIXTURE NEW_REPLAY_ROOT
moon run scripts/prx100-fp-prepare.mbtx -- INPUT_ROOT REPLAY_ROOT NEW_PHYSICAL_ROOT NEW_PHYSICAL_REPLAY_ROOT
moon run --target native cmd/prx100_fp -- parallel-formal NEW_FORMAL_ROOT
moon run --target native cmd/prx100_fp -- parallel-formal-negative NEW_NEGATIVE_ROOT
```

The preparation step retains the ordinary emitted RTL and records a separate
two-state helper normalization. The exact physical source must pass pinned
Verilator replay, pinned Yosys synthesis, helper equivalence and scoped formal
checks before programming. `scripts/prx100-fp-build.mbtx` builds the normalized
inputs in the Linux guest using the recorded Vivado2025.2 executable/version pin.
Its default50MHz profile is used here. Digital qualification binds the dot,
controller and vendor top source hashes to the actual build inputs.

```sh
moon run /work/prx100-fp-build.mbtx -- build /work/builds/prx100-fp-inputs-NEW /work/builds/prx100-fp-vivado-NEW
moon run /work/prx100-fpp-board.mbtx -- run BUILD JOBS QUALIFICATION /work/builds/prx100-fpp-board-NEW
moon run /work/prx100-fpp-audit.mbtx -- JOBS TRANSACTIONS RESULTS NEW_AUDIT_JSON
moon run /work/prx100-fpp-close.mbtx -- OWN_BOARD_ROOT
```

The board driver programs volatile configuration through the identified
CPU_TAG cable and records40 jobs/320 result words, raw AXI requests/readbacks,
hardware counters, host launch and result-read windows, and operand-upload time.
The audit independently recomputes every result from the raw operand writes and
checks all complete Qwen bank images against the original scalar fixture. Flash
is outside this workflow. Full BRAM readback is not part of this profile.
