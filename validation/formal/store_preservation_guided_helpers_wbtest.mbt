///|
// Test-only original-transfer ghost, never fed back into hardware. This is
// native trajectory guidance, NOT an engine result or a safety assumption.
priv struct StoreGuidedTrace {
  emitted : @rtl.EmittedDesign
  producers : Array[@ir.NodeId]
  inputs : Array[String]
  causal : Array[String]
  words : Array[@wave.LogicValue]
  written : Array[UInt64]
  valid : Array[Bool]
  rows : Array[UInt64]
  columns : Array[UInt64]
  mut seen : Bool
  mut store_seen : Bool
  mut read_seen : Bool
  mut pregrant_seen : Bool
  mut intermediate : Bool
  mut final_seen : Bool
  mut generation_live : Bool
  mut grant_seen : Bool
  mut write_seen : Bool
  mut completed : Bool
  mut read_active : Bool
  mut read_basis : Bool
  mut read_slot : Int32
  mut read_id : UInt64
  mut read_address : Int32
  mut read_word : @wave.LogicValue
  mut steps : Int32
  mut read_accepts : Int32
  mut pregrant_edges : Int32
  mut opposite_accepts : Int32
  mut intermediate_captures : Int32
  mut final_captures : Int32
  mut genuine_hits : Int32
  mut qualified_grants : Int32
  mut qualified_writes : Int32
  mut qualified_acks : Int32
  mut coherent_hits : Int32
}

///|
fn store_guided_role(
  scenario : StoreCorrespondenceScenario,
  role : @flux_tile.StorePreservationRole,
) -> UInt64 raise {
  store_correspondence_observe(scenario.observer, scenario.source, role)
}

///|
fn store_guided_value(value : @wave.LogicValue) -> String {
  "width=\{value.width()} value=\{value.value_bits().to_string(radix=16)} known=\{value.known_mask().to_string(radix=16)}"
}

