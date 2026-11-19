PBlaze3 passive ILA monitor connectivity proof, 2026-10-28

Actual Vivado 2026.1 SW6511674/IP6504888 BD inference and RTL generation, without synthesis, implementation, hardware access, or native module cache use.

Independent review found that the first accelerator ILA prepare's scalar `connect_bd_net` taps override implicit AXI interface members. Its generated top ties memory S00/S01 requests and M00 responses to constants and omits MIG address/valid connections. The unchanged production ID guard rejected that attempt. A source identity and narrow excerpt are retained; the original full attempt is owned by the board evidence archive. Renaming expected ID nets would have hidden a functional defect and was not used.

The replacement is a passive module-reference interface: all AXI ports are inputs, each has X_INTERFACE_INFO for AXIMM, and exactly one port per interface carries lowercase X_INTERFACE_MODE="monitor". Joining it to the named existing interface net preserves the master/slave connection and adds exactly one Monitor endpoint.

Final fixture a3 passes exact public MODE/endpoint checks and generated-RTL equality for all 37 AXI4 signals (128-bit data, 32-bit address, 5-bit ID) and all19 AXI4-Lite signals (32-bit data/address, no ID). It has zero ordinary warnings, Critical Warnings, or errors. Five copied-RTL negative controls disconnect one endpoint of AWADDR, WDATA, BID, RDATA, and AXI-Lite ARREADY; each is rejected specifically for that signal. These controls test the connectivity checker, not a modified physical implementation.

Exploratory a1 has a checker-regex escaping defect and exits1 after generation; a2 corrects it and passes connectivity but reports two unassigned-address Critical Warnings in the synthetic fixture. Neither is claimed as a clean accepted fixture. Final a3 assigns both synthetic address spaces and fixes the initial clock-port warning. All attempts are retained, no old archive changed.

For production diagnostic integration, preserve the exact existing full-width ID/RTL guard; permit only the explicitly named Monitor endpoint in diagnostic mode and verify MODE=Monitor. Verify all actual generated endpoint signals on the full board design, including AXI-Lite and unequal address-width links, rather than extrapolating fixture widths. Probe packing must use monitor outputs and retain original source mapping. Actual ILA core licensing, clock topology, routed timing and hardware capture remain separate gates.

Primary references:
- https://docs.amd.com/r/2022.1-English/ug994-vivado-ip-subsystems/List-of-Supported-X_-Attributes
- https://docs.amd.com/r/2025.1-English/ug835-vivado-tcl-commands/connect_bd_intf_net
