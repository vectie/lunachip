///|
// Full exact closure is independently rederived before accepting a supplied
// plan. Exposed privately for count-preserving node/spec/cut corruption tests.
fn store_storage_projection_from_plan(
  fixture : @flux_tile.StorePreservationFixture,
  plan : StoreStorageProjectionPlan,
) -> StoreStorageProjection raise {
  if plan != store_storage_projection_plan(fixture) {
    raise InvalidFormalBundleIdentity(
      "Store projection: complete original closure drift",
    )
  }
  let source = fixture.hardware()
  let mapping : Array[@ir.NodeId?] = Array::make(source.nodes().length(), None)
  for index, original in plan.selected {
    mapping[original.id().ordinal()] = Some(@ir.NodeId::new(index))
  }
  let memory_mapping : Array[@ir.MemoryId?] = Array::make(
    source.memories().length(),
    None,
  )
  for index, original in plan.memories {
    memory_mapping[original.id().ordinal()] = Some(@ir.MemoryId::new(index))
  }
  let nodes : Array[@ir.Node] = []
  for original in plan.selected {
    let kind : @ir.NodeKind = if plan.arithmetic.any(cut => {
        cut.id() == original.id()
      }) {
      Input("arithmetic_n\{original.id().ordinal()}")
    } else {
      match original.kind() {
        Input(name) => Input(name)
        Register(spec) => dependency_sequential_register_kind(spec, mapping)
        MemoryRead(memory~, port~) =>
          MemoryRead(
            memory=queue_storage_sequential_mapped_memory(
              memory_mapping, memory,
            ),
            port~,
          )
        _ => dependency_generation_remap(original.kind(), mapping)
      }
    }
    nodes.push(
      @ir.Node::new(
        dependency_generation_mapped(mapping, original.id()),
        original.signal_type(),
        kind,
      ),
    )
  }
  let memories : Array[@ir.MemorySpec] = []
  for original in plan.memories {
    memories.push(
      queue_storage_sequential_memory(original, mapping, memory_mapping),
    )
  }
  let outputs : Array[@ir.OutputPort] = []
  // Preserve the ordinary ABI and add private observation aliases only.
  for output in source.outputs() {
    outputs.push(
      @ir.OutputPort::new(
        output.name(),
        output.signal_type(),
        dependency_generation_mapped(mapping, output.driver()),
      ),
    )
  }
  for index, observation in fixture.observations() {
    outputs.push(
      @ir.OutputPort::new(
        "store_observation_\{index}",
        observation.signal_type(),
        dependency_generation_mapped(mapping, observation.node()),
      ),
    )
  }
  for original in plan.selected {
    let name = match original.kind() {
      Register(_) =>
        if plan.arithmetic.any(cut => cut.id() == original.id()) {
          None
        } else {
          Some("current_n\{original.id().ordinal()}")
        }
      MemoryRead(..) => Some("read_n\{original.id().ordinal()}")
      _ => None
    }
    if name is Some(name) {
      outputs.push(
        @ir.OutputPort::new(
          name,
          original.signal_type(),
          dependency_generation_mapped(mapping, original.id()),
        ),
      )
    }
  }
  {
    hardware: @ir.Module::checked_with_memories(
      "StoreStorageProjection", nodes, memories, outputs,
    ),
    plan,
    original_to_local: ReadOnlyArray::from_array(mapping),
    original_to_local_memory: ReadOnlyArray::from_array(memory_mapping),
  }
}

///|
#warnings("-unused_value")
fn store_storage_projection(
  fixture : @flux_tile.StorePreservationFixture,
) -> StoreStorageProjection raise {
  store_storage_projection_from_plan(
    fixture,
    store_storage_projection_plan(fixture),
  )
}
