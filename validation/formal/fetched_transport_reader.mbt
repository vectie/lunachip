///|
fn fetched_transport_reader_state(
  source : @ir.Module,
  gate : @ir.NodeId,
  active : @ir.NodeId,
  value : UInt64,
) -> @ir.NodeId raise {
  let (mask, comparison) = dependency_generation_decoder_and(source, gate)
  if mask != active {
    raise InvalidFormalBundleIdentity("fetched discovery: reader active mask")
  }
  dependency_generation_decoder_equal_constant(source, comparison, 3, value)
}

///|
fn fetched_transport_reader(
  source : @ir.Module,
  clock : @ir.NodeId,
  reset : @ir.NodeId,
  arbiter : FetchedTransportArbiter,
  roots : Array[DependencyComputeRoot],
  boundaries : Array[TwoClientArbiterCandidate],
  events : Array[QueueControlAlias],
) -> Unit raise {
  let ready = two_client_arbiter_output(source, "config_ready", @wire.bits(1))
  let (active, _) = dependency_generation_decoder_and(source, ready)
  guard dependency_generation_node(source, active).kind()
    is BitAnd(inactive, not_poison) &&
    inactive == arbiter.inactive &&
    dependency_generation_node(source, not_poison).kind() ==
    BitNot(two_client_arbiter_output(source, "transport_halted", @wire.bits(1))) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: original reader poison gating",
    )
  }
  let state = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_state",
    fetched_transport_reader_state(source, ready, active, 0UL),
    @wire.uint(3),
  )
  if fetched_transport_reader_state(source, arbiter.reader_valid, active, 3UL) !=
    state.node ||
    fetched_transport_reader_state(source, arbiter.reader_ready, active, 4UL) !=
    state.node ||
    fetched_transport_reader_state(
      source,
      two_client_arbiter_output(source, "ring_fault_valid", @wire.bits(1)),
      arbiter.inactive,
      6UL,
    ) !=
    state.node {
    raise InvalidFormalBundleIdentity("fetched discovery: real reader states")
  }
  let config_valid = dependency_generation_input(
    source,
    "config_valid",
    @wire.bits(1),
  )
  let config_base = dependency_generation_input(
    source,
    "config_base",
    @wire.uint(32),
  )
  let config_origin = dependency_generation_input(
    source,
    "config_origin",
    @wire.uint(32),
  )
  let publish_valid = dependency_generation_input(
    source,
    "publish_valid",
    @wire.bits(1),
  )
  let publish_producer = dependency_generation_input(
    source,
    "publish_producer",
    @wire.uint(32),
  )
  let base_node = fetched_transport_unique(source, "captured reader base", node => {
    guard node.signal_type() == @wire.uint(32) &&
      node.kind() is Register(spec) &&
      dependency_generation_node(source, spec.next()).kind()
      is Mux(select~, when_true~, when_false~) &&
      when_true == config_base &&
      when_false == node.id() &&
      dependency_generation_node(source, select).kind() ==
      BitAnd(ready, config_valid) else {
      return false
    }
    true
  })
  let base = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_base",
    base_node,
    @wire.uint(32),
  )
  let (config_accept, _, _) = dependency_generation_decoder_mux(
    source,
    base.spec.next(),
  )
  let origin = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_origin",
    fetched_transport_find_latch(
      source, config_accept, config_origin, 32, "captured reader origin",
    ),
    @wire.uint(32),
  )
  let producer = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_producer",
    two_client_arbiter_output(source, "producer_count", @wire.uint(32)),
    @wire.uint(32),
  )
  let consumer = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_consumer",
    two_client_arbiter_output(source, "consumer_count", @wire.uint(32)),
    @wire.uint(32),
  )
  let (configured_node, reset_mask) = dependency_generation_decoder_and(
    source,
    two_client_arbiter_output(source, "configured", @wire.bits(1)),
  )
  if reset_mask != arbiter.inactive {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: configured public mask",
    )
  }
  let configured = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_configured",
    configured_node,
    @wire.bits(1),
  )
  guard dependency_generation_node(source, configured.spec.next()).kind()
    is BitOr(held, config_ok) &&
    held == configured.node else {
    raise InvalidFormalBundleIdentity("fetched discovery: sticky configured")
  }
  let (producer_config, producer_origin, publication) = dependency_generation_decoder_mux(
    source,
    producer.spec.next(),
  )
  let (publication_good, producer_value, producer_hold) = dependency_generation_decoder_mux(
    source, publication,
  )
  if producer_config != config_ok ||
    producer_origin != origin.node ||
    producer_value != publish_producer ||
    producer_hold != producer.node {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: original producer publication",
    )
  }
  let publish_ready = two_client_arbiter_output(
    source,
    "publish_ready",
    @wire.bits(1),
  )
  guard dependency_generation_node(source, publish_ready).kind()
    is BitOr(reader_idle, packet_accept) &&
    fetched_transport_reader_state(source, reader_idle, active, 2UL) ==
    state.node &&
    dependency_generation_node(source, packet_accept).kind()
    is BitAnd(packet_valid, queue_ready) &&
    fetched_transport_reader_state(source, packet_valid, active, 5UL) ==
    state.node &&
    dependency_generation_node(source, publication_good).kind()
    is BitAnd(publish_accept, publication_ok) &&
    dependency_generation_node(source, publish_accept).kind() ==
    BitAnd(publish_ready, publish_valid) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: packet/publication original boundaries",
    )
  }
  let (consumer_config, consumer_origin, consumer_update) = dependency_generation_decoder_mux(
    source,
    consumer.spec.next(),
  )
  let (packet_ack, consumer_plus_one, consumer_hold) = dependency_generation_decoder_mux(
    source, consumer_update,
  )
  guard consumer_config == config_ok &&
    consumer_origin == origin.node &&
    packet_ack == packet_accept &&
    consumer_hold == consumer.node &&
    dependency_generation_node(source, consumer_plus_one).kind()
    is Add(counter, one) &&
    counter == consumer.node &&
    fetched_transport_constant(source, one, 32, 1UL) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: consumer advances only packet ACK",
    )
  }
  let tag = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_tag",
    arbiter.reader_fields[5],
    @wire.uint(32),
  )
  let (request_accept, increment, tag_hold) = dependency_generation_decoder_mux(
    source,
    tag.spec.next(),
  )
  guard tag_hold == tag.node &&
    dependency_generation_node(source, increment).kind()
    is Add(raw_tag, tag_one) &&
    raw_tag == tag.node &&
    fetched_transport_constant(source, tag_one, 32, 1UL) &&
    dependency_generation_node(source, request_accept).kind()
    is BitAnd(request_valid, request_ready) &&
    request_valid == arbiter.reader_valid else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: reader local tag handshake",
    )
  }
  let expected = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_expected_tag",
    fetched_transport_find_latch(
      source,
      request_accept,
      tag.node,
      32,
      "reader expected tag",
    ),
    @wire.uint(32),
  )
  guard dependency_generation_node(source, arbiter.reader_fields[1]).kind()
    is Truncate(wide_address) &&
    dependency_generation_node(source, wide_address).kind()
    is Add(slot_address, extended_cursor) &&
    dependency_generation_node(source, extended_cursor).kind()
    is ZeroExtend(cursor_node) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: wide original reader address",
    )
  }
  let cursor = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_cursor",
    cursor_node,
    @wire.uint(5),
  )
  let (start, cursor_zero, cursor_update) = dependency_generation_decoder_mux(
    source,
    cursor.spec.next(),
  )
  let (response_good, cursor_plus_one, cursor_hold) = dependency_generation_decoder_mux(
    source, cursor_update,
  )
  guard fetched_transport_constant(source, cursor_zero, 5, 0UL) &&
    cursor_hold == cursor.node &&
    dependency_generation_node(source, cursor_plus_one).kind()
    is Add(raw_cursor, cursor_one) &&
    raw_cursor == cursor.node &&
    fetched_transport_constant(source, cursor_one, 5, 1UL) else {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: reader cursor commits only good response",
    )
  }
  let response_accept = fetched_transport_unique(
    source,
    "reader response acceptance",
    node => {
      node.kind() == BitAnd(arbiter.reader_ready, arbiter.reader_response_valid)
    },
  )
  let lane_nodes = source
    .nodes()
    .filter(node => {
      guard node.signal_type() == @wire.bits(64) &&
        node.kind() is Register(spec) &&
        dependency_generation_node(source, spec.next()).kind()
        is Mux(select=start_guard, when_true=zero, when_false=update) &&
        start_guard == start &&
        fetched_transport_constant(source, zero, 64, 0UL) &&
        dependency_generation_node(source, update).kind()
        is Mux(select=enable, when_true=changed, when_false=hold) &&
        hold == node.id() &&
        dependency_generation_node(source, changed).kind() is BitOr(raw_lane, _) &&
        raw_lane == node.id() &&
        dependency_generation_node(source, enable).kind() is BitAnd(good, _) &&
        good == response_good else {
        return false
      }
      true
    })
  if lane_nodes.length() != 4 {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: four real reader assembly registers",
    )
  }
  for lane in 0..<4 {
    let matches = lane_nodes.filter(node => {
      guard node.kind() is Register(spec) &&
        dependency_generation_node(source, spec.next()).kind()
        is Mux(when_false=update, ..) &&
        dependency_generation_node(source, update).kind()
        is Mux(select=enable, ..) &&
        dependency_generation_node(source, enable).kind()
        is BitAnd(_, comparison) &&
        dependency_generation_node(source, comparison).kind()
        is Equal(index, constant) &&
        fetched_transport_constant(source, constant, 2, lane.to_uint64()) &&
        dependency_generation_node(source, index).kind() is Reinterpret(slice) &&
        dependency_generation_node(source, slice).kind()
        is Slice(value~, msb=4, lsb=3) &&
        value == cursor.node else {
        return false
      }
      true
    })
    guard matches is [node] else {
      raise InvalidFormalBundleIdentity(
        "fetched discovery: lane byte slice identity",
      )
    }
    ignore(
      fetched_transport_root(
        source,
        roots,
        clock,
        reset,
        "reader_lane_\{lane}",
        node.id(),
        @wire.bits(64),
      ),
    )
  }
  let fault = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_fault",
    two_client_arbiter_output(source, "ring_fault_code", @wire.uint(3)),
    @wire.uint(3),
  )
  let fault_address = fetched_transport_root(
    source,
    roots,
    clock,
    reset,
    "reader_fault_address",
    two_client_arbiter_output(source, "ring_fault_address", @wire.uint(32)),
    @wire.uint(32),
  )
  let (terminal, _, fault_hold) = dependency_generation_decoder_mux(
    source,
    fault.spec.next(),
  )
  let (address_terminal, _, address_hold) = dependency_generation_decoder_mux(
    source,
    fault_address.spec.next(),
  )
  if fault_hold != fault.node ||
    address_hold != fault_address.node ||
    address_terminal != terminal {
    raise InvalidFormalBundleIdentity(
      "fetched discovery: sticky fault identity",
    )
  }
  // Interface cuts are confined to external host pins and downstream ready.
  for
    (name, id) in [
      ("config_valid", config_valid),
      ("config_base", config_base),
      ("config_origin", config_origin),
      ("publish_valid", publish_valid),
      ("publish_producer", publish_producer),
      ("queue_packet_ready", queue_ready),
    ] {
    two_client_arbiter_boundary(
      source,
      boundaries,
      id,
      dependency_generation_node(source, id).signal_type(),
      name,
    )
  }
  for
    (name, id) in [
      ("reader_config_accept", config_accept),
      ("reader_config_ok", config_ok),
      ("reader_publish_accept", publish_accept),
      ("reader_publication_ok", publication_ok),
      ("reader_packet_valid", packet_valid),
      ("reader_packet_accept", packet_accept),
      ("reader_start", start),
      ("reader_request_accept", request_accept),
      ("reader_response_accept", response_accept),
      ("reader_response_good", response_good),
      ("reader_terminal", terminal),
      ("reader_wide_address", wide_address),
      ("reader_slot_address", slot_address),
      ("reader_request_ready_actual", request_ready),
      ("reader_expected_tag_observation", expected.node),
    ] {
    fetched_transport_event(source, events, name, id)
  }
  // Original fixed reader packet-read fields remain constants in the cone.
  for
    (field, width, value) in [
      (0, 1, 0UL),
      (2, 3, 1UL),
      (3, 4, 1UL),
      (4, 32, 0UL),
    ] {
    if !fetched_transport_constant(
        source,
        arbiter.reader_fields[field],
        width,
        value,
      ) {
      raise InvalidFormalBundleIdentity(
        "fetched discovery: original one-byte read field",
      )
    }
  }
}
