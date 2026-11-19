///|
priv struct Bench {
  hardware : @ir.Module
  core_hw : @ir.Module
  sim : @sim.Simulator
  core : @sim.Simulator
  memory : Map[UInt32, UInt32]
  inputs : Array[@ir.Node]
  outputs : Array[(String, Int32)]
  stimulus : StringBuilder
  expected : StringBuilder
  core_stimulus : StringBuilder
  core_expected : StringBuilder
  core_ports : ReadOnlyArray[@verilator.HarnessPort]
  descriptor_writes : Array[(UInt64, UInt64)]
  mut pending : (Int32, UInt32, UInt32, UInt64, Int32)?
  mut cycle : Int32
  mut random : UInt32
  mut healthy : Bool
  mut stalled : Bool
  mut fault : UInt64
  mut recording : Bool
  overlapped_reads : Array[Int32]
  simultaneous_reads : Array[Int32]
  observations : Map[String, @ir.NodeId]
  publications : Array[(UInt64, UInt64, UInt64)]
  collection_requests : Array[Int32]
  memory_requests : Array[(Int32, UInt64, UInt64, UInt64)]
}

///|
fn Bench::observe(self : Bench, name : String) -> UInt64 raise {
  let v = self.sim.value(self.observations[name])
  assert_true(v.is_fully_known())
  v.value_bits()
}

