///|
test "layer control elaborates deterministically and reports identity without uninitialized core data" {
  let hw = @prx100_layer.controller() catch { e => fail("\{Repr(e)}") }
  let s = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      s.set_input(
        name,
        @wave.LogicValue::from_uint64(
          width=node.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  set("memory_healthy", 1, 1UL)
  set("s_axi_araddr", 32, 0UL)
  set("s_axi_arvalid", 1, 1UL)
  s.rising_edge("clock")
  set("s_axi_arvalid", 1, 0UL)
  s.rising_edge("clock")
  assert_eq(get("s_axi_rvalid"), 1UL)
  assert_eq(get("s_axi_rresp"), 0UL)
  assert_eq(get("s_axi_rdata"), 0x514c5930UL)
  set("s_axi_rready", 1, 1UL)
  s.rising_edge("clock")
  // Busy host program writes must complete with SLVERR and no core write.
  set("c_busy", 1, 1UL)
  set("s_axi_awaddr", 32, 0x20000000UL)
  set("s_axi_awvalid", 1, 1UL)
  set("s_axi_wdata", 32, 0x12345678UL)
  set("s_axi_wstrb", 4, 15UL)
  set("s_axi_wvalid", 1, 1UL)
  s.rising_edge("clock")
  set("s_axi_awvalid", 1, 0UL)
  set("s_axi_wvalid", 1, 0UL)
  assert_eq(get("program_write"), 0UL)
  s.rising_edge("clock")
  assert_eq(get("s_axi_bvalid"), 1UL)
  assert_eq(get("s_axi_bresp"), 2UL)
}

///|
test "stalled DDR read payload stays zero while an independent AXI W channel changes" {
  let hw = @prx100_layer.controller()
  let s = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      s.set_input(
        name,
        @wave.LogicValue::from_uint64(
          width=node.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  fn set(name : String, width : Int32, value : UInt64) -> Unit raise {
    s.set_input(name, @wave.LogicValue::from_uint64(width~, value~))
  }
  fn get(name : String) -> UInt64 raise {
    let v = s.output(name)
    assert_true(v.is_fully_known())
    v.value_bits()
  }
  set("reset", 1, 1UL)
  s.rising_edge("clock")
  set("reset", 1, 0UL)
  set("memory_healthy", 1, 1UL)
  set("s_axi_araddr", 32, 0x10000000UL)
  set("s_axi_arvalid", 1, 1UL)
  s.rising_edge("clock")
  set("s_axi_arvalid", 1, 0UL)
  s.rising_edge("clock")
  assert_eq(get("ddr_request_valid"), 1UL)
  assert_eq(get("ddr_request_write"), 0UL)
  assert_eq(get("ddr_request_data"), 0UL)
  set("s_axi_wdata", 32, 0xdeadbeefUL)
  set("s_axi_wstrb", 4, 15UL)
  set("s_axi_wvalid", 1, 1UL)
  s.rising_edge("clock")
  set("s_axi_wvalid", 1, 0UL)
  for _ in 0..<5 {
    s.rising_edge("clock")
    assert_eq(get("ddr_request_valid"), 1UL)
    assert_eq(get("ddr_request_address"), 0UL)
    assert_eq(get("ddr_request_write"), 0UL)
    assert_eq(get("ddr_request_data"), 0UL)
  }
}
