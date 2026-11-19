///|
fn bridge_net(name : String) -> String {
  match name {
    "clock" => "clk50_global"
    "ui_clock" => "ui_clk"
    "reset" => "reset50"
    _ =>
      if name.has_prefix("request_") || name.has_prefix("response_") {
        "ddr_" + name
      } else {
        name
      }
  }
}

///|
fn physical_wrapper(
  c : @ir.Module,
  h : @ir.Module,
  e : @systemverilog.EmittedDesign,
) -> String raise {
  let text = StringBuilder()
  text.write_string(physical_header())
  text.write_string(
    (
      #|  wire reset50_async=ui_reset || system_reset;
      #|  (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) reg [3:0] reset50_pipe=4'b1111;
      #|  always @(posedge clk50_global or posedge reset50_async)
      #|    if(reset50_async) reset50_pipe<=4'b1111; else reset50_pipe<={reset50_pipe[2:0],1'b0};
      #|  wire reset50=reset50_pipe[3];
      #|
    ),
  )
  let declared : Map[String, Int32] = Map([])
  fn emit_wire(name : String, width : Int32) -> Unit raise {
    match declared.get(name) {
      Some(old) => assert_eq(width, old)
      None => {
        declared[name] = width
        text.write_string("  wire " + range(width) + name + ";\n")
      }
    }
  }
  let connections : Array[String] = []
  for node in c.nodes() {
    if node.kind() is Input(name) && external_input(name) {
      let net = if name == "clock" {
        "clk50_global"
      } else if name == "reset" {
        "reset50"
      } else {
        name
      }
      if name != "clock" && name != "reset" {
        emit_wire(net, node.signal_type().width().bits())
      }
      connections.push("." + name + "(" + net + ")")
    }
  }
  for p in c.outputs() {
    if external_output(p.name()) {
      emit_wire(p.name(), p.signal_type().width().bits())
      connections.push("." + p.name() + "(" + p.name() + ")")
    }
  }
  let bridge_connections : Array[String] = []
  for node in h.nodes() {
    if node.kind() is Input(name) {
      let net = bridge_net(name)
      if !["clock", "ui_clock", "reset", "ui_reset", "calibrated"].contains(
          name,
        ) {
        emit_wire(net, node.signal_type().width().bits())
      }
      bridge_connections.push(
        "." + mapped(e, name, InputPort) + "(" + net + ")",
      )
    }
  }
  for p in h.outputs() {
    let net = bridge_net(p.name())
    emit_wire(net, p.signal_type().width().bits())
    bridge_connections.push(
      "." + mapped(e, p.name(), OutputPort) + "(" + net + ")",
    )
  }
  text.write_string(
    "  prx100_projection_system system_i(" + connections.join(",") + ");\n",
  )
  text.write_string(
    "  " +
    e.modules()[0].identifier() +
    " bridge_i(" +
    bridge_connections.join(",") +
    ");\n",
  )
  text.write_string(physical_tail())
  text.to_string()
}
