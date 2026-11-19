///|
test "a stalled AXI DDR grant stays owned when the other channel arrives" {
  for writing_first in [false, true] {
    let b = bench()
    b.memory[0U] = 0x89abcdefU
    b.environment(stalled=true)
    b.set("s_axi_rready", 1, 0UL)
    b.set("s_axi_bready", 1, 0UL)
    b.set("s_axi_awaddr", 32, 0x10000004UL)
    b.set("s_axi_wdata", 32, 0x10203040UL)
    b.set("s_axi_wstrb", 4, 15UL)
    b.set("s_axi_araddr", 32, 0x10000000UL)
    if writing_first {
      b.set("s_axi_awvalid", 1, 1UL)
      b.set("s_axi_wvalid", 1, 1UL)
    } else {
      b.set("s_axi_arvalid", 1, 1UL)
    }
    b.step()
    b.set("s_axi_awvalid", 1, 0UL)
    b.set("s_axi_wvalid", 1, 0UL)
    b.set("s_axi_arvalid", 1, 0UL)
    for _ in 0..<3 {
      b.step()
    }
    assert_eq(value(b.sim, "ddr_request_valid"), 1UL)
    let held = (
      value(b.sim, "ddr_request_write"),
      value(b.sim, "ddr_request_address"),
      value(b.sim, "ddr_request_data"),
    )
    if writing_first {
      b.set("s_axi_arvalid", 1, 1UL)
    } else {
      b.set("s_axi_awvalid", 1, 1UL)
      b.set("s_axi_wvalid", 1, 1UL)
    }
    b.step()
    b.set("s_axi_awvalid", 1, 0UL)
    b.set("s_axi_wvalid", 1, 0UL)
    b.set("s_axi_arvalid", 1, 0UL)
    for _ in 0..<12 {
      b.step()
      assert_eq(value(b.sim, "ddr_request_valid"), 1UL)
      assert_eq(
        (
          value(b.sim, "ddr_request_write"),
          value(b.sim, "ddr_request_address"),
          value(b.sim, "ddr_request_data"),
        ),
        held,
      )
    }
    b.environment()
    for _ in 0..<100 {
      b.step()
      if value(b.sim, "s_axi_rvalid") == 1UL &&
        value(b.sim, "s_axi_bvalid") == 1UL {
        break
      }
    }
    assert_eq(value(b.sim, "s_axi_rvalid"), 1UL)
    assert_eq(value(b.sim, "s_axi_bvalid"), 1UL)
    assert_eq(value(b.sim, "s_axi_rdata"), 0x89abcdefUL)
    assert_eq(value(b.sim, "s_axi_rresp"), 0UL)
    assert_eq(value(b.sim, "s_axi_bresp"), 0UL)
    assert_eq(b.memory[4U], 0x10203040U)
    b.set("s_axi_rready", 1, 1UL)
    b.set("s_axi_bready", 1, 1UL)
    b.step()
    b.set("s_axi_rready", 1, 0UL)
    b.set("s_axi_bready", 1, 0UL)
    assert_eq(b.read(0x10000004UL), 0x10203040UL)
  }
}
