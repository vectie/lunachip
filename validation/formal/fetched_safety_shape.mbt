///|
fn fetched_safety_latch(
  source : @ir.Module,
  id : @ir.NodeId,
) -> (@ir.NodeId, @ir.NodeId) raise {
  guard dependency_generation_node(source, id).kind() is Register(spec) else {
    raise InvalidFormalBundleIdentity("fetched shape: real latch required")
  }
  if spec.enable() is Some(event) {
    return (event, spec.next())
  }
  guard dependency_generation_node(source, spec.next()).kind()
    is Mux(select=event, when_true=input, when_false=held) &&
    held == id else {
    raise InvalidFormalBundleIdentity("fetched shape: exact held latch")
  }
  (event, input)
}

///|
// Recover physical-result shape from the actual C-memory enable comparisons,
// then follow the real finish latches back to the core admission registers.
fn fetched_safety_shape_roots(
  source : @ir.Module,
  rows? : Int = 1,
  columns? : Int = 1,
  max_reduction? : Int = 2,
) -> Array[QueueControlAlias] raise {
  let aliases : Array[QueueControlAlias] = []
  let active : Array[@ir.NodeId] = []
  let captures : Array[@ir.NodeId] = []
  for slot in 0..<2 {
    guard source
      .memories()
      .filter(memory => memory.name() == "c_result_slot_\{slot}")
      is [memory] &&
      memory.depth().elements() == rows * columns &&
      memory.read_ports() is [read] &&
      read.enable() is Some(enable) &&
      memory.write_ports() is [write] &&
      write.enable() is Some(write_enable) &&
      dependency_generation_node(source, enable).kind() is BitAnd(_, bounds) &&
      dependency_generation_node(source, bounds).kind()
      is BitAnd(row_bound, column_bound) &&
      dependency_generation_node(source, write_enable).kind()
      is BitAnd(capture, _) else {
      raise InvalidFormalBundleIdentity(
        "fetched shape: actual physical C ports",
      )
    }
    captures.push(capture)
    for (field, bound) in [("rows", row_bound), ("columns", column_bound)] {
      guard dependency_generation_node(source, bound).kind()
        is LessThan(_, stored) &&
        dependency_generation_node(source, stored).signal_type() ==
        @wire.uint(4) &&
        dependency_generation_node(source, stored).kind() is Register(_) else {
        raise InvalidFormalBundleIdentity(
          "fetched shape: full-width stored/core shape latch",
        )
      }
      let (_, value) = fetched_safety_latch(source, stored)
      guard dependency_generation_node(source, value).kind() is Register(_) else {
        raise InvalidFormalBundleIdentity(
          "fetched shape: original core shape register",
        )
      }
      aliases.push({
        name: "composition_shape_slot\{slot}_\{field}",
        node: stored,
        signal_type: @wire.uint(4),
      })
      active.push(value)
    }
  }
  guard active[0] == active[2] &&
    active[1] == active[3] &&
    captures[0] == captures[1] else {
    raise InvalidFormalBundleIdentity(
      "fetched shape: shared actual core accept/shape",
    )
  }
  let (accept, command_rows) = fetched_safety_latch(source, active[0])
  let (column_accept, command_columns) = fetched_safety_latch(source, active[1])
  guard column_accept == accept else {
    raise InvalidFormalBundleIdentity("fetched shape: shared shape accept")
  }
  let fault = fetched_transport_unique(source, "core success fault latch", node => {
    guard node.signal_type() == @wire.uint(2) && node.kind() is Register(_) else {
      return false
    }
    let (event, input) = fetched_safety_latch(source, node.id()) catch {
      _ => return false
    }
    guard event == accept &&
      dependency_generation_node(source, input).kind()
      is Mux(when_true=initialized, when_false=invalid, ..) &&
      dependency_generation_node(source, initialized).kind()
      is Mux(when_true=success, when_false=unloaded, ..) else {
      return false
    }
    fetched_transport_constant(source, success, 2, 0UL) &&
    fetched_transport_constant(source, unloaded, 2, 2UL) &&
    fetched_transport_constant(source, invalid, 2, 1UL)
  })
  let (_, fault_input) = fetched_safety_latch(source, fault)
  guard dependency_generation_node(source, fault_input).kind()
    is Mux(select=dimensions, ..) &&
    dependency_generation_node(source, accept).kind() is BitAnd(idle, _) &&
    dependency_generation_node(source, idle).kind() is BitAnd(idle_state, _) &&
    dependency_generation_node(source, idle_state).kind()
    is Equal(core_state, zero) &&
    fetched_transport_constant(source, zero, 2, 0UL) &&
    dependency_generation_node(source, core_state).kind() is Register(_) else {
    raise InvalidFormalBundleIdentity(
      "fetched shape: real dimension/fault/state path",
    )
  }
  let leaves : Array[@ir.NodeId] = []
  let pending = [dimensions]
  for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
    let id = pending[cursor]
    match dependency_generation_node(source, id).kind() {
      BitAnd(a, b) => {
        pending.push(a)
        pending.push(b)
      }
      _ => leaves.push(id)
    }
  }
  for (command, maximum) in [(command_rows, rows), (command_columns, columns)] {
    guard leaves.any(id => {
      dependency_generation_node(source, id).kind() is LessEqual(value, bound) &&
      value == command &&
      fetched_transport_constant(source, bound, 4, maximum.to_uint64())
    }) else {
      raise InvalidFormalBundleIdentity(
        "fetched shape: original physical dimension bound",
      )
    }
  }
  let reduction = fetched_transport_unique(
    source,
    "core full-width reduction latch",
    node => {
      guard node.signal_type() == @wire.uint(13) && node.kind() is Register(_) else {
        return false
      }
      let (event, input) = fetched_safety_latch(source, node.id()) catch {
        _ => return false
      }
      if event != accept {
        return false
      }
      leaves.any(id => {
        dependency_generation_node(source, id).kind() is LessEqual(value, bound) &&
        value == input &&
        fetched_transport_constant(source, bound, 13, max_reduction.to_uint64())
      })
    },
  )
  for
    (name, id) in [
      ("core_rows", active[0]),
      ("core_columns", active[1]),
      ("core_fault", fault),
      ("core_state", core_state),
      ("core_reduction", reduction),
      ("capture", captures[0]),
    ] {
    aliases.push({
      name: "composition_shape_" + name,
      node: id,
      signal_type: dependency_generation_node(source, id).signal_type(),
    })
  }
  aliases
}

