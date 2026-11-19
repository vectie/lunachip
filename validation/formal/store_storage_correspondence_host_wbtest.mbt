///|
// Scenario-local use of the existing RecordsResponse byte-host model. This
// answers only observed public requests and never reads or writes device SRAM.
priv struct StoreCorrespondenceScenario {
  source : @sim.Simulator
  observer : StoreStorageCorrespondence
  memory : Array[UInt64]
  requests : Array[Array[UInt64]]
  completions : Array[Array[UInt64]]
  mut pending : RecordsResponse?
  mut pending_request : Array[UInt64]?
  mut held : Array[UInt64]?
  mut next_tag : UInt64
  mut latency : Int32
  mut request_ready : UInt64
  mut admissions : Int32
  mut read_acks : Int32
  mut write_acks : Int32
}

///|
fn store_scenario_prepare() -> StoreCorrespondenceScenario raise {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let source = @sim.Simulator::prepare(fixture.hardware())
  let observer = store_correspondence_prepare(fixture)
  let scenario : StoreCorrespondenceScenario = {
    source,
    observer,
    memory: Array::make(1024, 165UL),
    requests: [],
    completions: [],
    pending: None,
    pending_request: None,
    held: None,
    next_tag: 0UL,
    latency: 2,
    request_ready: 1UL,
    admissions: 0,
    read_acks: 0,
    write_acks: 0,
  }
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  records_put(source, "reset", 1, 1UL)
  store_scenario_tick(scenario)
  records_put(source, "reset", 1, 0UL)
  records_put(source, "completion_ready", 1, 1UL)
  scenario
}

///|
fn store_scenario_request(source : @sim.Simulator) -> Array[UInt64] raise {
  let request : Array[UInt64] = []
  for field in ["write", "address", "bytes", "mask", "data", "tag"] {
    request.push(records_output(source, "memory_request_" + field))
  }
  request
}

///|
fn store_scenario_tick(scenario : StoreCorrespondenceScenario) -> Unit raise {
  let source = scenario.source
  let responding = scenario.pending is Some(response) && response.delay == 0
  records_put(source, "memory_request_ready", 1, scenario.request_ready)
  records_put(
    source,
    "memory_response_valid",
    1,
    if responding {
      1UL
    } else {
      0UL
    },
  )
  records_put(source, "memory_response_fault", 2, 0UL)
  match scenario.pending {
    Some(response) => {
      records_put(source, "memory_response_tag", 32, response.tag)
      records_put(source, "memory_response_data", 32, response.data)
    }
    None => {
      records_put(source, "memory_response_tag", 32, 0UL)
      records_put(source, "memory_response_data", 32, 0UL)
    }
  }
  source.settle()
  let reset = source.value(scenario.observer.slice.plan.probe.reset).to_uint64() ==
    1UL
  let valid = records_output(source, "memory_request_valid") == 1UL
  let offered = if valid { Some(store_scenario_request(source)) } else { None }
  if !reset && scenario.held is Some(previous) {
    assert_eq(offered, Some(previous))
  }
  scenario.held = if !reset && scenario.request_ready == 0UL {
    offered
  } else {
    None
  }
  let accepted = valid && scenario.request_ready == 1UL
  let response_ack = responding &&
    records_output(source, "memory_response_ready") == 1UL
  let public_admit = !reset &&
    source
    .value(
      dependency_generation_input(
        scenario.observer.fixture.hardware(),
        "descriptor_valid",
        @wire.bits(1),
      ),
    )
    .to_uint64() ==
    1UL &&
    records_output(source, "descriptor_ready") == 1UL
  if !reset &&
    records_output(source, "completion_valid") == 1UL &&
    source
    .value(
      dependency_generation_input(
        scenario.observer.fixture.hardware(),
        "completion_ready",
        @wire.bits(1),
      ),
    )
    .to_uint64() ==
    1UL {
    let completion : Array[UInt64] = []
    for field in ["id", "fault", "bytes_completed", "fault_address"] {
      completion.push(records_output(source, "completion_" + field))
    }
    scenario.completions.push(completion)
  }
  let mut newly_pending : RecordsResponse? = None
  let mut newly_owned : Array[UInt64]? = None
  if accepted {
    assert_false(reset || response_ack)
    assert_eq(scenario.pending, None)
    assert_eq(scenario.pending_request, None)
    guard offered is Some(request) else {
      fail("accepted request must have an actual offer")
    }
    assert_eq(request[5], scenario.next_tag)
    let address = request[1].to_int()
    assert_true(address >= 0 && address + request[2].to_int() <= 1024)
    let write = request[0] == 1UL
    assert_eq(request[0], if write { 1UL } else { 0UL })
    assert_eq(request[2], if write { 4UL } else { 1UL })
    assert_eq(request[3], if write { 15UL } else { 1UL })
    if write {
      for byte in 0..<4 {
        scenario.memory[address + byte] = (request[4] >> (byte * 8)) & 255UL
      }
    } else {
      assert_eq(request[4], 0UL)
    }
    newly_pending = Some({
      tag: request[5],
      data: if write {
        0UL
      } else {
        scenario.memory[address]
      },
      delay: scenario.latency,
    })
    newly_owned = Some(request)
    scenario.requests.push(request)
    scenario.next_tag += 1UL
  }
  if response_ack {
    assert_false(reset || accepted)
    guard scenario.pending is Some(response) &&
      scenario.pending_request is Some(owned) else {
      fail("actual response acknowledgment must belong to an accepted request")
    }
    assert_eq(response.tag, owned[5])
    if owned[0] == 1UL {
      scenario.write_acks += 1
    } else {
      scenario.read_acks += 1
    }
  }
  store_correspondence_tick(scenario.observer, source)
  if public_admit {
    scenario.admissions += 1
  }
  if newly_pending is Some(response) {
    scenario.pending = Some(response)
    scenario.pending_request = newly_owned
  } else if response_ack {
    scenario.pending = None
    scenario.pending_request = None
  } else if scenario.pending is Some(response) && response.delay > 0 {
    scenario.pending = Some({ ..response, delay: response.delay - 1, })
  }
}

