///|
fn pattern(address : UInt64, lane : Int32, round : UInt64) -> UInt64 {
  let salts = [0x13579bdfUL, 0x2468ace0UL, 0x9e3779b9UL, 0x5a5aa5a5UL]
  (
    address ^
    0x31415926UL ^
    salts[lane] ^
    (if round == 0UL { 0UL } else { 0xffffffffUL })
  ) &
  0xffffffffUL
}

///|
fn Bench::word(self : Bench, address : UInt64) -> UInt64 {
  self.memory.get(address & self.alias_mask).unwrap_or(0xdeadbeefUL) ^
  (if self.corrupt_address == Some(address) { 0x100UL } else { 0UL })
}

///|
fn Bench::step(self : Bench) -> Unit raise {
  self.random = self.random * 1664525U + 1013904223U
  let awr = !self.aw_pause && (self.random & 3U) != 0U
  let wr = !self.w_pause && (self.random & 12U) != 0U
  let arr = !self.ar_pause && (self.random & 48U) != 0U
  self.drive("m_axi_awready", if awr { 1UL } else { 0UL })
  self.drive("m_axi_wready", if wr { 1UL } else { 0UL })
  self.drive("m_axi_arready", if arr { 1UL } else { 0UL })
  let rv = self.rd is Some((_, due)) && due <= self.cycle
  let bv = self.bd is Some(due) && due <= self.cycle
  self.drive("m_axi_rvalid", if rv { 1UL } else { 0UL })
  self.drive("m_axi_rlast", if self.bad_last { 0UL } else { 1UL })
  self.drive("m_axi_rresp", self.read_fault)
  self.drive("m_axi_bvalid", if bv { 1UL } else { 0UL })
  self.drive("m_axi_bresp", self.write_fault)
  for i in 0..<4 {
    self.drive(
      "m_axi_rword" + i.to_string(),
      if self.rd is Some((a, _)) {
        self.word(a + i.to_uint64() * 4UL)
      } else {
        0UL
      },
    )
  }
  self.settle()
  if self.inputs["reset"] == 0UL {
    for (name, old) in self.previous {
      assert_eq(self.get(name), old, msg=name)
    }
    self.previous.clear()
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
      ] {
      if self.get(valid) == 1UL && !ready {
        for name in held {
          self.previous.push((name, self.get(name)))
        }
      }
    }
    if rv && self.get("m_axi_rready") == 1UL {
      self.rd = None
    }
    if bv && self.get("m_axi_bready") == 1UL {
      self.bd = None
    }
    if awr && self.get("m_axi_awvalid") == 1UL {
      assert_true(self.aw is None)
      let a = self.get("m_axi_awaddr")
      assert_eq(a, self.base + self.writes % self.beats * 16UL)
      assert_true(a < 0x80000000UL)
      assert_eq(self.get("m_axi_awlen"), 0UL)
      assert_eq(self.get("m_axi_awsize"), 4UL)
      assert_eq(self.get("m_axi_awburst"), 1UL)
      assert_eq(
        self.reads,
        self.writes / self.beats * self.beats,
        msg="no next-round writes before complete read pass",
      )
      self.aw = Some(a)
      self.writes += 1UL
    }
    if wr && self.get("m_axi_wvalid") == 1UL {
      assert_true(self.wd is None)
      assert_eq(self.get("m_axi_wstrb"), 65535UL)
      assert_eq(self.get("m_axi_wlast"), 1UL)
      self.wd = Some(
        Array::makei(4, i => self.get("m_axi_wword" + i.to_string())),
      )
    }
    if arr && self.get("m_axi_arvalid") == 1UL {
      assert_true(self.rd is None)
      let a = self.get("m_axi_araddr")
      assert_eq(a, self.base + self.reads % self.beats * 16UL)
      assert_true(a < 0x80000000UL)
      assert_eq(self.get("m_axi_arlen"), 0UL)
      assert_eq(self.get("m_axi_arsize"), 4UL)
      assert_eq(self.get("m_axi_arburst"), 1UL)
      assert_eq(
        self.writes,
        (self.reads / self.beats + 1UL) * self.beats,
        msg="entire aperture must be written before first read",
      )
      assert_eq(
        self.memory.length(),
        if self.alias_mask == 0xffffffffUL {
          (self.beats * 4UL).to_int()
        } else {
          (self.beats * 2UL).to_int()
        },
      )
      self.rd = Some(
        (a, self.cycle + 1 + (self.random % 7U).reinterpret_as_int()),
      )
      self.reads += 1UL
    }
    if self.aw is Some(a) && self.wd is Some(words) {
      assert_true(self.bd is None)
      let round = (self.writes - 1UL) / self.beats
      for i in 0..<4 {
        assert_eq(
          words[i],
          pattern(a, i, round),
          msg="independent address/round/lane pattern",
        )
        self.memory[(a + i.to_uint64() * 4UL) & self.alias_mask] = words[i]
      }
      self.aw = None
      self.wd = None
      self.bd = Some(self.cycle + 1 + (self.random % 5U).reinterpret_as_int())
    }
  }
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
  let event = @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(self.cycle.to_uint64()),
    [],
    [@ir.ClockDomainId::new(0)],
  )
  // Freeze both modules' input snapshots before either sequential commit.
  self.control.sim.apply_event(event)
  self.bridge.sim.apply_event(event)
  self.settle()
  let row = [self.cycle.to_string(), self.cycle.to_string()]
  for p in @v.output_ports(self.ports) {
    row.push(@v.padded_hex(self.get(p.source_name()), p.width()))
  }
  self.rows.write_string(row.join("\t") + "\n")
  self.cycle += 1
}
