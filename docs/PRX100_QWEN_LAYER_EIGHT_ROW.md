# PRX100 eight-row DDR request profile

The four-row read-ahead image still performs four ownership/request/CDC
round trips to fill a sixteen-row BF16/FP32 stripe. This experiment uses two
eight-row requests instead, reserving every unstallable native return before
issue. It retains sixteen ordered output accumulators, four-word responses,
the 30 ns core period, 100 MHz DDR UI and the same resident host policy.

This is a separate fixed target transport profile: a marked request selects
eight rows rather than four. The core, controller and bridge must be selected
together. Descriptor encoding and host register ABI stay unchanged. Legacy
target generators must retain byte-identical artifacts. The integer core and
FP arithmetic implementation must stay unchanged.

Qualification requires native ordering/backpressure/reset/fault/address-bound
tests, actual RTL differential replay, pinned synthesis, bounded safety gates
with a failing calibration case, and routed timing/DRC. No candidate may be
programmed before those gates pass. A fresh four-row baseline and eight-row
candidate must run the same complete four-token layer and cached position-3
decode with five resident samples each, actual CPU comparisons and final
readback inside the timer. Full diagnostics stay separate. All failures and
samples are retained; only physical measurements support a speedup claim.

## Reproduce the matched inputs

Use the pinned native toolchain recorded in the evidence:

```sh
moon run --target native cmd/prx100_layer -- export-eight-row /work/builds/prx100-layer-inputs-NEW
```

This emits all fifteen canonical/emitted inputs and `SHA256SUMS` together.
Run `scripts/prx100-layer-build.mbtx` with that inventory's recorded SHA256,
the qualified MIG project, a fresh build directory and core frequency
`33333333` (the physical generated clock is exactly 100 MHz / 3). The retained
route-repair driver operates on the initial routed checkpoint without changing
RTL, IP or constraints. The final Linux and Mac exports match every selected
Vivado input byte. Timing qualification is required for every rebuilt image.

The selected profile fetches eight strided 128-byte rows per marked request.
It reserves 256 32-bit words / 64 native reads before issue, emits ordered
four-word packets, and asserts LAST on packet 63. The core expects row 7/15
terminal packets; the controller uses the same terminal count. Header extent
is checked in 31 bits with an explicit overflow regression before narrowing
to the 256 MiB address ABI. Legacy profiles retain four-row semantics. Never
mix independently selected legacy and eight-row components.

## Measured qualification — 2026-10-20

The [eight-row DDR continuation](../artifacts/prx100-layer-stripe-20261020/report.md) halves ownership/request handoffs per sixteen-row weight stripe while retaining sixteen BF16/FP32 arithmetic lanes and a 30 ns core period. Resident four-token latency improves **649.402 → 581.413 ms (10.47%)**; cached position-3 decode improves **182.845 → 169.938 ms (7.06%)**. Five samples per workload/profile include launch, completion, final readback and actual CPU checks; upload, program installation, integrity and complete diagnostics are separate. All 845,696 paired FP32 words pass CPU tolerance and ordered-model bit equality. All 199 integer inputs and the FP arithmetic implementation remain unchanged. The matching core loader, controller and bridge reserve 64 native return lines per eight-row owner. All 1,274 strict native tests, actual RTL replays, zero-SCC composition, fresh core/controller bounded checks, all 83 bridge properties over 128 global frames with exact coverage, and strict route/clock gates pass. Utilization is 45,411 LUTs / 134.5 BRAM tiles / 51 DSPs, with +0.056/+0.036 ns setup/hold slack. This is one fixed complete layer at context four; full-model inference and broader phase closure remain open.

Selected bitstream SHA256:
`d8377cfb94615400b3f9648e60d01ca59f0b45658c330a76ccbb79af3a4f975c`.
