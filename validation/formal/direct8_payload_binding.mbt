///|
// Resolve metadata at the original Store-valid producer and indexed read latch.
// No data word, guessed node ordinal, independent input or memory rewrite.
fn direct8_payload_bindings(
  fixture : @flux_tile.QueueConservationFixture,
) -> Array[QueueControlAlias] raise {
  let source = fixture.hardware()
  let probe = direct8_arbiter_probe(fixture)
  let owners = direct8_engine_owner_bindings(fixture, probe)
  let transfer = direct8_engine_transfer_bindings(fixture, probe)
  let find = (bindings : Array[QueueControlAlias], name : String) => {
    guard bindings.filter(item => item.name == name) is [item] else {
      fail("pending payload: unique original alias")
    }
    item.node
  }
  let accepted = find(owners, "o_read_accept")
  let slot = find(owners, "o_store_slot")
  guard probe.boundaries.filter(item => item.roles.contains("engine_valid"))
    is [valid] else {
    fail("pending payload: original Store producer")
  }
  let leaves = direct8_engine_and_leaves(source, valid.original.id())
  let identities : Array[(@ir.NodeId, @ir.NodeId)] = []
  let faults : Array[@ir.NodeId] = []
  for leaf in leaves {
    if dependency_generation_node(source, leaf).kind() is Equal(a, b) {
      for (response, held) in [(a, b), (b, a)] {
        let response_node = dependency_generation_node(source, response)
        if response_node.signal_type() == @wire.uint(32) &&
          response_node.kind() is Register(_) &&
          dependency_generation_node(source, held).signal_type() ==
          @wire.uint(32) &&
          dependency_generation_node(source, held).kind() is Register(_) {
          let (event, input) = fetched_safety_latch(source, response)
          let (owner, _) = fetched_safety_latch(source, held)
          if event == accepted &&
            input == held &&
            owner == queue_control_binding(fixture, EngineAccept(2)).node {
            identities.push((response, held))
          }
        }
        if response_node.signal_type() == @wire.uint(2) &&
          response_node.kind() is Register(_) &&
          fetched_transport_constant(source, held, 2, 0UL) {
          faults.push(response)
        }
      }
    }
  }
  guard identities is [(response_id, store_id)] && faults is [response_fault] else {
    fail("pending payload: exact full ID comparison and status producer")
  }
  let (fault_accept, read_fault) = fetched_safety_latch(source, response_fault)
  guard fault_accept == accepted &&
    dependency_generation_node(source, read_fault).kind()
    is Mux(select=one, when_true=fault1, when_false=fault0) &&
    dependency_generation_node(source, one).kind() is Equal(selected, constant) &&
    selected == slot &&
    fetched_transport_constant(source, constant, 1, 1UL) else {
    fail("pending payload: same-event selected C read status")
  }
  let bindings : Array[QueueControlAlias] = []
  for
    (name, node, signal_type) in [
      ("response_id", response_id, @wire.uint(32)),
      ("store_id", store_id, @wire.uint(32)),
      ("response_fault", response_fault, @wire.uint(2)),
      ("read_fault", read_fault, @wire.uint(2)),
    ] {
    bindings.push({ name: "p_" + name, node, signal_type, })
  }
  for (index, fault) in [(0, fault0), (1, fault1)] {
    guard dependency_generation_node(source, fault).kind()
      is Mux(select=valid_c, when_true=checked, when_false=invalid) &&
      fetched_transport_constant(source, invalid, 2, 2UL) &&
      dependency_generation_node(source, valid_c).kind() is Register(valid_spec) &&
      dependency_generation_node(source, checked).kind()
      is Mux(select=bounds, when_true=good, when_false=bad) &&
      fetched_transport_constant(source, good, 2, 0UL) &&
      fetched_transport_constant(source, bad, 2, 1UL) &&
      dependency_generation_node(source, bounds).kind()
      is BitAnd(row_ok, column_ok) &&
      dependency_generation_node(source, row_ok).kind()
      is LessThan(read_row, rows) &&
      dependency_generation_node(source, column_ok).kind()
      is LessThan(read_column, columns) &&
      dependency_generation_node(source, read_row).kind() is Truncate(full_row) &&
      full_row == find(transfer, "t_engine_row") &&
      dependency_generation_node(source, read_column).kind()
      is Truncate(full_column) &&
      full_column == find(transfer, "t_engine_column") &&
      dependency_generation_node(source, valid_spec.next()).kind()
      is Mux(when_true=zero, when_false=publish_next, ..) &&
      fetched_transport_constant(source, zero, 1, 0UL) &&
      dependency_generation_node(source, publish_next).kind()
      is Mux(select=finish, when_true=published, when_false=held_valid) &&
      held_valid == valid_c &&
      fetched_transport_constant(source, published, 1, 1UL) else {
      fail("pending payload: original slot status and full cursor decoder")
    }
    let (rows_event, _) = fetched_safety_latch(source, rows)
    let (columns_event, _) = fetched_safety_latch(source, columns)
    assert_eq((rows_event, columns_event), (finish, finish))
    for
      (name, node, signal_type) in [
        ("valid", valid_c, @wire.bits(1)),
        ("rows", rows, @wire.uint(4)),
        ("columns", columns, @wire.uint(4)),
      ] {
      assert_eq(
        dependency_generation_node(source, node).signal_type(),
        signal_type,
      )
      bindings.push({ name: "p_c_" + name + "_\{index}", node, signal_type, })
    }
  }
  assert_eq(bindings.length(), 10)
  bindings
}
