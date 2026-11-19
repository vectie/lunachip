///|
priv struct Model {
  hw : @ir.Module
  sim : @sim.Simulator
  emitted : @sv.EmittedDesign
  identity : String
  inputs : Map[String, @wave.LogicValue]
}

///|
priv struct Link {
  source : Model
  output : String
  destination : Model
  input : String
}

///|
priv struct Bench {
  core : Model
  control : Model
  bridge : Model
  links : Array[Link]
  ports : ReadOnlyArray[@v.HarnessPort]
  inputs : Map[String, UInt64]
  memory : Map[UInt64, UInt64]
  recording : Bool
  events : Array[@v.AtomicStimulusEvent]
  rows : StringBuilder
  previous : Array[(String, UInt64)]
  mut cycle : Int32
  mut random : UInt32
  mut aw : (UInt64, Int32)?
  wd : Array[(Array[UInt64], UInt64, UInt64, Bool)]
  mut write_fault : UInt64
  mut burst_writes : Int32
  rd : Array[(UInt64, Int32, Bool)]
  lanes : Int32
  mut bd : Int32?
  mut reads : Int32
  group_headers : Array[UInt64]?
  read_addresses : Array[UInt64]?
  mut writes : Int32
  mut read_fault : UInt64
}

///|
fn model(hw : @ir.Module, identity : String) -> Model raise {
  let m = Model::{
    hw,
    identity,
    sim: @sim.Simulator::prepare(hw),
    emitted: @sv.emit_design(@ir.Design::single(identity, hw)),
    inputs: Map([]),
  }
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      m.drive(
        name,
        @wave.LogicValue::from_uint64(
          width=node.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  m
}

///|
fn Model::drive(
  self : Model,
  name : String,
  value : @wave.LogicValue,
) -> Unit raise {
  self.sim.set_input(name, value)
  self.inputs[name] = value
}

///|
fn known(value : @wave.LogicValue) -> UInt64 raise {
  assert_true(value.is_fully_known())
  value.value_bits()
}

///|
fn Model::get(self : Model, name : String) -> UInt64 raise {
  known(self.sim.output(name))
}

///|
fn Bench::drive(self : Bench, name : String, value : UInt64) -> Unit raise {
  self.inputs[name] = value
  let port = self.ports
    .iter()
    .find_first(p => p.is_input() && p.source_name() == name)
    .unwrap()
  let raw = @wave.LogicValue::from_uint64(width=port.width(), value~)
  if name == "clock" || name == "reset" {
    self.control.drive(name, raw)
    self.bridge.drive(name, raw)
    if name == "clock" {
      self.core.drive(name, raw)
    }
  } else if name == "memory_healthy" {
    self.bridge.drive("calibrated", raw)
  } else if name.has_prefix("s_axi_") {
    self.control.drive(
      name,
      if name == "s_axi_awaddr" || name == "s_axi_araddr" {
        @wave.LogicValue::from_uint64(
          width=32,
          value=(value - 0x40000000UL) & 0xffffffffUL,
        )
      } else {
        raw
      },
    )
  } else {
    self.bridge.drive(name, raw)
  }
}

///|
fn Bench::get(self : Bench, name : String) -> UInt64 raise {
  if name.has_prefix("s_axi_") {
    self.control.get(name)
  } else {
    self.bridge.get(name)
  }
}

///|
// Settle only combinational wires. Every model's input snapshot is frozen
// before any sequential update, so coincident edges observe old global state.
fn Bench::settle(self : Bench) -> Unit raise {
  for m in [self.core, self.control, self.bridge] {
    m.sim.settle()
  }
  for _ in 0..<8 {
    let mut changed = false
    for link in self.links {
      let value = link.source.sim.output(link.output)
      if link.destination.inputs[link.input] != value {
        changed = true
        link.destination.drive(link.input, value)
      }
    }
    for m in [self.core, self.control, self.bridge] {
      m.sim.settle()
    }
    if !changed {
      return
    }
  }
  fail("PBlaze3 digital interconnect did not settle")
}

///|
fn bench(
  recording~ : Bool = false,
  streaming~ : Bool = false,
  profile~ : Bool = false,
  vectors~ : Bool = false,
  wide512~ : Bool = false,
  rows64~ : Bool = false,
  banked64~ : Bool = false,
  prefetch256~ : Bool = false,
  scalar_lines~ : Bool = false,
  store_bursts~ : Bool = false,
  chain~ : Bool = false,
  program_bursts~ : Bool = false,
  stream_unary~ : Bool = false,
  staged_decode~ : Bool = false,
  stream_reductions~ : Bool = false,
  paired_rows~ : Bool = false,
  full_rows~ : Bool = false,
  dual_read~ : Bool = false,
  indirect_bf16~ : Bool = false,
  bounded_add~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  read_addresses~ : Array[UInt64]? = None,
  group_headers~ : Array[UInt64]? = None,
) -> Bench raise {
  let core = model(
    if vectors {
      @fp.interleaved_layer_machine(
        memory=GiB2,
        pipelined_vectors=true,
        wide512~,
        rows64~,
        banked64~,
        prefetch256~,
        scalar_lines~,
        store_bursts~,
        stream_unary~,
        staged_decode~,
        stream_reductions~,
        paired_rows~,
        full_rows~,
        dual_read~,
        indirect_bf16~,
        bounded_add~,
        deep_batch~,
        strided_rows~,
      )
    } else {
      @fp.feedback_layer_machine(delivery=true, memory=GiB2)
    },
    "pblaze3-layer-core/v1",
  )
  let control = model(
    @control.controller(
      deep_batch~,
      strided_rows~,
      indirect_bf16~,
      chain~,
      program_bursts~,
      stream_unary~,
      profile~,
      wide512~,
      wide1024=prefetch256,
      scalar_lines~,
      store_bursts~,
    ),
    "pblaze3-layer-control/v1",
  )
  let bridge = model(
    @axi.bridge(
      streaming~,
      wide512~,
      wide1024=prefetch256,
      store_bursts~,
      deep_batch~,
      strided_rows~,
    ),
    "pblaze3-axi/v1",
  )
  let links : Array[Link] = []
  fn link(
    source : Model,
    output : String,
    destination : Model,
    input : String,
  ) -> Unit {
    links.push({ source, output, destination, input, })
  }
  for n in core.hw.nodes() {
    if n.kind() is Input(name) && name != "clock" {
      let source = if name == "reset" {
        "core_reset"
      } else if name == "memory_healthy" || name.has_prefix("ddr_") {
        name + "_to_core"
      } else {
        name
      }
      link(control, source, core, name)
    }
  }
  for n in control.hw.nodes() {
    if n.kind() is Input(name) {
      if name.has_prefix("c_") {
        link(core, name[2:].to_owned(), control, name)
      } else if name == "memory_healthy" {
        link(bridge, name, control, name)
      } else if name.has_prefix("ddr_") {
        link(bridge, name[4:].to_owned(), control, name)
      }
    }
  }
  for n in bridge.hw.nodes() {
    if n.kind() is Input(name) &&
      (name.has_prefix("request_") || name == "response_ready") {
      link(control, "ddr_" + name, bridge, name)
    }
  }
  let ports : Array[@v.HarnessPort] = []
  for m in [control, bridge] {
    for p in @v.collect_ports(m.hw, m.emitted.manifest()) {
      let name = p.source_name()
      if name.has_prefix("s_axi_") ||
        name.has_prefix("m_axi_") ||
        (
          m.hw.name() == control.hw.name() &&
          (name == "clock" || name == "reset" || name == "memory_healthy")
        ) {
        ports.push({
          source_name: name,
          emitted_name: name,
          direction: p.direction,
          width: p.width(),
          signal_type: p.signal_type(),
        })
      }
    }
  }
  let b = Bench::{
    core,
    control,
    bridge,
    links,
    ports: ReadOnlyArray::from_array(ports),
    inputs: Map([]),
    memory: Map([]),
    recording,
    events: [],
    rows: StringBuilder(),
    previous: [],
    cycle: 0,
    random: 0x49f32U,
    aw: None,
    wd: [],
    write_fault: 0UL,
    burst_writes: 0,
    rd: [],
    lanes: if prefetch256 {
      32
    } else if wide512 {
      16
    } else if streaming {
      8
    } else {
      4
    },
    bd: None,
    reads: 0,
    read_addresses,
    group_headers,
    writes: 0,
    read_fault: 0UL,
  }
  for p in @v.input_ports(b.ports) {
    b.drive(p.source_name(), 0UL)
  }
  b.reset()
  b
}

///|
fn Bench::reset(self : Bench) -> Unit raise {
  self.drive("reset", 1UL)
  self.drive("memory_healthy", 0UL)
  for
    name in [
      "s_axi_awvalid", "s_axi_wvalid", "s_axi_arvalid", "s_axi_bready", "s_axi_rready",
    ] {
    self.drive(name, 0UL)
  }
  self.aw = None
  self.wd.clear()
  self.write_fault = 0UL
  self.rd.clear()
  self.bd = None
  self.read_fault = 0UL
  self.previous.clear()
  self.step()
  self.step()
  self.drive("reset", 0UL)
  self.drive("memory_healthy", 1UL)
  self.step()
  assert_eq(self.core.get("busy"), 0UL)
  assert_eq(self.core.get("fault"), 0UL)
}
