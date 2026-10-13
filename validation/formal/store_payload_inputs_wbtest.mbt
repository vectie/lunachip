///|
test "Store payload selection preserves the complete original body and sole startup premise" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  assert_eq(
    sha256_hex(inputs.boolean_source),
    "a9c39c92ee7fdcb9cf1b6f551ce257414556bf336c69ebfe28e8378ff6335633",
  )
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  let body = store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, ""),
    inputs.memory_bounds,
  )
  let bindings = store_preservation_proof_bindings(
    inputs.projection,
    inputs.emitted,
  )
  for index, group in store_payload_groups() {
    let observer = bindings + store_payload_observer(group)
    let source = store_payload_source(inputs, group)
    assert_eq(source.split(observer).count(), 2)
    assert_eq(source.replace(old=observer, new=""), body)
    assert_eq(source.split(": assume (").count(), 2)
    assert_false(source.contains(": cover ("))
    assert_eq(
      source.split(": assert (").count() - 1,
      [6, 6, 7, 7, 22, 4, 29][index],
    )
    for label in inputs.memory_bounds {
      assert_false(source.contains(label + ": assert"))
    }
  }
  let storage = store_payload_slot_source(0, true)
  assert_false(storage.contains("lc_payload_word_0_0 <= 32'd0"))
  assert_false(storage.contains("lc_actual_c_0_0 <="))
  assert_true(
    storage.contains("lc_payload_read_word_0 <= lc_payload_selected_0"),
  )
  assert_true(
    store_payload_producer_source().contains("lc_production_3 : 32'd0"),
  )
  assert_false(
    store_payload_slot_source(0, false).contains("lc_payload_read_tracked_0"),
  )
}

///|
test "Store payload collector exposes independent pinned-policy input groups without inventing outcomes" {
  let artifacts = store_payload_artifacts()
  assert_eq(artifacts.length(), 15)
  for index, group in store_payload_groups() {
    assert_eq(artifacts[index * 2].path, group + ".sv")
    let config = artifacts[index * 2 + 1]
    assert_eq(config.path, group + ".sby")
    assert_true(
      config.content.contains(
        "mode prove\ndepth 20\ntimeout 600\nmulticlock on\n",
      ),
    )
    assert_true(config.content.contains("smtbmc bitwuzla\n"))
    assert_true(config.content.contains("logger -werror .*\n"))
    assert_false(config.content.contains("chformal"))
  }
  assert_true(
    artifacts[14].content.contains("no-SRAM-zero-no-arbitrary-read-payload"),
  )
  assert_true(
    artifacts[14].content.contains(
      "not-complete-generation-publication-coverage",
    ),
  )
  let composed = store_payload_composition_source()
  assert_true(
    composed.contains("lc_payload_origin_word <= lc_payload_pending_word"),
  )
  assert_false(composed.contains("lc_payload_origin_word <= lc_e_ResponseData"))
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_PAYLOAD_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "STORE-PAYLOAD-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-PAYLOAD-ARTIFACT \{artifact.path}")
    }
  }
}