///|
fn fetched_safety_shape_support() -> String {
  (
    #|  always @($global_clock) begin
    #|    lc_fetched_core_success_shape: assert ((!lc_seen_edge || lc_dut_composition_shape_core_fault != 2'd0 || (lc_dut_composition_shape_core_rows <= 4'd1 && lc_dut_composition_shape_core_columns <= 4'd1 && lc_dut_composition_shape_core_reduction <= 13'd2)) === 1'b1);
    #|    lc_fetched_core_active_success: assert ((!lc_seen_edge || !(lc_dut_composition_shape_core_state == 2'd1 || lc_dut_composition_shape_core_state == 2'd2) || lc_dut_composition_shape_core_fault == 2'd0) === 1'b1);
    #|    lc_fetched_capture_success: assert ((!lc_seen_edge || !lc_dut_composition_shape_capture || lc_dut_composition_shape_core_fault == 2'd0) === 1'b1);
    #|    lc_fetched_result_shape_slot0: assert ((!lc_seen_edge || (lc_dut_composition_shape_slot0_rows <= 4'd1 && lc_dut_composition_shape_slot0_columns <= 4'd1)) === 1'b1);
    #|    lc_fetched_result_shape_slot1: assert ((!lc_seen_edge || (lc_dut_composition_shape_slot1_rows <= 4'd1 && lc_dut_composition_shape_slot1_columns <= 4'd1)) === 1'b1);
    #|  end
    #|
  )
}
