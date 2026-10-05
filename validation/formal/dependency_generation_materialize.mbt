///|
// A combinational transfer of the exact discovered production cone. This is
// not an independent oracle, supporting assumption, or completed proof.
// The proof-input exporter consumes hardware/plan; the full original-to-local
// map is retained for exact-copy white-box checks.
#warnings("-unused_field")
priv struct DependencyGenerationTransfer {
  hardware : @ir.Module
  plan : DependencyGenerationPlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
}

///|
fn dependency_generation_mapped(
  mapping : ArrayView[@ir.NodeId?],
  original : @ir.NodeId,
) -> @ir.NodeId raise FormalGateError {
  guard mapping.get(original.ordinal()) is Some(Some(mapped_id)) else {
    raise InvalidFormalBundleIdentity(
      "generation transfer: missing original operand \{original.ordinal()}",
    )
  }
  mapped_id
}

///|
fn dependency_generation_remap(
  kind : @ir.NodeKind,
  mapping : ArrayView[@ir.NodeId?],
) -> @ir.NodeKind raise FormalGateError {
  fn mapped(id) raise FormalGateError {
    dependency_generation_mapped(mapping, id)
  }
  match kind {
    Constant(value) => Constant(value)
    BitNot(value) => BitNot(mapped(value))
    ZeroExtend(value) => ZeroExtend(mapped(value))
    SignExtend(value) => SignExtend(mapped(value))
    Truncate(value) => Truncate(mapped(value))
    Reinterpret(value) => Reinterpret(mapped(value))
    Slice(value~, msb~, lsb~) => Slice(value=mapped(value), msb~, lsb~)
    Add(left, right) => Add(mapped(left), mapped(right))
    Sub(left, right) => Sub(mapped(left), mapped(right))
    MulLow(left, right) => MulLow(mapped(left), mapped(right))
    MulFull(left, right) => MulFull(mapped(left), mapped(right))
    BitAnd(left, right) => BitAnd(mapped(left), mapped(right))
    BitOr(left, right) => BitOr(mapped(left), mapped(right))
    BitXor(left, right) => BitXor(mapped(left), mapped(right))
    Equal(left, right) => Equal(mapped(left), mapped(right))
    LessThan(left, right) => LessThan(mapped(left), mapped(right))
    LessEqual(left, right) => LessEqual(mapped(left), mapped(right))
    ShiftLeft(value~, amount~) =>
      ShiftLeft(value=mapped(value), amount=mapped(amount))
    LogicalShiftRight(value~, amount~) =>
      LogicalShiftRight(value=mapped(value), amount=mapped(amount))
    ArithmeticShiftRight(value~, amount~) =>
      ArithmeticShiftRight(value=mapped(value), amount=mapped(amount))
    Concat(most_significant~, least_significant~) =>
      Concat(
        most_significant=mapped(most_significant),
        least_significant=mapped(least_significant),
      )
    Mux(select~, when_true~, when_false~) =>
      Mux(
        select=mapped(select),
        when_true=mapped(when_true),
        when_false=mapped(when_false),
      )
    Input(_) | Register(_) | MemoryRead(..) | AsyncFifoRead(..) =>
      raise InvalidFormalBundleIdentity(
        "generation transfer: unlisted graph leaf",
      )
  }
}

///|
fn dependency_generation_append(
  nodes : Array[@ir.Node],
  signal_type : @ir.SignalType,
  kind : @ir.NodeKind,
) -> @ir.NodeId raise {
  let id = @ir.NodeId::new(nodes.length())
  nodes.push(@ir.Node::new(id, signal_type, kind))
  id
}

///|
// Discovery validates the reset/domain/type contract before this exact edge
// transfer is materialized. Keep reset > enable > hold in one tested path.
fn dependency_generation_edge_transfer(
  nodes : Array[@ir.Node],
  mapping : ArrayView[@ir.NodeId?],
  root : DependencyGenerationRoot,
  reset_select : @ir.NodeId,
) -> @ir.NodeId raise {
  let current = dependency_generation_mapped(mapping, root.binding.node)
  let next = dependency_generation_mapped(mapping, root.spec.next())
  let enabled = match root.spec.enable() {
    Some(enable) =>
      dependency_generation_append(
        nodes,
        root.binding.signal_type,
        Mux(
          select=dependency_generation_mapped(mapping, enable),
          when_true=next,
          when_false=current,
        ),
      )
    None => next
  }
  guard root.spec.reset() is Some(control) else {
    raise InvalidFormalBundleIdentity(
      "generation transfer: missing checked reset",
    )
  }
  let reset_value = dependency_generation_append(
    nodes,
    root.binding.signal_type,
    Constant(control.value()),
  )
  dependency_generation_append(
    nodes,
    root.binding.signal_type,
    Mux(select=reset_select, when_true=reset_value, when_false=enabled),
  )
}

///|
// Used only by the separately requested local proof-input exporter and tests;
// do not add work to the existing full-device tasks.
fn dependency_generation_materialize(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyGenerationTransfer raise {
  let source = fixture.hardware()
  let plan = dependency_generation_discover(fixture)
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  let nodes : Array[@ir.Node] = []
  let outputs : Array[@ir.OutputPort] = []
  for cut in plan.cuts {
    let mapped_id = dependency_generation_append(
      nodes,
      cut.signal_type,
      Input("cut_n\{cut.node.ordinal()}"),
    )
    mapping[cut.node.ordinal()] = Some(mapped_id)
  }
  for original in plan.cone {
    let mapped_id = dependency_generation_append(
      nodes,
      original.signal_type(),
      dependency_generation_remap(original.kind(), mapping),
    )
    mapping[original.id().ordinal()] = Some(mapped_id)
  }
  // Reset is a typed control input. Reinterpretation preserves its sole bit;
  // the discovered specs require synchronous active-high reset on this node.
  let reset_select = dependency_generation_append(
    nodes,
    @wire.bits(1),
    Reinterpret(dependency_generation_mapped(mapping, plan.reset)),
  )
  for root in plan.roots {
    let post = dependency_generation_edge_transfer(
      nodes, mapping, root, reset_select,
    )
    outputs.push(
      @ir.OutputPort::new(
        "post_" + dependency_role_name(root.binding.role),
        root.binding.signal_type,
        post,
      ),
    )
  }
  for
    (name, original) in [
      ("local_fault", plan.local_fault),
      ("local_reject", plan.local_reject),
      ("public_halted", plan.public_halted),
    ] {
    let node = dependency_generation_node(source, original)
    outputs.push(
      @ir.OutputPort::new(
        name,
        node.signal_type(),
        dependency_generation_mapped(mapping, original),
      ),
    )
  }
  for binding in plan.decoder_bindings {
    outputs.push(
      @ir.OutputPort::new(
        binding.name,
        binding.signal_type,
        dependency_generation_mapped(mapping, binding.node),
      ),
    )
  }
  {
    hardware: @ir.Module::checked(
      "DependencyGenerationTransfer", nodes, outputs,
    ),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
