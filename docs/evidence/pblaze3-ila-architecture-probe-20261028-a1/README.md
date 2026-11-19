PBlaze3 ILA architecture and actual-tool catalog probes, 2026-10-28

Actual Vivado 2026.1 SW6511674/IP6504888 catalog and generated-IP checks, not an implemented diagnostic image. All probes ran without hardware access; the retained production a9 project was opened read-only. No canonical generator or native module cache was changed. Compiler and vendor generation caches remain outside evidence.

The first exploratory ordinary ILA6.2 creation exposed an important default: C_MONITOR_TYPE=AXI and C_ENABLE_ILA_AXI_MON=true cause 44 probe pins despite C_NUM_OF_PROBES=5. That setup is not accepted for the intended five-probe diagnostic. The second probe explicitly sets C_MONITOR_TYPE=Native and C_ENABLE_ILA_AXI_MON=false; it asserts exactly five physical probe ports and the requested widths64/147/9/142/64, depth1024 and input pipeline stage1. This checks actual configuration, not synthesis licensing or timing.

The public a9 BD pins confirm XDMA M_AXI address64/data128/ID4 at250MHz, MIG S_AXI address31/data128/ID4 at200MHz in smoke mode, and XDMA M_AXI_LITE address32/data32/noID at250MHz. The accelerator MIG contract uses ID5 and is separately guarded by the board recipe. Scalar names are xdma/m_axi_*, xdma/m_axil_* and mig/s_axi_*.

Fresh clk_wiz6.0 generation accepts PRIM_SOURCE=No_buffer, emits a direct clk_in1 assignment with no input IBUF, and comments the primary create_clock/jitter lines in the ordinary scoped XDC. Its OOC XDC still defines20ns. Therefore diagnostic shared-IBUF/BUFG raw50 topology needs an unconditional top-level create_clock named clk_in1_50M at20ns. The reset supervisor should retain its existing MMCM-generated50MHz clock and ancestry gate. Raw50 hub/status capture is then independent of source-MMCM lock, DDR calibration and PCIe reset, assuming the board oscillator itself runs.

Recommended full diagnostics use separate ILAs for raw50 synchronized status, MIG UI200 AXI, XDMA250 AXI, and accelerator33MHz AXI. Only independent one-bit status flags cross into raw50 through XPM; no raw multibit AXI payload is sampled asynchronously. Five probes can pack AW/W/B/AR/R; append same-domain reset and AXI-Lite control fields to AW/AR to reveal START/status traffic. Preserve the exact final transport-reset fanout by observing its upstream operands instead. Equal input pipelining preserves within-domain alignment. Depth1024 gives20.48us/5.12us/4.096us/30.72us respectively.

Trigger guidance: use calibration transitions or synchronized supervisor release falling for reset events; raw healthy pulses can be missed by a simple status synchronizer. For AXI, trigger on presented error responses RVALID with RRESP[1] or BVALID with BRESP[1], on VALID&&!READY stalls, or on selected address+VALID; count transfers only when VALID&&READY. Capture windows are too short to record an entire long calibration sequence. Cross-domain captures are not cycle-aligned proof.

Provide a separate raw50 status-only fallback image: UI/XDMA debug clocks can stop during reset, and a stable hub alone does not establish that Hardware Manager can still access every core. UG908 distinguishes discovery from measurement, but warns about stopped core clocks. Actual mixed-clock hardware behavior remains untested. The status-only variant avoids those optional stopped debug cores.

Debug hub clock binding must persist into child implementation through an implementation-only debug XDC, not only an in-memory open_run edit. Set C_CLK_INPUT_FREQ_HZ=50000000, C_ENABLE_CLK_DIVIDER=false, connect dbg_hub/clk to the exact raw50 net, then verify routed clock and buffer topology. Retain the exact .ltx, probe bit-offset mapping and .bit identities. No timing/CDC/DRC gate is weakened; actual licensed synthesis/implementation is still required.

Primary references:
- https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Debug-Core-Clocks
- https://docs.amd.com/r/2023.1-English/ug908-vivado-programming-debugging/Debug-Cores-Clocking-Guidelines
- https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Saving-Constraints-After-Running-Debug-XDC-Commands
- https://docs.amd.com/r/en-US/ug908-vivado-programming-debugging/Programming-the-Hardware-Device
- https://docs.amd.com/r/en-US/pg195-pcie-dma/Clocking-and-Resets
