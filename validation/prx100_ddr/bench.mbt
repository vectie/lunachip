///|
priv struct Bench {
  hardware : @ir.Module
  sim : @sim.Simulator
  inputs : Array[@ir.Node]
  outputs : Array[(String, Int32)]
  memory : Array[Array[UInt32]]
  write_commands : Array[Int32]
  write_data : Array[(Array[UInt32], UInt64)]
  read_commands : Array[(Int32, Int32)]
  stimulus : StringBuilder
  expected : StringBuilder
  mut write_head : Int32
  mut read_head : Int32
  mut cycle : Int32
  mut random : UInt32
  mut calibrated : Bool
  mut stalled : Bool
  mut corrupt_lane : Int32
  mut alias_modulus : Int32
  mut bad_end : Bool
}

///|
fn drive(
  sim : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  sim.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn read(sim : @sim.Simulator, name : String) -> UInt64 raise {
  let v = sim.output(name)
  guard v.is_fully_known() else { fail("unknown " + name) }
  v.value_bits()
}

///|
fn Bench::set(
  self : Bench,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  drive(self.sim, name, width, value)
}

///|
fn Bench::value(self : Bench, name : String) -> UInt64 raise {
  read(self.sim, name)
}

///|
fn Bench::step(self : Bench) -> Unit raise {
  self.random = self.random * 1664525U + 1013904223U
  let command_ready = !self.stalled && (self.random & 3U) != 0U
  let data_ready = !self.stalled && (self.random & 12U) != 0U
  self.set("calibrated", 1, if self.calibrated { 1UL } else { 0UL })
  self.set("app_rdy", 1, if command_ready { 1UL } else { 0UL })
  self.set("app_wdf_rdy", 1, if data_ready { 1UL } else { 0UL })
  let response = self.read_head < self.read_commands.length() &&
    self.read_commands[self.read_head].0 <= self.cycle
  self.set("app_rd_data_valid", 1, if response { 1UL } else { 0UL })
  self.set(
    "app_rd_data_end",
    1,
    if response && !self.bad_end {
      1UL
    } else {
      0UL
    },
  )
  for lane in 0..<4 {
    let mut word = 0U
    if response {
      let index = self.read_commands[self.read_head].1
      word = self.memory[index][lane]
      if lane == self.corrupt_lane {
        word = word ^ 0x80000000U
      }
    }
    self.set("app_rd_word" + lane.to_string(), 32, word.to_uint64())
  }
  self.sim.settle()
  let values : Array[String] = [self.cycle.to_string()]
  for node in self.inputs {
    if node.kind() is Input(name) && name != "clock" {
      values.push(
        @verilator.padded_hex(
          self.sim.value(node.id()).value_bits(),
          node.signal_type().width().bits(),
        ),
      )
    }
  }
  self.stimulus.write_string(values.join("\t") + "\n")
  if self.value("app_en") == 1UL && command_ready {
    let native = self.value("app_addr")
    assert_eq(native % 8UL, 0UL)
    let mut index = (native / 8UL).to_int()
    guard index >= 0 && index < self.memory.length() else {
      fail("native address out of bounds")
    }
    if self.alias_modulus > 0 {
      index = index % self.alias_modulus
    }
    if self.value("app_cmd") == 0UL {
      self.write_commands.push(index)
    } else {
      assert_eq(self.value("app_cmd"), 1UL)
      let due = self.cycle + 2 + (self.random >> 16).reinterpret_as_int() % 7
      self.read_commands.push((due, index))
    }
  }
  if self.value("app_wdf_wren") == 1UL && data_ready {
    assert_eq(self.value("app_wdf_end"), 1UL)
    let words : Array[UInt32] = []
    for lane in 0..<4 {
      words.push(self.value("app_wdf_word" + lane.to_string()).to_uint())
    }
    self.write_data.push((words, self.value("app_wdf_mask")))
  }
  while self.write_head < self.write_commands.length() &&
        self.write_head < self.write_data.length() {
    let index = self.write_commands[self.write_head]
    let (data, mask) = self.write_data[self.write_head]
    for lane in 0..<4 {
      let mut word = self.memory[index][lane]
      for byte in 0..<4 {
        let offset = lane * 4 + byte
        if (mask & (1UL << offset)) == 0UL {
          let bits = 0xffU << (byte * 8)
          word = (word & bits.lnot()) | (data[lane] & bits)
        }
      }
      self.memory[index][lane] = word
    }
    self.write_head = self.write_head + 1
  }
  if response {
    self.read_head = self.read_head + 1
  }
  self.sim.rising_edge("clock")
  let results : Array[String] = [self.cycle.to_string()]
  for (name, width) in self.outputs {
    results.push(@verilator.padded_hex(self.value(name), width))
  }
  if self.cycle > 0 {
    self.expected.write_string(results.join("\t") + "\n")
  }
  self.cycle = self.cycle + 1
}

///|
fn bench(beats : Int32) -> Bench raise {
  let hardware = @ddr.controller()
  let sim = @sim.Simulator::prepare(hardware)
  let names : Array[String] = ["cycle"]
  for node in hardware.nodes() {
    if node.kind() is Input(name) {
      drive(sim, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let inputs : Array[@ir.Node] = []
  let ports = replay_ports()
  for port in @verilator.input_ports(ports) {
    let index = hardware
      .nodes()
      .search_by(node => {
        node.kind() is Input(name) && name == port.source_name()
      })
      .unwrap()
    inputs.push(hardware.nodes()[index])
    names.push(port.emitted_name())
  }
  let outputs = @verilator.output_ports(ports).map(p => {
    (p.source_name(), p.width())
  })
  let b = Bench::{
    hardware,
    sim,
    inputs,
    outputs,
    memory: Array::makei(beats, _ => [0U, 0U, 0U, 0U]),
    write_commands: [],
    write_data: [],
    read_commands: [],
    write_head: 0,
    read_head: 0,
    cycle: 0,
    random: 0x1052026U,
    calibrated: true,
    stalled: false,
    corrupt_lane: -1,
    alias_modulus: 0,
    bad_end: false,
    stimulus: StringBuilder(),
    expected: StringBuilder(),
  }
  b.stimulus.write_string(names.join("\t") + "\n")
  b.expected.write_string(@verilator.tsv_header(@verilator.output_ports(ports)))
  b.set("reset", 1, 1UL)
  b.step()
  b.step()
  b.set("reset", 1, 0UL)
  b.step()
  b
}

///|
fn Bench::write(
  self : Bench,
  address : UInt64,
  data : UInt64,
  strobe~ : UInt64 = 15UL,
  data_first~ : Bool = false,
) -> UInt64 raise {
  self.set("s_axi_bready", 1, 0UL)
  self.set("s_axi_awaddr", 32, address)
  self.set("s_axi_wdata", 32, data)
  self.set("s_axi_wstrb", 4, strobe)
  self.set("s_axi_awvalid", 1, if data_first { 0UL } else { 1UL })
  self.set("s_axi_wvalid", 1, if data_first { 1UL } else { 0UL })
  self.step()
  self.set("s_axi_awvalid", 1, if data_first { 1UL } else { 0UL })
  self.set("s_axi_wvalid", 1, if data_first { 0UL } else { 1UL })
  self.step()
  self.set("s_axi_awvalid", 1, 0UL)
  self.set("s_axi_wvalid", 1, 0UL)
  for _ in 0..<10 {
    self.step()
    if self.value("s_axi_bvalid") == 1UL {
      break
    }
  }
  assert_eq(self.value("s_axi_bvalid"), 1UL)
  let result = self.value("s_axi_bresp")
  for _ in 0..<3 {
    self.step()
    assert_eq(self.value("s_axi_bvalid"), 1UL)
    assert_eq(self.value("s_axi_bresp"), result)
  }
  self.set("s_axi_bready", 1, 1UL)
  self.step()
  self.set("s_axi_bready", 1, 0UL)
  result
}

///|
fn Bench::get(
  self : Bench,
  address : UInt64,
  response~ : UInt64 = 0UL,
) -> UInt64 raise {
  self.set("s_axi_rready", 1, 0UL)
  self.set("s_axi_araddr", 32, address)
  self.set("s_axi_arvalid", 1, 1UL)
  self.step()
  self.set("s_axi_arvalid", 1, 0UL)
  assert_eq(self.value("s_axi_rvalid"), 1UL)
  assert_eq(self.value("s_axi_rresp"), response)
  let result = self.value("s_axi_rdata")
  for _ in 0..<3 {
    self.step()
    assert_eq(self.value("s_axi_rdata"), result)
    assert_eq(self.value("s_axi_rvalid"), 1UL)
  }
  self.set("s_axi_rready", 1, 1UL)
  self.step()
  self.set("s_axi_rready", 1, 0UL)
  result
}

///|
fn Bench::start_test(
  self : Bench,
  mode : UInt64,
  seed : UInt64,
  beats : Int32,
  command~ : UInt64 = 1UL,
) -> Unit raise {
  assert_eq(self.write(20UL, seed), 0UL)
  assert_eq(self.write(24UL, beats.to_uint64(), data_first=true), 0UL)
  assert_eq(self.write(28UL, mode), 0UL)
  assert_eq(self.write(16UL, command), 0UL)
}

///|
fn Bench::run(
  self : Bench,
  mode : UInt64,
  seed : UInt64,
  beats : Int32,
  command~ : UInt64 = 1UL,
) -> Unit raise {
  self.start_test(mode, seed, beats, command~)
  for _ in 0..<10000 {
    if self.value("test_state") >= 3UL {
      break
    }
    self.step()
  }
  assert_eq(self.value("test_state"), 3UL)
  assert_eq(self.value("test_mismatches"), 0UL)
  assert_eq(self.value("test_error"), 0UL)
  let writes = if (command & 2UL) != 0UL { 0UL } else { beats.to_uint64() }
  let reads = if (command & 4UL) != 0UL { 0UL } else { beats.to_uint64() }
  assert_eq(self.value("test_writes"), writes)
  assert_eq(self.value("test_data_beats"), writes)
  assert_eq(self.value("test_reads"), reads)
  assert_eq(self.value("test_checked"), reads)
}

///|
fn Bench::reset_model(self : Bench) -> Unit raise {
  self.calibrated = true
  self.stalled = false
  self.corrupt_lane = -1
  self.alias_modulus = 0
  self.bad_end = false
  self.set("reset", 1, 1UL)
  self.step()
  self.step()
  self.write_commands.clear()
  self.write_data.clear()
  self.read_commands.clear()
  self.write_head = 0
  self.read_head = 0
  self.set("reset", 1, 0UL)
  self.step()
}
