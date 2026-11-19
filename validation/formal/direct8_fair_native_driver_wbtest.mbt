///|
fn direct8_fair_sample(
  simulator : @sim.Simulator,
  pins : Array[(String, @ir.NodeId)],
) -> Direct8FairEdge raise {
  let input = name => {
    guard pins.filter(pin => pin.0 == name) is [(_, id)] else {
      fail("missing public direct8 input")
    }
    simulator.value(id).to_uint64()
  }
  let output = name => simulator.output(name).to_uint64()
  let request_valid = output("memory_request_valid") == 1UL
  let completion_valid = output("completion_valid") == 1UL
  {
    reset: input("reset") == 1UL,
    descriptor_valid: input("descriptor_valid") == 1UL,
    descriptor_ready: output("descriptor_ready") == 1UL,
    packet: Array::makei(4, lane => input("descriptor_lane_\{lane}")),
    request_valid,
    request_ready: input("memory_request_ready") == 1UL,
    request: if request_valid {
      ["write", "address", "bytes", "mask", "data", "tag"].map(field => {
        output("memory_request_" + field)
      })
    } else {
      [0UL, 0UL, 0UL, 0UL, 0UL, 0UL]
    },
    response_valid: input("memory_response_valid") == 1UL,
    response_ready: output("memory_response_ready") == 1UL,
    response: ["tag", "fault", "data"].map(field => {
      input("memory_response_" + field)
    }),
    completion_valid,
    completion_ready: input("completion_ready") == 1UL,
    completion: if completion_valid {
      ["id", "fault", "bytes_completed", "fault_address"].map(field => {
        output("completion_" + field)
      })
    } else {
      [0UL, 0UL, 0UL, 0UL]
    },
  }
}

///|
fn direct8_fair_hardware() -> @ir.Module raise {
  @flux_tile.queued_concurrent_tile(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    queue_depth=3,
  )
}

