///|
priv struct Bench {
  shell_sim : @sim.Simulator
  core_sim : @sim.Simulator
  hardware : @ir.Module
  received : Array[Byte]
  stimulus : StringBuilder
  expected : StringBuilder
  mut cycle : Int32
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
  let value = sim.output(name)
  guard value.is_fully_known() else { fail("unknown \{name}") }
  value.value_bits()
}

///|
fn Bench::step(self : Bench, byte? : Byte, ready~ : Bool = true) -> Unit raise {
  drive(self.shell_sim, "rx_valid", 1, if byte is Some(_) { 1UL } else { 0UL })
  drive(self.shell_sim, "rx_data", 8, byte.unwrap_or(0).to_uint64())
  drive(self.shell_sim, "tx_ready", 1, if ready { 1UL } else { 0UL })
  let reset = self.shell_sim.value(@ir.NodeId::new(1)).value_bits()
  self.stimulus.write_string(
    "\{self.cycle}\t\{reset}\t\{@verilator.padded_hex(byte.unwrap_or(0).to_uint64(), 8)}\t0\t\{if byte is Some(_) { 1 } else { 0 }}\t\{if ready { 1 } else { 0 }}\n",
  )
  // Settle the inter-module combinational graph before committing either
  // side. Both simulators then sample these old-state inputs on this edge.
  for _ in 0..<3 {
    for port in self.hardware.outputs() {
      self.shell_sim.set_input(
        "c_" + port.name(),
        self.core_sim.output(port.name()),
      )
    }
    self.shell_sim.settle()
    for node in self.hardware.nodes() {
      if node.kind() is Input(name) && name != "clock" {
        let output = if name == "reset" { "core_reset" } else { name }
        self.core_sim.set_input(name, self.shell_sim.output(output))
      }
    }
    self.core_sim.settle()
  }
  if ready && read(self.shell_sim, "tx_valid") == 1UL {
    self.received.push(read(self.shell_sim, "tx_data").to_byte())
  }
  self.shell_sim.rising_edge("clock")
  self.core_sim.rising_edge("clock")
  if self.cycle > 0 {
    self.expected.write_string(
      "\{self.cycle}\t\{@verilator.padded_hex(read(self.shell_sim, "tx_data"), 8)}\t\{read(self.shell_sim, "tx_valid")}\n",
    )
  }
  self.cycle += 1
}

///|
fn bench() -> Bench raise {
  let hardware = @prx100.core(Smoke)
  let shell_hw = @prx100.byte_shell(Smoke)
  let shell_sim = @sim.Simulator::prepare(shell_hw)
  let core_sim = @sim.Simulator::prepare(hardware)
  for (hw, simulator) in [(shell_hw, shell_sim), (hardware, core_sim)] {
    for node in hw.nodes() {
      if node.kind() is Input(name) {
        drive(simulator, name, node.signal_type().width().bits(), 0UL)
      }
    }
  }
  let result = Bench::{
    shell_sim,
    core_sim,
    hardware,
    received: [],
    cycle: 0,
    stimulus: StringBuilder(),
    expected: StringBuilder(),
  }
  result.stimulus.write_string(
    "cycle\treset\trx_data\trx_error\trx_valid\ttx_ready\n",
  )
  result.expected.write_string("cycle\ttx_data\ttx_valid\n")
  drive(shell_sim, "reset", 1, 1UL)
  result.step()
  result.step()
  drive(shell_sim, "reset", 1, 0UL)
  result.step()
  result
}

///|
fn Bench::exchange(self : Bench, frame : Bytes) -> @prx100.Reply raise {
  self.received.clear()
  for byte in frame {
    self.step(byte~)
  }
  for _ in 0..<100 {
    self.step()
    if self.received.length() == 32 {
      break
    }
  }
  assert_eq(self.received.length(), 32)
  // A byte-seam transmitter is always ready; give the drain state an edge.
  self.step()
  @prx100.decode_reply(Bytes::from_array(self.received)[:])
}

///|
fn Bench::command(
  self : Bench,
  op : Byte,
  arg~ : UInt32 = 0U,
  data~ : UInt32 = 0U,
) -> @prx100.Reply raise {
  self.exchange(@prx100.request(op, 0x1234, arg, data))
}

///|
fn packet(
  op : Byte,
  id : UInt32,
  rows : Byte,
  columns : Byte,
  reduction : Byte,
  base : UInt32,
) -> Bytes {
  let bytes : Array[Byte] = [0, 2, op, 0]
  for offset in 0..<4 {
    bytes.push((id >> (offset * 8)).to_byte())
  }
  for value in [rows, columns, reduction] {
    bytes.push(value)
    bytes.push(0)
  }
  bytes.push(0)
  bytes.push(0)
  for offset in 0..<4 {
    bytes.push((base >> (offset * 8)).to_byte())
  }
  let stride = if op == 3 { 4U } else if op == 0 || op == 1 { 1U } else { 0U }
  for offset in 0..<4 {
    bytes.push((stride >> (offset * 8)).to_byte())
  }
  for _ in 0..<8 {
    bytes.push(0)
  }
  Bytes::from_array(bytes)
}

///|
fn Bench::upload(self : Bench, address : UInt32, bytes : Bytes) -> Unit raise {
  assert_eq(bytes.length() % 4, 0)
  for index in 0..<(bytes.length() / 4) {
    let mut value = 0U
    for offset in 0..<4 {
      value = value | (bytes[index * 4 + offset].to_uint() << (offset * 8))
    }
    assert_eq(
      self.command(
        1,
        arg=address + (index * 4).reinterpret_as_uint(),
        data=value,
      ).status,
      0,
    )
  }
}

///|
fn Bench::workload(self : Bench) -> Unit raise {
  self.upload(0U, packet(0, 11U, 1, 1, 0, 256U))
  self.upload(32U, packet(1, 12U, 1, 1, 0, 260U))
  self.upload(64U, packet(2, 13U, 1, 1, 1, 0U))
  self.upload(96U, packet(3, 14U, 1, 1, 0, 512U))
  assert_eq(self.command(1, arg=256U, data=249U).status, 0) // -7
  assert_eq(self.command(1, arg=260U, data=9U).status, 0)
  assert_eq(self.command(1, arg=512U, data=0x13579bdfU).status, 0)
  assert_eq(self.command(3).status, 0)
  assert_eq(self.command(4, arg=4U).status, 0)
}
