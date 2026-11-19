///|
priv struct BridgeBench {
  group_rows : Int32
  packet_words : Int32
  period : Int32
  max_outstanding : Ref[Int32]
  hardware : @ir.Module
  sim : @sim.Simulator
  ports : ReadOnlyArray[@verilator.HarnessPort]
  events : Array[@verilator.AtomicStimulusEvent]
  rows : StringBuilder
  recording : Bool
  memory : Array[Array[UInt32]]
  commands : Array[Int32]
  data : Array[(Array[UInt32], UInt64)]
  reads : Array[(Int32, Int32)]
  mut write_head : Int32
  mut read_head : Int32
  mut tick : Int32
  mut random : UInt32
  mut accepted : Bool
  mut result : (UInt64, UInt64)?
  results : Array[(UInt64, UInt64, UInt64)]
  mut bad_end : Bool
  mut paused : Bool
  mut command_paused : Bool
  mut data_paused : Bool
  mut read_delay : Int32
  joined : Array[@ir.AsyncFifoPrimitive]
}

///|
fn BridgeBench::environment(
  self : BridgeBench,
  bad_end~ : Bool = false,
  paused~ : Bool = false,
) -> Unit {
  self.bad_end = bad_end
  self.paused = paused
}

///|
fn BridgeBench::step(self : BridgeBench) -> Unit raise {
  self.random = self.random * 1664525U + 1013904223U
  let command_ready = !self.paused &&
    !self.command_paused &&
    (self.random & 3U) != 0U
  let data_ready = !self.paused &&
    !self.data_paused &&
    (self.random & 12U) != 0U
  set(self.sim, "app_rdy", 1, if command_ready { 1UL } else { 0UL })
  set(self.sim, "app_wdf_rdy", 1, if data_ready { 1UL } else { 0UL })
  let response = self.read_head < self.reads.length() &&
    self.reads[self.read_head].0 <= self.tick
  set(self.sim, "app_rd_data_valid", 1, if response { 1UL } else { 0UL })
  set(
    self.sim,
    "app_rd_data_end",
    1,
    if response && !self.bad_end {
      1UL
    } else {
      0UL
    },
  )
  for lane in 0..<4 {
    let word = if response {
      self.memory[self.reads[self.read_head].1][lane].to_uint64()
    } else {
      0UL
    }
    set(self.sim, "app_rd_word" + lane.to_string(), 32, word)
  }
  self.sim.settle()
  if !self.joined.is_empty() {
    for i, f in self.joined {
      let first = self.joined[i / self.packet_words * self.packet_words]
      for
        (a, c) in [
          (first.source_transfer(), f.source_transfer()),
          (first.destination_transfer(), f.destination_transfer()),
          (first.write_binary(), f.write_binary()),
          (first.read_binary(), f.read_binary()),
        ] {
        assert_eq(self.sim.value(a), self.sim.value(c))
      }
      if self.sim.value(f.source_valid()).value_bits() == 1UL {
        assert_eq(self.sim.value(f.source_ready()).value_bits(), 1UL)
      }
      if self.sim.value(f.destination_ready()).value_bits() == 1UL {
        assert_eq(self.sim.value(f.destination_valid()).value_bits(), 1UL)
      }
    }
  }
  let source_reset = self.sim.value(@ir.NodeId::new(2)).value_bits() == 1UL
  let ui_reset = self.sim.value(@ir.NodeId::new(3)).value_bits() == 1UL
  if !source_reset && self.tick % self.period == 0 {
    let request = self.sim.value(@ir.NodeId::new(4)).value_bits()
    if request == 1UL && value(self.sim, "request_ready") == 1UL {
      self.accepted = true
    }
    if value(self.sim, "response_valid") == 1UL &&
      self.sim.value(@ir.NodeId::new(8)).value_bits() == 1UL {
      let data = value(self.sim, "response_data")
      let fault = value(self.sim, "response_fault")
      let last = value(self.sim, "response_last")
      self.results.push((data, fault, last))
      if last == 1UL {
        assert_true(self.result is None)
        self.result = Some((data, fault))
      }
    }
  }
  if !ui_reset {
    if value(self.sim, "app_en") == 1UL && command_ready {
      assert_eq(value(self.sim, "app_addr") % 8UL, 0UL)
      let index = (value(self.sim, "app_addr") / 8UL).to_int()
      assert_true(index >= 0 && index < self.memory.length())
      if value(self.sim, "app_cmd") == 0UL {
        self.commands.push(index)
      } else {
        assert_eq(value(self.sim, "app_cmd"), 1UL)
        self.reads.push(
          (
            self.tick +
            self.read_delay +
            (self.random % 7U).reinterpret_as_int(),
            index,
          ),
        )
      }
    }
    if value(self.sim, "app_wdf_wren") == 1UL && data_ready {
      assert_eq(value(self.sim, "app_wdf_end"), 1UL)
      let words = Array::makei(4, i => {
        value(self.sim, "app_wdf_word" + i.to_string()).to_uint()
      })
      self.data.push((words, value(self.sim, "app_wdf_mask")))
    }
    if response {
      self.read_head += 1
    }
  }
  self.max_outstanding.val = Int32::max(
    self.max_outstanding.val,
    self.reads.length() - self.read_head,
  )
  while self.write_head < self.commands.length() &&
        self.write_head < self.data.length() {
    let index = self.commands[self.write_head]
    let (words, mask) = self.data[self.write_head]
    for lane in 0..<4 {
      let mut written = self.memory[index][lane]
      for byte in 0..<4 {
        if (mask & (1UL << (lane * 4 + byte))) == 0UL {
          let bits = 255U << (byte * 8)
          written = (written & bits.lnot()) | (words[lane] & bits)
        }
      }
      self.memory[index][lane] = written
    }
    self.write_head += 1
  }
  let domains = if self.tick % self.period == 0 {
    [@ir.ClockDomainId::new(0), @ir.ClockDomainId::new(1)]
  } else {
    [@ir.ClockDomainId::new(1)]
  }
  if self.recording {
    let drives : Array[@verilator.AtomicStimulusDrive] = []
    for p in @verilator.input_ports(self.ports) {
      let node = self.hardware
        .nodes()
        .iter()
        .find_first(n => n.kind() is Input(name) && name == p.source_name())
        .unwrap()
      let logic = self.sim.value(node.id())
      assert_true(logic.is_fully_known())
      drives.push(
        @verilator.AtomicStimulusDrive::checked(
          p.emitted_name(),
          @verilator.normalized_known(p.width(), logic.value_bits()),
        ),
      )
    }
    self.events.push(
      @verilator.AtomicStimulusEvent::checked(
        self.tick.to_uint64(),
        self.tick.to_uint64(),
        drives,
        domains.map(d => d.ordinal()),
      ),
    )
  }
  self.sim.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(self.tick.to_uint64()),
      [],
      domains,
    ),
  )
  if self.recording {
    let row = [self.tick.to_string(), self.tick.to_string()]
    for p in @verilator.output_ports(self.ports) {
      row.push(
        @verilator.padded_hex(value(self.sim, p.source_name()), p.width()),
      )
    }
    self.rows.write_string(row.join("\t") + "\n")
  }
  self.tick += 1
}

