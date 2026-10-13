///|
test "Store generation task preserves original production and source transitions" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  let observer = store_preservation_proof_bindings(
      inputs.projection,
      inputs.emitted,
    ) +
    store_generation_observer()
  let source = store_generation_source(inputs)
  let body = store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, ""),
    inputs.memory_bounds,
  )
  assert_eq(source.replace(old=observer, new=""), body)
  assert_eq(source.split(store_preservation_production_source()).count(), 2)
  assert_eq(source.split(": assume (").count(), 2)
  assert_eq(source.split(": assert (").count(), 31)
  assert_eq(source.split("logic lc_seen_edge = 1'b0;").count(), 2)
  assert_false(source.contains(": cover ("))
  assert_true(
    source.contains(
      "lc_store_generation_original_p3: assert (lc_produced_storage === 1'b1)",
    ),
  )
  assert_false(source.contains("lc_payload_written_"))
  assert_false(source.contains("lc_payload_origin_word"))
  for label in inputs.memory_bounds {
    assert_false(source.contains(label + ": assert"))
  }
}

///|
test "Store generation collector retains exact locked induction policy" {
  let artifacts = store_generation_artifacts()
  assert_eq(artifacts.length(), 3)
  assert_eq(artifacts[0].path, "payload-generation-storage.sv")
  assert_eq(artifacts[1].path, "payload-generation-storage.sby")
  assert_true(
    artifacts[1].content.contains(
      "mode prove\ndepth 20\ntimeout 600\nmulticlock on\n",
    ),
  )
  assert_true(artifacts[1].content.contains("smtbmc bitwuzla\n"))
  assert_true(artifacts[1].content.contains("logger -werror .*\n"))
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_GENERATION_INPUTS_PRINT") ==
    Some("1") {
    for artifact in artifacts {
      println(
        "STORE-GENERATION-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-GENERATION-ARTIFACT \{artifact.path}")
    }
  }
}
