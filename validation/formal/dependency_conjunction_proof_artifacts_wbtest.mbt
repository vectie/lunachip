///|
test "private dependency conjunction ten inputs bind complete source maps original sixteen properties and three negatives" {
  let artifacts = dependency_conjunction_proof_artifacts()
  assert_eq(artifacts, dependency_conjunction_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-failed-generation.sv", "negative-new-intent-priority.sv", "negative-inner-identity.sv",
    "properties.lcfp", "names.lcnm", "bridge-inputs.txt",
  ])
  let inputs = dependency_conjunction_proof_inputs(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
    @flux_tile.queued_concurrent_dependency_formal_fixture(),
  )
  let report = dependency_conjunction_sequential_report(inputs.sequential)
  let marker = "CANDIDATE-DEPENDENCY-CONJUNCTION not-accepted-projection-or-proof\n"
  guard artifacts[9].content.split(marker).to_array()
    is [inventory, report_tail] else {
    fail("complete original report missing")
  }
  assert_eq(marker + report_tail.to_owned(), report)
  assert_true(
    inventory.has_prefix(
      "SCOPE original-seven-dependency-conjunction-source-bound-supporting-inputs-not-proof-or-receipt\n",
    ),
  )
  assert_true(
    inventory.contains(
      "REVIEWED-INVENTORY sha256 442cb1ac95b10b5e4c8cd9983ca80c9e2b93bbf07e08588d21214ad92f9e1fa4\n",
    ),
  )
  assert_true(
    inventory.contains(
      "PROJECTED-IR sha256 26214abad606bbe414fa9a7186d47fc9d7766bae3481d38f7b5aaa5c636860cd\n",
    ),
  )
  assert_true(
    inventory.contains("PROJECTION-REPORT sha256 \{sha256_hex(report)}\n"),
  )
  assert_true(inventory.contains("total2226bits-no-zero-storage-premise"))
  assert_true(
    inventory.contains(
      "12-original-public-pins66-raw-foreign-registers-no-derived-control-or-observed-dependency-cut",
    ),
  )
  assert_eq(inventory.split("\nASSUMPTION ").count(), 5)
  assert_eq(inventory.split("\nASSERTION ").count(), 8)
  assert_eq(inventory.split("\nCOVER ").count(), 6)
  assert_eq(inventory.split("\nGLOBAL-ASSERTION ").count(), 2)
  assert_eq(inventory.split("\nMEMORY-ASSERTION ").count(), 9)
  assert_eq(inventory.split("\nREGISTER ").count(), 80)
  assert_eq(inventory.split("\nCUT ").count(), 79)
  assert_eq(inventory.split("\nMEMORY ").count(), 5)
  assert_eq(inventory.split("\nREAD-STATE ").count(), 5)
  assert_eq(inventory.split("\nNEGATIVE ").count(), 4)
  assert_eq(inventory.split("\nSOURCE ").count(), 10)
  for artifact in artifacts[:9] {
    assert_eq(
      inventory
      .split("SOURCE \{artifact.path} sha256 \{sha256_hex(artifact.content)}\n")
      .count(),
      2,
    )
  }
  assert_eq(
    artifacts[0].content,
    @ir_codec.serialize(
      @ir.Design::single(
        "DependencyConjunctionSequential",
        inputs.sequential.hardware,
      ),
    ),
  )
  assert_eq(artifacts[1].content, top_emitted_module(inputs.emitted).source())
  assert_eq(artifacts[2].content, inputs.boolean_source)
  assert_eq(artifacts[3].content, inputs.positive)
  for index in 0..<3 {
    assert_eq(artifacts[index + 4].content, inputs.negatives[index])
  }
  assert_eq(artifacts[7].content, inputs.properties.manifest())
  assert_eq(artifacts[8].content, inputs.emitted.manifest().to_canonical_text())
  let variants = [
    DependencyFormalFixture::NegativeFailedGeneration,
    NegativeNewIntentPriority,
    NegativeInnerIdentity,
  ]
  let failure_names = [
    "latest_writer_matches_independent_model", "new_intent_wins_matching_older_terminal",
    "inner_compute_preserves_saved_authorization",
  ]
  for index, variant in variants {
    let selected = dependency_expected_failure(
      variant,
      inputs.properties.property_manifest(),
    )
    guard inputs.properties
      .properties()
      .filter(property => property.stable_name() == selected)
      is [property] else {
      fail("negative original assertion missing")
    }
    assert_eq(property.source_name(), failure_names[index])
    assert_true(property.kind() is Assertion)
    assert_eq(
      inventory
      .split(
        "NEGATIVE \{artifacts[index + 4].path} selected-original-assertion \{selected}\n",
      )
      .count(),
      2,
    )
  }
  // Opt-in stdout collector only, never filesystem/evidence writes or jobs.
  if @env.get_env_var("LUNACHIP_PHASE6_DEPENDENCY_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "DEPENDENCY-CONJUNCTION-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-DEPENDENCY-CONJUNCTION-ARTIFACT \{artifact.path}")
    }
  }
}
