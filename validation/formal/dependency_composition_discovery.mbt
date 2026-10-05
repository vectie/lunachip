///|
// Recompute from all actual register specifications. Merely joining the two
// old cut lists would make the compute terminal a free input and shadow the
// same controller whose state this slice must retain.
fn dependency_composition_plan(
  hardware : @ir.Module,
  bindings : ArrayView[DependencyGenerationBinding],
) -> DependencyCompositionPlan raise {
  let generation = dependency_generation_plan(hardware, bindings)
  let compute = dependency_compute_plan(hardware, bindings)
  if generation.clock != compute.clock ||
    generation.reset != compute.reset ||
    generation.raw_poison != compute.raw_poison ||
    generation.public_halted != compute.public_halted {
    raise InvalidFormalBundleIdentity("composition discovery: shared aliases")
  }
  let roots : Array[DependencyComputeRoot] = []
  for root in generation.roots {
    roots.push({
      name: "generation_" + dependency_role_name(root.binding.role),
      node: root.binding.node,
      signal_type: root.binding.signal_type,
      spec: root.spec,
    })
  }
  for root in compute.roots {
    if roots.any(previous => previous.node == root.node) {
      raise InvalidFormalBundleIdentity("composition discovery: aliased roots")
    }
    roots.push({ ..root, name: "compute_" + root.name, })
  }
  let mut state_bits = 0
  for root in roots {
    state_bits += root.signal_type.width().bits()
  }
  if roots.length() != 27 || state_bits != 416 {
    raise InvalidFormalBundleIdentity("composition discovery: state inventory")
  }
  let cuts : Array[DependencyGenerationCut] = []
  let seeds : Array[@ir.NodeId] = []
  for root in roots {
    dependency_generation_add_cut(hardware, cuts, root.node, root.name)
    seeds.push(root.spec.next())
    if root.spec.reset() is Some(control) {
      seeds.push(control.signal())
    }
    if root.spec.enable() is Some(enable) {
      seeds.push(enable)
    }
  }
  // Retain only original free boundaries which neither retained cone derives.
  // Original node order is canonical; role aliases are deduplicated separately.
  for node in hardware.nodes() {
    let id = node.id()
    if roots.any(root => root.node == id) ||
      generation.cone.any(original => original.id() == id) ||
      compute.cone.any(original => original.id() == id) {
      continue
    }
    for old_cuts in [generation.cuts, compute.cuts] {
      for cut in old_cuts {
        if cut.node != id {
          continue
        }
        for role in cut.roles {
          if !cuts.any(existing => {
              existing.node == id && existing.roles.any(label => label == role)
            }) {
            dependency_generation_add_cut(hardware, cuts, id, role)
          }
        }
      }
    }
  }
  let mut free_count = 0
  let mut free_bits = 0
  for cut in cuts {
    if !roots.any(root => root.node == cut.node) {
      free_count += 1
      free_bits += cut.signal_type.width().bits()
    }
  }
  // Eighteen free boundaries plus the original clock: 19 inputs / 341 bits.
  if free_count != 18 || free_bits != 340 {
    raise InvalidFormalBundleIdentity("composition discovery: free inventory")
  }
  for
    original in [
      generation.local_fault,
      generation.local_reject,
      generation.public_halted,
      compute.accept,
      compute.preflight,
      compute.inner_valid,
      compute.inner_ready,
      compute.terminal,
    ] {
    seeds.push(original)
  }
  for binding in generation.decoder_bindings {
    seeds.push(binding.node)
  }
  let cone = dependency_generation_closure(hardware, cuts, seeds)
  for
    derived in [
      generation.local_fault,
      generation.local_reject,
      generation.public_halted,
      compute.accept,
      compute.inner_valid,
      compute.terminal,
    ] {
    if cuts.any(cut => cut.node == derived) ||
      !cone.any(node => node.id() == derived) {
      raise InvalidFormalBundleIdentity(
        "composition discovery: derived event shadowed or omitted",
      )
    }
  }
  {
    generation,
    compute,
    roots: ReadOnlyArray::from_array(roots),
    cuts: ReadOnlyArray::from_array(cuts),
    cone: ReadOnlyArray::from_array(cone),
    clock: generation.clock,
    reset: generation.reset,
  }
}

///|
fn dependency_composition_discover(
  fixture : @flux_tile.QueuedConcurrentFormalFixture,
) -> DependencyCompositionPlan raise {
  dependency_composition_plan(
    fixture.hardware(),
    dependency_generation_bindings(fixture),
  )
}
