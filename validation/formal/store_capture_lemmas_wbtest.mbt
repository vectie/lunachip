///|
test "Store capture conclusions preserve original body cuts and startup premise" {
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
  let bindings = store_preservation_proof_bindings(
    inputs.projection,
    inputs.emitted,
  )
  let body = store_lease_select_bounds(
    store_preservation_adapter(inputs.projection, inputs.emitted, ""),
    inputs.memory_bounds,
  )
  for
    (group, count) in [
      ("capture-cursor", 3),
      ("capture-publication", 8),
      ("capture-safety", 14),
      ("capture-composition", 26),
    ] {
    let observer = bindings + store_capture_observer(group)
    let source = store_capture_source(inputs, group)
    assert_eq(source.split(observer).count(), 2)
    assert_eq(source.replace(old=observer, new=""), body)
    assert_eq(source.split(": assert (").count(), count + 1)
    assert_eq(source.split(": assume (").count(), 2)
    assert_eq(source.split(": cover (").count(), 1)
    for label in inputs.memory_bounds {
      assert_false(source.contains(label + ": assert"))
    }
    assert_true(
      source.contains(
        "lc_store_lease_startup: assume ((lc_seen_edge || lc_reset) === 1'b1);",
      ),
    )
  }
  assert_true(store_capture_cursor_source().contains("CaptureColumn + 4'd1"))
  assert_true(store_capture_safety_source().contains("CaptureColumn} + 5'd1"))
  assert_false(store_capture_safety_source().contains(": assume"))
  assert_false(store_capture_publication_source().contains(": assume"))
  assert_false(store_capture_safety_source().contains("lc_reset ||"))
}

///|
test "Store capture collector emits independently checked components and composition" {
  let artifacts = store_capture_artifacts()
  assert_eq(artifacts.length(), 9)
  assert_eq(artifacts.map(artifact => artifact.path), [
    "capture-cursor.sv", "capture-cursor.sby", "capture-publication.sv", "capture-publication.sby",
    "capture-safety.sv", "capture-safety.sby", "capture-composition.sv", "capture-composition.sby",
    "capture-inputs.txt",
  ])
  for index in [1, 3, 5, 7] {
    let config = artifacts[index].content
    assert_true(
      config.contains("mode prove\ndepth 20\ntimeout 600\nmulticlock on\n"),
    )
    assert_true(config.contains("smtbmc bitwuzla\n"))
    assert_true(config.contains("logger -werror .*\n"))
    assert_true(config.contains("write_rtlil /out/"))
    assert_false(config.contains("chformal"))
  }
  assert_true(
    artifacts[8].content.contains(
      "all-relations-assertions-no-internal-assumption",
    ),
  )
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_CAPTURE_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "STORE-CAPTURE-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-CAPTURE-ARTIFACT \{artifact.path}")
    }
  }
}
