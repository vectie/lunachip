///|
// Export-only observation of the retained raw response-data interface. The
// native correspondence module remains unchanged with its original28 aliases.
// This direct output makes the otherwise unused reviewed cut reachable to the
// fail-closed emitter; no operation, state, constraint or theorem is added.
fn two_client_arbiter_proof_view(
  sequential : TwoClientArbiterSequential,
) -> @ir.Module raise {
  let probe = sequential.probe
  if sha256_hex(two_client_arbiter_probe_report(probe)) !=
    "cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138" {
    raise InvalidFormalBundleIdentity("arbiter proof view: reviewed inventory")
  }
  guard probe.candidates.filter(candidate => {
      candidate.roles.contains("response_data")
    })
    is [candidate] &&
    candidate.original.kind() is Input("memory_response_data") &&
    candidate.original.signal_type() is Bits(width) &&
    width.bits() == 32 else {
    raise InvalidFormalBundleIdentity(
      "arbiter proof view: original raw response data",
    )
  }
  let original = candidate.original
  let mapped = dependency_generation_mapped(
    sequential.original_to_local,
    original.id(),
  )
  guard sequential.hardware.node(mapped) is Some(node) &&
    node.signal_type() == original.signal_type() &&
    node.kind() == Input("cut_n\{original.id().ordinal()}") else {
    raise InvalidFormalBundleIdentity("arbiter proof view: mapped raw input")
  }
  let outputs = sequential.hardware.outputs().iter().to_array()
  if outputs.length() != 28 ||
    outputs.any(output => output.name() == "raw_response_data_observation") {
    raise InvalidFormalBundleIdentity(
      "arbiter proof view: original output inventory",
    )
  }
  outputs.push(
    @ir.OutputPort::new(
      "raw_response_data_observation",
      original.signal_type(),
      mapped,
    ),
  )
  @ir.Module::checked_with_metadata(
    sequential.hardware.name(),
    sequential.hardware.domains(),
    sequential.hardware.nodes(),
    sequential.hardware.memories(),
    outputs,
    sequential.hardware.metadata(),
  )
}
