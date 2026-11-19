///|
test "engine ownership exporter preserves the exact sequential state and returns inputs only" {
  let artifacts = @formal.generate_queue_owner_proof_artifacts()
  assert_eq(artifacts, @formal.generate_queue_owner_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path()), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-engine-ticket.sv", "bridge-inputs.txt",
  ])
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing ownership proof input")
    }
    artifact.content()
  }
  let design = @ir_codec.parse(content("sequential.lcir"))
  assert_eq(design.name(), "QueueOwnerSequential")
  guard design.top_module() is Some(hardware) else {
    fail("missing ownership slice")
  }
  let registers = hardware.nodes().filter(node => node.kind() is Register(_))
  assert_eq(registers.length(), 30)
  assert_eq(
    registers.fold(init=0, (bits, node) => {
      bits + node.signal_type().width().bits()
    }),
    304,
  )
  assert_eq(hardware.nodes().length(), 1268)
  assert_eq(
    hardware.nodes().filter(node => node.kind() is Input(_)).length(),
    83,
  )
  assert_eq(hardware.outputs().length(), 89)
  assert_eq(hardware.memories().length(), 0)
  assert_eq(hardware.domains().length(), 1)
  let inventory = content("bridge-inputs.txt")
  assert_true(inventory.contains("not-proof-or-full-device-gate"))
  assert_true(
    inventory.contains(
      "startup-reset-only-no-ownership-readiness-history-fairness-or-payload-premise",
    ),
  )
  assert_true(
    inventory.contains(
      "no-packet-provenance-generation-lease-DMA-memory-payload-fairness-or-full-device-claim",
    ),
  )
  assert_true(
    inventory.contains(
      "Boolean-helper-equivalence-and-engine-execution-not-established-by-export",
    ),
  )
  assert_true(
    inventory.contains(
      "REVIEWED-INVENTORY sha256 ad6dc56cf01fc55a28eacc6be5dc16493f882b665e1d9570e6e737f9985b289a\n",
    ),
  )
  assert_true(
    inventory.contains(
      "PRODUCTION sha256 35d7ef4b198dfe5ef8227f328eb4479080105ad14c2a593e1a9561449a4f28bc\n",
    ),
  )
  assert_eq(inventory.split("\nREGISTER ").count() - 1, 30)
  assert_eq(inventory.split("\nCUT node ").count() - 1, 82)
  assert_eq(inventory.split("\nEVENT ").count() - 1, 118)
  assert_eq(inventory.split("\nASSERTION ").count() - 1, 9)
  assert_eq(inventory.split("\nASSUMPTION ").count() - 1, 1)
  assert_eq(inventory.split("\nSOURCE ").count() - 1, 5)
  assert_eq(inventory.split("\nROOT ").count() - 1, 30)
  assert_eq(inventory.split("\nCANDIDATE node ").count() - 1, 82)
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
  let positive = content("bridge.sv")
  let negative = content("negative-engine-ticket.sv")
  assert_true(positive.contains("module lc_queue_owner_bridge;"))
  assert_eq(positive.split(": assert (").count() - 1, 9)
  assert_eq(negative.split(": assert (").count() - 1, 9)
  assert_eq(positive.split(": assume (").count() - 1, 1)
  assert_eq(negative.split(": assume (").count() - 1, 1)
  for label in inventory.split("\nASSERTION ").drop(1) {
    let name = label.split("\n").next().unwrap()
    assert_true(positive.contains("\{name}: assert ("))
    assert_true(negative.contains("\{name}: assert ("))
  }
  assert_false(
    artifacts.any(artifact => {
      artifact.path().has_suffix(".lcfr") ||
      artifact.path().has_suffix(".lcfg") ||
      artifact.path() == "job.json" ||
      artifact.path() == "source-set.lcfs"
    }),
  )
  assert_true(content("sequential-production.sv").contains("always_ff"))
  assert_true(
    content("sequential-production.sv") != content("sequential-boolean.sv"),
  )
}
