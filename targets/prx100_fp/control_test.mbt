///|
test "FP AXI independent address/data response holds exact operands and rejects bad transactions" {
  let hw = @prx100_fp.controller()
  let s = @sim.Simulator::prepare(hw)
  let c = @sim.Simulator::prepare(@fp.dot_product())
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn out(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  let mut resetting = true
  fn step() -> Unit raise {
    for n in hw.nodes() {
      if n.kind() is Input(name) && name.has_prefix("c_") {
        s.set_input(name, c.output(name[2:].to_owned()))
      }
    }
    s.settle()
    c.set_input("clock", @wave.LogicValue::from_uint64(width=1, value=0UL))
    c.set_input(
      "reset",
      @wave.LogicValue::from_uint64(
        width=1,
        value=if resetting { 1UL } else { 0UL },
      ),
    )
    for name in ["load", "write_address", "write_data", "length", "start"] {
      c.set_input(name, s.output(name))
    }
    s.rising_edge("clock")
    c.rising_edge("clock")
  }
  for n in hw.nodes() {
    if n.kind() is Input(name) {
      set(name, n.signal_type().width().bits(), 0UL)
    }
  }
  set("reset", 1, 1UL)
  step()
  resetting = false
  set("reset", 1, 0UL)
  step()
  fn write(
    address : UInt64,
    word : UInt64,
    strobe : UInt64,
    skew : Bool,
  ) -> UInt64 raise {
    set("s_axi_awaddr", 32, address)
    set("s_axi_wdata", 32, word)
    set("s_axi_wstrb", 4, strobe)
    set("s_axi_awvalid", 1, if skew { 0UL } else { 1UL })
    set("s_axi_wvalid", 1, 1UL)
    step()
    set("s_axi_wvalid", 1, 0UL)
    if skew {
      for _ in 0..<3 {
        step()
      }
      set("s_axi_awvalid", 1, 1UL)
      step()
    }
    set("s_axi_awvalid", 1, 0UL)
    step()
    assert_eq(out("s_axi_bvalid"), 1UL)
    let response = out("s_axi_bresp")
    for _ in 0..<4 {
      step()
      assert_eq(out("s_axi_bvalid"), 1UL)
      assert_eq(out("s_axi_bresp"), response)
    }
    set("s_axi_bready", 1, 1UL)
    step()
    set("s_axi_bready", 1, 0UL)
    response
  }
  fn read(address : UInt64, expected_response : UInt64) -> UInt64 raise {
    set("s_axi_araddr", 32, address)
    set("s_axi_arvalid", 1, 1UL)
    step()
    set("s_axi_arvalid", 1, 0UL)
    assert_eq(out("s_axi_rvalid"), 1UL)
    assert_eq(out("s_axi_rresp"), expected_response)
    let word = out("s_axi_rdata")
    for _ in 0..<4 {
      step()
      assert_eq(out("s_axi_rdata"), word)
    }
    set("s_axi_rready", 1, 1UL)
    step()
    set("s_axi_rready", 1, 0UL)
    word
  }
  assert_eq(read(0UL, 0UL), 0x46504231UL)
  assert_eq(read(4UL, 0UL), 0x10000UL)
  for address in [1UL, 28UL, 4096UL] {
    assert_eq(read(address, 2UL), 0UL)
  }
  for
    (address, word, strobe) in [
      (0UL, 1UL, 15UL),
      (12UL, 0UL, 15UL),
      (12UL, 1025UL, 15UL),
      (4097UL, 0UL, 15UL),
      (4096UL, 0UL, 3UL),
      (8192UL, 0UL, 15UL),
      (16UL, 1UL, 15UL),
    ] {
    assert_eq(write(address, word, strobe, true), 2UL)
  }
  assert_eq(write(4096UL, 0x40003f00UL, 15UL, true), 0UL)
  assert_eq(write(4100UL, 0x3f00bfa0UL, 15UL, false), 0UL)
  assert_eq(write(12UL, 2UL, 15UL, false), 0UL)
  assert_eq(write(16UL, 1UL, 15UL, false), 0UL)
  for _ in 0..<15 {
    step()
  }
  assert_eq(read(8UL, 0UL), 2UL)
  assert_eq(read(20UL, 0UL), 0x3ec00000UL)
  assert_eq(read(24UL, 0UL), 8UL)
}
