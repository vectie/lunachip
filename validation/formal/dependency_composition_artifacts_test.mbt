///|
test "compute generation public exporter returns six deterministic local proof inputs" {
  let artifacts = @formal.generate_dependency_compute_generation_artifacts()
  assert_eq(
    artifacts,
    @formal.generate_dependency_compute_generation_artifacts(),
  )
  assert_eq(artifacts.length(), 6)
  assert_eq(artifacts.map(artifact => artifact.path()), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-inner.sv", "bridge-inputs.txt",
  ])
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing composition artifact")
    }
    artifact.content()
  }
  let design = @ir_codec.parse(content("sequential.lcir"))
  guard design.top_module() is Some(hardware) else {
    fail("missing composition top")
  }
  let registers = hardware.nodes().filter(node => node.kind() is Register(_))
  let inputs = hardware.nodes().filter(node => node.kind() is Input(_))
  assert_eq(registers.length(), 27)
  assert_eq(
    registers.fold(init=0, (bits, node) => {
      bits + node.signal_type().width().bits()
    }),
    416,
  )
  assert_eq(inputs.length(), 19)
  assert_eq(
    inputs.fold(init=0, (bits, node) => bits + node.signal_type().width().bits()),
    341,
  )
  assert_eq(hardware.outputs().length(), 42)
  assert_eq(hardware.domains().length(), 1)
  assert_eq(hardware.memories().length(), 0)
  let inventory = content("bridge-inputs.txt")
  assert_true(inventory.contains("not-proof-or-full-device-gate"))
  assert_true(
    inventory.contains("reference-live-generation-and-compute-444-bits"),
  )
  assert_true(inventory.contains("no-relation-authorization-or-event-premise"))
  assert_eq(inventory.split("\nREGISTER ").length() - 1, 27)
  assert_eq(inventory.split("\nCUT node ").length() - 1, 18)
  assert_eq(inventory.split("\nINPUT ").length() - 1, 19)
  assert_eq(inventory.split("\nOUTPUT ").length() - 1, 42)
  assert_eq(inventory.split("\nDECODER ").length() - 1, 7)
  assert_eq(inventory.split("\nSOURCE ").length() - 1, 5)
  assert_true(content("sequential-production.sv").contains("always_ff"))
  assert_true(
    content("sequential-production.sv") != content("sequential-boolean.sv"),
  )
  assert_false(artifacts.any(artifact => artifact.path() == "job.json"))
  assert_false(artifacts.any(artifact => artifact.path() == "source-set.lcfs"))
}
