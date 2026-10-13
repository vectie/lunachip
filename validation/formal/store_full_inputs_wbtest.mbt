///|
test "Store full selection preserves exact original conclusions and DUT" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  let support = store_full_checked_support()
  assert_eq(support.split(": assert (").count() - 1, 82)
  assert_false(support.contains(": assume ("))
  assert_false(support.contains("anyseq"))
  let bounds = store_bounds_support_source(inputs)
  assert_eq(bounds.split(": assert (").count() - 1, 8)
  assert_false(bounds.contains(": assume ("))
  assert_false(bounds.contains("anyseq"))
  for group in store_full_groups() {
    let selected = store_full_original_selected(inputs, group)
    let added = (if group == "store-memory-bounds" { "" } else { support }) +
      (if group == "store-memory-bounds" || group == "store-full-conjunction" {
        bounds
      } else {
        ""
      })
    let source = store_full_source(inputs, group)
    assert_eq(
      source.replace(old=added + "endmodule\n", new="endmodule\n"),
      selected,
    )
    assert_eq(source.split(": assume (").count(), 2)
    assert_false(source.contains(": cover ("))
    assert_eq(source.split(store_preservation_production_source()).count(), 2)
    assert_eq(source.split(store_preservation_control_source()).count(), 2)
    assert_eq(
      source.split(store_preservation_transfer_source(false)).count(),
      2,
    )
    let retention = store_preservation_retention_source(
      inputs.projection,
      inputs.emitted,
    )
    let selected_retention = if group == "store-p5-composition" {
      store_full_remove_statement(
        retention,
        inputs.global_assertions[0],
        "assert",
      )
    } else {
      retention
    }
    assert_eq(source.split(selected_retention).count(), 2)
    for label in inputs.memory_bounds {
      assert_eq(
        source.contains(label + ": assert"),
        group == "store-memory-bounds" || group == "store-full-conjunction",
      )
    }
    let expected_original = match group {
      "store-p5-composition" => 4
      "store-p6-composition" => 5
      "store-memory-bounds" => 13
      _ => 19
    }
    assert_eq(selected.split(": assert (").count() - 1, expected_original)
    assert_eq(
      source.split(": assert (").count() - 1,
      expected_original + added.split(": assert (").count() - 1,
    )
  }
  let full = store_full_original_selected(inputs, "store-full-conjunction")
  guard inputs.properties
    .properties()
    .filter(property => property.kind() is Cover)
    is [cover] else {
    fail("one original overlap cover required")
  }
  assert_eq(
    full,
    store_full_remove_statement(inputs.positive, cover.stable_name(), "cover"),
  )
  for property in inputs.properties.properties() {
    if property.kind() is Assertion {
      assert_true(
        full.contains(
          property.stable_name() + ": assert ((lc_" + property.source_name(),
        ),
      )
    }
  }
}

///|
test "Store full collector preserves exact locked task policy" {
  let artifacts = store_full_artifacts()
  assert_eq(artifacts.length(), 9)
  for group in store_full_groups() {
    guard artifacts.filter(artifact => artifact.path == group + ".sby")
      is [config] else {
      fail("one locked config per task required")
    }
    assert_true(
      config.content.contains(
        "mode prove\ndepth 20\ntimeout 600\nmulticlock on\n",
      ),
    )
    assert_true(config.content.contains("smtbmc bitwuzla\n"))
    assert_true(config.content.contains("logger -werror .*\n"))
  }
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_FULL_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "STORE-FULL-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-FULL-ARTIFACT \{artifact.path}")
    }
  }
}
