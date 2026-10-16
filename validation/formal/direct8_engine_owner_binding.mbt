///|
fn direct8_engine_and_leaves(
  source : @ir.Module,
  root : @ir.NodeId,
) -> Array[@ir.NodeId] raise {
  let pending = [root]
  let leaves : Array[@ir.NodeId] = []
  for cursor = 0; cursor < pending.length(); cursor = cursor + 1 {
    match dependency_generation_node(source, pending[cursor]).kind() {
      BitAnd(a, b) => {
        pending.push(a)
        pending.push(b)
      }
      _ => leaves.push(pending[cursor])
    }
  }
  leaves
}

///|
// Discover ownership at the physical memory ports and the real response-valid
// producer. Prefix and pending registers stay original, resettable state.
fn direct8_engine_owner_bindings(
  fixture : @flux_tile.QueueConservationFixture,
  probe : TwoClientArbiterProbe,
) -> Array[QueueControlAlias] raise {
  let source = fixture.hardware()
  let aliases : Array[QueueControlAlias] = []
  guard probe.boundaries.filter(binding => {
      binding.roles.contains("engine_valid")
    })
    is [valid] else {
    fail("direct8 ownership: actual Store request producer")
  }
  let leaves = direct8_engine_and_leaves(source, valid.original.id())
  let pending = fetched_transport_unique(source, "physical pending read", node => {
    node.signal_type() == @wire.bits(1) &&
    node.kind() is Register(_) &&
    leaves.contains(node.id())
  })
  guard dependency_generation_node(source, pending).kind()
    is Register(pending_spec) &&
    dependency_generation_node(source, pending_spec.next()).kind()
    is Mux(select=read_accept, when_true=one, when_false=held_pending) &&
    fetched_transport_constant(source, one, 1, 1UL) &&
    dependency_generation_node(source, held_pending).kind()
    is BitAnd(same_pending, _) &&
    same_pending == pending else {
    fail("direct8 ownership: pending recurrence")
  }
  for (name, id) in [("pending", pending), ("read_accept", read_accept)] {
    aliases.push({ name: "o_" + name, node: id, signal_type: @wire.bits(1), })
  }
  let load_accept = queue_control_binding(fixture, EngineAccept(0)).node
  let store_accept = queue_control_binding(fixture, EngineAccept(2)).node
  let compute_accept = queue_control_binding(fixture, EngineAccept(1)).node
  guard direct8_engine_compute_bindings(fixture).filter(binding => {
      binding.name == "x_slotted_accept"
    })
    is [slotted] else {
    fail("direct8 ownership: shared slotted acceptance")
  }
  let selectors : Array[(@ir.NodeId, @ir.NodeId)] = []
  let load_slots : Array[@ir.NodeId] = []
  for operand in ["a", "b"] {
    for slot in 0..<2 {
      for bank in 0..<8 {
        guard source
          .memories()
          .filter(memory => {
            memory.name() == "\{operand}_slot_\{slot}_bank_\{bank}"
          })
          is [memory] &&
          memory.read_ports() is [read] &&
          read.enable() is Some(read_enable) &&
          dependency_generation_node(source, read_enable).kind()
          is BitAnd(_, selected) &&
          dependency_generation_node(source, selected).kind()
          is Equal(active_slot, slot_constant) &&
          fetched_transport_constant(source, slot_constant, 1, slot.to_uint64()) &&
          memory.write_ports() is [write] &&
          write.enable() is Some(write_enable) &&
          dependency_generation_node(source, write_enable).kind()
          is BitAnd(ready, _) else {
          fail("direct8 ownership: actual physical operand ports")
        }
        let (event, candidate_slot) = fetched_safety_latch(source, active_slot)
        let (candidate_event, _) = fetched_safety_latch(source, candidate_slot)
        assert_eq(candidate_event, compute_accept)
        if slot == 0 && bank == 0 {
          selectors.push((active_slot, candidate_slot))
        }
        assert_eq(
          (active_slot, candidate_slot),
          selectors[if operand == "a" { 0 } else { 1 }],
        )
        let terms = direct8_engine_and_leaves(source, ready)
        let prefixes = terms.filter_map(id => {
          match dependency_generation_node(source, id).kind() {
            LessEqual(_, prefix) if dependency_generation_node(source, prefix).kind()
              is Register(_) => Some(prefix)
            _ => None
          }
        })
        guard prefixes is [prefix] &&
          dependency_generation_node(source, prefix).signal_type() ==
          @wire.uint(13) else {
          fail("direct8 ownership: original full prefix register")
        }
        aliases.push({
          name: "p_\{operand}_\{slot}_\{bank}",
          node: prefix,
          signal_type: @wire.uint(13),
        })
        let slot_candidates = terms.filter_map(id => {
          guard dependency_generation_node(source, id).kind()
            is Equal(selection, constant) &&
            fetched_transport_constant(source, constant, 1, slot.to_uint64()) &&
            dependency_generation_node(source, selection).kind() is Register(_) &&
            dependency_generation_node(source, selection).signal_type() ==
            @wire.uint(1) else {
            return None
          }
          let (accepted, _) = fetched_safety_latch(source, selection)
          if accepted == load_accept {
            Some(selection)
          } else {
            None
          }
        })
        guard slot_candidates is [load_slot] else {
          fail("direct8 ownership: original loader selector")
        }
        load_slots.push(load_slot)
        assert_eq(event, slotted.node)
      }
    }
  }
  assert_true(load_slots.all(slot => slot == load_slots[0]))
  let load_slot = load_slots[0]
  let operand = fetched_transport_unique(source, "loader operand latch", node => {
    guard node.signal_type() == @wire.uint(1) &&
      node.kind() is Register(_) &&
      node.id() != load_slot else {
      return false
    }
    let (event, _) = fetched_safety_latch(source, node.id()) catch {
      _ => return false
    }
    event == load_accept
  })
  guard source.memories().filter(memory => memory.name() == "c_result_slot_0")
    is [c_memory] &&
    c_memory.write_ports() is [c_write] &&
    c_write.enable() is Some(c_enable) &&
    dependency_generation_node(source, c_enable).kind() is BitAnd(_, c_selected) &&
    dependency_generation_node(source, c_selected).kind()
    is Equal(active_c, c_zero) &&
    fetched_transport_constant(source, c_zero, 1, 0UL) &&
    c_memory.read_ports() is [c_read] &&
    c_read.enable() is Some(c_read_enable) else {
    fail("direct8 ownership: physical result selector")
  }
  let (_, compute_c) = fetched_safety_latch(source, active_c)
  let (c_accept, _) = fetched_safety_latch(source, compute_c)
  assert_eq(c_accept, compute_accept)
  selectors.push((active_c, compute_c))
  let store_terms = direct8_engine_and_leaves(source, c_read_enable)
  let store_slots = store_terms.filter_map(id => {
    guard dependency_generation_node(source, id).kind()
      is Equal(selection, constant) &&
      fetched_transport_constant(source, constant, 1, 0UL) &&
      dependency_generation_node(source, selection).kind() is Register(_) &&
      dependency_generation_node(source, selection).signal_type() ==
      @wire.uint(1) else {
      return None
    }
    let (event, _) = fetched_safety_latch(source, selection)
    if event == store_accept {
      Some(selection)
    } else {
      None
    }
  })
  guard store_slots is [store_slot] else {
    fail("direct8 ownership: Store selector")
  }
  for index, pair in selectors {
    let name = ["a", "b", "c"][index]
    for (role, id) in [("active", pair.0), ("compute", pair.1)] {
      aliases.push({
        name: "o_" + role + "_" + name,
        node: id,
        signal_type: @wire.uint(1),
      })
    }
  }
  for
    (name, id) in [
      ("load_slot", load_slot),
      ("load_operand", operand),
      ("store_slot", store_slot),
    ] {
    aliases.push({ name: "o_" + name, node: id, signal_type: @wire.uint(1), })
  }
  aliases
}
