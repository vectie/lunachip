///|
test "Store p4 groups preserve original DUT production and transfer equations" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  let body = store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, ""),
    inputs.memory_bounds,
  )
  for group in store_p4_groups() {
    let observer = store_preservation_proof_bindings(
        inputs.projection,
        inputs.emitted,
      ) +
      store_p4_observer(group)
    let source = store_p4_source(inputs, group)
    assert_eq(source.replace(old=observer, new=""), body)
    assert_eq(source.split(store_preservation_production_source()).count(), 2)
    assert_eq(
      source.split(store_preservation_transfer_source(false)).count(),
      2,
    )
    assert_eq(source.split(": assume (").count(), 2)
    let expected = match group {
      "store-p4-reservation" => 54
      "store-p4-cursor" => 70
      "store-p4-generation-basis" => 83
      _ => 85
    }
    assert_eq(source.split(": assert (").count() - 1, expected)
    assert_eq(source.split("logic lc_seen_edge = 1'b0;").count(), 2)
    assert_false(source.contains(": cover ("))
    assert_false(source.contains("lc_payload_written_"))
    for label in inputs.memory_bounds {
      assert_false(source.contains(label + ": assert"))
    }
    assert_eq(
      source.contains(
        "lc_store_p4_original_p4: assert (lc_pending_and_dma_payload === 1'b1)",
      ),
      group == "store-p4-composition",
    )
  }
}

///|
test "Store p4 collector retains original conclusion and locked induction policy" {
  let artifacts = store_p4_artifacts()
  assert_eq(artifacts.length(), 9)
  for group in store_p4_groups() {
    guard artifacts.filter(artifact => artifact.path == group + ".sby")
      is [config] else {
      fail("one config per selected task required")
    }
    assert_true(
      config.content.contains(
        "mode prove\ndepth 20\ntimeout 600\nmulticlock on\n",
      ),
    )
    assert_true(config.content.contains("smtbmc bitwuzla\n"))
    assert_true(config.content.contains("logger -werror .*\n"))
  }
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_P4_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "STORE-P4-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-P4-ARTIFACT \{artifact.path}")
    }
  }
}
