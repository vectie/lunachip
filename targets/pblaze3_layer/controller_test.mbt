///|
priv struct Harness {
  sim : @sim.Simulator
}

///|
fn Harness::new(
  profile~ : Bool = false,
  chain~ : Bool = false,
) -> Harness raise {
  let hw = @pblaze3_layer.controller(profile~, chain~)
  let sim = @sim.Simulator::prepare(hw)
  for node in hw.nodes() {
    if node.kind() is Input(name) {
      sim.set_input(
        name,
        @wave.LogicValue::from_uint64(
          width=node.signal_type().width().bits(),
          value=0UL,
        ),
      )
    }
  }
  let h = { sim, }
  h.set("reset", 1, 1UL)
  h.tick()
  h.set("reset", 1, 0UL)
  h.set("memory_healthy", 1, 1UL)
  h
}

///|
fn Harness::set(
  h : Harness,
  name : String,
  bits : Int32,
  value : UInt64,
) -> Unit raise {
  h.sim.set_input(name, @wave.LogicValue::from_uint64(width=bits, value~))
}

///|
fn Harness::get(h : Harness, name : String) -> UInt64 raise {
  h.sim.settle()
  let value = h.sim.output(name)
  assert_true(value.is_fully_known())
  value.value_bits()
}

///|
fn Harness::tick(h : Harness) -> Unit raise {
  h.sim.rising_edge("clock")
}

///|
fn Harness::read(h : Harness, address : UInt64) -> (UInt64, UInt64) raise {
  h.set("s_axi_araddr", 32, address)
  h.set("s_axi_arvalid", 1, 1UL)
  h.tick()
  h.set("s_axi_arvalid", 1, 0UL)
  h.tick()
  assert_eq(h.get("s_axi_rvalid"), 1UL)
  let result = (h.get("s_axi_rresp"), h.get("s_axi_rdata"))
  // The read result must remain stable while the host stalls.
  h.tick()
  assert_eq((h.get("s_axi_rresp"), h.get("s_axi_rdata")), result)
  h.set("s_axi_rready", 1, 1UL)
  h.tick()
  h.set("s_axi_rready", 1, 0UL)
  result
}

///|
test "PBlaze3 exposes versioned2GiB capability and rejects old DDR portal aliases" {
  let h = Harness::new()
  for
    (address, value) in [
      (0UL, 0x50423330UL),
      (4UL, 0x10001UL),
      (0x38UL, 0UL),
      (0x80UL, 0x80000000UL),
      (0x84UL, 0UL),
      (0x88UL, 31UL),
      (0x8cUL, 1UL),
    ] {
    assert_eq(h.read(address), (0UL, value))
  }
  for address in [0x10000000UL, 0x20000000UL, 0x30000000UL, 0x80000000UL] {
    assert_eq(h.read(address), (2UL, 0UL))
    assert_eq(h.get("ddr_request_valid"), 0UL)
  }
}

///|
fn Harness::write(
  h : Harness,
  address : UInt64,
  data : UInt64,
  strobe~ : UInt64 = 15UL,
) -> UInt64 raise {
  h.set("s_axi_awaddr", 32, address)
  h.set("s_axi_awvalid", 1, 1UL)
  h.set("s_axi_wdata", 32, data)
  h.set("s_axi_wstrb", 4, strobe)
  h.set("s_axi_wvalid", 1, 1UL)
  h.tick()
  h.set("s_axi_awvalid", 1, 0UL)
  h.set("s_axi_wvalid", 1, 0UL)
  h.tick()
  assert_eq(h.get("s_axi_bvalid"), 1UL)
  let response = h.get("s_axi_bresp")
  for _ in 0..<4 {
    h.tick()
    assert_eq(h.get("s_axi_bvalid"), 1UL)
    assert_eq(h.get("s_axi_bresp"), response)
  }
  h.set("s_axi_bready", 1, 1UL)
  h.tick()
  h.set("s_axi_bready", 1, 0UL)
  response
}

