///|
fn fetched_dependency_aliases(
  source : @ir.Module,
) -> Array[QueueControlAlias] raise {
  let fixture = @flux_tile.ring_concurrent_dependency_formal_fixture()
  let expected = dependency_expected_observations()
  guard fixture.hardware() == source &&
    fixture.observations().length() == 48 &&
    expected.length() == 48 else {
    raise InvalidFormalBundleIdentity(
      "fetched dependency: exact ordinary q2 graph and inventory",
    )
  }
  let aliases : Array[QueueControlAlias] = []
  for index, observation in fixture.observations() {
    let (role, width) = expected[index]
    guard observation.role() == role &&
      observation.signal_type().width().bits() == width &&
      dependency_generation_node(source, observation.node()).signal_type() ==
      observation.signal_type() else {
      raise InvalidFormalBundleIdentity(
        "fetched dependency: actual typed observation",
      )
    }
    aliases.push({
      name: "composition_dependency_" + dependency_role_name(role),
      node: observation.node(),
      signal_type: observation.signal_type(),
    })
  }
  aliases
}

///|
fn fetched_dependency_view(
  sequential : FetchedTransportSequential,
) -> @ir.Module raise {
  let original = fetched_dma_view(sequential)
  let outputs = original.outputs().iter().to_array()
  for binding in fetched_dependency_aliases(sequential.probe.source) {
    guard !outputs.any(output => output.name() == binding.name) else {
      raise InvalidFormalBundleIdentity("fetched dependency: duplicate alias")
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
