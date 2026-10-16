///|
// Follow the original UInt64 address BEFORE encoding, then the actual cursor
// recurrences. These are aliases, not new state or independent engine inputs.
fn direct8_engine_transfer_bindings(
  fixture : @flux_tile.QueueConservationFixture,
  probe : TwoClientArbiterProbe,
) -> Array[QueueControlAlias] raise {
  let source = fixture.hardware()
  let aliases : Array[QueueControlAlias] = []
  for (client, engine, bytes) in [("reader", 0, 1), ("engine", 2, 4)] {
    guard probe.boundaries.filter(item => {
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
      fail("direct8 engines: original full-width DMA equation")
    }
    for
      id in [
        full_address, base_row, row_offset, column_offset, extended_base, extended_row,
        extended_stride, extended_column,
      ] {
      assert_eq(
        dependency_generation_node(source, id).signal_type(),
        @wire.uint(64),
      )
    }
    let (accept, _) = fetched_safety_latch(source, base)
    let (stride_accept, _) = fetched_safety_latch(source, stride)
    guard stride_accept == accept &&
      accept == queue_control_binding(fixture, EngineAccept(engine)).node &&
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
      is BitAnd(advance, last_column) &&
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
      is Mux(
        select=column_accept,
        when_true=column_zero,
        when_false=column_update
      ) &&
      column_accept == accept &&
      fetched_transport_constant(source, column_zero, 13, 0UL) &&
      dependency_generation_node(source, column_update).kind()
      is Mux(
        select=column_advance,
        when_true=advanced_column,
        when_false=held_column
      ) &&
      column_advance == advance &&
      held_column == column &&
      dependency_generation_node(source, advanced_column).kind()
      is Mux(select=same_last, when_true=last_zero, when_false=same_increment) &&
      same_last == last_column &&
      dependency_generation_node(source, same_increment).kind()
      is Add(advanced_same_column, advanced_column_one) &&
      advanced_same_column == column &&
      fetched_transport_constant(source, advanced_column_one, 13, 1UL) &&
      fetched_transport_constant(source, last_zero, 13, 0UL) else {
      fail("direct8 engines: original full-width cursor recurrence")
    }
    let (columns_accept, _) = fetched_safety_latch(source, columns)
    assert_eq(columns_accept, accept)
    let rows = fetched_transport_unique(source, client + " rows latch", node => {
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
    for
      (name, id, signal_type) in [
        ("base", base, @wire.uint(32)),
        ("stride", stride, @wire.uint(32)),
        ("row", row, @wire.uint(13)),
        ("column", column, @wire.uint(13)),
        ("rows", rows, @wire.uint(13)),
        ("columns", columns, @wire.uint(13)),
        ("address_full", full_address, @wire.uint(64)),
        ("accept", accept, @wire.bits(1)),
        ("advance", advance, @wire.bits(1)),
        ("last_column", last_column, @wire.bits(1)),
      ] {
      assert_eq(
        dependency_generation_node(source, id).signal_type(),
        signal_type,
      )
      aliases.push({ name: "t_" + client + "_" + name, node: id, signal_type, })
    }
  }
  aliases
}
