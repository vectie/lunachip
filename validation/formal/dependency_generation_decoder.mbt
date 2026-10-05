///|
// Private aliases into the production cone, not new inputs or a second decoder.
priv struct DependencyGenerationDecoderBinding {
  name : String
  node : @ir.NodeId
  signal_type : @ir.SignalType
} derive(Debug, Eq)

///|
fn dependency_generation_decoder_mux(
  hardware : @ir.Module,
  id : @ir.NodeId,
) -> (@ir.NodeId, @ir.NodeId, @ir.NodeId) raise FormalGateError {
  guard dependency_generation_node(hardware, id).kind()
    is Mux(select~, when_true~, when_false~) else {
    raise InvalidFormalBundleIdentity("generation decoder: expected mux")
  }
  (select, when_true, when_false)
}

///|
fn dependency_generation_decoder_constant(
  hardware : @ir.Module,
  id : @ir.NodeId,
  signal_type : @ir.SignalType,
  value : UInt64,
) -> Unit raise FormalGateError {
  let node = dependency_generation_node(hardware, id)
  if node.signal_type() != signal_type || node.kind() != Constant(value) {
    raise InvalidFormalBundleIdentity("generation decoder: constant drift")
  }
}

///|
fn dependency_generation_decoder_equal_constant(
  hardware : @ir.Module,
  id : @ir.NodeId,
  width : Int,
  value : UInt64,
) -> @ir.NodeId raise {
  let node = dependency_generation_node(hardware, id)
  guard node.signal_type() == @wire.bits(1) && node.kind() is Equal(left, right) else {
    raise InvalidFormalBundleIdentity("generation decoder: equality drift")
  }
  dependency_generation_decoder_constant(
    hardware,
    right,
    @wire.uint(width),
    value,
  )
  if dependency_generation_node(hardware, left).signal_type() !=
    @wire.uint(width) {
    raise InvalidFormalBundleIdentity(
      "generation decoder: equality operand type",
    )
  }
  left
}

///|
fn dependency_generation_decoder_and(
  hardware : @ir.Module,
  id : @ir.NodeId,
) -> (@ir.NodeId, @ir.NodeId) raise {
  let node = dependency_generation_node(hardware, id)
  guard node.signal_type() == @wire.bits(1) &&
    node.kind() is BitAnd(left, right) else {
    raise InvalidFormalBundleIdentity("generation decoder: conjunction drift")
  }
  (left, right)
}

///|
// Follow the exact five selector muxes and verify all six state leaves. Both
// status and ticket snapshots must select with this same original index node.
fn dependency_generation_decoder_source(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
  snapshot_role : @flux_tile.QueuedConcurrentFormalRole,
  ticket : Bool,
  reserve : @ir.NodeId,
) -> @ir.NodeId raise {
  let snapshot = dependency_generation_binding(bindings, snapshot_role).node
  guard dependency_generation_node(hardware, snapshot).kind() is Register(spec) else {
    raise InvalidFormalBundleIdentity("generation decoder: snapshot register")
  }
  let (update, selected, hold) = dependency_generation_decoder_mux(
    hardware,
    spec.next(),
  )
  if update != reserve || hold != snapshot {
    raise InvalidFormalBundleIdentity("generation decoder: snapshot hold drift")
  }
  let mut cursor = selected
  let mut source : @ir.NodeId? = None
  for offset in 0..<5 {
    let ordinal = 5 - offset
    let (condition, leaf, rest) = dependency_generation_decoder_mux(
      hardware, cursor,
    )
    let index = dependency_generation_decoder_equal_constant(
      hardware,
      condition,
      3,
      ordinal.to_uint64(),
    )
    let role : @flux_tile.QueuedConcurrentFormalRole = if ticket {
      WriterTicket(ordinal)
    } else {
      WriterStatus(ordinal)
    }
    if leaf != dependency_generation_binding(bindings, role).node ||
      (source is Some(previous) && previous != index) {
      raise InvalidFormalBundleIdentity(
        "generation decoder: snapshot selector drift",
      )
    }
    source = Some(index)
    cursor = rest
  }
  let default_role : @flux_tile.QueuedConcurrentFormalRole = if ticket {
    WriterTicket(0)
  } else {
    WriterStatus(0)
  }
  if cursor != dependency_generation_binding(bindings, default_role).node {
    raise InvalidFormalBundleIdentity(
      "generation decoder: snapshot default drift",
    )
  }
  guard source is Some(index) else {
    raise InvalidFormalBundleIdentity("generation decoder: missing source")
  }
  index
}

