///|
fn export_mig_monitor(root : String) -> Unit raise {
  guard !@fs.path_exists(root) else { fail("fresh output directory required") }
  let hardware = @target.mig_monitor()
  let design = @ir.Design::single("pblaze3-mig-monitor/v1", hardware)
  let emitted = @sv.emit_design(design) catch {
    @sv.UnreachableNode(module_name~, node~) =>
      fail("unreachable \{node} in \{module_name}")
    e => raise e
  }
  let declarations : Array[String] = []
  let connections : Array[String] = []
  fn port(
    name : String,
    width : Int32,
    direction : String,
    kind : @sv.SymbolKind,
  ) -> Unit raise {
    let attr = if name == "clock" {
      "(* X_INTERFACE_INFO = \"xilinx.com:signal:clock:1.0 clock CLK\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME clock, ASSOCIATED_BUSIF S_AXI:MIG_MON:NARROW_MON:WIDE_MON, ASSOCIATED_RESET reset, FREQ_HZ 200000000\" *) "
    } else if name == "reset" {
      "(* X_INTERFACE_INFO = \"xilinx.com:signal:reset:1.0 reset RST\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME reset, POLARITY ACTIVE_HIGH\" *) "
    } else if name.has_prefix("s_axi_") {
      "(* X_INTERFACE_INFO = \"xilinx.com:interface:aximm:1.0 S_AXI " +
      name[6:].to_owned().to_upper() +
      "\" *) "
    } else if name.has_prefix("mig_") ||
      name.has_prefix("wide_") ||
      name.has_prefix("narrow_") {
      let (bus, pin) = name.split_once("_").unwrap()
      if pin.has_suffix("select") && bus != "mig" {
        ""
      } else {
        let logical = pin.to_owned().replace(old="select", new="id").to_upper()
        let interface = bus.to_owned().to_upper() + "_MON"
        let width = if bus == "wide" { 1024 } else { 512 }
        let address = if bus == "mig" { 31 } else { 32 }
        let id = if bus == "mig" { 1 } else { 0 }
        let mode = if pin == "arvalid" {
          "X_INTERFACE_MODE = \"monitor\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME \{interface}, PROTOCOL AXI4, DATA_WIDTH \{width}, ADDR_WIDTH \{address}, ID_WIDTH \{id}, READ_WRITE_MODE READ_WRITE, SUPPORTS_NARROW_BURST 1\", "
        } else {
          ""
        }
        "(* " +
        mode +
        "X_INTERFACE_INFO = \"xilinx.com:interface:aximm:1.0 \{interface} \{logical}\" *) "
      }
    } else {
      ""
    }
    let range = if width == 1 { "" } else { "[\{width - 1}:0] " }
    declarations.push(attr + direction + " wire " + range + name)
    connections.push("." + mapped(emitted, name, kind) + "(" + name + ")")
  }
  for node in hardware.nodes() {
    if node.kind() is Input(name) {
      port(name, node.signal_type().width().bits(), "input", InputPort)
    }
  }
  for output in hardware.outputs() {
    port(
      output.name(),
      output.signal_type().width().bits(),
      "output",
      OutputPort,
    )
  }
  // Native monitor interfaces mirror the source bus contract. Payload and
  // write-channel boundary wires are unused by these read-only counters.
  for prefix in ["mig", "narrow", "wide"] {
    let address = if prefix == "mig" { 31 } else { 32 }
    let data = if prefix == "wide" { 1024 } else { 512 }
    for
      (pin, bits) in [
        ("ARADDR", address),
        ("RDATA", data),
        ("RRESP", 2),
        ("ARLEN", 8),
        ("ARSIZE", 3),
        ("ARBURST", 2),
        ("AWADDR", address),
        ("WDATA", data),
        ("WSTRB", data / 8),
        ("BRESP", 2),
        ("AWVALID", 1),
        ("AWREADY", 1),
        ("WVALID", 1),
        ("WREADY", 1),
        ("BVALID", 1),
        ("BREADY", 1),
        ("WLAST", 1),
        ("AWLEN", 8),
        ("AWSIZE", 3),
        ("AWBURST", 2),
      ] {
      declarations.push(
        "(* X_INTERFACE_INFO = \"xilinx.com:interface:aximm:1.0 \{prefix.to_upper()}_MON \{pin}\" *) input wire [\{bits-1}:0] \{prefix}_\{pin.to_lower()}",
      )
    }
  }
  @fs.create_dir(root)
  save(root, "monitor.lcir", @codec.serialize(design))
  guard hardware.cdc_primitives()[:] is [BitSynchronizer(sync)] else {
    fail("one scope synchronizer")
  }
  let mut rtl = normalize(emitted.source())
  for node in sync.stages() {
    let decl = "  logic lc_n\{node.ordinal()};"
    assert_eq(rtl.split(decl).count(), 2)
    rtl = rtl.replace(
      old=decl,
      new="  (* ASYNC_REG = \"TRUE\", SHREG_EXTRACT = \"NO\" *) logic lc_n\{node.ordinal()};",
    )
  }
  save(root, "monitor-core.sv", rtl)
  let first = sync.stages()[0].ordinal()
  save(
    root,
    "monitor-cdc.xdc",
    "set_false_path -to [get_pins -hierarchical -filter {NAME =~ */mig_profile/inst/observer/lc_n\{first}_reg/D}]\n",
  )
  save(
    root,
    "pblaze3_mig_monitor.sv",
    "`default_nettype none\nmodule pblaze3_mig_monitor(\n" +
    declarations.join(",\n") +
    "\n);\n" +
    emitted.modules()[0].identifier() +
    " observer(" +
    connections.join(",") +
    ");\nendmodule\n`default_nettype wire\n",
  )
  println("exported passive MIG observer " + root)
}