///|
fn set(
  sim : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn value(sim : @sim.Simulator, name : String) -> UInt64 raise {
  let v = sim.output(name)
  guard v.is_fully_known() else { fail("unknown " + name) }
  v.value_bits()
}

///|
fn Bench::set(
  self : Bench,
  name : String,
  width : Int32,
  data : UInt64,
) -> Unit raise {
  set(self.sim, name, width, data)
}

///|
fn Bench::environment(
  self : Bench,
  healthy~ : Bool = true,
  stalled~ : Bool = false,
  fault~ : UInt64 = 0UL,
) -> Unit {
  self.healthy = healthy
  self.stalled = stalled
  self.fault = fault
}

///|
fn Bench::step(self : Bench) -> Unit raise {
  self.random = self.random * 1664525U + 1013904223U
  let resetting = self.sim.value(@ir.NodeId::new(1)).value_bits() == 1UL
  let ready = !resetting &&
    !self.stalled &&
    self.pending is None &&
    (self.random & 3U) != 0U
  self.set("memory_healthy", 1, if self.healthy { 1UL } else { 0UL })
  self.set("ddr_request_ready", 1, if ready { 1UL } else { 0UL })
  let response = match self.pending {
    Some((due, _, _, _, _)) => due <= self.cycle
    None => false
  }
  self.set("ddr_response_valid", 1, if response { 1UL } else { 0UL })
  self.set(
    "ddr_response_data",
    32,
    match self.pending {
      Some((_, _, word, _, _)) => word.to_uint64()
      None => 0UL
    },
  )
  self.set(
    "ddr_response_fault",
    2,
    match self.pending {
      Some((_, _, _, fault, _)) => fault
      None => 0UL
    },
  )
  self.set(
    "ddr_response_last",
    1,
    match self.pending {
      Some((_, _, _, _, remaining)) => if remaining == 0 { 1UL } else { 0UL }
      None => 1UL
    },
  )
  for _ in 0..<3 {
    for node in self.inputs {
      if node.kind() is Input(name) && name.has_prefix("c_") {
        self.sim.set_input(name, self.core.output(name[2:].to_owned()))
      }
    }
    self.sim.settle()
    for node in self.core_hw.nodes() {
      if node.kind() is Input(name) && name != "clock" {
        self.core.set_input(
          name,
          self.sim.output(if name == "reset" { "core_reset" } else { name }),
        )
      }
    }
    self.core.settle()
  }
  if self.recording {
    let row : Array[String] = [self.cycle.to_string()]
    for node in self.inputs {
      let v = self.sim.value(node.id())
      guard v.is_fully_known() else {
        fail("unknown stimulus at node" + node.id().ordinal().to_string())
      }
      row.push(
        @verilator.padded_hex(v.value_bits(), node.signal_type().width().bits()),
      )
    }
    self.stimulus.write_string(row.join("\t") + "\n")
    let row = [self.cycle.to_string()]
    for port in @verilator.input_ports(self.core_ports) {
      let node = self.core_hw
        .nodes()
        .iter()
        .find_first(n => n.kind() is Input(name) && name == port.source_name())
        .unwrap()
      let v = self.core.value(node.id())
      assert_true(v.is_fully_known())
      row.push(@verilator.padded_hex(v.value_bits(), port.width()))
    }
    self.core_stimulus.write_string(row.join("\t") + "\n")
  }
  if response {
    self.pending = match self.pending {
      Some((_, address, _, fault, remaining)) if remaining > 0 =>
        Some(
          (
            self.cycle + 1 + (self.random % 3U).reinterpret_as_int(),
            address + 4U,
            self.memory.get(address + 4U).unwrap_or(0U),
            fault,
            remaining - 1,
          ),
        )
      _ => None
    }
  }
  if ready && value(self.sim, "ddr_request_valid") == 1UL {
    let address = value(self.sim, "ddr_request_address").to_uint()
    assert_eq(address % 4U, 0U)
    assert_true(address < 0x10000000U)
    let writing = value(self.sim, "ddr_request_write") == 1UL
    let line = value(self.sim, "ddr_request_line") == 1UL
    let burst = value(self.sim, "ddr_request_burst") == 1UL
    if line {
      assert_eq(address % 16U, 0U)
    }
    if burst {
      assert_true(line && !writing)
      assert_eq(address % 128U, 0U)
    }
    if !writing && self.observe("state") == 7UL {
      self.overlapped_reads.push(self.cycle)
    }
    let word = value(self.sim, "ddr_request_data").to_uint()
    if writing && self.fault == 0UL {
      self.memory[address] = word
      if line {
        for lane in 1..<4 {
          self.memory[address + lane.reinterpret_as_uint() * 4U] = value(
            self.sim,
            "ddr_request_data" + lane.to_string(),
          ).to_uint()
        }
      }
    }
    self.pending = Some(
      (
        self.cycle + 2 + (self.random % 5U).reinterpret_as_int(),
        address,
        if writing {
          0U
        } else {
          self.memory.get(address).unwrap_or(0U)
        },
        self.fault,
        if line && !writing {
          if burst {
            31
          } else {
            3
          }
        } else {
          0
        },
      ),
    )
  }
  let port = self.hardware.memories()[0].write_ports()[0]
  if !resetting &&
    value(self.sim, "memory_request_ready") == 1UL &&
    value(self.core, "memory_request_valid") == 1UL {
    self.memory_requests.push(
      (
        self.cycle,
        value(self.core, "memory_request_write"),
        value(self.core, "memory_request_address"),
        value(self.core, "memory_request_bytes"),
      ),
    )
  }
  if !resetting &&
    value(self.sim, "publish_valid") == 1UL &&
    value(self.core, "publish_ready") == 1UL {
    self.publications.push(
      (
        value(self.sim, "publish_producer"),
        self.observe("retired"),
        self.observe("partials"),
      ),
    )
  }
  if !resetting &&
    self.observe("state") >= 9UL &&
    self.observe("state") <= 12UL &&
    value(self.sim, "memory_request_ready") == 1UL &&
    value(self.core, "memory_request_valid") == 1UL {
    self.collection_requests.push(self.cycle)
  }
  if self.sim.value(port.enable().unwrap()).value_bits() == 1UL {
    let address = self.sim.value(port.address()).value_bits()
    if !(address >= 256UL && address <= 263UL) &&
      !(address >= 768UL && address <= 775UL) &&
      value(self.sim, "completion_ready") == 1UL &&
      value(self.sim, "memory_request_ready") == 1UL &&
      value(self.core, "memory_request_valid") == 1UL {
      assert_eq(value(self.core, "memory_request_write"), 0UL)
      assert_true(value(self.core, "memory_request_address") / 4UL != address)
      self.simultaneous_reads.push(self.cycle)
    }
    if address < 32UL {
      // A fetched/held packet owns its slot until atomic queue acceptance.
      assert_eq(
        value(self.core, "consumer_count"),
        value(self.core, "producer_count"),
      )
      self.descriptor_writes.push(
        (address, self.sim.value(port.data()).value_bits()),
      )
    }
  }
  self.sim.rising_edge("clock")
  self.core.rising_edge("clock")
  if self.recording && self.cycle > 0 {
    let row : Array[String] = [self.cycle.to_string()]
    for (name, width) in self.outputs {
      row.push(@verilator.padded_hex(value(self.sim, name), width))
    }
    self.expected.write_string(row.join("\t") + "\n")
    let row = [self.cycle.to_string()]
    for port in @verilator.output_ports(self.core_ports) {
      row.push(
        @verilator.padded_hex(
          value(self.core, port.source_name()),
          port.width(),
        ),
      )
    }
    self.core_expected.write_string(row.join("\t") + "\n")
  }
  self.cycle += 1
}

///|
fn bench(
  watchdog~ : UInt64 = 50000000UL,
  recording~ : Bool = false,
) -> Bench raise {
  let hw = @projection.controller(watchdog~)
  let (_, observed) = @projection.controller_evidence()
  // Watchdog only changes the constant, not node allocation.
  let observations = Map::from_array(
    observed.map(o => (o.name, o.node)).iter().to_array(),
  )
  let core_hw = @projection.core()
  let sim = @sim.Simulator::prepare(hw)
  let core = @sim.Simulator::prepare(core_hw)
  let inputs = hw
    .nodes()
    .filter(n => {
      match n.kind() {
        Input(name) => name != "clock"
        _ => false
      }
    })
    .iter()
    .to_array()
  let outputs = hw
    .outputs()
    .map(p => (p.name(), p.signal_type().width().bits()))
    .iter()
    .to_array()
  for (hardware, s) in [(hw, sim), (core_hw, core)] {
    for node in hardware.nodes() {
      if node.kind() is Input(name) {
        set(s, name, node.signal_type().width().bits(), 0UL)
      }
    }
  }
  let result = Bench::{
    hardware: hw,
    core_hw,
    sim,
    core,
    memory: Map([]),
    inputs,
    outputs,
    stimulus: StringBuilder(),
    expected: StringBuilder(),
    core_stimulus: StringBuilder(),
    core_expected: StringBuilder(),
    core_ports: if recording {
      @verilator.collect_ports(
        core_hw,
        @systemverilog.emit_design(
          @ir.Design::single(
            "phase6-fetched-concurrent-word32-8x8-k16-two-slots", core_hw,
          ),
        ).manifest(),
      )
    } else {
      ReadOnlyArray::from_array([])
    },
    descriptor_writes: [],
    pending: None,
    cycle: 0,
    random: 0x1162026U,
    healthy: true,
    stalled: false,
    fault: 0UL,
    recording: false,
    overlapped_reads: [],
    simultaneous_reads: [],
    observations,
    publications: [],
    collection_requests: [],
    memory_requests: [],
  }
  if recording {
    let e = @systemverilog.emit_design(
      @ir.Design::single("prx100-ddr-projection-controller/v1", hw),
    )
    let ports = @verilator.collect_ports(hw, e.manifest())
    result.inputs.clear()
    let names = ["cycle"]
    for p in @verilator.input_ports(ports) {
      let node = hw
        .nodes()
        .iter()
        .find_first(n => n.kind() is Input(name) && name == p.source_name())
        .unwrap()
      result.inputs.push(node)
      names.push(p.emitted_name())
    }
    result.stimulus.write_string(names.join("\t") + "\n")
    result.outputs.clear()
    for p in @verilator.output_ports(ports) {
      result.outputs.push((p.source_name(), p.width()))
    }
    result.expected.write_string(
      @verilator.tsv_header(@verilator.output_ports(ports)),
    )
    result.core_stimulus.write_string(
      "cycle\t" +
      @verilator.input_ports(result.core_ports)
      .map(p => p.emitted_name())
      .join("\t") +
      "\n",
    )
    result.core_expected.write_string(
      @verilator.tsv_header(@verilator.output_ports(result.core_ports)),
    )
  }
  result.set("reset", 1, 1UL)
  result.step()
  result.cycle = 0
  result.recording = recording
  result.step()
  result.step()
  result.set("reset", 1, 0UL)
  result.step()
  result
}
