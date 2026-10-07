///|
// Full LogicValue PRE/POST comparison; cuts only sample the ordinary graph.
fn fetched_transport_native_compare(
  slice : FetchedTransportSequential,
  source : @sim.Simulator,
  projection : @sim.Simulator,
) -> Unit raise {
  for cut in slice.probe.candidates {
    projection.set_input(
      "cut_n\{cut.original.id().ordinal()}",
      source.value(cut.original.id()),
    )
  }
  projection.settle()
  for root in slice.probe.roots {
    assert_eq(
      source.value(root.node),
      projection.value(
        dependency_generation_mapped(slice.original_to_local, root.node),
      ),
    )
  }
  for event in slice.probe.events {
    assert_eq(
      source.value(event.node),
      projection.value(
        dependency_generation_mapped(slice.original_to_local, event.node),
      ),
    )
  }
}

///|
fn fetched_transport_native_tick(
  slice : FetchedTransportSequential,
  source : @sim.Simulator,
  projection : @sim.Simulator,
) -> Unit raise {
  source.settle()
  fetched_transport_native_compare(slice, source, projection)
  source.rising_edge("clock")
  // Keep the PRE cuts unchanged for this edge; only then resample POST.
  projection.rising_edge("clock")
  source.settle()
  fetched_transport_native_compare(slice, source, projection)
}

///|
test "fresh fetched correspondence reads duplicate-ID packets across origin wrap and later reset" {
  let slice = fetched_transport_sequential()
  let source = @sim.Simulator::prepare(slice.probe.source)
  let projection = @sim.Simulator::prepare(slice.hardware)
  for node in slice.probe.source.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  assert_true(
    slice.probe.roots.any(root => !source.value(root.node).is_fully_known()),
  )
  records_put(source, "reset", 1, 1UL)
  fetched_transport_native_tick(slice, source, projection)
  records_put(source, "reset", 1, 0UL)
  records_put(source, "config_valid", 1, 1UL)
  records_put(source, "config_base", 32, 0UL)
  records_put(source, "config_origin", 32, 0xfffffffeUL)
  fetched_transport_native_tick(slice, source, projection)
  records_put(source, "config_valid", 1, 0UL)
  fetched_transport_native_tick(slice, source, projection)
  assert_eq(records_output(source, "configured"), 1UL)
  records_put(source, "publish_valid", 1, 1UL)
  records_put(source, "publish_producer", 32, 1UL) // three slots, UInt32 wrap
  records_put(source, "completion_ready", 1, 1UL)
  let fence = records_packet(4UL, 0UL, 0UL, 0UL, 0UL, 0UL)
  let mut pending : (UInt64, UInt64)? = None
  let mut requests = 0
  let mut responses = 0
  let mut packets = 0
  let mut completions = 0
  let mut held_offers = 0
  let mut published = false
  for edge in 0..<1024 {
    records_put(
      source,
      "memory_request_ready",
      1,
      if edge % 5 < 2 {
        0UL
      } else {
        1UL
      },
    )
    records_put(
      source,
      "memory_response_valid",
      1,
      if pending is Some(_) {
        1UL
      } else {
        0UL
      },
    )
    if pending is Some((tag, data)) {
      records_put(source, "memory_response_tag", 32, tag)
      records_put(source, "memory_response_fault", 2, 0UL)
      records_put(source, "memory_response_data", 32, data)
    }
    source.settle()
    let publish = !published && records_output(source, "publish_ready") == 1UL
    let request = records_output(source, "memory_request_valid") == 1UL &&
      edge % 5 >= 2
    let response = pending is Some(_) &&
      records_output(source, "memory_response_ready") == 1UL
    let packet = slice.probe.events.filter(event => {
      event.name == "reader_packet_accept"
    })
    guard packet is [packet_event] else {
      fail("missing actual reader packet ACK")
    }
    let packet_ack = source.value(packet_event.node).to_uint64() == 1UL
    if records_output(source, "memory_request_valid") == 1UL && !request {
      held_offers += 1
    }
    let mut accepted : (UInt64, UInt64)? = None
    if request {
      assert_eq(pending, None)
      let address = records_output(source, "memory_request_address")
      assert_true(address < 128UL)
      assert_eq(records_output(source, "memory_request_write"), 0UL)
      assert_eq(records_output(source, "memory_request_bytes"), 1UL)
      assert_eq(records_output(source, "memory_request_mask"), 1UL)
      let offset = (address % 32UL).to_int()
      let byte = (fence[offset / 8] >> (offset % 8 * 8)) & 255UL
      accepted = Some((records_output(source, "memory_request_tag"), byte))
    }
    if records_output(source, "completion_valid") == 1UL {
      assert_eq(records_output(source, "completion_id"), 73UL)
      assert_eq(records_output(source, "completion_fault"), 0UL)
      completions += 1
    }
    fetched_transport_native_tick(slice, source, projection)
    if publish {
      published = true
      records_put(source, "publish_valid", 1, 0UL)
    }
    if response {
      responses += 1
      pending = None
    }
    if accepted is Some(value) {
      requests += 1
      pending = Some(value)
    }
    if packet_ack {
      packets += 1
    }
    if packets == 3 && completions == 3 {
      break
    }
  }
  assert_eq(requests, 96)
  assert_eq(responses, 96)
  assert_eq(packets, 3)
  assert_eq(completions, 3)
  assert_eq(records_output(source, "consumer_count"), 1UL)
  assert_true(held_offers > 0)
  // Interrupt another genuine held descriptor-read Offer, not injected state.
  records_put(source, "publish_valid", 1, 1UL)
  records_put(source, "publish_producer", 32, 2UL)
  records_put(source, "memory_response_valid", 1, 0UL)
  records_put(source, "memory_request_ready", 1, 0UL)
  let mut held = false
  for _ in 0..<16 {
    source.settle()
    let publication = records_output(source, "publish_ready") == 1UL
    if records_output(source, "memory_request_valid") == 1UL {
      held = true
      break
    }
    fetched_transport_native_tick(slice, source, projection)
    if publication {
      records_put(source, "publish_valid", 1, 0UL)
    }
  }
  assert_true(held)
  records_put(source, "reset", 1, 1UL)
  fetched_transport_native_tick(slice, source, projection)
  for root in slice.probe.roots {
    assert_eq(source.value(root.node).to_uint64(), 0UL)
  }
  records_put(source, "reset", 1, 0UL)
  fetched_transport_native_tick(slice, source, projection)
  assert_eq(records_output(source, "configured"), 0UL)
}
