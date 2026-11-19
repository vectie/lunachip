///|
fn export_mig_reader(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh MIG reader directory") }
  @fs.create_dir(root)
  let design = @ir.Design::single(
    "pblaze3-mig-read-benchmark/v1",
    @memtest.mig_reader(),
  )
  let e = @sv.emit_design(design)
  let decl : Array[String] = [
    "(* X_INTERFACE_INFO=\"xilinx.com:signal:clock:1.0 clock CLK\", X_INTERFACE_PARAMETER=\"XIL_INTERFACENAME clock, ASSOCIATED_BUSIF M_AXI, ASSOCIATED_RESET reset, FREQ_HZ 200000000\" *) input wire clock",
    "(* X_INTERFACE_INFO=\"xilinx.com:signal:reset:1.0 reset RST\", X_INTERFACE_PARAMETER=\"XIL_INTERFACENAME reset, POLARITY ACTIVE_HIGH\" *) input wire reset",
    "input wire calibrated,start", "input wire [1:0] mode", "output wire [5:0] flags",
    "output wire [31:0] cycles,beats,requests,bursts,checksum",
  ]
  let sb = StringBuilder()
  sb.write_string(normalize(optimized(e.source())))
  let fixed = StringBuilder()
  for
    (name, width, dir, constant) in [
      ("awid", 1, "output", 0),
      ("awaddr", 31, "output", 0),
      ("awlen", 8, "output", 0),
      ("awsize", 3, "output", 6),
      ("awburst", 2, "output", 1),
      ("awlock", 1, "output", 0),
      ("awcache", 4, "output", 3),
      ("awprot", 3, "output", 0),
      ("awqos", 4, "output", 0),
      ("awvalid", 1, "output", 0),
      ("awready", 1, "input", -1),
      ("wdata", 512, "output", 0),
      ("wstrb", 64, "output", 0),
      ("wlast", 1, "output", 0),
      ("wvalid", 1, "output", 0),
      ("wready", 1, "input", -1),
      ("bid", 1, "input", -1),
      ("bresp", 2, "input", -1),
      ("bvalid", 1, "input", -1),
      ("bready", 1, "output", 1),
      ("arid", 1, "output", 0),
      ("araddr", 31, "output", -1),
      ("arlen", 8, "output", -1),
      ("arsize", 3, "output", 6),
      ("arburst", 2, "output", 1),
      ("arlock", 1, "output", 0),
      ("arcache", 4, "output", 3),
      ("arprot", 3, "output", 0),
      ("arqos", 4, "output", 0),
      ("arvalid", 1, "output", -1),
      ("arready", 1, "input", -1),
      ("rid", 1, "input", -1),
      ("rdata", 512, "input", -1),
      ("rresp", 2, "input", -1),
      ("rlast", 1, "input", -1),
      ("rvalid", 1, "input", -1),
      ("rready", 1, "output", -1),
    ] {
    let param = if name == "awaddr" {
      ", X_INTERFACE_PARAMETER=\"XIL_INTERFACENAME M_AXI, PROTOCOL AXI4, DATA_WIDTH 512, ADDR_WIDTH 31, ID_WIDTH 1, READ_WRITE_MODE READ_WRITE, MAX_BURST_LENGTH 64, NUM_READ_OUTSTANDING 16, NUM_WRITE_OUTSTANDING 1, SUPPORTS_NARROW_BURST 0\""
    } else {
      ""
    }
    let size = if width == 1 { "" } else { "[\{width-1}:0] " }
    decl.push(
      "(* X_INTERFACE_INFO=\"xilinx.com:interface:aximm:1.0 M_AXI " +
      name.to_upper() +
      "\"" +
      param +
      " *) " +
      dir +
      " wire " +
      size +
      "axi_" +
      name,
    )
    if constant >= 0 {
      fixed.write_string("assign axi_" + name + " = \{width}'d\{constant};\n")
    }
  }
  sb.write_string(
    "\nmodule mig_read_probe(\n" +
    decl.join(",\n") +
    "\n);\n" +
    fixed.to_string(),
  )
  let pins : Array[String] = []
  for
    name in [
      "clock", "reset", "calibrated", "mode", "start", "arready", "rvalid", "rlast",
      "rresp", "rid", "sample", "arvalid", "araddr", "arlen", "rready", "flags",
      "cycles", "beats", "requests", "bursts", "checksum",
    ] {
    let pin = match name {
      "sample" => "axi_rdata[31:0]"
      "arready"
      | "rvalid"
      | "rlast"
      | "rresp"
      | "rid"
      | "arvalid"
      | "araddr"
      | "arlen"
      | "rready" => "axi_" + name
      _ => name
    }
    let output = [
      "arvalid", "araddr", "arlen", "rready", "flags", "cycles", "beats", "requests",
      "bursts", "checksum",
    ].contains(name)
    pins.push(
      "." +
      mapped(e, name, if output { OutputPort } else { InputPort }) +
      "(" +
      pin +
      ")",
    )
  }
  sb.write_string(
    e.modules()[0].identifier() +
    " counter(\n" +
    pins.join(",\n") +
    "\n);\nendmodule\n",
  )
  save(root, "reader.sv", sb.to_string())
  save(root, "reader.lcir", @codec.serialize(design))
}
