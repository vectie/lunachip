# Fresh PBlaze3 supervisor synthesis review

This review examines the actual linked synthesis design of smoke run `20261026-v20261-build-a9`, created from sealed ready inputs `artifacts/pblaze3-ready-inputs-20261026-2026-1-a5`. It does not reuse the earlier a4 checkpoint. It establishes mapped reset structure and constraint scope; routed timing, pulse-width, CDC and physical-board behavior are not claimed here. Accelerator a10 and both routed designs remain pending.

Vivado is 2026.1 SW build 6511674 / IP build 6504888, targeting `xc7k325tffg900-2`. The read-only probe opens the existing project with `-read_only`, links `synth_1`, queries cells/pins/clocks, writes unique review reports and closes the project. It does not synthesize, place, route, save a checkpoint, generate a bitstream or access hardware.

## Actual mapped supervisor

The supervisor contains three FDPE registers `fault_cdc/arststages_ff_reg[0..2]`, each with ASYNC_REG=1. Stage0 D is GND; all CE pins are VCC. Stage0 Q drives only stage1 D, and stage1 Q drives only stage2 D. Stage2 Q has exactly eight endpoints, the CLR pins of the eight FDCE counter registers `hold_i/lc_n2_reg[0..7]`. All eleven registers have INIT=0 in this mapped design; reset assertion is supplied by the explicit asynchronous PRE/CLR wiring.

All eleven register clocks are `reset_clk50_pblaze3_clocks_0`, period 20.000 ns, driven by `clocks/inst/clkout3_buf/O`. Its master is the primary `clk_in1_50M`, also 20.000 ns. The probe checks that ancestry and period before capturing the register clock pins. No supervisor register depends on an XDMA output clock.

Raw healthy enters a LUT1 with INIT=2'h1, whose output drives all three XPM PRE pins. Thus a fault asserts all three stages asynchronously and the final stage asynchronously clears the entire counter. Healthy recovery shifts zeros through the three stages before releasing the counter reset.

Counter bit7 Q directly drives the supervisor `released_n` output and final transport-reset LUT2 I0. The same raw healthy signal directly drives final LUT2 I1. The final LUT has INIT=4'h8, so release is exactly registered-bit7 AND raw-healthy. There is no combinational multi-bit terminal-count output feeding the reset boundary.

All eight counter CE pins are driven by the inversion of bit7, giving saturation once release is reached. The captured lower-bit LUT equations implement increment; bit7 D is the AND of bits0 through6 while counting. Therefore the mapped counter reaches bit7 on the 128th enabled rising edge and then holds. At the checked 20 ns period, the counter adds 2.56 microseconds after synchronized reset release. The asynchronous raw-healthy path immediately asserts final reset and restarts this hold on a subsequent fault. Canonical counter simulation/formal and actual-XPM simulation are retained separately by the board/validation owners.

## Exact boundary and constraint scope

The unchanged guard passes on the fresh linked netlist: exact ten synthesis reset endpoints, with the three synthesis-only outputs proven dead, plus the reviewed PIPE/status-release structure. Routed optimization must still reduce this to the exact seven endpoints and pass the routed guard; no routed result is inferred from synthesis.

Both smoke and accelerator ready-a5 `reset-boundary.xdc` files have the previously tested SHA-256 `f0622b8aa9e00f72e7adc23149e72d9ef1f7ea9e53fd0e1fdf6b9cee8963702b`. The exported applied XDC contains that same seven-pin boundary constraint. The only clock-group command is the existing vendor `pcieclkmux` physically-exclusive 125/250 MHz clock alternative rule.

The new XPM supplies its standard module-scoped asynchronous-reset exception through `src_arst` inside `transport_supervisor/inst/fault_cdc`. The captured mapped fanout is exactly the three FDPE PRE pins. There is no new board-wide clock-group or payload-data false path. Existing scoped vendor constraints remain present.

## Input normalization and evidence

Earlier fresh attempts a7/a8 could not provide a linked supervisor because Vivado rejected canonical `input logic` declarations under `default_nettype none`. The ready-a5 normalized reset-core file differs from its retained ordinary source in exactly two module input declarations, adding explicit `wire`; function inputs and sequential logic are unchanged. The archive retainer verifies the exact inverse transformation before sealing.

The actual structure snapshot has SHA-256 `54c03912c74bf95587eadfb401f3bccb1d14f85d959c22164c50a65e86e96105`. Applied constraints have SHA-256 `f069326dc88841caa0bb6690f64cfc68e49afb898378bded48a9bd4a66bb8e69`. Unique guest review files are under `/work/builds/pblaze3-review-supervisor-a9-synthesis-a1`; original build files remain under `/work/builds/pblaze3-work-20261026-v20261-build-a9`.

Earlier sealed reset-boundary and payload-timing negative controls remain immutable in `docs/evidence/pblaze3-routed-review-20261026-2026-1-a1`. This fresh synthesis receipt is additive and does not accept any routed build.
