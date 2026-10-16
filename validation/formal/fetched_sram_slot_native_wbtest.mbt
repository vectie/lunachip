///|
test "fetched SRAM slot one preserves captured value ticket isolation and reset unknowns" {
  let source = fetched_transport_sequential().probe.source
  let simulator = @sim.Simulator::prepare(source)
  let model = FetchedSramNative::new(source)
  for node in source.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let packets = Array::makei(4, index => fetched_useful_packet(index))
  for (index, selectors) in [(0, 1UL), (1, 256UL), (2, 65793UL), (3, 65536UL)] {
    packets[index][3] = selectors
  }
  let mut configured = false
  let mut published = false
  let mut pending : FetchedUsefulNativeRequest? = None
  let mut retired = 0
  let mut writes = 0
  for edge in 0..<1600 {
    let reset = edge == 0
    let ready = edge % 4 == 0
    let respond = pending is Some(_) && edge % 3 == 0
    let data = match pending {
      Some(r) if !r.write && r.address < 128UL => {
        let offset = (r.address % 32UL).to_int()
        (packets[(r.address / 32UL).to_int()][offset / 8] >> (offset % 8 * 8)) &
        255UL
      }
      Some(r) if !r.write => fetched_useful_native_data(r.address)
      _ => 0UL
    }
    for
      (name, width, value) in [
        ("reset", 1, if reset { 1UL } else { 0UL }),
        ("config_valid", 1, if !reset && !configured { 1UL } else { 0UL }),
        (
          "publish_valid",
          1,
          if !reset && configured && !published {
            1UL
          } else {
            0UL
          },
        ),
        ("publish_producer", 32, 4UL),
        ("completion_ready", 1, if edge % 5 != 0 { 1UL } else { 0UL }),
        ("memory_request_ready", 1, if ready { 1UL } else { 0UL }),
        ("memory_response_valid", 1, if respond { 1UL } else { 0UL }),
        ("memory_response_tag", 32, pending.map(r => r.tag).unwrap_or(0UL)),
        ("memory_response_data", 32, data),
      ] {
      records_put(simulator, name, width, value)
    }
    simulator.settle()
    if !reset {
      if !configured && records_output(simulator, "config_ready") == 1UL {
        configured = true
      } else if configured &&
        !published &&
        records_output(simulator, "publish_ready") == 1UL {
        published = true
      }
      if ready && records_output(simulator, "memory_request_valid") == 1UL {
        assert_true(pending is None)
        let r : FetchedUsefulNativeRequest = {
          tag: records_output(simulator, "memory_request_tag"),
          address: records_output(simulator, "memory_request_address"),
          write: records_output(simulator, "memory_request_write") == 1UL,
          bytes: records_output(simulator, "memory_request_bytes"),
          mask: records_output(simulator, "memory_request_mask"),
          data: records_output(simulator, "memory_request_data"),
        }
        assert_true(fetched_dma_request_ok(r))
        if r.write {
          assert_eq((r.address, r.data), (768UL, 4294967267UL))
          writes += 1
        }
        pending = Some(r)
      } else if respond {
        assert_eq(records_output(simulator, "memory_response_ready"), 1UL)
        pending = None
      }
      if edge % 5 != 0 && records_output(simulator, "completion_valid") == 1UL {
        assert_eq(records_output(simulator, "completion_fault"), 0UL)
        retired += 1
      }
    }
    model.step(simulator, reset)
    simulator.rising_edge("clock")
    simulator.settle()
    model.check(simulator)
    if retired == 4 {
      break
    }
  }
  assert_eq((retired, writes, model.captures), (4, 1, 1))
  assert_true(model.snapshot_seen)
  assert_true(pending is None)
  assert_true(simulator.memory_cell("c_result_slot_0", 0).is_fully_unknown())
  assert_eq(
    simulator.memory_cell("c_result_slot_1", 0).to_uint64(),
    4294967267UL,
  )
  model.ticket[1] = model.ticket[1] ^ 0x80000000UL
  try model.check(simulator) catch {
    _ => ()
  } noraise {
    _ => fail("wrong high generation ticket accepted")
  }
  model.ticket[1] = model.ticket[1] ^ 0x80000000UL
  let before = simulator.memory_cell("c_result_slot_1", 0)
  records_put(simulator, "reset", 1, 1UL)
  simulator.settle()
  model.step(simulator, true)
  simulator.rising_edge("clock")
  simulator.settle()
  model.check(simulator)
  assert_eq(simulator.memory_cell("c_result_slot_1", 0), before)
  assert_true(simulator.memory_cell("c_result_slot_0", 0).is_fully_unknown())
}
