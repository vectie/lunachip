///|
/// Physical pin provenance: supplied io.xdc plus retained MIG pin selection.
/// Dedicated transceiver complementary/RX pins are placed by the PCIe IP.
/// IP owns its generated clock and CDC exceptions. No broad internal timing
/// exception is applied to make timing reports pass.
pub fn constraints() -> String {
  (
    #|# Generated from the supplied PBlaze3 io.xdc; physical identity provisional.
    #|set_property PACKAGE_PIN D27 [get_ports clk_in1_50M]
    #|set_property IOSTANDARD LVCMOS18 [get_ports clk_in1_50M]
    #|# clk_wiz owns the 20ns primary clock on clk_in1_50M in its scoped XDC.
    #|set_property PACKAGE_PIN U8 [get_ports {CLK_IN_D_0_clk_p[0]}]
    #|create_clock -name pcie_ref100 -period 10.000 [get_ports {CLK_IN_D_0_clk_p[0]}]
    #|set_property PACKAGE_PIN L4 [get_ports {pcie_mgt_0_txp[0]}]
    #|set_property PACKAGE_PIN M2 [get_ports {pcie_mgt_0_txp[1]}]
    #|set_property PACKAGE_PIN N4 [get_ports {pcie_mgt_0_txp[2]}]
    #|set_property PACKAGE_PIN P2 [get_ports {pcie_mgt_0_txp[3]}]
    #|set_property PACKAGE_PIN T2 [get_ports {pcie_mgt_0_txp[4]}]
    #|set_property PACKAGE_PIN U4 [get_ports {pcie_mgt_0_txp[5]}]
    #|set_property PACKAGE_PIN V2 [get_ports {pcie_mgt_0_txp[6]}]
    #|set_property PACKAGE_PIN Y2 [get_ports {pcie_mgt_0_txp[7]}]
    #|set_property PACKAGE_PIN V22 [get_ports sys_rst_n_0]
    #|set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n_0]
    #|set_property PULLUP true [get_ports sys_rst_n_0]
    #|set_property PACKAGE_PIN T20 [get_ports {led[2]}]
    #|set_property PACKAGE_PIN T21 [get_ports {led[1]}]
    #|set_property PACKAGE_PIN R24 [get_ports {led[0]}]
    #|set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]
    #|# LEDs have no synchronous off-chip receiver. This exception ends at ports.
    #|set_false_path -to [get_ports {led[*]}]
    #|set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
    #|set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
    #|set_property CFGBVS VCCO [current_design]
    #|set_property CONFIG_VOLTAGE 3.3 [current_design]
    #|
  )
}
