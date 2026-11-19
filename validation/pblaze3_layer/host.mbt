///|
fn Bench::write(
  self : Bench,
  offset : UInt64,
  data : UInt64,
  response~ : UInt64 = 0UL,
  skew~ : Int32 = 0,
) -> Unit raise {
  self.drive("s_axi_awaddr", 0x40000000UL + offset)
  self.drive("s_axi_wdata", data)
  self.drive("s_axi_wstrb", 15UL)
  self.drive("s_axi_bready", 0UL)
  let mut aw = false
  let mut w = false
  for i in 0..<100 {
    self.drive(
      "s_axi_awvalid",
      if !aw && i >= (if skew > 0 { skew } else { 0 }) {
        1UL
      } else {
        0UL
      },
    )
    self.drive(
      "s_axi_wvalid",
      if !w && i >= (if skew < 0 { -skew } else { 0 }) {
        1UL
      } else {
        0UL
      },
    )
    self.settle()
    let af = self.inputs["s_axi_awvalid"] == 1UL &&
      self.get("s_axi_awready") == 1UL
    let wf = self.inputs["s_axi_wvalid"] == 1UL &&
      self.get("s_axi_wready") == 1UL
    self.step()
    aw = aw || af
    w = w || wf
    if self.get("s_axi_bvalid") == 1UL {
      break
    }
  }
  assert_true(aw && w)
  self.drive("s_axi_awvalid", 0UL)
  self.drive("s_axi_wvalid", 0UL)
  assert_eq(self.get("s_axi_bvalid"), 1UL)
  assert_eq(self.get("s_axi_bresp"), response)
  for _ in 0..<2 {
    self.step()
  }
  self.drive("s_axi_bready", 1UL)
  self.step()
  self.drive("s_axi_bready", 0UL)
}

///|
fn Bench::read(self : Bench, offset : UInt64) -> UInt64 raise {
  self.drive("s_axi_araddr", 0x40000000UL + offset)
  self.drive("s_axi_arvalid", 1UL)
  self.drive("s_axi_rready", 0UL)
  let mut accepted = false
  for _ in 0..<100 {
    self.settle()
    let fire = self.inputs["s_axi_arvalid"] == 1UL &&
      self.get("s_axi_arready") == 1UL
    self.step()
    if fire {
      accepted = true
      self.drive("s_axi_arvalid", 0UL)
    }
    if self.get("s_axi_rvalid") == 1UL {
      break
    }
  }
  assert_true(accepted)
  assert_eq(self.get("s_axi_rvalid"), 1UL)
  assert_eq(self.get("s_axi_rresp"), 0UL)
  let data = self.get("s_axi_rdata")
  for _ in 0..<2 {
    self.step()
  }
  self.drive("s_axi_rready", 1UL)
  self.step()
  self.drive("s_axi_rready", 0UL)
  data
}

///|
fn Bench::upload(self : Bench, program : Array[UInt32]) -> Unit raise {
  for i, word in program {
    self.write(
      0x20000UL + i.to_uint64() * 4UL,
      word.to_uint64(),
      skew=i % 5 - 2,
    )
  }
  assert_eq(self.read(0x20000UL), program[0].to_uint64())
  self.write(0x14UL, (program.length() / 16).to_uint64())
}

///|
fn Bench::complete(self : Bench, polls~ : Int32 = 500) -> Unit raise {
  for _ in 0..<polls {
    let status = self.read(8UL)
    assert_eq(status & 8UL, 0UL)
    if (status & 4UL) != 0UL {
      break
    }
  }
  assert_eq(self.read(8UL), 5UL)
  assert_eq(self.read(12UL), 0UL)
  assert_eq(self.control.get("observe_protocol"), 0UL)
}
