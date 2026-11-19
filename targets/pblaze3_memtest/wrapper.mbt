///|
fn range(width : Int32) -> String {
  if width == 1 {
    ""
  } else {
    "[" + (width - 1).to_string() + ":0] "
  }
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

///|
/// Structural connection of canonical controller and unchanged AXI bridge.
/// The board owns calibration synchronization, coordinated reset and AXI CDC.
pub fn wrapper(
  control : @ir.Module,
  ce : @sv.EmittedDesign,
  bridge : @ir.Module,
  be : @sv.EmittedDesign,
  replay~ : Bool = false,
) -> String raise {
  let declarations : Array[String] = [
    "  (* X_INTERFACE_INFO = \"xilinx.com:signal:clock:1.0 clock CLK\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME clock, ASSOCIATED_BUSIF M_AXI_DDR, ASSOCIATED_RESET reset, FREQ_HZ 50000000\" *)\n  input wire clock",
    "  (* X_INTERFACE_INFO = \"xilinx.com:signal:reset:1.0 reset RST\", X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME reset, POLARITY ACTIVE_HIGH\" *)\n  input wire reset",
    "  input wire calibrated", "  output wire [31:0] status0", "  output wire [31:0] status1",
  ]
  fn port(name : String, width : Int32, direction : String) -> Unit {
    let attrs = if name == "m_axi_awaddr" {
      "  (* X_INTERFACE_PARAMETER = \"XIL_INTERFACENAME M_AXI_DDR, PROTOCOL AXI4, DATA_WIDTH 128, ADDR_WIDTH 32, ID_WIDTH " +
      (if replay { "0" } else { "4" }) +
      ", SUPPORTS_NARROW_BURST 0, READ_WRITE_MODE READ_WRITE, MAX_BURST_LENGTH 1, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1\" *)\n"
    } else {
      ""
    }
    declarations.push(
      attrs +
      "  (* X_INTERFACE_INFO = \"xilinx.com:interface:aximm:1.0 M_AXI_DDR " +
      name[6:].to_owned().to_upper() +
      "\" *)\n  " +
      direction +
      " wire " +
      range(width) +
      name,
    )
  }
  for node in bridge.nodes() {
    if node.kind() is Input(name) &&
      name.has_prefix("m_axi_") &&
      (replay || !name.has_prefix("m_axi_rword")) {
      port(name, node.signal_type().width().bits(), "input")
    }
  }
  for p in bridge.outputs() {
    if p.name().has_prefix("m_axi_") &&
      (replay || !p.name().has_prefix("m_axi_wword")) {
      port(p.name(), p.signal_type().width().bits(), "output")
    }
  }
  if replay {
    for p in control.outputs() {
      if p.name() != "status0" && p.name() != "status1" {
        declarations.push(
          "  output wire " + range(p.signal_type().width().bits()) + p.name(),
        )
      }
    }
  } else {
    port("m_axi_wdata", 128, "output")
    port("m_axi_rdata", 128, "input")
    port("m_axi_awid", 4, "output")
    port("m_axi_arid", 4, "output")
    port("m_axi_bid", 4, "input")
    port("m_axi_rid", 4, "input")
  }
  let text = StringBuilder()
  text.write_string(
    "`default_nettype none\nmodule pblaze3_memtest_system(\n" +
    declarations.join(",\n") +
    "\n);\n",
  )
  if !replay {
    text.write_string(
      "  assign m_axi_awid = 4'b0000;\n  assign m_axi_arid = 4'b0000;\n  wire [7:0] unused_response_ids = {m_axi_bid,m_axi_rid};\n",
    )
  }
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
  for node in control.nodes() {
    if node.kind() is Input(name) &&
      name != "clock" &&
      name != "reset" &&
      name != "calibrated" {
      wire("d_" + name, node.signal_type().width().bits())
    }
  }
  fn control_net(name : String) -> String {
    if name == "status0" || name == "status1" || replay {
      name
    } else if name.has_prefix("request_") || name == "response_ready" {
      "d_" + name
    } else {
      "unused_d_" + name
    }
  }
  for p in control.outputs() {
    if !replay && p.name() != "status0" && p.name() != "status1" {
      wire(control_net(p.name()), p.signal_type().width().bits())
    }
  }
  let controller_ports : Array[String] = []
  for node in control.nodes() {
    if node.kind() is Input(name) {
      let net = if name == "clock" || name == "reset" || name == "calibrated" {
        name
      } else {
        "d_" + name
      }
      controller_ports.push("." + mapped(ce, name, InputPort) + "(" + net + ")")
    }
  }
  for p in control.outputs() {
    let name = p.name()
    controller_ports.push(
      "." + mapped(ce, name, OutputPort) + "(" + control_net(name) + ")",
    )
  }
  text.write_string(
    "  " +
    ce.modules()[0].identifier() +
    " controller_i(" +
    controller_ports.join(",") +
    ");\n",
  )
  let bridge_ports : Array[String] = []
  for node in bridge.nodes() {
    if node.kind() is Input(name) {
      let net = if name.has_prefix("request_") || name == "response_ready" {
        control_net(name)
      } else if name.has_prefix("m_axi_rword") && !replay {
        let lane = match name[name.length() - 1:].to_owned() {
          "0" => 0
          "1" => 1
          "2" => 2
          "3" => 3
          _ => fail("unexpected lane")
        }
        "m_axi_rdata[" +
        (lane * 32 + 31).to_string() +
        ":" +
        (lane * 32).to_string() +
        "]"
      } else {
        name
      }
      bridge_ports.push("." + mapped(be, name, InputPort) + "(" + net + ")")
    }
  }
  for p in bridge.outputs() {
    let name = p.name()
    let net = if name.has_prefix("m_axi_wword") && !replay {
      let lane = match name[name.length() - 1:].to_owned() {
        "0" => 0
        "1" => 1
        "2" => 2
        "3" => 3
        _ => fail("unexpected lane")
      }
      "m_axi_wdata[" +
      (lane * 32 + 31).to_string() +
      ":" +
      (lane * 32).to_string() +
      "]"
    } else if name.has_prefix("m_axi_") {
      name
    } else {
      let used = control
        .nodes()
        .iter()
        .any(n => n.kind() is Input(input_name) && input_name == name)
      let net = (if used { "d_" } else { "unused_d_" }) + name
      wire(net, p.signal_type().width().bits())
      net
    }
    bridge_ports.push("." + mapped(be, name, OutputPort) + "(" + net + ")")
  }
  text.write_string(
    "  " +
    be.modules()[0].identifier() +
    " bridge_i(" +
    bridge_ports.join(",") +
    ");\nendmodule\n`default_nettype wire\n",
  )
  text.to_string()
}
