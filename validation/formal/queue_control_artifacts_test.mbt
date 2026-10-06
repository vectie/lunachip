///|
test "queue control public exporter returns six deterministic scoped proof inputs" {
  let artifacts = @formal.generate_queue_control_proof_artifacts()
  assert_eq(artifacts, @formal.generate_queue_control_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path()), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-reserve.sv", "bridge-inputs.txt",
  ])
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing queue proof input")
    }
    artifact.content()
  }
  let design = @ir_codec.parse(content("sequential.lcir"))
  guard design.top_module() is Some(hardware) else {
    fail("missing queue control top")
  }
  let registers = hardware.nodes().filter(node => node.kind() is Register(_))
  let inputs = hardware.nodes().filter(node => node.kind() is Input(_))
  assert_eq(registers.length(), 16)
  assert_eq(
    registers.fold(init=0, (bits, node) => {
      bits + node.signal_type().width().bits()
    }),
    37,
  )
  assert_eq(inputs.length(), 9)
  assert_eq(
    inputs.fold(init=0, (bits, node) => bits + node.signal_type().width().bits()),
    9,
  )
  assert_eq(hardware.outputs().length(), 54)
  assert_eq(hardware.domains().length(), 1)
  assert_eq(hardware.memories().length(), 0)
  let inventory = content("bridge-inputs.txt")
  assert_true(inventory.contains("not-proof-or-full-device-gate"))
  assert_true(inventory.contains("independent-public-outstanding-4-bits"))
  assert_true(
    inventory.contains("no-relation-event-readiness-or-progress-premise"),
  )
  assert_true(
    inventory.contains(
      "genuine-original-PRE-reserve-event-not-post-reservation-transition",
    ),
  )
  assert_true(
    inventory.contains(
      "no-State3-live-entry-no-engine-packet-memory-or-whole-device-claim",
    ),
  )
  assert_eq(inventory.split("\nREGISTER ").length() - 1, 16)
  assert_eq(inventory.split("\nCUT node ").length() - 1, 8)
  assert_eq(inventory.split("\nINPUT ").length() - 1, 9)
  assert_eq(inventory.split("\nOUTPUT ").length() - 1, 54)
  assert_eq(inventory.split("\nASSERTION ").length() - 1, 6)
  assert_eq(inventory.split("\nASSUMPTION ").length() - 1, 1)
  assert_eq(inventory.split("\nSOURCE ").length() - 1, 5)
  assert_true(content("sequential-production.sv").contains("always_ff"))
  assert_true(
    content("sequential-production.sv") != content("sequential-boolean.sv"),
  )
  assert_false(
    artifacts.any(artifact => {
      artifact.path() == "job.json" || artifact.path() == "source-set.lcfs"
    }),
  )
}