///|
fn direct8_fair_native_run(
  packets : Array[Array[UInt64]],
  faults : Array[UInt64],
  watch_index : Int32,
  expected_reads : Int32,
  expected_writes : Int32,
  require_competing~ : Bool = false,
  observe_engines~ : Bool = false,
  observe_latency~ : Bool = false,
  observe_done~ : Bool = false,
  payload_observer? : Direct8PayloadNative,
) -> Direct8FairNative raise {
  let source = direct8_fair_hardware()
  let simulator = @sim.Simulator::prepare(source)
  let pins = source
    .nodes()
    .filter_map(node => {
      match node.kind() {
        Input(name) if name != "clock" => Some((name, node.id()))
        _ => None
      }
    })
    .iter()
    .to_array()
  for node in source.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let mut initial_bits = 0
  for memory in source.memories() {
    initial_bits += memory.depth().elements() *
      memory.element_type().width().bits()
    for index in 0..<memory.depth().elements() {
      assert_true(
        simulator.memory_cell(memory.name(), index).is_fully_unknown(),
      )
    }
    for port in memory.read_ports() {
      assert_true(simulator.value(port.result()).is_fully_unknown())
    }
  }
  assert_eq((source.memories().length(), initial_bits), (38, 8960))
  let model = Direct8FairNative::new()
  let progress = Direct8ProgressNative::new()
  let arbiter = Direct8ArbiterNative::new()
  let arbiter_nodes = direct8_arbiter_native_nodes(source)
  let engines = if observe_engines {
    Some(Direct8EngineNative::new())
  } else {
    None
  }
  let latency = if observe_latency {
    Some(Direct8LatencyNative::new())
  } else {
    None
  }
  let observe_payload = payload_observer is Some(_)
  let engine_nodes = if observe_engines ||
    observe_latency ||
    observe_done ||
    observe_payload {
    direct8_engine_native_nodes(source, pending_slot=observe_done)
  } else {
    Map([])
  }
  if observe_payload {
    for binding in direct8_payload_bindings(direct8_arbiter_fixture()) {
      engine_nodes[binding.name] = binding.node
    }
  }
  let useful = if expected_reads == 256 && expected_writes == 64 {
    Some(Direct8UsefulNative::new())
  } else {
    None
  }
  let mut reads = 0
  let mut writes = 0
  let mut request_count = 0
  for edge in 0..<11752 {
    let reset = edge == 0
    let packet = packets.get(model.admitted).unwrap_or([0UL, 0UL, 0UL, 0UL])
    let respond = model.owner is Some(_) &&
      model.response_age >= (if request_count % 2 == 0 { 2 } else { 1 })
    let tag = model.owner.map(request => request[5]).unwrap_or(0UL)
    let data = model.owner
      .map(request => (request[1] * 17UL + 139UL) & 255UL)
      .unwrap_or(0UL)
    for
      (name, width, value) in [
        ("reset", 1, if reset { 1UL } else { 0UL }),
        (
          "descriptor_valid",
          1,
          if !reset && model.admitted < packets.length() {
            1UL
          } else {
            0UL
          },
        ),
        ("memory_request_ready", 1, if edge % 2 == 0 { 1UL } else { 0UL }),
        ("completion_ready", 1, if edge % 2 == 1 { 1UL } else { 0UL }),
        ("memory_response_valid", 1, if respond { 1UL } else { 0UL }),
        ("memory_response_tag", 32, tag),
        ("memory_response_fault", 2, 0UL),
        ("memory_response_data", 32, data),
      ] {
      records_put(simulator, name, width, value)
    }
    for lane in 0..<4 {
      records_put(simulator, "descriptor_lane_\{lane}", 64, packet[lane])
    }
    simulator.settle()
    let sample = direct8_fair_sample(simulator, pins)
    if !reset && sample.request_valid && sample.request_ready {
      assert_true(sample.request[1] + sample.request[2] <= 4096UL)
      if sample.request[0] == 1UL {
        assert_eq((sample.request[2], sample.request[3]), (4UL, 15UL))
        assert_eq(sample.request[1], 1024UL + (writes % 64).to_uint64() * 4UL)
        writes += 1
      } else {
        assert_eq((sample.request[2], sample.request[3]), (1UL, 1UL))
        let address = if reads % 256 < 128 {
          256UL + (reads % 256).to_uint64()
        } else {
          512UL + (reads % 256 - 128).to_uint64()
        }
        assert_eq(sample.request[1], address)
        reads += 1
      }
      request_count += 1
    }
    if !reset && sample.completion_valid && sample.completion_ready {
      assert_eq(sample.completion[0], 73UL)
      assert_eq(sample.completion[1], faults[model.retired])
    }
    progress.step(sample)
    if observe_done {
      direct8_done_core_native(name => {
        simulator.value(engine_nodes.get(name).unwrap()).to_uint64()
      })
      direct8_done_slot_native(name => {
        simulator.value(engine_nodes.get(name).unwrap()).to_uint64()
      })
    }
    if payload_observer is Some(observer) {
      observer.step(name => {
        simulator.value(engine_nodes.get(name).unwrap()).to_uint64()
      })
    }
    if latency is Some(observer) {
      direct8_service_credit_native(
        name => simulator.value(engine_nodes.get(name).unwrap()).to_uint64(),
        arbiter,
      )
      observer.step(
        name => simulator.value(engine_nodes.get(name).unwrap()).to_uint64(),
        arbiter.watches,
      )
    }
    arbiter.step(name => {
      simulator.value(arbiter_nodes.get(name).unwrap()).to_uint64()
    })
    if engines is Some(observer) {
      observer.step(name => {
        if name == "reader_ack" || name == "engine_ack" {
          let client = if name == "reader_ack" { "reader" } else { "engine" }
          let valid = simulator
            .value(engine_nodes.get("e_" + client + "_response_valid").unwrap())
            .to_uint64()
          let ready = simulator
            .value(engine_nodes.get("i_" + client + "_response_ready").unwrap())
            .to_uint64()
          valid & ready
        } else {
          simulator.value(engine_nodes.get(name).unwrap()).to_uint64()
        }
      })
    }
    if useful is Some(observer) {
      observer.step(sample)
    }
    model.step(sample, model.admitted == watch_index)
    simulator.rising_edge("clock")
    simulator.settle()
    if model.retired == packets.length() {
      break
    }
  }
  assert_eq(
    (model.admitted, model.retired, model.outstanding),
    (packets.length(), packets.length(), 0),
  )
  assert_eq((reads, writes), (expected_reads, expected_writes))
  assert_true(model.taken && !model.active && model.owner is None)
  assert_true(model.watch_retire_age is Some(age) && age <= 11718)
  assert_true(progress.owner is None && !progress.active)
  assert_false(arbiter.active)
  assert_true(arbiter.watches.all(watch => !watch.active))
  assert_eq(
    (arbiter.grants, arbiter.acks),
    ([expected_reads, expected_writes], [expected_reads, expected_writes]),
  )
  assert_eq(arbiter.done_events, arbiter.collector_events)
  if latency is Some(observer) {
    assert_eq(observer.completed, arbiter.done_events)
    assert_eq(observer.active, [false, false, false])
    assert_eq(observer.ages, [0, 0, 0])
    for engine, bound in [1666, 99, 898] {
      assert_true(observer.maximum[engine] <= bound)
    }
  }
  if require_competing {
    assert_true(arbiter.tied_grants > 0 || arbiter.contended_edges > 0)
    assert_eq(arbiter.done_events, [4, 2, 2])
    assert_true(arbiter.head_events.all(count => count >= 8))
  }
  if engines is Some(observer) {
    assert_eq(observer.advances, [expected_reads, expected_writes])
    assert_eq(
      (observer.core_advances, observer.captures, observer.releases),
      (60, 128, 2),
    )
    assert_eq(observer.lease, Some(0UL))
  }
  if useful is Some(observer) {
    assert_true(observer.qualified && observer.retired == 4)
    assert_eq((arbiter.grants, arbiter.acks), ([256, 64], [256, 64]))
    assert_eq(
      (arbiter.done_events, arbiter.collector_events),
      ([2, 1, 1], [2, 1, 1]),
    )
    assert_true(arbiter.head_events.all(count => count >= 4))
  }
  // Reset the real device, separately from the no-later-reset liveness scope.
  let memories = source.memories()
  let cells = Array::makei(memories.length(), m => {
    Array::makei(memories[m].depth().elements(), index => {
      simulator.memory_cell(memories[m].name(), index)
    })
  })
  let read_values = Array::makei(memories.length(), m => {
    Array::makei(memories[m].read_ports().length(), r => {
      simulator.value(memories[m].read_ports()[r].result())
    })
  })
  records_put(simulator, "reset", 1, 1UL)
  records_put(simulator, "memory_response_valid", 1, 0UL)
  simulator.rising_edge("clock")
  simulator.settle()
  for m, memory in memories {
    for index in 0..<memory.depth().elements() {
      assert_eq(simulator.memory_cell(memory.name(), index), cells[m][index])
    }
    for r, port in memory.read_ports() {
      assert_eq(simulator.value(port.result()), read_values[m][r])
    }
  }
  model
}
