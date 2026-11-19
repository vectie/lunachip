///|
// Vendor AXI4 burst master and conversion-mode AXI4-to-Lite boundary.
// Port list follows the generated Vivado 2025.2 instantiation templates.
fn jtag_boundary() -> String {
  let ports = [
    ("awid", 1),
    ("awaddr", 32),
    ("awlen", 8),
    ("awsize", 3),
    ("awburst", 2),
    ("awlock", 1),
    ("awcache", 4),
    ("awprot", 3),
    ("awqos", 4),
    ("awvalid", 1),
    ("awready", 1),
    ("wdata", 32),
    ("wstrb", 4),
    ("wlast", 1),
    ("wvalid", 1),
    ("wready", 1),
    ("bid", 1),
    ("bresp", 2),
    ("bvalid", 1),
    ("bready", 1),
    ("arid", 1),
    ("araddr", 32),
    ("arlen", 8),
    ("arsize", 3),
    ("arburst", 2),
    ("arlock", 1),
    ("arcache", 4),
    ("arprot", 3),
    ("arqos", 4),
    ("arvalid", 1),
    ("arready", 1),
    ("rid", 1),
    ("rdata", 32),
    ("rresp", 2),
    ("rlast", 1),
    ("rvalid", 1),
    ("rready", 1),
  ]
  let text = StringBuilder()
  let master = [".aclk(clk50_global)", ".aresetn(!reset50)"]
  let converter = [
    ".aclk(clk50_global)", ".aresetn(!reset50)", ".s_axi_awregion(4'b0000)", ".s_axi_arregion(4'b0000)",
  ]
  for (name, width) in ports {
    text.write_string("  wire " + range(width) + "j_" + name + ";\n")
    master.push(".m_axi_" + name + "(j_" + name + ")")
    converter.push(".s_axi_" + name + "(j_" + name + ")")
  }
  for
    name in [
      "awaddr", "awprot", "awvalid", "awready", "wdata", "wstrb", "wvalid", "wready",
      "bresp", "bvalid", "bready", "araddr", "arprot", "arvalid", "arready", "rdata",
      "rresp", "rvalid", "rready",
    ] {
    converter.push(
      ".m_axi_" +
      name +
      "(" +
      (if name == "awprot" || name == "arprot" { "" } else { "s_axi_" + name }) +
      ")",
    )
  }
  text.write_string("  prx100_ddr_jtag jtag_i(" + master.join(",") + ");\n")
  text.write_string(
    "  prx100_fpa_protocol protocol_i(" + converter.join(",") + ");\n",
  )
  text.to_string()
}