///|
test "PBlaze3 launch sequence distinguishes accepted START from stale DONE" {
  let h = Harness::new()
  assert_eq(h.write(0x10UL, 1UL), 2UL) // no program count yet
  assert_eq(h.read(0x38UL), (0UL, 0UL))
  assert_eq(h.write(0x14UL, 1UL), 0UL)
  h.set("c_done", 1, 1UL)
  assert_eq(h.write(0x10UL, 1UL), 0UL)
  assert_eq(h.read(0x38UL), (0UL, 1UL))
  // The old DONE input is deliberately held; it cannot advance a launch.
  for _ in 0..<8 {
    h.tick()
  }
  assert_eq(h.read(0x38UL), (0UL, 1UL))
  assert_eq(h.write(0x10UL, 2UL), 2UL)
  assert_eq(h.write(0x10UL, 1UL, strobe=1UL), 2UL)
  h.set("c_busy", 1, 1UL)
  assert_eq(h.write(0x10UL, 1UL), 2UL)
  h.set("c_busy", 1, 0UL)
  h.set("memory_healthy", 1, 0UL)
  assert_eq(h.write(0x10UL, 1UL), 2UL)
  assert_eq(h.read(0x38UL), (0UL, 1UL))
  h.set("memory_healthy", 1, 1UL)
  assert_eq(h.write(0x10UL, 1UL), 0UL)
  assert_eq(h.read(0x38UL), (0UL, 2UL))
  h.set("reset", 1, 1UL)
  h.tick()
  h.set("reset", 1, 0UL)
  assert_eq(h.read(0x38UL), (0UL, 0UL))
}

///|
test "PBlaze3 program writes use compact window and independent AW W handshake" {
  let h = Harness::new()
  h.set("s_axi_awaddr", 32, 0x20008UL)
  h.set("s_axi_awvalid", 1, 1UL)
  h.tick()
  h.set("s_axi_awvalid", 1, 0UL)
  for _ in 0..<4 {
    h.tick()
    assert_eq(h.get("program_write"), 0UL)
    assert_eq(h.get("s_axi_bvalid"), 0UL)
  }
  h.set("s_axi_wdata", 32, 0x12345678UL)
  h.set("s_axi_wstrb", 4, 15UL)
  h.set("s_axi_wvalid", 1, 1UL)
  h.tick()
  h.set("s_axi_wvalid", 1, 0UL)
  assert_eq(h.get("program_write"), 1UL)
  assert_eq(h.get("program_address"), 2UL)
  assert_eq(h.get("program_data"), 0x12345678UL)
  h.tick()
  assert_eq(h.get("s_axi_bvalid"), 1UL)
  assert_eq(h.get("s_axi_bresp"), 0UL)
  h.set("s_axi_bready", 1, 1UL)
  h.tick()
  h.set("s_axi_bready", 1, 0UL)
  h.set("c_busy", 1, 1UL)
  h.set("s_axi_awvalid", 1, 1UL)
  h.set("s_axi_wvalid", 1, 1UL)
  h.tick()
  h.set("s_axi_awvalid", 1, 0UL)
  h.set("s_axi_wvalid", 1, 0UL)
  assert_eq(h.get("program_write"), 0UL)
  h.tick()
  assert_eq(h.get("s_axi_bresp"), 2UL)
}

///|
test "PBlaze3 retains highDDRaddress under stall and owns all64 paired responses" {
  for early in [false, true] {
    let h = Harness::new()
    h.set("c_ddr_request_valid", 1, 1UL)
    h.set("c_ddr_request_line", 1, 1UL)
    h.set("c_ddr_request_burst", 1, 1UL)
    h.set("c_ddr_request_wide", 1, 1UL)
    h.set("c_ddr_request_address", 32, 0x70000000UL)
    h.set("c_ddr_request_data", 32, 0x80000100UL)
    h.tick()
    h.set("c_ddr_request_valid", 1, 0UL)
    h.set("c_ddr_request_address", 32, 0UL)
    for _ in 0..<4 {
      assert_eq(h.get("ddr_request_address"), 0x70000000UL)
      assert_eq(h.get("ddr_request_valid"), 1UL)
      h.tick()
    }
    h.set("ddr_request_ready", 1, 1UL)
    h.tick()
    h.set("ddr_request_ready", 1, 0UL)
    for i in 0..<64 {
      h.set("ddr_response_valid", 1, 1UL)
      h.set(
        "ddr_response_last",
        1,
        if i == (if early { 31 } else { 63 }) {
          1UL
        } else {
          0UL
        },
      )
      h.set("ddr_response_data7", 32, (i + 100).to_uint64())
      assert_eq(h.get("ddr_response_data7_to_core"), (i + 100).to_uint64())
      h.tick()
      if early && i == 31 {
        assert_eq(h.get("memory_healthy_to_core"), 0UL)
        break
      }
    }
    h.set("ddr_response_valid", 1, 0UL)
    h.set("ddr_response_last", 1, 0UL)
    h.tick()
    assert_eq(h.get("memory_healthy_to_core"), if early { 0UL } else { 1UL })
  }
}
