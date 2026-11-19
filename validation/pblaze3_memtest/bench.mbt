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
  control : Model
  bridge : Model
  links : Array[Link]
  ports : ReadOnlyArray[@v.HarnessPort]
  inputs : Map[String, UInt64]
  memory : Map[UInt64, UInt64]
  events : Array[@v.AtomicStimulusEvent]
  rows : StringBuilder
  cases : Array[Json]
  previous : Array[(String, UInt64)]
  beats : UInt64
  base : UInt64
  mut cycle : Int32
  mut random : UInt32
  mut aw : UInt64?
  mut wd : Array[UInt64]?
  mut rd : (UInt64, Int32)?
  mut bd : Int32?
  mut writes : UInt64
  mut reads : UInt64
  mut alias_mask : UInt64
  mut corrupt_address : UInt64?
  mut read_fault : UInt64
  mut write_fault : UInt64
  mut bad_last : Bool
  mut aw_pause : Bool
  mut w_pause : Bool
  mut ar_pause : Bool
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
fn Model::get(self : Model, name : String) -> UInt64 raise {
  let v = self.sim.output(name)
  assert_true(v.is_fully_known(), msg=name)
  v.value_bits()
}

///|
fn Bench::drive(self : Bench, name : String, value : UInt64) -> Unit raise {
  self.inputs[name] = value
  let port = self.ports
    .iter()
    .find_first(p => p.is_input() && p.source_name() == name)
    .unwrap()
  let raw = @wave.LogicValue::from_uint64(width=port.width(), value~)
  if name == "clock" || name == "reset" || name == "calibrated" {
    self.control.drive(name, raw)
    self.bridge.drive(name, raw)
  } else {
    self.bridge.drive(name, raw)
  }
}

///|
fn Bench::get(self : Bench, name : String) -> UInt64 raise {
  if name.has_prefix("m_axi_") {
    self.bridge.get(name)
  } else {
    self.control.get(name)
  }
}

///|
fn Bench::settle(self : Bench) -> Unit raise {
  for m in [self.control, self.bridge] {
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
    for m in [self.control, self.bridge] {
      m.sim.settle()
    }
    if !changed {
      return
    }
  }
  fail("memtest interconnect did not settle")
}

///|
fn bench(high : Bool) -> Bench raise {
  let beats = 16U
  let base = if high { 0x7fffff00U } else { 0U }
  let control = model(
    @memtest.controller(beats~, base_address=base),
    "pblaze3-memtest/v1",
  )
  let bridge = model(@axi.bridge(), "pblaze3-axi/v1")
  let links : Array[Link] = []
  for n in control.hw.nodes() {
    if n.kind() is Input(name) &&
      name != "clock" &&
      name != "reset" &&
      name != "calibrated" {
      links.push({
        source: bridge,
        output: name,
        destination: control,
        input: name,
      })
    }
  }
  for n in bridge.hw.nodes() {
    if n.kind() is Input(name) &&
      (name.has_prefix("request_") || name == "response_ready") {
      links.push({
        source: control,
        output: name,
        destination: bridge,
        input: name,
      })
    }
  }
  let ports : Array[@v.HarnessPort] = []
  for m in [control, bridge] {
    for p in @v.collect_ports(m.hw, m.emitted.manifest()) {
      let name = p.source_name()
      if (
          m.hw.name() == control.hw.name() &&
          (!p.is_input() || ["clock", "reset", "calibrated"].contains(name))
        ) ||
        name.has_prefix("m_axi_") {
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
    control,
    bridge,
    links,
    ports: ReadOnlyArray::from_array(ports),
    inputs: Map([]),
    memory: Map([]),
    events: [],
    rows: StringBuilder(),
    cases: [],
    previous: [],
    beats: beats.to_uint64(),
    base: base.to_uint64(),
    cycle: 0,
    random: 0x671293U,
    aw: None,
    wd: None,
    rd: None,
    bd: None,
    writes: 0UL,
    reads: 0UL,
    alias_mask: 0xffffffffUL,
    corrupt_address: None,
    read_fault: 0UL,
    write_fault: 0UL,
    bad_last: false,
    aw_pause: false,
    w_pause: false,
    ar_pause: false,
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
  self.drive("calibrated", 0UL)
  self.aw = None
  self.wd = None
  self.rd = None
  self.bd = None
  self.writes = 0UL
  self.reads = 0UL
  self.alias_mask = 0xffffffffUL
  self.corrupt_address = None
  self.read_fault = 0UL
  self.write_fault = 0UL
  self.bad_last = false
  self.aw_pause = false
  self.w_pause = false
  self.ar_pause = false
  self.previous.clear()
  self.memory.clear()
  self.step()
  self.step()
  self.drive("reset", 0UL)
  for _ in 0..<8 {
    self.step()
  }
  assert_eq(self.get("phase"), 0UL)
  assert_eq(self.writes, 0UL)
  assert_eq(self.reads, 0UL)
  self.drive("calibrated", 1UL)
}
