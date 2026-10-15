///|
fn fetched_retirement_aliases(
  original : @ir.Module,
) -> Array[QueueControlAlias] raise {
  let fixture = @flux_tile.ring_concurrent_queue_formal_fixture()
  guard fixture.hardware() == original && fixture.observations().length() == 102 else {
    raise InvalidFormalBundleIdentity(
      "fetched retirement: exact ordinary q2 graph",
    )
  }
  let aliases : Array[QueueControlAlias] = []
  for (role, signal_type) in queue_expected_observations() {
    if role
      is (EntryValid(2)
      | EntryTerminal(2)
      | EntryTicket(2)
      | EntryId(2)
      | EntryFault(2)
      | EntryProgress(2)
      | EntryAddress(2)
      | EntryAllocate(2)
      | EntryAcknowledge(2)
      | EntryLocalTerminal(2)
      | EntryCollector(2, _)) {
      continue
    }
    let binding = queue_control_binding(fixture, role)
    guard binding.signal_type == signal_type else {
      raise InvalidFormalBundleIdentity(
        "fetched retirement: exact q2 role type",
      )
    }
    aliases.push({ ..binding, name: "composition_queue_" + binding.name, })
  }
  guard aliases.length() == 102 else {
    raise InvalidFormalBundleIdentity(
      "fetched retirement: complete q2 inventory",
    )
  }
  aliases
}

///|
fn fetched_retirement_view(
  sequential : FetchedTransportSequential,
) -> @ir.Module raise {
  let original = fetched_safety_view(sequential)
  let outputs = original.outputs().iter().to_array()
  for binding in fetched_retirement_aliases(sequential.probe.source) {
    guard !outputs.any(output => output.name() == binding.name) else {
      raise InvalidFormalBundleIdentity("fetched retirement: duplicate alias")
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