///|
fn dependency_generation_decoder_bindings(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
  local_fault : @ir.NodeId,
  raw_poison : @ir.NodeId,
) -> Array[DependencyGenerationDecoderBinding] raise {
  let (poison, poison_fault, dispatch_fault) = dependency_generation_decoder_mux(
    hardware, local_fault,
  )
  dependency_generation_decoder_constant(
    hardware,
    poison_fault,
    @wire.uint(4),
    15UL,
  )
  if poison != raw_poison {
    raise InvalidFormalBundleIdentity("generation decoder: poison alias drift")
  }
  let (syntax_ok, semantic_fault, syntax_fault) = dependency_generation_decoder_mux(
    hardware, dispatch_fault,
  )
  if dependency_generation_decoder_equal_constant(hardware, syntax_ok, 4, 0UL) !=
    syntax_fault {
    raise InvalidFormalBundleIdentity(
      "generation decoder: syntax priority drift",
    )
  }
  let (unused_ok, shape_fault, unused_fault) = dependency_generation_decoder_mux(
    hardware, semantic_fault,
  )
  dependency_generation_decoder_constant(
    hardware,
    unused_fault,
    @wire.uint(4),
    2UL,
  )
  let (dimensions_ok, dependency_fault, dimensions_fault) = dependency_generation_decoder_mux(
    hardware, shape_fault,
  )
  dependency_generation_decoder_constant(
    hardware,
    dimensions_fault,
    @wire.uint(4),
    3UL,
  )
  let (_, unavailable_fault, success) = dependency_generation_decoder_mux(
    hardware, dependency_fault,
  )
  dependency_generation_decoder_constant(hardware, success, @wire.uint(4), 0UL)
  let (_, mat_fault, store_fault) = dependency_generation_decoder_mux(
    hardware, unavailable_fault,
  )
  dependency_generation_decoder_constant(
    hardware,
    mat_fault,
    @wire.uint(4),
    4UL,
  )
  dependency_generation_decoder_constant(
    hardware,
    store_fault,
    @wire.uint(4),
    5UL,
  )
  let reserve = dependency_generation_binding(bindings, HeadReserve).node
  let sources : Array[@ir.NodeId] = []
  for ordinal in 0..<2 {
    let status_index = dependency_generation_decoder_source(
      hardware,
      bindings,
      DependencyStatus(ordinal),
      false,
      reserve,
    )
    let ticket_index = dependency_generation_decoder_source(
      hardware,
      bindings,
      DependencyTicket(ordinal),
      true,
      reserve,
    )
    if status_index != ticket_index {
      raise InvalidFormalBundleIdentity(
        "generation decoder: status/ticket source mismatch",
      )
    }
    sources.push(status_index)
  }
  let mut saved_publish : @ir.NodeId? = None
  let mut saved_writer : @ir.NodeId? = None
  let mut saved_slot : @ir.NodeId? = None
  for ordinal in 0..<6 {
    let status = dependency_generation_binding(bindings, WriterStatus(ordinal)).node
    guard dependency_generation_node(hardware, status).kind() is Register(spec) else {
      raise InvalidFormalBundleIdentity("generation decoder: writer register")
    }
    let (intent, pending, _) = dependency_generation_decoder_mux(
      hardware,
      spec.next(),
    )
    dependency_generation_decoder_constant(
      hardware,
      pending,
      @wire.uint(2),
      1UL,
    )
    let (publish, slot_match) = dependency_generation_decoder_and(
      hardware, intent,
    )
    let slot = dependency_generation_decoder_equal_constant(
      hardware,
      slot_match,
      3,
      ordinal.to_uint64(),
    )
    let ticket = dependency_generation_binding(bindings, WriterTicket(ordinal)).node
    guard dependency_generation_node(hardware, ticket).kind()
      is Register(ticket_spec) else {
      raise InvalidFormalBundleIdentity(
        "generation decoder: writer ticket register",
      )
    }
    let (ticket_intent, next_ticket, ticket_hold) = dependency_generation_decoder_mux(
      hardware,
      ticket_spec.next(),
    )
    if ticket_intent != intent ||
      ticket_hold != ticket ||
      next_ticket != dependency_generation_binding(bindings, NextTicket).node {
      raise InvalidFormalBundleIdentity(
        "generation decoder: writer ticket intent drift",
      )
    }
    let (syntax_publish, not_poison) = dependency_generation_decoder_and(
      hardware, publish,
    )
    let (writer_publish, publish_syntax_ok) = dependency_generation_decoder_and(
      hardware, syntax_publish,
    )
    let (publish_reserve, writer) = dependency_generation_decoder_and(
      hardware, writer_publish,
    )
    if publish_reserve != reserve ||
      dependency_generation_decoder_equal_constant(
        hardware, publish_syntax_ok, 4, 0UL,
      ) !=
      syntax_fault ||
      dependency_generation_node(hardware, not_poison).kind() !=
      BitNot(raw_poison) ||
      (saved_publish is Some(previous) && previous != publish) ||
      (saved_writer is Some(previous) && previous != writer) ||
      (saved_slot is Some(previous) && previous != slot) {
      raise InvalidFormalBundleIdentity(
        "generation decoder: publication source drift",
      )
    }
    saved_publish = Some(publish)
    saved_writer = Some(writer)
    saved_slot = Some(slot)
  }
  guard saved_writer is Some(writer) && saved_slot is Some(slot) else {
    raise InvalidFormalBundleIdentity(
      "generation decoder: missing writer identity",
    )
  }
  let projections = [
    ("decoder_syntax_fault", syntax_fault, @wire.uint(4)),
    ("decoder_source_0", sources[0], @wire.uint(3)),
    ("decoder_source_1", sources[1], @wire.uint(3)),
    ("decoder_is_writer", writer, @wire.bits(1)),
    ("decoder_writer_slot", slot, @wire.uint(3)),
    ("decoder_unused_ok", unused_ok, @wire.bits(1)),
    ("decoder_dimensions_ok", dimensions_ok, @wire.bits(1)),
  ]
  let result : Array[DependencyGenerationDecoderBinding] = []
  for (name, node, signal_type) in projections {
    if dependency_generation_node(hardware, node).signal_type() != signal_type {
      raise InvalidFormalBundleIdentity(
        "generation decoder: projection type drift",
      )
    }
    result.push({ name, node, signal_type, })
  }
  result
}
