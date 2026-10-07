///|
test "private Store preservation input artifacts are deterministic source-bound and not a receipt" {
  let artifacts = store_preservation_proof_artifacts()
  assert_eq(artifacts, store_preservation_proof_artifacts())
  assert_eq(artifacts.map(artifact => artifact.path), [
    "sequential.lcir", "sequential-production.sv", "sequential-boolean.sv", "bridge.sv",
    "negative-pending-word.sv", "properties.lcfp", "names.lcnm", "bridge-inputs.txt",
  ])
  let fixture = @flux_tile.queued_concurrent_store_preservation_fixture()
  let inputs = store_preservation_proof_inputs(fixture)
  let projection_report = store_storage_projection_report(inputs.projection)
  guard artifacts[7].content.split("STORE-STORAGE-PROJECTION 1\n").to_array()
    is [inventory, report_tail] else {
    fail("one complete nested original Store projection report required")
  }
  assert_eq(
    "STORE-STORAGE-PROJECTION 1\n" + report_tail.to_owned(),
    projection_report,
  )
  assert_true(
    inventory.has_prefix(
      "SCOPE binary-original-Store-data-control-supporting-inputs-not-proof-or-receipt\n",
    ),
  )
  assert_true(inventory.contains("TOP \{inputs.top_identifier}\n"))
  assert_true(
    inventory.contains(
      "PROJECTION-REPORT sha256 \{sha256_hex(projection_report)}\n",
    ),
  )
  assert_true(
    inventory.contains(
      "PROJECTED-IR sha256 \{sha256_hex(artifacts[0].content)}\n",
    ),
  )
  assert_true(inventory.contains("no-other-foreign-state-or-control-cuts"))
  assert_true(inventory.contains("no-zero-storage-premise"))
  assert_true(
    inventory.contains(
      "no-numeric-MatMul-liveness-fairness-public-ordinal-retirement-or-full-device-proof",
    ),
  )
  assert_true(
    inventory.contains(
      "successful2x2-rectangle-engine-completion-not-public-ordinal-retirement",
    ),
  )
  assert_true(
    inventory.contains(
      "QUALIFICATION Boolean-helper-equivalence-prepared-model-review-and-engine-execution-pending\n",
    ),
  )
  assert_eq(inventory.split("\nASSUMPTION ").count(), 2)
  assert_eq(inventory.split("\nASSERTION ").count(), 7)
  assert_eq(inventory.split("\nCOVER ").count(), 2)
  assert_eq(inventory.split("\nGLOBAL-ASSERTION ").count(), 2)
  assert_eq(inventory.split("\nMEMORY-ASSERTION ").count(), 13)
  assert_eq(inventory.split("\nCUT ").count(), 5)
  assert_eq(inventory.split("\nREGISTER ").count(), 163)
  assert_eq(inventory.split("\nREAD-STATE ").count(), 7)
  assert_eq(inventory.split("\nMEMORY ").count(), 7)
  assert_eq(inventory.split("\nSOURCE ").count(), 8)
  let definitions = [
    ("startup_reset", "ASSUMPTION"),
    ("reservation_exclusion", "ASSERTION"),
    ("capture_publication_and_lease", "ASSERTION"),
    ("produced_storage", "ASSERTION"),
    ("pending_and_dma_payload", "ASSERTION"),
    ("cursor_progress_and_terminal", "ASSERTION"),
    ("reset_establishment", "ASSERTION"),
    ("coherent_store_overlap", "COVER"),
  ]
  assert_eq(inputs.properties.properties().length(), definitions.length())
  for index, definition in definitions {
    let property = inputs.properties.properties()[index]
    let (name, kind) = definition
    assert_eq(property.source_name(), name)
    assert_true(
      inventory.contains("\{kind} \{property.stable_name()} source \{name}\n"),
    )
  }
  for label in inputs.memory_bounds {
    assert_eq(inventory.split("MEMORY-ASSERTION \{label}\n").count(), 2)
    assert_eq(artifacts[3].content.split(label + ": assert").count(), 2)
    assert_eq(artifacts[4].content.split(label + ": assert").count(), 2)
  }
  for artifact in artifacts[:7] {
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
      @ir.Design::single("StoreStorageProjection", inputs.projection.hardware),
    ),
  )
  assert_eq(artifacts[1].content, top_emitted_module(inputs.emitted).source())
  assert_eq(artifacts[2].content, inputs.boolean_source)
  assert_eq(artifacts[3].content, inputs.positive)
  assert_eq(artifacts[4].content, inputs.negative)
  assert_eq(artifacts[5].content, inputs.properties.manifest())
  assert_eq(artifacts[6].content, inputs.emitted.manifest().to_canonical_text())
  assert_eq(
    artifacts[4].content.replace(
      old="(lc_e_ResponseData ^ (lc_genuine_held_overlap ? 32'd1 : 32'd0))",
      new="lc_e_ResponseData",
    ),
    artifacts[3].content,
  )
  // Opt-in collector is stdout only. Ordinary tests neither print large source
  // bundles nor write evidence/artifacts; root owns retention and engine jobs.
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "STORE-PRESERVATION-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-PRESERVATION-ARTIFACT \{artifact.path}")
    }
  }
}
