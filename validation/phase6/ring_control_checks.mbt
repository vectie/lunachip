///|
priv struct RingControlCounts {
  retired : Array[Int32]
  requests : Array[Array[Int32]]
  acks : Array[Array[Int32]]
  configurations : Array[Int32]
  publications : Array[Int32]
  mut noop_publications : Int32
  mut held_edges : Int32
  mut held : CompletionSnapshot?
}

///|
fn ring_control_counts() -> RingControlCounts {
  {
    retired: Array::make(7, 0),
    requests: [
      for _ in 0..<7 => [0, 0, 0]
    ],
    acks: [
      for _ in 0..<7 => [0, 0, 0]
    ],
    configurations: Array::make(7, 0),
    publications: Array::make(7, 0),
    noop_publications: 0,
    held_edges: 0,
    held: None,
  }
}

///|
fn ring_control_core(context : FaultContext) -> Array[UInt64] raise {
  [
    for
      name in [
        "accepted_steps", "active_cycles", "elapsed_cycles", "stall_cycles", "capture_cycles",
      ] => output_value(context.trace.simulator, name)
  ]
}

///|
fn ring_control_assert_transport(context : FaultContext) -> Unit raise {
  for name in ["transport_halted", "transport_fault_address", "halted"] {
    if output_value(context.trace.simulator, name) != 0UL {
      fail(
        "ring-control rejection incorrectly poisoned shared transport: \{name}",
      )
    }
  }
}

///|
fn ring_control_request_class(request : Request) -> Int32 raise {
  if request.write == 1UL {
    2
  } else if request.write == 0UL &&
    request.bytes == 1UL &&
    request.mask == 1UL &&
    request.data == 0UL {
    if request.address >= 3072UL && request.address < 3200UL {
      0
    } else if request.address == 32UL ||
      request.address == 64UL ||
      (request.address >= 512UL && request.address < 1024UL) ||
      (request.address >= 1280UL && request.address < 1792UL) {
      1
    } else {
      fail("ring-control request is outside authored source regions")
    }
  } else {
    fail("ring-control read payload is not one canonical byte")
  }
}

///|
fn ring_control_assert_request(
  counts : RingControlCounts,
  request : Request,
  epoch : Int32,
) -> Unit raise {
  if epoch < 6 {
    fail("control-only epoch issued a memory request")
  }
  let class = ring_control_request_class(request)
  let ordinal = counts.requests[epoch - 1][class]
  match class {
    0 => {
      let bound = if epoch == 6 { 128 } else { 224 }
      let address = (3072 + ordinal / 32 % 4 * 32 + ordinal % 32).to_uint64()
      if ordinal >= bound || request.address != address {
        fail(
          "ring-control descriptor request is not the next authored packet byte",
        )
      }
    }
    1 => {
      let address = if epoch == 6 {
        if ordinal < 512 {
          (512 + ordinal).to_uint64()
        } else if ordinal < 1024 {
          (1280 + ordinal - 512).to_uint64()
        } else {
          fail("ring-control long loads issued an extra byte")
        }
      } else {
        match ordinal {
          0 => 32UL
          1 => 64UL
          _ => fail("ring-control recovery issued unexpected operand DMA")
        }
      }
      if request.address != address {
        fail(
          "ring-control operand request differs from its independent load layout",
        )
      }
    }
    _ => {
      if ordinal != 0 {
        fail("ring-control epoch issued an extra Store word")
      }
      ring_control_assert_write(request, epoch)
    }
  }
  let classes = counts.requests[epoch - 1]
  let total = classes[0] + classes[1] + classes[2]
  if request.tag != total.to_uint64() {
    fail(
      "ring-control actual global request tag is not sequential within reset epoch",
    )
  }
}

