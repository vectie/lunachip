///|
fn Bench::word(self : Bench, address : UInt64) -> UInt64 {
  self.memory.get(address).unwrap_or(0x5ac31fe0UL ^ (address / 4UL))
}

///|
fn Bench::step(self : Bench) -> Unit raise {
  self.random = self.random * 1664525U + 1013904223U
  let awr = (self.random & 3U) != 0U
  let wr = (self.random & 12U) != 0U
  let arr = (self.random & 48U) != 0U
  self.drive("m_axi_awready", if awr { 1UL } else { 0UL })
  self.drive("m_axi_wready", if wr { 1UL } else { 0UL })
  self.drive("m_axi_arready", if arr { 1UL } else { 0UL })
  let front = self.rd.get(0)
  let rv = front is Some((_, due, _)) && due <= self.cycle
  let bv = self.bd is Some(due) && due <= self.cycle
  self.drive("m_axi_rvalid", if rv { 1UL } else { 0UL })
  self.drive("m_axi_rlast", if front is Some((_, _, true)) { 1UL } else { 0UL })
  self.drive("m_axi_rresp", self.read_fault)
  self.drive("m_axi_bvalid", if bv { 1UL } else { 0UL })
  self.drive("m_axi_bresp", self.write_fault)
  for i in 0..<self.lanes {
    self.drive(
      "m_axi_rword" + i.to_string(),
      if front is Some((address, _, _)) {
        self.word(address + i.to_uint64() * 4UL)
      } else {
        0UL
      },
    )
  }
  self.settle()
  if self.inputs["reset"] == 0UL {
    if self.group_headers is Some(trace) &&
      self.control.get("ddr_request_valid") == 1UL &&
      self.bridge.get("request_ready") == 1UL &&
      self.control.get("ddr_request_wide") == 1UL {
      trace.push(self.control.get("ddr_request_data"))
    }
    for (name, value) in self.previous {
      assert_eq(self.get(name), value, msg=name)
    }
    self.previous.clear()
    for
      (valid, ready, names) in [
        (
          "m_axi_awvalid",
          awr,
          ["m_axi_awvalid", "m_axi_awaddr", "m_axi_awlen", "m_axi_awsize"],
        ),
        (
          "m_axi_arvalid",
          arr,
          ["m_axi_arvalid", "m_axi_araddr", "m_axi_arlen", "m_axi_arsize"],
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
          "s_axi_bvalid",
          self.inputs["s_axi_bready"] == 1UL,
          ["s_axi_bvalid", "s_axi_bresp"],
        ),
        (
          "s_axi_rvalid",
          self.inputs["s_axi_rready"] == 1UL,
          ["s_axi_rvalid", "s_axi_rresp", "s_axi_rdata"],
        ),
      ] {
      if self.get(valid) == 1UL && !ready {
        for name in names {
          self.previous.push((name, self.get(name)))
        }
      }
    }
    if rv && self.get("m_axi_rready") == 1UL {
      ignore(self.rd.remove(0))
    }
    if bv && self.get("m_axi_bready") == 1UL {
      self.bd = None
    }
    if awr && self.get("m_axi_awvalid") == 1UL {
      assert_true(self.aw is None)
      let address = self.get("m_axi_awaddr")
      assert_true(address < 0x80000000UL && address % 16UL == 0UL)
      let len = self.get("m_axi_awlen").to_int()
      assert_true(
        len == 0 || (len == 1 && self.lanes == 32 && address % 256UL == 0UL),
      )
      assert_eq(self.get("m_axi_awburst"), 1UL)
      assert_true(
        address % 4096UL + (len + 1).to_uint64() * (self.lanes * 4).to_uint64() <=
        4096UL,
      )
      if len == 1 {
        self.burst_writes += 1
      }
      assert_eq(
        1UL << self.get("m_axi_awsize").to_int(),
        (self.lanes * 4).to_uint64(),
      )
      self.aw = Some((address, len + 1))
      self.writes += 1
    }
    if !wr && self.lanes == 32 && self.get("m_axi_wvalid") == 1UL {
      self.previous.push(("m_axi_wstrb_hi", self.get("m_axi_wstrb_hi")))
      for lane in 4..<32 {
        let name = "m_axi_wword" + lane.to_string()
        self.previous.push((name, self.get(name)))
      }
    }
    if wr && self.get("m_axi_wvalid") == 1UL {
      assert_true(self.wd.length() < 2)
      self.wd.push(
        (
          Array::makei(self.lanes, i => self.get("m_axi_wword" + i.to_string())),
          self.get("m_axi_wstrb"),
          if self.lanes == 32 {
            self.get("m_axi_wstrb_hi")
          } else {
            0UL
          },
          self.get("m_axi_wlast") == 1UL,
        ),
      )
    }
    if arr && self.get("m_axi_arvalid") == 1UL {
      let address = self.get("m_axi_araddr")
      if self.read_addresses is Some(trace) {
        trace.push(address)
      }
      let bytes = (self.lanes * 4).to_uint64()
      let len = self.get("m_axi_arlen").to_int()
      assert_true(
        len == 0 ||
        (self.lanes == 32 && len == 3) ||
        (self.lanes >= 8 && len == 32 / self.lanes - 1),
      )
      assert_true(
        address < 0x80000000UL &&
        address % bytes == 0UL &&
        address % 4096UL + (len + 1).to_uint64() * bytes <= 4096UL,
      )
      assert_eq(1UL << self.get("m_axi_arsize").to_int(), bytes)
      for beat in 0..<=len {
        self.rd.push(
          (
            address + beat.to_uint64() * bytes,
            self.cycle + 1 + (self.random % 7U).reinterpret_as_int() + beat,
            beat == len,
          ),
        )
      }
      self.reads += 1
    }
    if self.aw is Some((address, remaining)) &&
      self.wd.get(0) is Some((words, lower, upper, last)) {
      assert_eq(last, remaining == 1)
      ignore(self.wd.remove(0))
      assert_true(self.bd is None)
      for i in 0..<self.lanes {
        let a = address + i.to_uint64() * 4UL
        let mut data = self.word(a)
        let mask = if i < 16 { lower } else { upper }
        for byte in 0..<4 {
          if (mask & (1UL << (i % 16 * 4 + byte))) != 0UL {
            let bits = 255UL << (byte * 8)
            data = (data & bits.lnot()) | (words[i] & bits)
          }
        }
        self.memory[a] = data
      }
      if last {
        self.aw = None
        self.bd = Some(self.cycle + 1 + (self.random % 5U).reinterpret_as_int())
      } else {
        self.aw = Some((address + (self.lanes * 4).to_uint64(), remaining - 1))
      }
    }
  }
  if self.recording {
    self.events.push(
      @v.AtomicStimulusEvent::checked(
        self.cycle.to_uint64(),
        self.cycle.to_uint64(),
        @v.input_ports(self.ports).map(p => {
          @v.AtomicStimulusDrive::checked(
            p.emitted_name(),
            @v.normalized_known(p.width(), self.inputs[p.source_name()]),
          )
        }),
        [0],
      ),
    )
  }
  // All inter-module inputs still refer to the same pre-edge snapshot.
  let event = @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(self.cycle.to_uint64()),
    [],
    [@ir.ClockDomainId::new(0)],
  )
  for m in [self.core, self.control, self.bridge] {
    m.sim.apply_event(event)
  }
  self.settle()
  if self.recording {
    let row = [self.cycle.to_string(), self.cycle.to_string()]
    for p in @v.output_ports(self.ports) {
      row.push(@v.padded_hex(self.get(p.source_name()), p.width()))
    }
    self.rows.write_string(row.join("\t") + "\n")
  }
  self.cycle += 1
}
