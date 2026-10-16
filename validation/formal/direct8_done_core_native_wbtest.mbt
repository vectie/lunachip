///|
fn direct8_done_core_native(read : (String) -> UInt64 raise) -> Unit raise {
  if read("i_reset") == 1UL || read("composition_capture_state") != 3UL {
    return
  }
  let expected = if read("composition_shape_core_fault") == 0UL {
    0UL
  } else {
    3UL
  }
  direct8_fair_require(
    read("composition_shape_core_state") == expected,
    "d8d_done_core",
  )
}

///|
test "Done linkage checks both successful original direct8 slot pipelines" {
  let packets = Array::makei(8, index => direct8_completion_packet(index % 4))
  for (index, selectors) in [(4, 1UL), (5, 256UL), (6, 65793UL), (7, 65536UL)] {
    packets[index][3] = selectors
  }
  ignore(
    direct8_fair_native_run(
      packets,
      Array::make(8, 0UL),
      3,
      512,
      128,
      require_competing=true,
      observe_engines=true,
      observe_latency=true,
      observe_done=true,
    ),
  )
}

///|
test "Done linkage rejects successful uncleared core and faulted prematurely cleared core" {
  for fault in 0..<=3 {
    let frame : Map[String, UInt64] = {
      "composition_capture_state": 3UL,
      "composition_shape_core_fault": fault.to_uint64(),
      "composition_shape_core_state": if fault == 0 {
        0UL
      } else {
        3UL
      },
    }
    let read : (String) -> UInt64 raise = name => frame.get(name).unwrap_or(0UL)
    direct8_done_core_native(read)
    frame["composition_shape_core_state"] = if fault == 0 { 3UL } else { 0UL }
    try direct8_done_core_native(read) catch {
      BadFairEdge(label) => assert_eq(label, "d8d_done_core")
      error => fail("unexpected Done linkage failure: \{error}")
    } noraise {
      _ => fail("incorrect success/fault phase must fail")
    }
  }
}

///|
test "original slotted core holds successful and natural fault Done phases until ACK without erasing SRAM" {
  // These natural underlying-core fault paths do not force an internal fault
  // through the direct8 outer preflight controller or claim formal reachability.
  for (rows, fault) in [(0UL, 1UL), (1UL, 2UL), (1UL, 0UL)] {
    let source = @flux_tile.slotted_execute_tile(
      rows=8,
      columns=8,
      max_reduction=16,
    )
    let simulator = @sim.Simulator::prepare(source)
    for node in source.nodes() {
      if node.kind() is Input(name) && name != "clock" {
        records_put(simulator, name, node.signal_type().width().bits(), 0UL)
      }
    }
    for memory in source.memories() {
      for index in 0..<memory.depth().elements() {
        assert_true(
          simulator.memory_cell(memory.name(), index).is_fully_unknown(),
        )
      }
      for port in memory.read_ports() {
        assert_true(simulator.value(port.result()).is_fully_unknown())
      }
    }
    let roots = fetched_safety_shape_roots(
      source,
      rows=8,
      columns=8,
      max_reduction=16,
    )
    for binding in fetched_capture_roots(source, columns=8, depth=64) {
      roots.push(binding)
    }
    let nodes : Map[String, @ir.NodeId] = Map([])
    for binding in roots {
      nodes[binding.name] = binding.node
    }
    let read : (String) -> UInt64 raise = name => {
      if name == "i_reset" {
        return 0UL
      }
      simulator.value(nodes.get(name).unwrap()).to_uint64()
    }
    records_put(simulator, "reset", 1, 1UL)
    simulator.rising_edge("clock")
    records_put(simulator, "reset", 1, 0UL)
    if fault == 0UL {
      for side in ["a", "b"] {
        records_put(simulator, "load_" + side + "_valid", 1, 1UL)
        records_put(simulator, "load_" + side + "_data", 8, 1UL)
      }
      simulator.rising_edge("clock")
      for side in ["a", "b"] {
        records_put(simulator, "load_" + side + "_valid", 1, 0UL)
      }
    }
    for
      (name, width, value) in [
        ("command_rows", 4, rows),
        ("command_columns", 4, 1UL),
        ("command_reduction", 13, 1UL),
        ("command_valid", 1, 1UL),
        ("step_ready", 1, 1UL),
      ] {
      records_put(simulator, name, width, value)
    }
    simulator.rising_edge("clock")
    records_put(simulator, "command_valid", 1, 0UL)
    for _ in 0..<120 {
      simulator.settle()
      if read("composition_capture_state") == 3UL {
        break
      }
      simulator.rising_edge("clock")
    }
    for _ in 0..<4 {
      simulator.settle()
      assert_eq(read("composition_capture_state"), 3UL)
      assert_eq(
        read("composition_shape_core_state"),
        if fault == 0UL {
          0UL
        } else {
          3UL
        },
      )
      assert_eq(read("composition_shape_core_fault"), fault)
      direct8_done_core_native(read)
      simulator.rising_edge("clock")
    }
    records_put(simulator, "completion_ready", 1, 1UL)
    simulator.rising_edge("clock")
    simulator.settle()
    assert_eq(read("composition_capture_state"), 0UL)
    assert_eq(read("composition_shape_core_state"), 0UL)
    let memories = source.memories()
    let cells = Array::makei(memories.length(), m => {
      Array::makei(memories[m].depth().elements(), index => {
        simulator.memory_cell(memories[m].name(), index)
      })
    })
    let reads = Array::makei(memories.length(), m => {
      Array::makei(memories[m].read_ports().length(), r => {
        simulator.value(memories[m].read_ports()[r].result())
      })
    })
    if fault == 0UL {
      assert_eq(simulator.memory_cell("c_result_slot_0", 0).to_uint64(), 1UL)
    }
    records_put(simulator, "reset", 1, 1UL)
    simulator.rising_edge("clock")
    simulator.settle()
    for m, memory in memories {
      for index in 0..<memory.depth().elements() {
        assert_eq(simulator.memory_cell(memory.name(), index), cells[m][index])
        if fault != 0UL {
          assert_true(cells[m][index].is_fully_unknown())
        }
      }
      for r, port in memory.read_ports() {
        assert_eq(simulator.value(port.result()), reads[m][r])
      }
    }
  }
}
