///|
fn range(width : Int32) -> String {
  if width == 1 {
    ""
  } else {
    "[" + (width - 1).to_string() + ":0] "
  }
}

///|
fn external_input(name : String) -> Bool {
  !name.has_prefix("c_")
}

///|
fn external_output(name : String) -> Bool {
  name.has_prefix("s_axi_") ||
  name.has_prefix("ddr_") ||
  name.has_prefix("observe_")
}

///|
fn core_wrapper(
  hw : @ir.Module,
  e : @sv.EmittedDesign,
  c : @ir.Module,
  ce : @sv.EmittedDesign,
) -> String raise {
  let text = StringBuilder()
  let ports : Array[String] = []
  for node in c.nodes() {
    if node.kind() is Input(name) && external_input(name) {
      ports.push(
        "input wire " + range(node.signal_type().width().bits()) + name,
      )
    }
  }
  for p in c.outputs() {
    if external_output(p.name()) {
      ports.push(
        "output wire " + range(p.signal_type().width().bits()) + p.name(),
      )
    }
  }
  text.write_string(
    "`default_nettype none\nmodule prx100_fpl_system(\n  " +
    ports.join(",\n  ") +
    ");\n",
  )
  text.write_string("  wire core_reset;\n")
  for node in hw.nodes() {
    if node.kind() is Input(name) && name != "clock" && name != "reset" {
      text.write_string(
        "  wire " +
        range(node.signal_type().width().bits()) +
        "d_" +
        name +
        ";\n",
      )
    }
  }
  for p in hw.outputs() {
    text.write_string(
      "  wire " +
      range(p.signal_type().width().bits()) +
      "d_" +
      p.name() +
      ";\n",
    )
  }
  let cc : Array[String] = []
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      let net = if name == "clock" {
        "clock"
      } else if name == "reset" {
        "core_reset"
      } else {
        "d_" + name
      }
      cc.push("." + mapped(e, name, InputPort) + "(" + net + ")")
    }
  }
  for p in hw.outputs() {
    cc.push("." + mapped(e, p.name(), OutputPort) + "(d_" + p.name() + ")")
  }
  text.write_string(
    "  " + e.modules()[0].identifier() + " core_i(" + cc.join(",") + ");\n",
  )
  let sc : Array[String] = []
  for node in c.nodes() {
    if node.kind() is Input(name) {
      let net = if name.has_prefix("c_") {
        "d_" + name[2:].to_owned()
      } else {
        name
      }
      sc.push("." + mapped(ce, name, InputPort) + "(" + net + ")")
    }
  }
  for p in c.outputs() {
    let net = if external_output(p.name()) || p.name() == "core_reset" {
      p.name()
    } else {
      "d_" + p.name()
    }
    sc.push("." + mapped(ce, p.name(), OutputPort) + "(" + net + ")")
  }
  text.write_string(
    "  " +
    ce.modules()[0].identifier() +
    " sequencer_i(" +
    sc.join(",") +
    ");\nendmodule\n`default_nettype wire\n",
  )
  text.to_string()
}

///|
fn preserve_bridge(hw : @ir.Module, e : @sv.EmittedDesign) -> String raise {
  let ids : Array[Int32] = []
  for primitive in hw.cdc_primitives() {
    let stages = match primitive {
      BitSynchronizer(s) => s.stages().iter().to_array()
      AsyncFifo(f) => {
        let nodes = f.read_gray_stages().iter().to_array()
        for id in f.write_gray_stages() {
          nodes.push(id)
        }
        nodes
      }
      _ => fail("unexpected bridge CDC primitive")
    }
    for id in stages {
      ids.push(id.ordinal())
    }
  }
  assert_eq(ids.length(), 10)
  let mut source = normalize(e.modules()[0].source())
  for id in ids {
    let m = e
      .manifest()
      .mappings()
      .iter()
      .find_first(m => m.kind() == Node && m.local_ordinal() == id)
      .unwrap()
    let node = hw.nodes()[id]
    let declaration = "  logic " +
      range(node.signal_type().width().bits()) +
      m.identifier() +
      ";"
    assert_eq(source.split(declaration).count(), 2)
    source = source.replace(
      old=declaration,
      new="  (* ASYNC_REG = \"TRUE\", SHREG_EXTRACT = \"NO\" *) logic " +
        range(node.signal_type().width().bits()) +
        m.identifier() +
        ";",
    )
  }
  source
}
