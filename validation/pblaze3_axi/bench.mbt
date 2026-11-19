///|
priv struct Bench {
  hw : @ir.Module
  sim : @sim.Simulator
  ports : ReadOnlyArray[@verilator.HarnessPort]
  recording : Bool
  events : Array[@verilator.AtomicStimulusEvent]
  rows : StringBuilder
  memory : Map[UInt64, UInt64]
  reads : Array[UInt64]
  delivered_at_ar : Array[Int32]
  writes : Array[UInt64]
  responses : Array[(Array[UInt64], UInt64, UInt64)]
  mut cycle : Int32
  mut random : UInt32
  mut aw : UInt64?
  mut wd : (Array[UInt64], UInt64, UInt64)?
  rd : Array[(UInt64, Int32, Bool)]
  lanes : Int32
  latency : Int32
  read_credits : Int32
  stripe512 : Bool
  mut outstanding : Int32
  mut peak_outstanding : Int32
  mut bd : Int32?
  mut accepted : Bool
  mut aw_pause : Bool
  mut w_pause : Bool
  mut ar_pause : Bool
  mut read_fault : UInt64
  mut write_fault : UInt64
  mut bad_last : Bool
  previous : Array[(String, UInt64)]
  comparison : @sim.Simulator?
}

///|
fn set(
  s : @sim.Simulator,
  name : String,
  width : Int32,
  value : UInt64,
) -> Unit raise {
  s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn value(s : @sim.Simulator, name : String) -> UInt64 raise {
  let v = s.output(name)
  assert_true(v.is_fully_known())
  v.value_bits()
}

///|
fn Bench::word(self : Bench, address : UInt64) -> UInt64 {
  self.memory.get(address).unwrap_or((address / 4UL) ^ 0x5a37c019UL)
}

///|
fn Bench::step(self : Bench) -> Unit raise {
  self.random = self.random * 1664525U + 1013904223U
  let awr = !self.aw_pause && (self.random & 3U) != 0U
  let wr = !self.w_pause && (self.random & 12U) != 0U
  let arr = !self.ar_pause &&
    self.outstanding < self.read_credits &&
    (self.random & 48U) != 0U
  set(self.sim, "m_axi_awready", 1, if awr { 1UL } else { 0UL })
  set(self.sim, "m_axi_wready", 1, if wr { 1UL } else { 0UL })
  set(self.sim, "m_axi_arready", 1, if arr { 1UL } else { 0UL })
  let front = self.rd.get(0)
  let rv = front is Some((_, due, _)) && due <= self.cycle
  let bv = self.bd is Some(due) && due <= self.cycle
  set(self.sim, "m_axi_rvalid", 1, if rv { 1UL } else { 0UL })
  let last = front is Some((_, _, true))
  set(self.sim, "m_axi_rlast", 1, if last != self.bad_last { 1UL } else { 0UL })
  set(self.sim, "m_axi_rresp", 2, self.read_fault)
  set(self.sim, "m_axi_bvalid", 1, if bv { 1UL } else { 0UL })
  set(self.sim, "m_axi_bresp", 2, self.write_fault)
  for i in 0..<self.lanes {
    set(
      self.sim,
      "m_axi_rword" + i.to_string(),
      32,
      if front is Some((address, _, _)) {
        self.word(address + i.to_uint64() * 4UL)
      } else {
        0UL
      },
    )
  }
  self.sim.settle()
  if self.comparison is Some(other) {
    for node in self.hw.nodes() {
      if node.kind() is Input(name) {
        other.set_input(name, self.sim.value(node.id()))
      }
    }
    other.settle()
    for output in self.hw.outputs() {
      assert_eq(
        other.output(output.name()),
        self.sim.output(output.name()),
        msg="before edge \{self.cycle}: " + output.name(),
      )
    }
  }
  let resetting = self.sim.value(@ir.NodeId::new(1)).value_bits() == 1UL
  if !resetting {
    for (name, old) in self.previous {
      assert_eq(value(self.sim, name), old, msg=name)
    }
  }
  self.previous.clear()
  if !resetting {
    for
      (valid, ready, held) in [
        (
          "m_axi_awvalid",
          awr,
          [
            "m_axi_awvalid", "m_axi_awaddr", "m_axi_awlen", "m_axi_awsize", "m_axi_awburst",
          ],
        ),
        (
          "m_axi_arvalid",
          arr,
          [
            "m_axi_arvalid", "m_axi_araddr", "m_axi_arlen", "m_axi_arsize", "m_axi_arburst",
          ],
        ),
        (
          "m_axi_wvalid",
          wr,
          [
            "m_axi_wvalid", "m_axi_wword0", "m_axi_wword1", "m_axi_wword2", "m_axi_wword3",
            "m_axi_wstrb", "m_axi_wlast",
          ],
        ),
        (
          "response_valid",
          self.input_value("response_ready") == 1UL,
          [
            "response_valid", "response_data", "response_data1", "response_data2",
            "response_data3", "response_data4", "response_data5", "response_data6",
            "response_data7", "response_fault", "response_last", "response_wide",
          ],
        ),
      ] {
      if value(self.sim, valid) == 1UL && !ready {
        for name in held {
          self.previous.push((name, value(self.sim, name)))
        }
      }
    }
    if self.input_value("request_valid") == 1UL &&
      value(self.sim, "request_ready") == 1UL {
      self.accepted = true
    }
    if value(self.sim, "response_valid") == 1UL &&
      self.input_value("response_ready") == 1UL {
      self.responses.push(
        (
          Array::makei(if self.lanes >= 16 { self.lanes } else { 8 }, i => {
            value(
              self.sim,
              if i == 0 {
                "response_data"
              } else {
                "response_data" + i.to_string()
              },
            )
          }),
          value(self.sim, "response_fault"),
          value(self.sim, "response_last"),
        ),
      )
    }
    if rv && value(self.sim, "m_axi_rready") == 1UL {
      ignore(self.rd.remove(0))
      if last {
        self.outstanding -= 1
      }
    }
    if bv && value(self.sim, "m_axi_bready") == 1UL {
      self.bd = None
    }
    if awr && value(self.sim, "m_axi_awvalid") == 1UL {
      assert_true(self.aw is None)
      let a = value(self.sim, "m_axi_awaddr")
      assert_true(a < 0x80000000UL && a % 16UL == 0UL)
      assert_eq(value(self.sim, "m_axi_awlen"), 0UL)
      assert_eq(
        1UL << value(self.sim, "m_axi_awsize").to_int(),
        (self.lanes * 4).to_uint64(),
      )
      self.aw = Some(a)
      self.writes.push(a)
    }
    if wr && value(self.sim, "m_axi_wvalid") == 1UL {
      assert_true(self.wd is None)
      assert_eq(value(self.sim, "m_axi_wlast"), 1UL)
      self.wd = Some(
        (
          Array::makei(self.lanes, i => {
            value(self.sim, "m_axi_wword" + i.to_string())
          }),
          value(self.sim, "m_axi_wstrb"),
          if self.lanes == 32 {
            value(self.sim, "m_axi_wstrb_hi")
          } else {
            0UL
          },
        ),
      )
    }
    if arr && value(self.sim, "m_axi_arvalid") == 1UL {
      let a = value(self.sim, "m_axi_araddr")
      let bytes = (self.lanes * 4).to_uint64()
      let len = value(self.sim, "m_axi_arlen").to_int()
      assert_true(
        len == 0 ||
        (len == 3 && self.lanes == 32) ||
        (len == 7 && self.stripe512 && self.lanes == 32) ||
        (self.lanes >= 8 && len == 32 / self.lanes - 1),
      )
      assert_eq(1UL << value(self.sim, "m_axi_arsize").to_int(), bytes)
      assert_true(a < 0x80000000UL && a % bytes == 0UL)
      assert_true(a % 4096UL + (len + 1).to_uint64() * bytes <= 4096UL)
      for i in 0..<=len {
        self.rd.push(
          (
            a + i.to_uint64() * bytes,
            self.cycle +
            self.latency +
            1 +
            (self.random % 7U).reinterpret_as_int() +
            i,
            i == len,
          ),
        )
      }
      self.outstanding += 1
      self.peak_outstanding = self.peak_outstanding.max(self.outstanding)
      assert_true(self.outstanding <= (if self.lanes >= 8 { 16 } else { 1 }))
      self.reads.push(a)
      self.delivered_at_ar.push(self.responses.length())
    }
    if self.aw is Some(a) && self.wd is Some((words, lower, upper)) {
      for i in 0..<self.lanes {
        let address = a + i.to_uint64() * 4UL
        let mut word = self.word(address)
        let mask = if i < 16 { lower } else { upper }
        for byte in 0..<4 {
          if (mask & (1UL << (i % 16 * 4 + byte))) != 0UL {
            let bits = 255UL << (byte * 8)
            word = (word & bits.lnot()) | (words[i] & bits)
          }
        }
        self.memory[address] = word
      }
      self.aw = None
      self.wd = None
      self.bd = Some(self.cycle + 1 + (self.random % 5U).reinterpret_as_int())
    }
  }
  if self.recording {
    self.events.push(
      @verilator.AtomicStimulusEvent::checked(
        self.cycle.to_uint64(),
        self.cycle.to_uint64(),
        @verilator.input_ports(self.ports).map(p => {
          @verilator.AtomicStimulusDrive::checked(
            p.emitted_name(),
            @verilator.normalized_known(
              p.width(),
              self.input_value(p.source_name()),
            ),
          )
        }),
        [0],
      ),
    )
  }
  self.sim.apply_event(
    @sim.TimestampEvent::checked(
      @sim.SimulationTime::from_uint64(self.cycle.to_uint64()),
      [],
      [@ir.ClockDomainId::new(0)],
    ),
  )
  if self.comparison is Some(other) {
    other.apply_event(
      @sim.TimestampEvent::checked(
        @sim.SimulationTime::from_uint64(self.cycle.to_uint64()),
        [],
        [@ir.ClockDomainId::new(0)],
      ),
    )
    for output in self.hw.outputs() {
      assert_eq(
        other.output(output.name()),
        self.sim.output(output.name()),
        msg="after edge \{self.cycle}: " + output.name(),
      )
    }
  }
  if self.recording {
    let row = [self.cycle.to_string(), self.cycle.to_string()]
    for p in @verilator.output_ports(self.ports) {
      row.push(
        @verilator.padded_hex(value(self.sim, p.source_name()), p.width()),
      )
    }
    self.rows.write_string(row.join("\t") + "\n")
  }
  self.cycle += 1
}

///|
fn Bench::input_value(self : Bench, name : String) -> UInt64 raise {
  let n = self.hw
    .nodes()
    .iter()
    .find_first(n => n.kind() is Input(s) && s == name)
    .unwrap()
  self.sim.value(n.id()).value_bits()
}

///|
fn bench(
  recording~ : Bool = false,
  streaming~ : Bool = false,
  wide512~ : Bool = false,
  wide1024~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  group64_rows~ : Bool = false,
  stripe512~ : Bool = false,
  prefetch_row_blocks~ : Bool = false,
  latency~ : Int32 = 0,
  read_credits~ : Int32 = 32,
  compare_staged_response_last~ : Bool = false,
) -> Bench raise {
  let hw = @axi.bridge(
    streaming~,
    wide512~,
    wide1024~,
    deep_batch~,
    strided_rows~,
    group64_rows~,
    stripe512~,
    prefetch_row_blocks~,
    store_bursts=deep_batch,
  )
  let s = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      set(s, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let e = @systemverilog.emit_design(@ir.Design::single("pblaze3-axi/v1", hw))
  let b = Bench::{
    comparison: if compare_staged_response_last {
      Some(
        @sim.Simulator::prepare(
          @axi.bridge(
            streaming~,
            wide512~,
            wide1024~,
            deep_batch~,
            strided_rows~,
            group64_rows~,
            stripe512~,
            prefetch_row_blocks~,
            store_bursts=deep_batch,
            staged_response_last=true,
          ),
        ),
      )
    } else {
      None
    },
    hw,
    sim: s,
    ports: @verilator.collect_ports(hw, e.manifest()),
    recording,
    events: [],
    rows: StringBuilder(),
    memory: Map([]),
    reads: [],
    delivered_at_ar: [],
    writes: [],
    responses: [],
    cycle: 0,
    random: 0x351c7U,
    aw: None,
    wd: None,
    rd: [],
    lanes: if wide1024 {
      32
    } else if wide512 {
      16
    } else if streaming {
      8
    } else {
      4
    },
    latency,
    read_credits,
    stripe512,
    outstanding: 0,
    peak_outstanding: 0,
    bd: None,
    accepted: false,
    aw_pause: false,
    w_pause: false,
    ar_pause: false,
    read_fault: 0UL,
    write_fault: 0UL,
    bad_last: false,
    previous: [],
  }
  b.reset()
  b
}

///|
fn Bench::reset(self : Bench) -> Unit raise {
  set(self.sim, "reset", 1, 1UL)
  set(self.sim, "request_valid", 1, 0UL)
  set(self.sim, "response_ready", 1, 0UL)
  set(self.sim, "calibrated", 1, 0UL)
  self.previous.clear()
  self.aw = None
  self.wd = None
  self.rd.clear()
  self.outstanding = 0
  self.bd = None
  self.read_fault = 0UL
  self.write_fault = 0UL
  self.bad_last = false
  self.step()
  self.step()
  set(self.sim, "reset", 1, 0UL)
  set(self.sim, "calibrated", 1, 1UL)
  self.step()
}
