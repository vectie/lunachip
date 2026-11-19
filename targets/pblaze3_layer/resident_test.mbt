///|
test "resident program loader owns stalled DDR and masks stale completion" {
  let h = Harness::new()
  assert_eq(h.read(0x90UL), (0UL, 1UL))
  assert_eq(h.write(0x3cUL, 0x70000004UL), 2UL)
  assert_eq(h.write(0x3cUL, 0x80000000UL), 2UL)
  assert_eq(h.write(0x3cUL, 0x7fffffc0UL), 0UL)
  assert_eq(h.write(0x14UL, 2UL), 0UL)
  assert_eq(h.write(0x10UL, 1UL), 2UL) // complete program would wrap aperture
  assert_eq(h.write(0x3cUL, 0x70000000UL), 0UL)
  h.set("c_done", 1, 1UL)
  assert_eq(h.write(0x10UL, 1UL), 0UL)
  assert_eq(h.read(8UL), (0UL, 3UL)) // healthy+busy, never stale DONE
  assert_eq(h.read(0x38UL), (0UL, 1UL))
  assert_eq(h.write(0x3cUL, 0UL), 2UL)
  assert_eq(h.write(0x20000UL, 0UL), 2UL)
  for i in 0..<32 {
    for _ in 0..<4 {
      h.tick()
    }
    assert_eq(h.get("ddr_request_valid"), 1UL)
    assert_eq(h.get("ddr_request_address"), 0x70000000UL + i.to_uint64() * 4UL)
    assert_eq(h.get("ddr_request_write"), 0UL)
    assert_eq(h.get("ddr_request_line"), 0UL)
    assert_eq(h.get("start"), 0UL)
    h.set("ddr_request_ready", 1, 1UL)
    h.tick()
    h.set("ddr_request_ready", 1, 0UL)
    for _ in 0..<3 {
      h.tick()
      assert_eq(h.get("program_write"), 0UL)
    }
    h.set("ddr_response_valid", 1, 1UL)
    h.set("ddr_response_last", 1, 1UL)
    h.set("ddr_response_data", 32, i.to_uint64() + 19UL)
    let owner = h.get("observe_owner")
    let issued = h.get("observe_issued")
    let protocol = h.get("observe_protocol")
    let result = h.get("observe_loader_result")
    let state = h.get("observe_loader_state")
    let fault = h.get("observe_loader_fault")
    assert_eq(
      h.get("program_write"),
      1UL,
      msg="word=\{i} owner=\{owner} issued=\{issued} protocol=\{protocol} result=\{result} state=\{state} fault=\{fault}",
    )
    assert_eq(h.get("program_address"), i.to_uint64())
    assert_eq(h.get("program_data"), i.to_uint64() + 19UL)
    assert_eq(h.get("ddr_response_valid_to_core"), 0UL)
    h.tick()
    h.set("ddr_response_valid", 1, 0UL)
    assert_eq(h.get("start"), if i == 31 { 1UL } else { 0UL })
  }
  h.set("c_busy", 1, 1UL)
  h.set("c_done", 1, 0UL)
  h.tick()
  assert_eq(h.get("start"), 0UL)
  let cycles = h.read(0x40UL).1
  assert_true(cycles > 250UL)
  for _ in 0..<4 {
    h.tick()
  }
  assert_eq(h.read(0x40UL).1, cycles)
  h.set("c_busy", 1, 0UL)
  h.set("c_done", 1, 1UL)
  assert_eq(h.read(8UL), (0UL, 5UL))
  assert_eq(h.read(0x38UL), (0UL, 1UL))
  assert_eq(h.write(0x3cUL, 0UL), 0UL)
  assert_eq(h.write(0x10UL, 1UL), 0UL) // legacy path still available
  assert_eq(h.read(0x38UL), (0UL, 2UL))
  assert_eq(h.read(0x40UL), (0UL, 0UL))
}

///|
test "resident fetch faults never commit a corrupt word or launch the core" {
  for fault in 0..<3 {
    let h = Harness::new()
    assert_eq(h.write(0x14UL, 1UL), 0UL)
    assert_eq(h.write(0x3cUL, 0x7fffffc0UL), 0UL)
    assert_eq(h.write(0x10UL, 1UL), 0UL)
    h.set("ddr_request_ready", 1, 1UL)
    h.tick()
    h.set("ddr_request_ready", 1, 0UL)
    h.set("ddr_response_valid", 1, 1UL)
    h.set("ddr_response_last", 1, if fault == 0 { 0UL } else { 1UL })
    h.set("ddr_response_fault", 2, if fault == 1 { 2UL } else { 0UL })
    if fault == 2 {
      h.set("memory_healthy", 1, 0UL)
    }
    assert_eq(h.get("program_write"), 0UL)
    assert_eq(h.get("start"), 0UL)
    h.tick()
    h.set("ddr_response_valid", 1, 0UL)
    h.set("memory_healthy", 1, 1UL)
    assert_eq(h.read(12UL), (0UL, 256UL))
    assert_eq(h.write(0x10UL, 1UL), 2UL)
    assert_eq(h.get("start"), 0UL)
    assert_eq(h.get("ddr_request_valid"), 0UL)
  }
}
