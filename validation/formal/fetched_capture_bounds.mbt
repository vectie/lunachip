///|
// Follow BOTH actual write encoders back through their original UInt8 sum,
// before its SRAM-address truncation, to the two full UInt4 capture registers.
fn fetched_capture_roots(
  source : @ir.Module,
  columns? : Int = 1,
  depth? : Int = 1,
) -> Array[QueueControlAlias] raise {
  let coordinates : Array[(@ir.NodeId, @ir.NodeId)] = []
  let events : Array[@ir.NodeId] = []
  for slot in 0..<2 {
    guard source
      .memories()
      .filter(memory => memory.name() == "c_result_slot_\{slot}")
      is [memory] &&
      memory.depth().elements() == depth &&
      memory.write_ports() is [write] &&
      write.enable() is Some(enabled) &&
      dependency_generation_node(source, enabled).kind() is BitAnd(capture, _) &&
      dependency_generation_node(source, write.address()).kind()
      is Truncate(sum) &&
      dependency_generation_node(source, sum).signal_type() == @wire.uint(8) &&
      dependency_generation_node(source, sum).kind()
      is Add(product, extended_column) &&
      dependency_generation_node(source, product).kind()
      is MulLow(extended_row, stride) &&
      fetched_transport_constant(source, stride, 8, columns.to_uint64()) &&
      dependency_generation_node(source, extended_row).kind() is ZeroExtend(row) &&
      dependency_generation_node(source, extended_column).kind()
      is ZeroExtend(column) else {
      raise InvalidFormalBundleIdentity(
        "fetched capture: original full address encoder",
      )
    }
    for id in [row, column] {
      guard dependency_generation_node(source, id).signal_type() ==
        @wire.uint(4) &&
        dependency_generation_node(source, id).kind() is Register(_) else {
        raise InvalidFormalBundleIdentity(
          "fetched capture: full UInt4 registers",
        )
      }
    }
    coordinates.push((row, column))
    events.push(capture)
  }
  guard coordinates[0] == coordinates[1] &&
    events[0] == events[1] &&
    dependency_generation_node(source, events[0]).kind() is BitOr(capturing, _) &&
    dependency_generation_node(source, capturing).kind()
    is BitAnd(_, is_capture) &&
    dependency_generation_node(source, is_capture).kind() is Equal(state, two) &&
    fetched_transport_constant(source, two, 2, 2UL) &&
    dependency_generation_node(source, state).kind() is Register(state_spec) &&
    dependency_generation_node(source, state_spec.next()).kind()
    is Mux(select=accept, ..) else {
    raise InvalidFormalBundleIdentity("fetched capture: original shared phase")
  }
  for id in [coordinates[0].0, coordinates[0].1] {
    guard dependency_generation_node(source, id).kind() is Register(spec) &&
      dependency_generation_node(source, spec.next()).kind()
      is Mux(select=same_accept, when_true=zero, ..) &&
      same_accept == accept &&
      fetched_transport_constant(source, zero, 4, 0UL) else {
      raise InvalidFormalBundleIdentity(
        "fetched capture: original accepted cursor reset",
      )
    }
  }
  [
    for
      (name, id) in [
        ("row", coordinates[0].0),
        ("column", coordinates[0].1),
        ("state", state),
      ] => {
      {
        name: "composition_capture_" + name,
        node: id,
        signal_type: dependency_generation_node(source, id).signal_type(),
      }
    }
  ]
}

///|
fn fetched_capture_bounds_support() -> String {
  (
    #|  wire lc_fr_capture_active = lc_dut_composition_capture_state == 2'd1 || lc_dut_composition_capture_state == 2'd2;
    #|  always @($global_clock) begin
    #|    lc_fr_capture_shape: assert ((!lc_seen_edge || !lc_fr_capture_active || (lc_dut_composition_shape_core_fault == 2'd0 && lc_dut_composition_shape_core_rows == 4'd1 && lc_dut_composition_shape_core_columns == 4'd1)) === 1'b1);
    #|    lc_fr_capture_cursor: assert ((!lc_seen_edge || !lc_fr_capture_active || (lc_dut_composition_capture_row == 4'd0 && lc_dut_composition_capture_column == 4'd0)) === 1'b1);
    #|    lc_fr_capture_phase: assert ((!lc_seen_edge || !lc_dut_composition_shape_capture || lc_fr_capture_active) === 1'b1);
    #|  end
    #|
  )
}
