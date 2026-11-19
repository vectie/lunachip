///|
fn range(width : Int32) -> String {
  if width == 1 {
    ""
  } else {
    "[" + (width - 1).to_string() + ":0] "
  }
}

///|
fn interface_attribute(name : String, data_bits : Int32) -> String {
  let (bus, signal) = if name.has_prefix("s_axi_") {
    ("S_AXI_CTRL", name[6:].to_owned().to_upper())
  } else {
    ("M_AXI_DDR", name[6:].to_owned().to_upper())
  }
  let parameter = if name == "s_axi_awaddr" {
    "  (* X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME S_AXI_CTRL, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 32, READ_WRITE_MODE READ_WRITE\" *)\n"
  } else if name == "m_axi_awaddr" {
    let burst = if data_bits == 1024 {
      4
    } else if data_bits >= 256 {
      1024 / data_bits
    } else {
      1
    }
    let outstanding = if data_bits >= 256 { 16 } else { 1 }
    "  (* X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME M_AXI_DDR, PROTOCOL AXI4, DATA_WIDTH \{data_bits}, ADDR_WIDTH 32, ID_WIDTH 0, READ_WRITE_MODE READ_WRITE, MAX_BURST_LENGTH \{burst}, NUM_READ_OUTSTANDING \{outstanding}, NUM_WRITE_OUTSTANDING 1\" *)\n"
  } else {
    ""
  }
  parameter +
  "  (* X_INTERFACE_INFO = \"xilinx.com:interface:aximm:1.0 " +
  bus +
  " " +
  signal +
  "\" *)\n"
}

