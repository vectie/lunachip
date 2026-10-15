///|
// Start at the actual three-client arbiter inputs, not a second transfer
// implementation. Decode the original UInt64 sum BEFORE UInt32 encoding.
fn fetched_dma_roots(
  sequential : FetchedTransportSequential,
) -> Array[QueueControlAlias] raise {
  let source = sequential.probe.source
  let fixture = @flux_tile.ring_concurrent_queue_formal_fixture()
  guard fixture.hardware() == source else {
    raise InvalidFormalBundleIdentity("fetched DMA: exact q2 graph")
  }
  let arbiter = fetched_transport_arbiter(
    source,
    sequential.probe.clock,
    sequential.probe.reset,
  )
  let aliases : Array[QueueControlAlias] = []
  for (client, engine, bytes) in [("loader", 0, 1), ("storer", 2, 4)] {
    guard arbiter.boundaries.filter(item => {
        item.roles.contains(client + "_address")
      })
      is [address] &&
      address.original.kind() is Truncate(full_address) &&
      dependency_generation_node(source, full_address).kind()
      is Add(base_row, column_offset) &&
      dependency_generation_node(source, base_row).kind()
      is Add(extended_base, row_offset) &&
      dependency_generation_node(source, extended_base).kind()
      is ZeroExtend(base) &&
      dependency_generation_node(source, row_offset).kind()
      is MulLow(extended_row, extended_stride) &&
      dependency_generation_node(source, extended_row).kind() is ZeroExtend(row) &&
      dependency_generation_node(source, extended_stride).kind()
      is ZeroExtend(stride) &&
      dependency_generation_node(source, column_offset).kind()
      is MulLow(extended_column, element_bytes) &&
      dependency_generation_node(source, extended_column).kind()
      is ZeroExtend(column) &&
      fetched_transport_constant(source, element_bytes, 64, bytes.to_uint64()) else {
      raise InvalidFormalBundleIdentity(
        "fetched DMA: original wide address equation",
      )
    }
    for
      id in [
        full_address, base_row, row_offset, column_offset, extended_base, extended_row,
        extended_stride, extended_column,
      ] {
      guard dependency_generation_node(source, id).signal_type() ==
        @wire.uint(64) else {
        raise InvalidFormalBundleIdentity("fetched DMA: full UInt64 arithmetic")
      }
    }
    let (accept, _) = fetched_safety_latch(source, base)
    let (stride_accept, _) = fetched_safety_latch(source, stride)
    guard accept == stride_accept &&
      dependency_generation_node(source, row).kind() is Register(row_spec) &&
      dependency_generation_node(source, row_spec.next()).kind()
      is Mux(select=row_accept, when_true=row_zero, when_false=row_update) &&
      row_accept == accept &&
      fetched_transport_constant(source, row_zero, 13, 0UL) &&
      dependency_generation_node(source, row_update).kind()
      is Mux(
        select=advance_last,
        when_true=incremented_row,
        when_false=held_row
      ) &&
      held_row == row &&
      dependency_generation_node(source, advance_last).kind()
      is BitAnd(_, last_column) &&
      dependency_generation_node(source, incremented_row).kind()
      is Add(same_row, row_one) &&
      same_row == row &&
      fetched_transport_constant(source, row_one, 13, 1UL) &&
      dependency_generation_node(source, last_column).kind()
      is Equal(incremented_column, columns) &&
      dependency_generation_node(source, incremented_column).kind()
      is Add(same_column, column_one) &&
      same_column == column &&
      fetched_transport_constant(source, column_one, 13, 1UL) &&
      dependency_generation_node(source, column).kind() is Register(column_spec) &&
      dependency_generation_node(source, column_spec.next()).kind()
      is Mux(select=column_accept, when_true=column_zero, ..) &&
      column_accept == accept &&
      fetched_transport_constant(source, column_zero, 13, 0UL) else {
      raise InvalidFormalBundleIdentity(
        "fetched DMA: original full cursor/reset recurrence",
      )
    }
    let (columns_accept, _) = fetched_safety_latch(source, columns)
    guard columns_accept == accept else {
      raise InvalidFormalBundleIdentity("fetched DMA: actual accepted columns")
    }
    let rows = fetched_transport_unique(source, client + " full rows latch", node => {
      guard node.signal_type() == @wire.uint(13) &&
        node.id() != columns &&
        node.kind() is Register(_) else {
        return false
      }
      let (event, _) = fetched_safety_latch(source, node.id()) catch {
        _ => return false
      }
      event == accept
    })
    let state = queue_control_binding(fixture, EngineState(engine)).node
    for
      (field, id, width) in [
        ("base", base, 32),
        ("stride", stride, 32),
        ("row", row, 13),
        ("column", column, 13),
        ("rows", rows, 13),
        ("columns", columns, 13),
        ("address_full", full_address, 64),
        ("state", state, 3),
      ] {
      guard dependency_generation_node(source, id).signal_type() ==
        @wire.uint(width) else {
        raise InvalidFormalBundleIdentity("fetched DMA: exact field width")
      }
      aliases.push({
        name: "composition_dma_" + client + "_" + field,
        node: id,
        signal_type: @wire.uint(width),
      })
    }
  }
  guard arbiter.boundaries.filter(item => item.roles.contains("storer_data"))
    is [data] &&
    data.original.kind() is Reinterpret(word) &&
    dependency_generation_node(source, word).signal_type() == @wire.sint(32) else {
    raise InvalidFormalBundleIdentity("fetched DMA: actual C response word")
  }
  aliases.push({
    name: "composition_dma_store_word",
    node: word,
    signal_type: @wire.sint(32),
  })
  aliases
}

///|
fn fetched_dma_view(
  sequential : FetchedTransportSequential,
) -> @ir.Module raise {
  let original = fetched_retirement_view(sequential)
  let outputs = original.outputs().iter().to_array()
  for binding in fetched_dma_roots(sequential) {
    guard !outputs.any(output => output.name() == binding.name) else {
      raise InvalidFormalBundleIdentity("fetched DMA: duplicate observation")
    }
    outputs.push(
      @ir.OutputPort::new(binding.name, binding.signal_type, binding.node),
    )
  }
  @ir.Module::checked_with_metadata(
    original.name(),
    original.domains(),
    original.nodes(),
    original.memories(),
    outputs,
    original.metadata(),
  )
}