///|
fn store_scenario_packet(
  opcode : UInt64,
  rows~ : UInt32 = 0,
  columns~ : UInt32 = 0,
  reduction~ : UInt32 = 0,
  base~ : UInt32 = 0,
  stride~ : UInt32 = 0,
  a~ : UInt32 = 0,
  b~ : UInt32 = 0,
  c~ : UInt32 = 0,
) -> Array[UInt64] raise {
  let descriptor : @slotted_descriptor.Descriptor = {
    opcode: match opcode {
      0UL => LoadA
      1UL => LoadB
      2UL => MatMul
      3UL => StoreC
      4UL => Fence
      _ => fail("unsupported scenario opcode")
    },
    id: 73,
    rows,
    columns,
    reduction,
    base,
    stride,
    a_slot: a,
    b_slot: b,
    c_slot: c,
  }
  let bytes = descriptor.encode()
  let lanes = Array::make(4, 0UL)
  for lane in 0..<4 {
    for byte in 0..<8 {
      lanes[lane] = lanes[lane] |
        (bytes[lane * 8 + byte].to_uint64() << (byte * 8))
    }
  }
  lanes
}

///|
fn store_scenario_admit(
  scenario : StoreCorrespondenceScenario,
  packet : Array[UInt64],
) -> Unit raise {
  let before = scenario.admissions
  records_present(scenario.source, Some(packet))
  for _ in 0..<256 {
    store_scenario_tick(scenario)
    if scenario.admissions == before + 1 {
      break
    }
  }
  assert_eq(scenario.admissions, before + 1)
  records_present(scenario.source, None)
}

///|
fn store_scenario_wait_completions(
  scenario : StoreCorrespondenceScenario,
  count : Int32,
) -> Unit raise {
  for _ in 0..<2048 {
    if scenario.completions.length() == count {
      break
    }
    store_scenario_tick(scenario)
  }
  assert_eq(scenario.completions.length(), count)
}

///|
fn store_scenario_command(
  scenario : StoreCorrespondenceScenario,
  packet : Array[UInt64],
  progress : UInt64,
) -> Unit raise {
  let ordinal = scenario.completions.length()
  store_scenario_admit(scenario, packet)
  store_scenario_wait_completions(scenario, ordinal + 1)
  assert_eq(scenario.completions[ordinal], [73UL, 0UL, progress, 0UL])
}

///|
fn store_scenario_seed(
  scenario : StoreCorrespondenceScenario,
  base : Int32,
  stride : Int32,
  values : Array[Int32],
) -> Unit raise {
  assert_eq(values.length(), 4)
  for row in 0..<2 {
    for column in 0..<2 {
      scenario.memory[base + row * stride + column] = (values[row * 2 + column] &
      255).to_uint64()
    }
  }
}

///|
fn store_scenario_expected_words(
  memory : Array[UInt64],
  base : Int32,
  stride : Int32,
  values : Array[Int32],
) -> Unit {
  for index in 0..<4 {
    let bits = values[index].to_int64().reinterpret_as_uint64() & 0xffffffffUL
    for byte in 0..<4 {
      memory[base + index / 2 * stride + index % 2 * 4 + byte] = (
          bits >> (byte * 8)
        ) &
        255UL
    }
  }
}
