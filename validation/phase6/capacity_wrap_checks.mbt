///|
priv struct CapacityWrapCounts {
  mut configurations : Int32
  mut publications : Int32
  mut requests : Int32
  mut acknowledgements : Int32
  mut retired : Int32
  mut held : CompletionSnapshot?
}

///|
fn capacity_wrap_assert_clean(context : FaultContext) -> Unit raise {
  for
    name in [
      "ring_fault_valid", "ring_fault_code", "ring_fault_address", "transport_halted",
      "transport_fault_address", "halted", "accepted_steps", "active_cycles", "elapsed_cycles",
      "stall_cycles", "capture_cycles",
    ] {
    if output_value(context.trace.simulator, name) != 0UL {
      fail("capacity/wrap replay changed \{name}")
    }
  }
}

///|
fn capacity_wrap_assert_held(
  context : FaultContext,
  counts : CapacityWrapCounts,
) -> Unit raise {
  let simulator = context.trace.simulator
  match counts.held {
    Some(previous) =>
      if output_value(simulator, "completion_valid") != 1UL ||
        completion_snapshot(simulator) != previous {
        fail("capacity/wrap oldest held terminal lost valid or payload")
      }
    None =>
      if output_value(simulator, "completion_valid") == 1UL {
        let actual = completion_snapshot(simulator)
        capacity_wrap_assert_completion(actual, 0)
        counts.held = Some(actual)
      }
  }
}

///|
fn capacity_wrap_idle(context : FaultContext) -> Bool {
  context.host.pending is None && context.host.held is None
}

///|
fn capacity_wrap_tick(
  context : FaultContext,
  counts : CapacityWrapCounts,
  config_valid~ : UInt64 = 0UL,
  publish_valid~ : UInt64 = 0UL,
  publish_producer~ : UInt64 = 0UL,
  completion_ready~ : UInt64 = 0UL,
) -> FaultEvents raise {
  capacity_wrap_assert_clean(context)
  if completion_ready == 0UL {
    capacity_wrap_assert_held(context, counts)
  }
  let simulator = context.trace.simulator
  let producer_before = output_value(simulator, "producer_count")
  let consumer_before = output_value(simulator, "consumer_count")
  let bus = context.host.drive(context.cycle + 1)
  let events = context.tick(
    bus,
    config_valid~,
    publish_valid~,
    publish_producer~,
    completion_ready~,
  )
  if events.configuration_accepted {
    counts.configurations += 1
    if counts.configurations != 1 {
      fail("capacity/wrap configuration was accepted more than once")
    }
  }
  if events.publication_accepted {
    let expected : Array[UInt64] = [0UL, 2UL, 4UL, 6UL]
    if counts.publications >= expected.length() ||
      publish_producer != expected[counts.publications] {
      fail("capacity/wrap accepted an unexpected publication")
    }
    // Capacity uses the committed PRE consumer, never this edge's admission.
    let occupancy = (producer_before - consumer_before) & 0xffffffffUL
    let advance = (publish_producer - producer_before) & 0xffffffffUL
    if occupancy > 2UL || advance > 2UL - occupancy {
      fail("capacity/wrap publication consumed uncommitted ring credit")
    }
    counts.publications += 1
  }
  if events.memory.accepted is Some(request) {
    if counts.requests >= 256 ||
      request.tag != counts.requests.to_uint64() ||
      request.write != 0UL ||
      request.bytes != 1UL ||
      request.mask != 1UL ||
      request.data != 0UL ||
      request.address != (3072 + counts.requests % 64).to_uint64() {
      fail("capacity/wrap accepted an unexpected descriptor-byte request")
    }
    counts.requests += 1
  }
  if events.memory.acknowledged is Some(request) {
    if request.tag != counts.acknowledgements.to_uint64() ||
      bus.response_valid != 1UL ||
      bus.response_fault != 0UL ||
      bus.response_tag != request.tag {
      fail("capacity/wrap descriptor ACK lost its saved successful ownership")
    }
    counts.acknowledgements += 1
  }
  if events.completion is Some(actual) {
    capacity_wrap_assert_completion(actual, counts.retired)
    counts.retired += 1
  }
  capacity_wrap_assert_clean(context)
  if completion_ready == 0UL {
    capacity_wrap_assert_held(context, counts)
  }
  events
}

///|
fn capacity_wrap_assert_blocked(
  context : FaultContext,
  counts : CapacityWrapCounts,
  slot : ArrayView[Int32],
) -> Unit raise {
  let simulator = context.trace.simulator
  for
    (name, expected) in [
      ("configured", 1UL),
      ("producer_count", 4UL),
      ("consumer_count", 3UL),
      ("queue_occupancy", 2UL),
      ("publish_ready", 0UL),
      ("memory_request_valid", 0UL),
    ] {
    if output_value(simulator, name) != expected {
      fail("capacity/wrap blocked checkpoint changed \{name}")
    }
  }
  if counts.configurations != 1 ||
    counts.publications != 3 ||
    counts.requests != 192 ||
    counts.acknowledgements != 192 ||
    counts.retired != 0 ||
    !capacity_wrap_idle(context) {
    fail(
      "capacity/wrap blocked checkpoint lost exact owners or host quiescence",
    )
  }
  capacity_wrap_assert_clean(context)
  capacity_wrap_assert_held(context, counts)
  if counts.held is None || slot.length() != 32 {
    fail("capacity/wrap blocked checkpoint has no saved terminal or slot")
  }
  for index in 0..<32 {
    if context.host.memory[3104 + index] != slot[index] {
      fail("capacity/wrap held reader slot changed before admission")
    }
  }
}

///|
fn capacity_wrap_assert_drained(
  context : FaultContext,
  counts : CapacityWrapCounts,
  retired : Int32,
  producer : UInt64,
) -> Unit raise {
  let simulator = context.trace.simulator
  if counts.retired != retired ||
    output_value(simulator, "producer_count") != producer ||
    output_value(simulator, "consumer_count") != producer ||
    output_value(simulator, "queue_occupancy") != 0UL ||
    output_value(simulator, "completion_valid") != 0UL ||
    !capacity_wrap_idle(context) {
    fail(
      "capacity/wrap pair refill preceded ordered retirement and committed credit",
    )
  }
  capacity_wrap_assert_clean(context)
}