///|
/// Wire the emitted core, controller and AXI bridge into the vendor-facing
/// digital shell. AXI-Lite addresses use the 0x40000000 translated bus base.
pub fn wrapper(
  core : @ir.Module,
  ce : @sv.EmittedDesign,
  control : @ir.Module,
  se : @sv.EmittedDesign,
  bridge : @ir.Module,
  be : @sv.EmittedDesign,
) -> String raise {
  let declarations : Array[String] = [
    "  (* X_INTERFACE_INFO = \"xilinx.com:signal:clock:1.0 clock CLK\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME clock, ASSOCIATED_BUSIF S_AXI_CTRL:M_AXI_DDR, ASSOCIATED_RESET reset, FREQ_HZ 33333333\" *)\n  input wire clock",
    "  (* X_INTERFACE_INFO = \"xilinx.com:signal:reset:1.0 reset RST\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME reset, POLARITY ACTIVE_HIGH\" *)\n  input wire reset",
    "  input wire memory_healthy",
  ]
  let lanes = bridge
    .outputs()
    .iter()
    .filter(p => p.name().has_prefix("m_axi_wword"))
    .count()
  guard lanes == 4 || lanes == 8 || lanes == 16 || lanes == 32 else {
    fail("unexpected AXI width")
  }
  let data_bits = lanes * 32
  let ordered = core.outputs().iter().any(p => p.name() == "mac_issue")
  if ordered {
    declarations.push(
      "  (* X_INTERFACE_INFO = \"xilinx.com:signal:clock:1.0 mac_clock CLK\" *) input wire mac_clock",
    )
  }
  fn data_lane(bus : String, name : String) -> String raise {
    for i in 0..<lanes {
      if name == "m_axi_rword" + i.to_string() ||
        name == "m_axi_wword" + i.to_string() {
        return "\{bus}[\{32*i+31}:\{32*i}]"
      }
    }
    fail("unexpected AXI lane " + name)
  }
  fn port(name : String, bits : Int32, direction : String) -> Unit {
    declarations.push(
      interface_attribute(name, data_bits) +
      "  " +
      direction +
      " wire " +
      range(bits) +
      name,
    )
  }
  for node in control.nodes() {
    if node.kind() is Input(name) && name.has_prefix("s_axi_") {
      port(name, node.signal_type().width().bits(), "input")
    }
  }
  for p in control.outputs() {
    if p.name().has_prefix("s_axi_") {
      port(p.name(), p.signal_type().width().bits(), "output")
    } else if p.name() == "observe_weight_owned" {
      declarations.push("  output wire profile_weight_owned")
    }
  }
  for node in bridge.nodes() {
    if node.kind() is Input(name) &&
      name.has_prefix("m_axi_") &&
      !name.has_prefix("m_axi_rword") {
      port(name, node.signal_type().width().bits(), "input")
    }
  }
  for p in bridge.outputs() {
    if lanes == 32 && p.name().has_prefix("m_axi_wstrb") {
      if p.name() == "m_axi_wstrb" {
        port(p.name(), 128, "output")
      }
    } else if p.name().has_prefix("m_axi_") &&
      !p.name().has_prefix("m_axi_wword") {
      port(p.name(), p.signal_type().width().bits(), "output")
    }
  }
  port("m_axi_wdata", data_bits, "output")
  port("m_axi_rdata", data_bits, "input")
  let text = StringBuilder()
  text.write_string(
    "`default_nettype none\nmodule pblaze3_layer_system(\n" +
    declarations.join(",\n") +
    "\n);\n",
  )
  let nets : Map[String, Int32] = Map([])
  fn wire(name : String, width : Int32) -> Unit raise {
    match nets.get(name) {
      Some(old) => assert_eq(old, width)
      None => {
        nets[name] = width
        text.write_string("  wire " + range(width) + name + ";\n")
      }
    }
  }
  wire("core_reset", 1)
  wire("bridge_healthy", 1)
  for node in core.nodes() {
    if node.kind() is Input(name) && name != "clock" && name != "reset" {
      wire("d_" + name, node.signal_type().width().bits())
    }
  }
  for p in core.outputs() {
    wire("d_" + p.name(), p.signal_type().width().bits())
  }
  for node in control.nodes() {
    if node.kind() is Input(name) && name.has_prefix("ddr_") {
      wire(name, node.signal_type().width().bits())
    }
  }
  for p in control.outputs() {
    if p.name().has_prefix("ddr_") && !p.name().has_suffix("_to_core") {
      wire(p.name(), p.signal_type().width().bits())
    }
  }
  let core_ports : Array[String] = []
  for node in core.nodes() {
    if node.kind() is Input(name) {
      let net = if name == "clock" {
        "clock"
      } else if name == "reset" {
        "core_reset"
      } else {
        "d_" + name
      }
      core_ports.push("." + mapped(ce, name, InputPort) + "(" + net + ")")
    }
  }
  for p in core.outputs() {
    core_ports.push(
      "." + mapped(ce, p.name(), OutputPort) + "(d_" + p.name() + ")",
    )
  }
  text.write_string(
    "  " +
    ce.modules()[0].identifier() +
    " core_i(" +
    core_ports.join(",") +
    ");\n",
  )
  let control_ports : Array[String] = []
  for node in control.nodes() {
    if node.kind() is Input(name) {
      let net = if name.has_prefix("c_") {
        "d_" + name[2:].to_owned()
      } else if name == "memory_healthy" {
        "bridge_healthy"
      } else if name == "s_axi_awaddr" || name == "s_axi_araddr" {
        "(" + name + " - 32'h40000000)"
      } else {
        name
      }
      control_ports.push("." + mapped(se, name, InputPort) + "(" + net + ")")
    }
  }
  for p in control.outputs() {
    let name = p.name()
    let net = if name == "observe_weight_owned" {
      "profile_weight_owned"
    } else if name.has_prefix("observe_") {
      let unused = "unused_" + name
      wire(unused, p.signal_type().width().bits())
      unused
    } else if name.has_suffix("_to_core") {
      "d_" + name[:name.length() - 8].to_owned()
    } else if name.has_prefix("s_axi_") ||
      name.has_prefix("ddr_") ||
      name == "core_reset" {
      name
    } else {
      "d_" + name
    }
    control_ports.push("." + mapped(se, name, OutputPort) + "(" + net + ")")
  }
  text.write_string(
    "  " +
    se.modules()[0].identifier() +
    " control_i(" +
    control_ports.join(",") +
    ");\n",
  )
  let bridge_ports : Array[String] = []
  for node in bridge.nodes() {
    if node.kind() is Input(name) {
      let net = if name == "calibrated" {
        "memory_healthy"
      } else if name.has_prefix("request_") || name == "response_ready" {
        "ddr_" + name
      } else if name.has_prefix("m_axi_rword") {
        data_lane("m_axi_rdata", name)
      } else {
        name
      }
      bridge_ports.push("." + mapped(be, name, InputPort) + "(" + net + ")")
    }
  }
  for p in bridge.outputs() {
    let name = p.name()
    let net = if name == "memory_healthy" {
      "bridge_healthy"
    } else if name == "bridge_poisoned" || name == "response_wide" {
      let unused = "unused_" + name
      wire(unused, p.signal_type().width().bits())
      unused
    } else if name.has_prefix("request_") || name.has_prefix("response_") {
      "ddr_" + name
    } else if lanes == 32 && name == "m_axi_wstrb" {
      "m_axi_wstrb[63:0]"
    } else if lanes == 32 && name == "m_axi_wstrb_hi" {
      "m_axi_wstrb[127:64]"
    } else if name.has_prefix("m_axi_wword") {
      data_lane("m_axi_wdata", name)
    } else {
      name
    }
    bridge_ports.push("." + mapped(be, name, OutputPort) + "(" + net + ")")
  }
  text.write_string(
    "  " +
    be.modules()[0].identifier() +
    " bridge_i(" +
    bridge_ports.join(",") +
    ");\n",
  )
  if ordered {
    let weights = Array::makei(64, i => "d_mac_weight" + (63 - i).to_string()).join(
      ",",
    )
    let sums = Array::makei(64, i => "d_mac_sum" + (63 - i).to_string()).join(
      ",",
    )
    text.write_string(
      "  ordered_clock_bridge matrix_i(.clock(clock),.mac_clock(mac_clock),.reset(core_reset),.flush(d_mac_flush),.credit(d_mac_credit),.fault(d_mac_fault),.issue(d_mac_issue),.slot(d_mac_slot),.phase(d_mac_phase),.first(d_mac_first),.last_col(d_mac_last),.activation(d_mac_activation),.weights({" +
      weights +
      "}),.retire(d_mac_retire),.retired_slot(d_mac_retired_slot),.sums({" +
      sums +
      "}));\n",
    )
  }
  text.write_string("endmodule\n`default_nettype wire\n")
  text.to_string()
}

///|
fn mapped(
  e : @sv.EmittedDesign,
  name : String,
  kind : @sv.SymbolKind,
) -> String raise {
  for item in e.manifest().mappings() {
    if item.kind() == kind && item.source_name() == name {
      return item.identifier()
    }
  }
  fail("missing emitted port " + name)
}
