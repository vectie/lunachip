///|
fn Bench::write(
  self : Bench,
  address : UInt64,
  data : UInt64,
  strobe~ : UInt64 = 15UL,
  data_first~ : Bool = false,
  hold~ : Int32 = 0,
) -> UInt64 raise {
  self.set("s_axi_awaddr", 32, address)
  self.set("s_axi_wdata", 32, data)
  self.set("s_axi_wstrb", 4, strobe)
  self.set("s_axi_bready", 1, 0UL)
  let mut aw = false
  let mut w = false
  for i in 0..<2000 {
    self.set(
      "s_axi_awvalid",
      1,
      if !aw && (!data_first || i > 2) {
        1UL
      } else {
        0UL
      },
    )
    self.set(
      "s_axi_wvalid",
      1,
      if !w && (data_first || i > 2) {
        1UL
      } else {
        0UL
      },
    )
    self.sim.settle()
    if value(self.sim, "s_axi_awready") == 1UL && (!data_first || i > 2) {
      aw = true
    }
    if value(self.sim, "s_axi_wready") == 1UL && (data_first || i > 2) {
      w = true
    }
    self.step()
    if value(self.sim, "s_axi_bvalid") == 1UL {
      break
    }
  }
  assert_true(aw && w)
  self.set("s_axi_awvalid", 1, 0UL)
  self.set("s_axi_wvalid", 1, 0UL)
  assert_eq(value(self.sim, "s_axi_bvalid"), 1UL)
  let response = value(self.sim, "s_axi_bresp")
  for _ in 0..<hold {
    self.step()
    assert_eq(value(self.sim, "s_axi_bvalid"), 1UL)
    assert_eq(value(self.sim, "s_axi_bresp"), response)
  }
  self.set("s_axi_bready", 1, 1UL)
  self.step()
  self.set("s_axi_bready", 1, 0UL)
  response
}

///|
fn Bench::read(
  self : Bench,
  address : UInt64,
  response~ : UInt64 = 0UL,
  hold~ : Int32 = 0,
) -> UInt64 raise {
  self.set("s_axi_araddr", 32, address)
  self.set("s_axi_arvalid", 1, 1UL)
  self.set("s_axi_rready", 1, 0UL)
  self.step()
  self.set("s_axi_arvalid", 1, 0UL)
  for _ in 0..<2000 {
    if value(self.sim, "s_axi_rvalid") == 1UL {
      break
    }
    self.step()
  }
  assert_eq(value(self.sim, "s_axi_rvalid"), 1UL)
  assert_eq(value(self.sim, "s_axi_rresp"), response)
  let data = value(self.sim, "s_axi_rdata")
  for _ in 0..<hold {
    self.step()
    assert_eq(value(self.sim, "s_axi_rvalid"), 1UL)
    assert_eq(value(self.sim, "s_axi_rdata"), data)
  }
  self.set("s_axi_rready", 1, 1UL)
  self.step()
  self.set("s_axi_rready", 1, 0UL)
  data
}
