///|
// Exact production-register slice for the separate sequential bridge. No
// reference, invariant, assumption or proof is constructed here.
#warnings("-unused_field")
priv struct DependencyGenerationSequential {
  hardware : @ir.Module
  plan : DependencyGenerationPlan
  original_to_local : ReadOnlyArray[@ir.NodeId?]
}

///|
fn dependency_generation_sequential(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyGenerationSequential raise {
  let source = fixture.hardware()
  let plan = dependency_generation_discover(fixture)
  // Production order keeps clock/reset/enable before each register while
  // allowing its next-state expression to occur later. Cuts-first order does
  // not satisfy that contract when state cuts become actual registers.
  let selected = source
    .nodes()
    .filter(node => {
      node.id() == plan.clock ||
      plan.cuts.any(cut => cut.node == node.id()) ||
      plan.cone.any(original => original.id() == node.id())
    })
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, original in selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let nodes : Array[@ir.Node] = []
  for original in selected {
    let kind : @ir.NodeKind = match
      plan.roots.filter(root => root.binding.node == original.id()) {
      [root] => {
        let spec = root.spec
        let domain = @ir.ClockDomain::rising(
          dependency_generation_mapped(mapping, spec.domain().clock()),
        )
        let reset = match spec.reset() {
          None => None
          Some(control) =>
            Some(
              @ir.ResetSpec::explicit(
                dependency_generation_mapped(mapping, control.signal()),
                control.value(),
                control.mode(),
                control.polarity(),
              ),
            )
        }
        let enable = match spec.enable() {
          None => None
          Some(control) => Some(dependency_generation_mapped(mapping, control))
        }
        let initial = spec.initial()
        Register(
          @ir.RegisterSpec::new(
            domain,
            dependency_generation_mapped(mapping, spec.next()),
            reset?,
            enable?,
            initial?,
          ),
        )
      }
      [] =>
        if original.id() == plan.clock {
          Input("clock")
        } else if plan.cuts.any(cut => cut.node == original.id()) {
          Input("cut_n\{original.id().ordinal()}")
        } else {
          dependency_generation_remap(original.kind(), mapping)
        }
      _ =>
        raise InvalidFormalBundleIdentity(
          "generation sequential: repeated state root",
        )
    }
    nodes.push(
      @ir.Node::new(
        dependency_generation_mapped(mapping, original.id()),
        original.signal_type(),
        kind,
      ),
    )
  }
  let outputs : Array[@ir.OutputPort] = []
  for root in plan.roots {
    outputs.push(
      @ir.OutputPort::new(
        "current_" + dependency_role_name(root.binding.role),
        root.binding.signal_type,
        dependency_generation_mapped(mapping, root.binding.node),
      ),
    )
  }
  for
    (name, original) in [
      ("local_fault", plan.local_fault),
      ("local_reject", plan.local_reject),
      ("public_halted", plan.public_halted),
    ] {
    outputs.push(
      @ir.OutputPort::new(
        name,
        dependency_generation_node(source, original).signal_type(),
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
      "DependencyGenerationSequential", nodes, outputs,
    ),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
}
