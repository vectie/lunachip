///|
priv struct SerialRun {
  simulator : @sim.Simulator
  inputs : ReadOnlyArray[(@verilator.HarnessPort, @ir.NodeId)]
  outputs : Array[@verilator.HarnessPort]
  stimulus : StringBuilder
  expected : StringBuilder
  received : Array[Byte]
  mut cycle : Int32
  mut wait : Int32
  mut bit_index : Int32
  mut value : UInt32
}

///|
fn SerialRun::tick(
  self : SerialRun,
  rx : UInt64,
  reset~ : UInt64 = 0UL,
) -> Unit raise {
  drive(self.simulator, "uart_rx", 1, rx)
  drive(self.simulator, "reset", 1, reset)
  self.stimulus.write_string(self.cycle.to_string())
  for (port, id) in self.inputs {
    let value = self.simulator.value(id)
    guard value.is_fully_known() else { fail("unknown UART fixture input") }
    self.stimulus.write_string(
      "\t" + @verilator.padded_hex(value.value_bits(), port.width),
    )
  }
  self.stimulus.write_string("\n")
  self.simulator.rising_edge("clock")
  if self.cycle > 0 {
    self.expected.write_string(self.cycle.to_string())
    for port in self.outputs {
      self.expected.write_string(
        "\t" +
        @verilator.padded_hex(
          read(self.simulator, port.source_name),
          port.width,
        ),
      )
    }
    self.expected.write_string("\n")
  }
  let tx = read(self.simulator, "uart_tx")
  if self.wait == 0 {
    if tx == 0UL {
      self.wait = 12
      self.bit_index = 0
      self.value = 0U
    }
  } else {
    self.wait -= 1
    if self.wait == 0 {
      if self.bit_index < 8 {
        self.value = self.value | (tx.to_uint() << self.bit_index)
        self.bit_index += 1
        self.wait = 8
      } else {
        assert_eq(tx, 1UL)
        self.received.push(self.value.to_byte())
      }
    }
  }
  self.cycle += 1
}

///|
fn uart_protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-PRX100-UART-RESULT", "1", "prx100-uart-shell-div8/v0.1",
  )
}

///|
/// Actual bit-level RX, synchronization, frame handling and TX are replayed
/// at divisor8, a separately identified accelerated digital test profile.
pub fn generate_uart_bundle() -> ReadOnlyArray[@prx100.Artifact] raise {
  let hardware = @prx100.shell(Smoke, divisor=8)
  let design = @ir.Design::single("prx100-uart-div8", hardware)
  let emitted = @systemverilog.emit_design(design)
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let simulator = @sim.Simulator::prepare(hardware)
  let inputs : Array[(@verilator.HarnessPort, @ir.NodeId)] = []
  for node in hardware.nodes() {
    if node.kind() is Input(name) {
      drive(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  for port in @verilator.input_ports(ports) {
    for node in hardware.nodes() {
      if node.kind() is Input(name) && name == port.source_name {
        inputs.push((port, node.id()))
      }
    }
  }
  let outputs = @verilator.output_ports(ports)
  let run = SerialRun::{
    simulator,
    inputs: ReadOnlyArray::from_array(inputs),
    outputs,
    stimulus: StringBuilder(),
    expected: StringBuilder(),
    received: [],
    cycle: 0,
    wait: 0,
    bit_index: 0,
    value: 0U,
  }
  run.stimulus.write_string(
    @verilator.tsv_header(@verilator.input_ports(ports)),
  )
  run.expected.write_string(@verilator.tsv_header(outputs))
  run.tick(1UL, reset=1UL)
  run.tick(1UL, reset=1UL)
  for _ in 0..<20 {
    run.tick(1UL)
  }
  for byte in @prx100.request(0, 0x4567, 0U, 0U) {
    for _ in 0..<8 {
      run.tick(0UL)
    }
    for bit in 0..<8 {
      for _ in 0..<8 {
        run.tick((byte.to_uint64() >> bit) & 1UL)
      }
    }
    for _ in 0..<8 {
      run.tick(1UL)
    }
  }
  for _ in 0..<3000 {
    run.tick(1UL)
    if run.received.length() == 32 {
      break
    }
  }
  let reply = @prx100.decode_reply(Bytes::from_array(run.received)[:])
  assert_eq(reply.sequence, 0x4567)
  assert_eq(reply.status, 0)
  assert_eq(reply.words[0], 0x50525831U)
  let stimulus = run.stimulus.to_string()
  let identity = @differential.ResultIdentity::checked(
    @differential.DesignIdentity::checked(
      uart_protocol().semantic_version(),
      @verilator.sha256_hex(@codec.serialize(design)),
    ),
    @verilator.sha256_hex(stimulus),
  )
  let result : Array[@prx100.Artifact] = [
    { path: "design.lcir", content: @codec.serialize(design), },
    { path: "manifest.json", content: @verilator.harness_json(emitted, ports), },
    {
      path: "harness.cpp",
      content: @verilator.harness_cpp(ports, identity, uart_protocol()),
    },
    { path: "stimulus.tsv", content: stimulus, },
    {
      path: "expected.tsv",
      content: "\{uart_protocol().magic()}\t1\t\{@verilator.utf8_hex(uart_protocol().semantic_version())}\tsha256\t\{identity.design().design_sha256()}\tsha256\t\{identity.stimulus_sha256()}\n" +
      run.expected.to_string(),
    },
    {
      path: "fixture.txt",
      content: "cycles=\{run.cycle - 1}\nuart_divisor=8\nphysical_target=false\n",
    },
  ]
  for source in emitted.modules() {
    result.push({ path: source.filename(), content: source.source(), })
  }
  ReadOnlyArray::from_array(result)
}

///|
pub fn audit_uart_replay(
  expected : String,
  actual : String,
  cycles : Int32,
) -> Unit raise {
  let hardware = @prx100.shell(Smoke, divisor=8)
  let emitted = @systemverilog.emit_design(
    @ir.Design::single("prx100-uart-div8", hardware),
  )
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  let wanted = @verilator.parse_actual_tsv(
    expected,
    ports,
    cycles,
    uart_protocol(),
  )
  let observed = @verilator.parse_actual_tsv(
    actual,
    ports,
    cycles,
    uart_protocol(),
  )
  assert_eq(@differential.compare(wanted, observed), Equal)
}