///|
fn store_guided_prepare() -> (StoreCorrespondenceScenario, StoreGuidedTrace) raise {
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let observer = store_correspondence_prepare(fixture)
  let scenario : StoreCorrespondenceScenario = {
    source: @sim.Simulator::prepare(fixture.hardware()),
    observer,
    memory: Array::make(1024, 165UL),
    requests: [],
    completions: [],
    pending: None,
    pending_request: None,
    held: None,
    next_tag: 0UL,
    latency: 0,
    request_ready: 1UL,
    admissions: 0,
    read_acks: 0,
    write_acks: 0,
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single("StoreStorageProjection", observer.slice.hardware),
  )
  let trace : StoreGuidedTrace = {
    emitted,
    producers: store_preservation_producers(observer.slice),
    inputs: [],
    causal: [],
    words: Array::make(8, @wave.LogicValue::unknown(width=32)),
    written: [0UL, 0UL],
    valid: [false, false],
    rows: [0UL, 0UL],
    columns: [0UL, 0UL],
    seen: false,
    store_seen: false,
    read_seen: false,
    pregrant_seen: false,
    intermediate: false,
    final_seen: false,
    generation_live: false,
    grant_seen: false,
    write_seen: false,
    completed: false,
    read_active: false,
    read_basis: false,
    read_slot: 0,
    read_id: 0UL,
    read_address: 0,
    read_word: @wave.LogicValue::unknown(width=32),
    steps: 0,
    read_accepts: 0,
    pregrant_edges: 0,
    opposite_accepts: 0,
    intermediate_captures: 0,
    final_captures: 0,
    genuine_hits: 0,
    qualified_grants: 0,
    qualified_writes: 0,
    qualified_acks: 0,
    coherent_hits: 0,
  }
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(scenario.source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  records_put(scenario.source, "reset", 1, 1UL)
  store_guided_tick(scenario, trace)
  records_put(scenario.source, "reset", 1, 0UL)
  records_put(scenario.source, "completion_ready", 1, 1UL)
  (scenario, trace)
}

///|
// Repeat only existing host drives before its tick, to record exactly the
// public inputs the existing byte-host helper will consume. No host state or
// internal controller is replaced. The helper subsequently checks the offer,
// accepts requests, drives matching responses and commits both real graphs.
fn store_guided_tick(
  scenario : StoreCorrespondenceScenario,
  trace : StoreGuidedTrace,
) -> Unit raise {
  guard trace.steps < 128 else { fail("guided Store exceeds 128 DUT edges") }
  let source = scenario.source
  records_put(source, "memory_request_ready", 1, scenario.request_ready)
  records_put(
    source,
    "memory_response_valid",
    1,
    if scenario.pending is Some(response) && response.delay == 0 {
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
  let slice = scenario.observer.slice
  for node in slice.plan.selected {
    if node.kind() is Input(name) && name != "clock" {
      let identifier = port_identifier(trace.emitted, InputPort, name)
      trace.inputs.push(
        "PRE \{trace.steps} public \{name} original=\{node.id().ordinal()} emitted=\{identifier} \{store_guided_value(source.value(node.id()))}",
      )
    }
  }
  for cell, producer in trace.producers {
    let name = "arithmetic_n\{producer.ordinal()}"
    let identifier = port_identifier(trace.emitted, InputPort, name)
    trace.inputs.push(
      "PRE \{trace.steps} producer \{cell} original=\{producer.ordinal()} emitted=\{identifier} \{store_guided_value(source.value(producer))}",
    )
  }
  store_guided_state(scenario, trace, "PRE")
  store_guided_monitor(scenario, trace)
  store_scenario_tick(scenario)
  store_guided_state(scenario, trace, "POST")
  trace.steps += 1
}

///|
// Complete native retained-state/read/cell and public-output record accompanies
// the input-only roster. These are observations, NEVER constraint targets.
fn store_guided_state(
  scenario : StoreCorrespondenceScenario,
  trace : StoreGuidedTrace,
  phase : String,
) -> Unit raise {
  let source = scenario.source
  let slice = scenario.observer.slice
  for observation in slice.plan.observations {
    trace.causal.push(
      "\{phase} \{trace.steps} \{store_preservation_role_alias(observation.role())} \{store_guided_value(source.value(observation.node()))}",
    )
  }
  for root in slice.plan.arbiter_roots {
    trace.causal.push(
      "\{phase} \{trace.steps} arbiter_\{root.name} \{store_guided_value(source.value(root.node))}",
    )
  }
  for node in slice.plan.selected {
    if !slice.plan.arithmetic.any(cut => cut.id() == node.id()) &&
      (node.kind() is Register(_) || node.kind() is MemoryRead(..)) {
      trace.causal.push(
        "\{phase} \{trace.steps} state original=\{node.id().ordinal()} \{store_guided_value(source.value(node.id()))}",
      )
    }
  }
  for memory in slice.plan.memories {
    for cell in 0..<memory.depth().elements() {
      trace.causal.push(
        "\{phase} \{trace.steps} cell memory=\{memory.id().ordinal()} index=\{cell} \{store_guided_value(source.memory_cell(memory.name(), cell))}",
      )
    }
  }
  for output in scenario.observer.fixture.hardware().outputs() {
    trace.causal.push(
      "\{phase} \{trace.steps} public-output \{output.name()} \{store_guided_value(source.output(output.name()))}",
    )
  }
  for cell, producer in trace.producers {
    trace.causal.push(
      "\{phase} \{trace.steps} producer \{cell} original=\{producer.ordinal()} \{store_guided_value(source.value(producer))}",
    )
  }
}

///|
// Implements only the nonfeeding production/transfer witness history in the
// frozen original monitor. Every boolean uses OLD PRE ghost and actual DUT
// events; reset/new Store/new read/generation priorities are kept explicit.
fn store_guided_monitor(
  scenario : StoreCorrespondenceScenario,
  trace : StoreGuidedTrace,
) -> Unit raise {
  let source = scenario.source
  if source.value(scenario.observer.slice.plan.probe.reset).to_uint64() == 1UL {
    trace.seen = true
    trace.store_seen = false
    trace.read_seen = false
    trace.pregrant_seen = false
    trace.intermediate = false
    trace.final_seen = false
    trace.generation_live = false
    trace.grant_seen = false
    trace.write_seen = false
    trace.completed = false
    trace.read_active = false
    trace.read_basis = false
    for slot in 0..<2 {
      trace.written[slot] = 0UL
      trace.valid[slot] = false
      trace.rows[slot] = 0UL
      trace.columns[slot] = 0UL
    }
    return
  }
  let store_accept = store_guided_role(scenario, Event(StoreAccept)) == 1UL
  let read_accept = store_guided_role(scenario, Event(ReadAccept)) == 1UL
  let legal = store_guided_role(scenario, Event(SlottedLegalAccept)) == 1UL
  let capture = store_guided_role(scenario, Event(Capture)) == 1UL
  let final_capture = store_guided_role(scenario, Event(FinalCapture)) == 1UL
  let state = store_guided_role(scenario, StoreRegister(State))
  let slot = store_guided_role(scenario, StoreRegister(Slot)).to_int()
  let id = store_guided_role(scenario, StoreRegister(Id))
  let address = store_guided_role(scenario, StoreRegister(Row)).to_int() * 2 +
    store_guided_role(scenario, StoreRegister(Column)).to_int()
  let ready = state == 3UL || state == 4UL
  let identity = trace.read_active &&
    trace.read_basis &&
    id == trace.read_id &&
    slot == trace.read_slot &&
    address == trace.read_address &&
    store_guided_role(scenario, Event(ResponseValid)) == 1UL &&
    store_guided_role(scenario, ResponseId) == trace.read_id &&
    store_guided_role(scenario, SlottedRegister(ResponseSlot)).to_int() ==
    trace.read_slot
  let pregrant = identity &&
    !ready &&
    state == 2UL &&
    store_guided_role(scenario, Event(StoreRequestValid)) == 1UL &&
    store_correspondence_arbiter(scenario.observer, source, "state") == 2UL &&
    store_correspondence_arbiter(scenario.observer, source, "owner") == 0UL
  guard scenario.observer.slice.plan.arbiter_roots.filter(root => {
      root.name == "owner"
    })
    is [owner] else {
    fail("guided exact original owner binding")
  }
  let (grant_node, choose_node, _) = dependency_generation_decoder_mux(
    scenario.observer.fixture.hardware(),
    owner.spec.next(),
  )
  let grant = source.value(grant_node).to_uint64() == 1UL &&
    source.value(choose_node).to_uint64() == 1UL
  assert_false(pregrant && grant)
  let opposite = pregrant &&
    trace.generation_live &&
    !legal &&
    capture &&
    store_guided_role(scenario, SlottedRegister(ActiveC)).to_int() !=
    trace.read_slot
  let genuine = trace.seen &&
    pregrant &&
    trace.read_seen &&
    trace.pregrant_seen &&
    trace.generation_live &&
    trace.intermediate &&
    trace.final_seen &&
    !legal &&
    store_guided_role(scenario, SlottedRegister(Pending)) == 1UL &&
    store_guided_role(scenario, ResponseFault) == 0UL &&
    @wave.LogicValue::from_uint64(
      width=32,
      value=store_guided_role(scenario, Event(ResponseData)),
    ) ==
    trace.read_word
  let coherent = trace.seen &&
    trace.store_seen &&
    trace.completed &&
    state == 4UL &&
    store_guided_role(scenario, StoreRegister(Fault)) == 0UL &&
    store_guided_role(scenario, StoreRegister(Rows)) == 2UL &&
    store_guided_role(scenario, StoreRegister(Columns)) == 2UL &&
    store_guided_role(scenario, StoreRegister(Progress)) == 16UL
  trace.causal.push(
    "PRE \{trace.steps} ghost read_active=\{trace.read_active} basis=\{trace.read_basis} read_slot=\{trace.read_slot} read_id=\{trace.read_id} read_address=\{trace.read_address} read_word=[\{store_guided_value(trace.read_word)}] store_seen=\{trace.store_seen} read_seen=\{trace.read_seen} pregrant_seen=\{trace.pregrant_seen} generation_live=\{trace.generation_live} intermediate=\{trace.intermediate} final=\{trace.final_seen} grant_seen=\{trace.grant_seen} write_seen=\{trace.write_seen} completed=\{trace.completed} genuine=\{genuine} coherent=\{coherent}",
  )
  for selected in 0..<2 {
    trace.causal.push(
      "PRE \{trace.steps} ghost-production slot=\{selected} valid=\{trace.valid[selected]} written=\{trace.written[selected]} rows=\{trace.rows[selected]} columns=\{trace.columns[selected]}",
    )
    for cell in 0..<4 {
      trace.causal.push(
        "PRE \{trace.steps} ghost-word slot=\{selected} cell=\{cell} \{store_guided_value(trace.words[selected * 4 + cell])}",
      )
    }
  }
  if genuine {
    trace.genuine_hits += 1
    let word = trace.read_word.to_uint64()
    assert_true((word ^ 1UL) != word)
  }
  if coherent {
    trace.coherent_hits += 1
  }
  if pregrant {
    trace.pregrant_edges += 1
  }
  let qualified_grant = trace.generation_live &&
    trace.final_seen &&
    identity &&
    grant
  let public_write = records_output(source, "memory_request_valid") == 1UL &&
    scenario.request_ready == 1UL &&
    store_correspondence_arbiter(scenario.observer, source, "owner") == 1UL &&
    records_output(source, "memory_request_write") == 1UL
  let good = store_guided_role(scenario, Event(StoreResponseGood)) == 1UL
  let next_active = read_accept || (trace.read_active && !ready)
  if store_accept {
    trace.store_seen = true
    trace.read_seen = false
    trace.pregrant_seen = false
    trace.intermediate = false
    trace.final_seen = false
    trace.generation_live = false
    trace.grant_seen = false
    trace.write_seen = false
    trace.completed = false
  } else if read_accept {
    trace.read_seen = trace.store_seen
    trace.pregrant_seen = false
    trace.intermediate = false
    trace.final_seen = false
    trace.grant_seen = false
    trace.write_seen = false
    trace.generation_live = legal &&
      store_guided_role(scenario, ComputeRegister(C)).to_int() != slot
  } else {
    if trace.grant_seen && trace.write_seen && good {
      trace.completed = true
      trace.qualified_acks += 1
    }
    if trace.grant_seen && public_write {
      trace.write_seen = true
      trace.qualified_writes += 1
    }
    if legal {
      trace.generation_live = trace.read_active &&
        !ready &&
        !trace.grant_seen &&
        store_guided_role(scenario, ComputeRegister(C)).to_int() !=
        trace.read_slot
      if trace.generation_live {
        trace.opposite_accepts += 1
      }
      if !trace.grant_seen {
        trace.intermediate = false
        trace.final_seen = false
      }
    } else {
      if trace.pregrant_seen && opposite && !final_capture {
        trace.intermediate = true
        trace.intermediate_captures += 1
      }
      if trace.intermediate && opposite && final_capture {
        trace.final_seen = true
        trace.final_captures += 1
      }
      if qualified_grant {
        trace.grant_seen = true
        trace.qualified_grants += 1
      }
    }
    if trace.store_seen && trace.read_seen && pregrant {
      trace.pregrant_seen = true
    }
  }
  if read_accept {
    trace.read_accepts += 1
    trace.read_slot = slot
    trace.read_id = id
    trace.read_address = address
    let in_bounds = store_guided_role(scenario, StoreRegister(Row)) <
      trace.rows[slot] &&
      store_guided_role(scenario, StoreRegister(Column)) < trace.columns[slot]
    trace.read_basis = trace.valid[slot] &&
      in_bounds &&
      address < 4 &&
      (trace.written[slot] & (1UL << address)) != 0UL
    trace.read_word = if trace.valid[slot] && in_bounds {
      trace.words[slot * 4 + address]
    } else {
      @wave.LogicValue::zero(width=32)
    }
  }
  trace.read_active = next_active
  // Original production ghost samples PRE producers at actual capture only.
  let active_slot = store_guided_role(scenario, SlottedRegister(ActiveC)).to_int()
  let capture_address = store_guided_role(scenario, SlottedRegister(CaptureRow)).to_int() *
    2 +
    store_guided_role(scenario, SlottedRegister(CaptureColumn)).to_int()
  for selected in 0..<2 {
    if legal &&
      store_guided_role(scenario, ComputeRegister(C)).to_int() == selected {
      trace.written[selected] = 0UL
      trace.valid[selected] = false
    } else if capture && active_slot == selected {
      assert_true(capture_address >= 0 && capture_address < 4)
      trace.written[selected] = trace.written[selected] |
        (1UL << capture_address)
      if final_capture {
        trace.valid[selected] = true
      }
    }
    if capture && active_slot == selected {
      trace.words[selected * 4 + capture_address] = source.value(
        trace.producers[capture_address],
      )
    }
    if final_capture && active_slot == selected {
      trace.rows[selected] = store_guided_role(scenario, CoreRegister(Rows))
      trace.columns[selected] = store_guided_role(
        scenario,
        CoreRegister(Columns),
      )
    }
  }
}
