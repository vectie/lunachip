# PBlaze3 routed review: smoke a4 and accelerator a5

Both original routed attempts are rejected. The smoke's seven failing endpoints are entirely in the intentionally asynchronous MIG-health-to-PCIe fundamental-reset boundary. The accelerator has that reset issue plus two genuine PCIe hard-block-to-BRAM setup failures. No existing archive, implementation checkpoint or vendor source was modified by this review. No hardware was programmed.

The actual tool is Vivado 2026.1 SW build 6511674 / IP build 6504888 on `xc7k325tffg900-2`. Runs are `20261026-v20261-build-a4` (smoke) and `20261026-v20261-build-a5` (accelerator). The existing pre-route evidence remains immutable at `docs/evidence/pblaze3-physical-review-20261026-2026-1-a1`.

## Smoke routed result

The authoritative child timing summary reports WNS -2.655 ns, TNS -18.096 ns, seven failing endpoints, WHS +0.014 ns and no hold or pulse-width failure. All nine reported failing setup/recovery checks originate at MIG `rstdiv0_sync_r1_reg_rep`; two PIPE reset pins are checked against both 125 MHz and 250 MHz mux alternatives. Three setup checks terminate at PCIe status registers' synchronous R pins; the other checks terminate at asynchronous CLR/PRE pins. The child `Timing 38-282` critical warning causes the new child-log gate to reject the attempt before normal root-level reporting or bitstream creation.

Read-only diagnostics were therefore generated separately by opening the existing routed checkpoint. They show zero unclocked sequential pins and zero unconstrained internal endpoints. The ten AXI converter bus-skew groups pass, with the smallest listed slack +3.452 ns. The pulse-width diagnostic reports no violation. The 250 MHz `userclk2` intradomain setup slack is +0.216 ns; GPIO's OOC 10 ns versus actual 4 ns warning does not identify a failing GPIO path. PCIe's separate 500 MHz `userclk1` domain has only +0.006 ns setup margin in this smoke placement.

The remaining missing I/O delays are eight DDR DQS positive pins, asynchronous board PERST input and DDR reset output; three LED outputs have deliberate output false paths. This is a complete internal timing-coverage check, not an external DDR signal-integrity or board validation.

## Exact reset boundary and release safety

`all_fanout -flat -endpoints_only` from `pblaze3_i/transport_reset_gate/Res[0]_INST_0/O` returns exactly these seven pins under `pblaze3_i/xdma/inst/pblaze3_xdma_0_pcie2_to_pcie3_wrapper_i/pcie2_ip_i/inst/inst/`:

- `gt_top_i/pipe_wrapper_i/reset_n_reg1_reg/CLR` and `reset_n_reg2_reg/CLR`, both FDCE with ASYNC_REG=1.
- `pl_phy_lnk_up_q_reg/R`, `pl_received_hot_rst_q_reg/R` and `user_lnk_up_int_reg/R`, all FDRE.
- `user_reset_int_reg/PRE` and `user_reset_out_reg/PRE`, both FDPE.

No payload or additional sequential endpoint is present. The first PIPE reset stage's Q has exactly one endpoint, the second stage's D. Both share the same clock and asynchronous clear. Its D is constant one; the second stage alone drives the downstream reset sequencers. Generated `pblaze3_xdma_0_pcie2_ip_pipe_wrapper.v:638-650` implements asynchronous assertion and two-stage synchronous release.

Generated `pblaze3_xdma_0_pcie2_ip_core_top.v:1043-1117` synchronizes hard-block link/hot-reset status through two-stage XPM synchronizers before the status registers. `user_reset_int` asserts asynchronously and can clear only after the hard-block reset has released and synchronized physical-link status is high. `user_reset_out` follows that registered result one cycle later. The synchronous status-reset paths are explicitly covered by vendor CDC-1 waivers in `ip_xilinx_pcie_2_1_7x_late.xdc:78-80`; `user_reset_int/PRE` has a vendor CDC-7 waiver at line82. The output-reset stage has no separate waiver line; its safety follows the inspected two-stage qualified release.

AMD's [PG054 reset contract](https://docs.amd.com/r/en-US/pg054-7series-pcie/Resets) defines `sys_rst_n` as an asynchronous fundamental reset of the core and transceivers, with user reset released synchronously. [PG054 System Interface](https://docs.amd.com/r/en-US/pg054-7series-pcie/System-Interface) requires at least 1500 ns assertion for power-on and warm reset. [PG195 Clocking and Resets](https://docs.amd.com/r/en-US/pg195-pcie-dma/Clocking-and-Resets) says the XDMA AXI clock is not free-running and can be unavailable before reset release.

The original combinational health gate does not independently guarantee the minimum reset pulse. The board correction therefore needs an independent 50 MHz supervisor with immediate fault assertion, synchronized healthy release and at least 128 complete clock cycles of hold after every fault. That is 2.56 microseconds at the guarded 20 ns supervisor-clock period. The supervisor uses a new 50 MHz clock-wizard output whose master is the 20 ns primary `clk_in1_50M`; it must not depend on the XDMA clock. A separate mapped guard must verify that actual generated-clock source, period and primary-clock ancestry. This is a real reset-duration correction; merely excluding the old reset paths would not satisfy that requirement.

The timing exception under review is restricted to paths through the exact final reset-boundary pin and to the exact seven reset endpoints. A fail-closed mapped-netlist guard checks complete fanout equality, primitive kinds, PIPE synchronization and stage wiring, qualified user-reset stage wiring, synchronized status sources and reviewed vendor release source structure. It must run after linked `open_run synth_1` and after `open_run impl_1`; a raw top synthesis DCP alone does not resolve OOC leaf cells. No primary clock groups or AXI data paths are excluded.