///|
fn bridge_bench(
  recording~ : Bool = false,
  legacy~ : Bool = false,
  period~ : Int32 = 4,
  wide~ : Bool = false,
  batch~ : Bool = false,
  streaming~ : Bool = false,
  staggered~ : Bool = false,
  read_ahead~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  delivery~ : Bool = false,
) -> BridgeBench raise {
  let hw = if read_ahead {
    @ddr.read_ahead_bridge_evidence(
      staggered~,
      eight_row~,
      sixteen_row~,
      aligned_extent~,
      delivery~,
    ).0
  } else if streaming {
    @ddr.streaming_bridge_evidence(staggered~).0
  } else if batch {
    @ddr.batched_bridge()
  } else if wide {
    @ddr.wide_bridge()
  } else if legacy {
    @projection.bridge()
  } else {
    @ddr.bridge()
  }
  let sim = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      set(sim, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let result = BridgeBench::{
    packet_words: if delivery {
      8
    } else {
      4
    },
    group_rows: if sixteen_row {
      16
    } else if eight_row {
      8
    } else {
      4
    },
    period,
    max_outstanding: Ref(0),
    hardware: hw,
    joined: if streaming || read_ahead {
      hw
      .cdc_primitives()
      .iter()
      .filter_map(p => {
        match p {
          AsyncFifo(f) if f.name() == "word_responses" ||
            f.name().has_prefix("wide_response_") => Some(f)
          _ => None
        }
      })
      .to_array()
    } else {
      []
    },
    sim,
    ports: @verilator.collect_ports(
      hw,
      @systemverilog.emit_design(
        @ir.Design::single("prx100-ddr-projection-bridge/v1", hw),
      ).manifest(),
    ),
    events: [],
    rows: StringBuilder(),
    recording,
    memory: Array::makei(
      if sixteen_row {
        256
      } else if eight_row {
        128
      } else {
        64
      },
      _ => [0U, 0U, 0U, 0U],
    ),
    commands: [],
    data: [],
    reads: [],
    write_head: 0,
    read_head: 0,
    tick: 0,
    random: 0x5abc123U,
    accepted: false,
    result: None,
    results: [],
    bad_end: false,
    paused: false,
    command_paused: false,
    data_paused: false,
    read_delay: 3,
  }
  result.reset()
  result
}

///|
fn BridgeBench::reset(self : BridgeBench) -> Unit raise {
  set(self.sim, "request_valid", 1, 0UL)
  set(self.sim, "response_ready", 1, 0UL)
  set(self.sim, "reset", 1, 1UL)
  set(self.sim, "ui_reset", 1, 1UL)
  set(self.sim, "calibrated", 1, 0UL)
  self.commands.clear()
  self.data.clear()
  self.reads.clear()
  self.write_head = 0
  self.read_head = 0
  self.accepted = false
  self.result = None
  self.results.clear()
  set(self.sim, "request_line", 1, 0UL)
  set(self.sim, "request_burst", 1, 0UL)
  for _ in 0..<(4 * self.period) {
    self.step()
  }
  set(self.sim, "reset", 1, 0UL)
  set(self.sim, "ui_reset", 1, 0UL)
  set(self.sim, "calibrated", 1, 1UL)
  for _ in 0..<(4 * self.period) {
    self.step()
  }
  assert_eq(value(self.sim, "memory_healthy"), 1UL)
}

///|
fn BridgeBench::transaction(
  self : BridgeBench,
  address : UInt64,
  word? : UInt64,
  hold~ : Int32 = 0,
) -> (UInt64, UInt64) raise {
  self.accepted = false
  self.result = None
  set(self.sim, "request_line", 1, 0UL)
  set(self.sim, "request_burst", 1, 0UL)
  set(self.sim, "request_address", 28, address)
  set(self.sim, "request_write", 1, if word is Some(_) { 1UL } else { 0UL })
  set(self.sim, "request_data", 32, word.unwrap_or(0UL))
  set(self.sim, "request_valid", 1, 1UL)
  set(self.sim, "response_ready", 1, 0UL)
  for _ in 0..<300 {
    self.step()
    if self.accepted {
      break
    }
  }
  assert_true(self.accepted)
  set(self.sim, "request_valid", 1, 0UL)
  for _ in 0..<300 {
    if value(self.sim, "response_valid") == 1UL {
      break
    }
    self.step()
  }
  assert_eq(value(self.sim, "response_valid"), 1UL)
  let data = value(self.sim, "response_data")
  let fault = value(self.sim, "response_fault")
  for _ in 0..<hold {
    self.step()
    assert_eq(value(self.sim, "response_data"), data)
    assert_eq(value(self.sim, "response_fault"), fault)
  }
  set(self.sim, "response_ready", 1, 1UL)
  for _ in 0..<(self.period + 1) {
    self.step()
    if self.result is Some(_) {
      break
    }
  }
  assert_eq(self.result, Some((data, fault)))
  set(self.sim, "response_ready", 1, 0UL)
  (data, fault)
}
