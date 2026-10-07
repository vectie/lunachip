///|
fn fetched_transport_proof_report_pin() -> String {
  "763a887609330105619add6b7ed34b213fb4a4c63daf19eeaf4cdfb777c45c2a"
}

///|
fn fetched_transport_proof_ir_pin() -> String {
  "27943639629c1f85a5a5e3ce2eacf375a89731f7b5caed95c16c4a14e1229cab"
}

///|
// Literal pins bind the independently reviewed complete native inventory and
// canonical copy. Source identity and correspondence are not a proof result.
fn fetched_transport_proof_require(
  sequential : FetchedTransportSequential,
) -> Unit raise {
  let fresh = fetched_transport_sequential()
  let canonical = @ir_codec.serialize(
    @ir.Design::single("FetchedTransportSequential", sequential.hardware),
  )
  if sequential != fresh ||
    sha256_hex(fetched_transport_probe_report(sequential.probe)) !=
    fetched_transport_proof_report_pin() ||
    sha256_hex(canonical) != fetched_transport_proof_ir_pin() {
    raise InvalidFormalBundleIdentity(
      "fetched proof: complete reviewed source/report/core identity required",
    )
  }
}

///|
fn fetched_transport_proof_view_aliases(
  sequential : FetchedTransportSequential,
) -> ReadOnlyArray[QueueControlAlias] raise {
  let probe = sequential.probe
  let arbiter = fetched_transport_arbiter(
    probe.source,
    probe.clock,
    probe.reset,
  )
  let aliases : Array[QueueControlAlias] = []
  for
    (name, original) in [
      ("reader_valid", arbiter.reader_valid),
      ("reader_ready", arbiter.reader_ready),
      ("reader_address", arbiter.reader_fields[1]),
      (
        "config_ready",
        two_client_arbiter_output(probe.source, "config_ready", @wire.bits(1)),
      ),
      (
        "publish_ready",
        two_client_arbiter_output(probe.source, "publish_ready", @wire.bits(1)),
      ),
    ] {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      original,
    )
    guard sequential.hardware.node(mapped) is Some(node) &&
      node.signal_type() ==
      dependency_generation_node(probe.source, original).signal_type() else {
      raise InvalidFormalBundleIdentity(
        "fetched proof view: alias must already be retained",
      )
    }
    aliases.push({ name, node: original, signal_type: node.signal_type(), })
  }
  ReadOnlyArray::from_array(aliases)
}

///|
// Five direct aliases of already retained nodes. No new operation, node,
// register, memory, cut or native-core change is introduced.
fn fetched_transport_proof_view(
  sequential : FetchedTransportSequential,
) -> @ir.Module raise {
  let outputs = sequential.hardware.outputs().iter().to_array()
  for view_alias in fetched_transport_proof_view_aliases(sequential) {
    let name = "proof_" + view_alias.name
    if outputs.any(output => output.name() == name) {
      raise InvalidFormalBundleIdentity("fetched proof view: duplicate alias")
    }
    outputs.push(
      @ir.OutputPort::new(
        name,
        view_alias.signal_type,
        dependency_generation_mapped(
          sequential.original_to_local,
          view_alias.node,
        ),
      ),
    )
  }
  @ir.Module::checked_with_metadata(
    sequential.hardware.name(),
    sequential.hardware.domains(),
    sequential.hardware.nodes(),
    sequential.hardware.memories(),
    outputs,
    sequential.hardware.metadata(),
  )
}