The linked synthesis netlist has exactly ten reset endpoints: the seven routed pins plus `user_lnk_up_mux_reg/R` and two XDMA shadow-reset CLR pins. The guard proves the mux Q and second shadow-register Q have no fanout, while the first shadow Q drives only the second D. Optimization removes those three dead endpoints; the routed guard therefore requires exactly seven. The static exception never includes the three synthesis-only pins. The XDC belongs only to implementation, with late processing; the separate pre-implementation guard runs on the fully linked synthesis design.

Actual Vivado probe `reset-probe-a7` passed both phase-specific guards and rejected deliberate wrong-fanout and missing-primitive controls. Applying the static XDC in memory to the original smoke routed checkpoint leaves zero failing setup/hold paths, minimum setup slack +0.006 ns and minimum hold slack +0.014 ns. No checkpoint was saved. This demonstrates the exception's scope; it does not accept the old board design, whose reset-pulse duration still needs the new supervisor.

The immutable trial inputs retain the practical query corrections: a1/a2 show that a standalone top synthesis DCP does not link OOC leaves; a3 exposed the three dead pre-optimization endpoints; a4 showed that `all_fanin` excludes constant drivers; a5 required complete hierarchical net-segment comparison across XPM boundaries; a6 showed that `all_fanin` traverses the PCIe hard block to its USERCLK2 timing startpoint. The final guard checks direct leaf-net drivers for VCC and TRNLNKUP provenance, without weakening the expected source or connectivity.

## Remaining CDC and DRC findings

The original smoke CDC report has two CDC-10 critical entries at the combinational reset gate feeding the PIPE reset synchronizer. The reset supervisor/guarded asynchronous interface correction must be reviewed against a fresh routed report. The other two critical CDC-13 entries are the vendor PCIe `pclk_sel_reg` driving BUFGCTRL S1 for rate switching, already covered by scoped vendor false paths. Three CDC-8 warnings concern existing MIG reset synchronizers; three CDC-15 warnings are inside the vendor asynchronous AXI FIFO. Recognized synchronizers and vendor-scoped constraints are retained; no new blanket exceptions are justified by those messages. Some FIFO internals are hidden in the vendor report, so this review does not claim independent proof of vendor implementation internals.

After the in-memory seven-pin exception, the two reset CDC-10 entries remain visible and are marked False Path. The two vendor CDC-13 entries also remain. Methodology no longer reports the reset TIMING-6/TIMING-7 critical relationships, but still reports four LUTAR-1, twelve PDRC-190 and one TIMING-9 warnings plus vendor advisories. The structural CDC observations have not been suppressed or recast as clean CDC.

The original default DRC has three ordinary checks: an unused LUT equation term inside the vendor XDMA FIFO, different intended buffer types on MIG PLL outputs, and unused FIFO/reset nets. Accelerator DRC adds DSP input/output pipeline advisories. No error or critical warning appears in default DRC, but methodology separately reports the reset-clock relationship critical checks. A clean default DRC alone is not a CDC acceptance result.

## Accelerator a5 remains independently blocked

The actual a5 timing report has two same-domain 2 ns PCIe hard-block-to-RAMB36E1 setup failures: TX BRAM `DIBDI[27]` at -0.022 ns and RX BRAM `DIBDI[3]` at -0.005 ns. These are in 500 MHz `userclk1`, have no reset-boundary traversal, and must remain fully timed. The 33.333 MHz LunaChip core domain has +7.345 ns setup slack and +0.080 ns hold slack in this attempt. Neither core margin nor the small magnitude of the PCIe failures permits accepting a5. A fresh implementation must pass all setup/hold/pulse and existing acceptance gates.

The separate actual-tool `payload-probe` opens the existing accelerator routed DCP, validates the same exact seven-pin guard and applies the identical XDC only in memory. It then requires the remaining negative setup endpoints to equal precisely those two TX/RX BRAM pins. This negative control passes and retains both failures at their original slacks. The reset exception cannot turn the original accelerator attempt into a timing pass.

## Source identities

Smoke routed DCP SHA-256: `1cf8a163d6edcffffb9a34a94b0a6b5d1a52979c8c75ecac92e5fbba2448409d`.

Reviewed vendor sources under the smoke a4 generated XDMA `ip_0/source` directory:

- `pblaze3_xdma_0_pcie2_ip_pipe_wrapper.v`: `37c049923d10cc48d120f00b4328374bbf4dca559779854d418c8a788bc04936`.
- `pblaze3_xdma_0_pcie2_ip_core_top.v`: `76cc3056b33cf22b3a50cd9efb319544d7df35ea1cbb074f0fbb78d8c311a3e2`.
- `ip_xilinx_pcie_2_1_7x_late.xdc`: `5ab22dd5974a4f76d83100e8544d6b51cbafcf22f48bd43c6f8eace954d6f9e9`.

Unique read-only diagnostics are under `/work/builds/pblaze3-review-routed-a4-20261026-a1`, produced by `/tmp/pblaze3-routed-diagnostics.mbtx`. The complete child build reports remain in their original attempt evidence; this review retains their identities instead of duplicating vendor caches, checkpoints or full build logs.

Frozen guard SHA-256: `a386449a8c46be4d147c530db05ef79e00c226b7b37d5ea83897c4ca0ec68aec`. Frozen static XDC SHA-256: `f0622b8aa9e00f72e7adc23149e72d9ef1f7ea9e53fd0e1fdf6b9cee8963702b`. The archive retainer checks these files are byte-identical to the helper and XDC used in both successful actual-tool probes before sealing.
