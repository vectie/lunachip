///|
test "original monitor exporter returns six deterministic supporting inputs and unchanged controller" {
  let artifacts = @formal.generate_queue_monitor_proof_artifacts()
  assert_eq(artifacts, @formal.generate_queue_monitor_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path()), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-population.sv", "bridge-inputs.txt",
  ])
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing monitor proof artifact")
    }
    artifact.content()
  }
  let accepted_control = @formal.generate_queue_control_proof_artifacts()
  for
    path in [
      "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv",
    ] {
    guard accepted_control.filter(artifact => artifact.path() == path)
      is [artifact] else {
      fail("missing accepted controller input")
    }
    assert_eq(content(path), artifact.content())
  }
  let design = @ir_codec.parse(content("sequential.lcir"))
  guard design.top_module() is Some(hardware) else {
    fail("missing controller")
  }
  assert_eq(design.name(), "QueueControlSequential")
  let registers = hardware.nodes().filter(node => node.kind() is Register(_))
  assert_eq(registers.length(), 16)
  assert_eq(
    registers.fold(init=0, (sum, node) => {
      sum + node.signal_type().width().bits()
    }),
    37,
  )
  assert_eq(hardware.memories().length(), 0)
  assert_eq(hardware.outputs().length(), 54)
  assert_eq(
    hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    9,
  )
  let inventory = content("bridge-inputs.txt")
  assert_true(inventory.contains("not-proof-or-full-device-gate"))
  assert_true(
    inventory.contains(
      "original-monitor-16-registers-35-bits-total72-excluding-clock",
    ),
  )
  assert_true(
    inventory.contains(
      "no-relation-history-event-readiness-or-progress-premise",
    ),
  )
  assert_true(inventory.contains("not-current-reserve-XOR"))
  assert_true(
    inventory.contains(
      "no-engine-identity-packet-provenance-nested-memory-fairness-or-full-device-claim",
    ),
  )
  assert_eq(inventory.split("\nREGISTER ").length() - 1, 16)
  assert_eq(inventory.split("\nMONITOR-REGISTER ").length() - 1, 16)
  assert_eq(inventory.split("\nCUT ").length() - 1, 8)
  assert_eq(inventory.split("\nEVENT ").length() - 1, 38)
  assert_eq(inventory.split("\nASSERTION ").length() - 1, 3)
  assert_eq(inventory.split("\nASSUMPTION ").length() - 1, 1)
  assert_eq(inventory.split("\nSOURCE ").length() - 1, 5)
  assert_eq(inventory.split("\nMONITOR ").length() - 1, 2)
  for artifact in artifacts {
    if artifact.path() != "bridge-inputs.txt" {
      let digest = @crypto.bytes_to_hex_string(
        @crypto.sha256(@utf8.encode(artifact.content())),
      )
      assert_true(
        inventory.contains("SOURCE \{artifact.path()} sha256 \{digest}\n"),
      )
    }
  }
  assert_false(
    artifacts.any(artifact => {
      artifact.path() == "job.json" || artifact.path() == "source-set.lcfs"
    }),
  )
  let positive = content("bridge.sv")
  let negative = content("negative-population.sv")
  assert_true(positive.contains("module lc_queue_monitor_bridge;"))
  assert_eq(positive.split(": assert (").length() - 1, 3)
  assert_eq(negative.split(": assert (").length() - 1, 3)
  assert_eq(positive.split(": assume (").length() - 1, 1)
  assert_eq(negative.split(": assume (").length() - 1, 1)
}