///|
fn ring_control_assert_publication(
  context : FaultContext,
  counts : RingControlCounts,
  epoch : Int32,
  candidate : UInt64,
) -> Unit raise {
  let ordinal = counts.publications[epoch - 1]
  let (expected_candidate, producer, consumer) = match (epoch, ordinal) {
    (4, 0) => (17UL, 17UL, 17UL)
    (4, 1) => (16UL, 17UL, 17UL)
    (5, 0) => (22UL, 17UL, 17UL)
    (6, 0) => (2UL, 0UL, 0UL)
    (6, 1) => (6UL, 2UL, 2UL)
    (6, 2) => (8UL, 6UL, 3UL)
    (7, 0) => (4UL, 0UL, 0UL)
    (7, 1) => (7UL, 4UL, 4UL)
    _ => fail("unexpected ring-control publication handshake")
  }
  let simulator = context.trace.simulator
  if candidate != expected_candidate ||
    output_value(simulator, "producer_count") != producer ||
    output_value(simulator, "consumer_count") != consumer {
    fail(
      "ring-control publication did not use its independent PRE credit checkpoint",
    )
  }
  if epoch == 6 && ordinal == 2 {
    let active = output_value(simulator, "active_cycles")
    if active == 0UL ||
      active >= 512UL ||
      counts.acks[5][0] != 128 ||
      context.host.pending is Some(_) ||
      context.host.held is Some(_) {
      fail(
        "invalid publication missed the complete Store packet during genuine Run",
      )
    }
  } else if epoch >= 6 &&
    (context.host.pending is Some(_) || context.host.held is Some(_)) {
    fail("ring-control refill reused a slot with a live host obligation")
  }
}

///|
// Drive through the existing trace and host, not a second controller. The
// immutable context configuration is merely a default; invalid runtime bases
// and nonzero origins are explicit input offers, never context mutations.
fn ring_control_tick(
  context : FaultContext,
  counts : RingControlCounts,
  epoch~ : Int32,
  config_base? : UInt64,
  config_origin? : UInt64,
  config_valid~ : UInt64 = 0UL,
  publish_valid~ : UInt64 = 0UL,
  publish_producer~ : UInt64 = 0UL,
  completion_ready~ : UInt64 = 1UL,
) -> FaultEvents raise {
  if epoch < 1 || epoch > 7 || context.cycle >= context.cycle_limit {
    fail("ring-control tick exceeded its fixed epoch/cycle bounds")
  }
  let base = match config_base {
    Some(value) => value
    None => context.config_base
  }
  let origin = match config_origin {
    Some(value) => value
    None => context.config_origin
  }
  let index = epoch - 1
  let bus = context.host.drive(context.cycle + 1)
  context.cycle += 1
  context.trace.drive(
    {
      reset: 0UL,
      config_valid,
      config_base: base,
      publish_valid,
      publish_producer,
      completion_ready,
      bus,
    },
    context.cycle.to_uint64(),
    config_origin=origin,
  )
  let simulator = context.trace.simulator
  ring_control_assert_transport(context)
  let before = ring_control_core(context)
  if epoch < 6 &&
    (
      before != [0UL, 0UL, 0UL, 0UL, 0UL] ||
      output_value(simulator, "queue_occupancy") != 0UL ||
      output_value(simulator, "completion_valid") != 0UL
    ) {
    fail("control-only ring epoch acquired queue or compute work")
  }
  let configuration_accepted = config_valid == 1UL &&
    output_value(simulator, "config_ready") == 1UL
  let publication_accepted = publish_valid == 1UL &&
    output_value(simulator, "publish_ready") == 1UL
  let producer = output_value(simulator, "producer_count")
  let ring_fault = output_value(simulator, "ring_fault_valid")
  if ring_fault == 1UL && (configuration_accepted || publication_accepted) {
    fail("sticky ring fault accepted another control handshake")
  }
  if configuration_accepted {
    let expected_base = match epoch {
      1 => 4097UL
      2 => 4064UL
      3 => 0xffffffc0UL
      _ => 3072UL
    }
    if counts.configurations[index] != 0 ||
      base != expected_base ||
      origin != (if epoch <= 5 { 17UL } else { 0UL }) {
      fail(
        "ring-control configuration was duplicated or lost its offered origin",
      )
    }
    counts.configurations[index] += 1
  }
  if publication_accepted {
    if output_value(simulator, "configured") != 1UL {
      fail("ring-control published before actual configuration validation")
    }
    ring_control_assert_publication(context, counts, epoch, publish_producer)
    counts.publications[index] += 1
    if producer == publish_producer {
      if epoch != 4 || producer != 17UL {
        fail("ring-control observed an unintended no-op publication")
      }
      counts.noop_publications += 1
    }
  }
  let visible = if output_value(simulator, "completion_valid") == 1UL {
    Some(completion_snapshot(simulator))
  } else {
    None
  }
  if counts.held is Some(previous) {
    if visible != Some(previous) {
      fail("held ring-control completion changed before the next edge")
    }
  }
  let completion = if completion_ready == 1UL { visible } else { None }
  if visible is Some(actual) {
    ring_control_assert_completion(actual, epoch, counts.retired[index])
    if (epoch == 6 && actual.id == 504UL) || (epoch == 7 && actual.id == 606UL) {
      // Use prior saved ACK count, not a response concurrently sampled below.
      if counts.acks[index][2] != 1 {
        fail("Store terminal appeared before its saved successful write ACK")
      }
    }
    if completion_ready == 0UL {
      if epoch != 6 || actual.id != 503UL {
        fail("ring-control held a completion outside its authored long Mat")
      }
      counts.held_edges += 1
      counts.held = Some(actual)
    } else {
      counts.held = None
    }
  }
  // Check the actual offered write BEFORE Host::accept applies memory effects.
  if output_value(simulator, "memory_request_valid") == 1UL {
    let request : Request = {
      write: output_value(simulator, "memory_request_write"),
      address: output_value(simulator, "memory_request_address"),
      bytes: output_value(simulator, "memory_request_bytes"),
      mask: output_value(simulator, "memory_request_mask"),
      data: output_value(simulator, "memory_request_data"),
      tag: output_value(simulator, "memory_request_tag"),
    }
    if ring_fault == 1UL && ring_control_request_class(request) == 0 {
      fail("sticky ring fault continued fetching descriptor bytes")
    }
    ring_control_assert_request(counts, request, epoch)
  }
  let memory = context.host.accept(simulator, bus)
  if memory.accepted is Some(request) {
    counts.requests[index][ring_control_request_class(request)] += 1
  }
  if memory.acknowledged is Some(request) {
    if epoch < 6 {
      fail("control-only epoch acknowledged a memory request")
    }
    let class = ring_control_request_class(request)
    let ack_classes = counts.acks[index]
    let expected_tag = (ack_classes[0] + ack_classes[1] + ack_classes[2]).to_uint64()
    if bus.response_valid != 1UL ||
      bus.response_fault != 0UL ||
      bus.response_tag != request.tag ||
      request.tag != expected_tag ||
      counts.acks[index][class] >= counts.requests[index][class] {
      fail("ring-control ACK lost its saved successful accepted owner")
    }
    counts.acks[index][class] += 1
  }
  if completion is Some(_) {
    counts.retired[index] += 1
  }
  context.trace.edge(context.cycle.to_uint64(), observe=true)
  ring_control_assert_transport(context)
  if counts.held is Some(previous) {
    if output_value(simulator, "completion_valid") != 1UL ||
      completion_snapshot(simulator) != previous {
      fail("held ring-control completion changed across an active edge")
    }
  }
  let after = ring_control_core(context)
  let maximum = if epoch == 6 {
    [512UL, 512UL, 513UL, 0UL, 1UL]
  } else if epoch == 7 {
    [1UL, 1UL, 2UL, 0UL, 1UL]
  } else {
    [0UL, 0UL, 0UL, 0UL, 0UL]
  }
  for component in 0..<5 {
    if after[component] < before[component] ||
      after[component] > maximum[component] ||
      after[component] > before[component] + 1UL {
      fail("ring-control compute counter left its finite per-edge range")
    }
  }
  if epoch < 6 &&
    (
      output_value(simulator, "queue_occupancy") != 0UL ||
      output_value(simulator, "completion_valid") != 0UL
    ) {
    fail("control-only ring epoch created a packet or completion on its edge")
  }
  { memory, configuration_accepted, publication_accepted, completion, }
}

///|
fn ring_control_assert_fault(
  context : FaultContext,
  epoch : Int32,
) -> Unit raise {
  let (code, address, configured, producer, consumer) = match epoch {
    1 => (1UL, 4097UL, 0UL, 0UL, 0UL)
    2 => (2UL, 4064UL, 0UL, 0UL, 0UL)
    3 => (2UL, 0xffffffc0UL, 0UL, 0UL, 0UL)
    4 | 5 => (3UL, 0UL, 1UL, 17UL, 17UL)
    6 => (3UL, 0UL, 1UL, 6UL, 4UL)
    _ => fail("recovery epoch must not have a ring fault")
  }
  for
    (name, expected) in [
      ("ring_fault_valid", 1UL),
      ("ring_fault_code", code),
      ("ring_fault_address", address),
      ("configured", configured),
      ("producer_count", producer),
      ("consumer_count", consumer),
      ("config_ready", 0UL),
      ("publish_ready", 0UL),
    ] {
    if output_value(context.trace.simulator, name) != expected {
      fail(
        "ring-control epoch\{epoch} sticky \{name} differs from its contract",
      )
    }
  }
  ring_control_assert_transport(context)
}

///|
fn ring_control_assert_drained(
  context : FaultContext,
  counts : RingControlCounts,
  epoch : Int32,
  retired : Int32,
) -> Unit raise {
  let expected_consumer = retired.to_uint64()
  if counts.retired[epoch - 1] != retired ||
    counts.requests[epoch - 1] != counts.acks[epoch - 1] ||
    context.host.pending is Some(_) ||
    context.host.held is Some(_) ||
    output_value(context.trace.simulator, "consumer_count") != expected_consumer ||
    output_value(context.trace.simulator, "queue_occupancy") != 0UL ||
    output_value(context.trace.simulator, "completion_valid") != 0UL {
    fail("ring-control batch did not fully drain its real obligations")
  }
  let expected_producer = if epoch == 6 && retired == 4 {
    6UL
  } else {
    expected_consumer
  }
  if output_value(context.trace.simulator, "producer_count") !=
    expected_producer {
    fail("ring-control batch was refilled without committed consumer credit")
  }
  let expected_core = if epoch == 6 && retired == 4 {
    [512UL, 512UL, 513UL, 0UL, 1UL]
  } else if epoch == 7 && retired == 7 {
    [1UL, 1UL, 2UL, 0UL, 1UL]
  } else {
    [0UL, 0UL, 0UL, 0UL, 0UL]
  }
  if ring_control_core(context) != expected_core {
    fail("ring-control drained batch has incorrect Run/capture counters")
  }
}

///|
fn ring_control_assert_totals(
  context : FaultContext,
  counts : RingControlCounts,
) -> Unit raise {
  for index in 0..<7 {
    let expected = match index {
      5 => [128, 1024, 1]
      6 => [224, 2, 1]
      _ => [0, 0, 0]
    }
    if counts.requests[index] != expected || counts.acks[index] != expected {
      fail("ring-control epoch\{index + 1} actual request/ACK classes differ")
    }
  }
  if counts.retired != [0, 0, 0, 0, 0, 4, 7] ||
    counts.configurations != [1, 1, 1, 1, 1, 1, 1] ||
    counts.publications != [0, 0, 0, 2, 1, 3, 2] ||
    counts.noop_publications != 1 ||
    counts.held_edges != 32 ||
    counts.held is Some(_) ||
    context.host.requests != 1380 ||
    context.host.reads != 1378 ||
    context.host.writes != 8 ||
    context.host.next_tag != 227UL ||
    context.cycle > 32768 {
    fail(
      "ring-control finite workload totals differ from the documented eleven descriptors",
    )
  }
  ring_control_assert_drained(context, counts, 7, 7)
  for name in ["ring_fault_valid", "ring_fault_code", "ring_fault_address"] {
    if output_value(context.trace.simulator, name) != 0UL {
      fail("fresh ring-control recovery retained an old reader fault")
    }
  }
  verify_ring_control_memory(context.host.memory)
}
