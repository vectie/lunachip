///|
test "Store lease lemmas select only conclusions over the unchanged original transition body" {
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
  for group in ["lease-update", "lease-exclusion", "pending-protection"] {
    let observer = bindings + store_lease_observer(group)
    let source = store_lease_source(inputs, group)
    assert_eq(source.split(observer).count(), 2)
    assert_eq(source.replace(old=observer, new=""), body)
    assert_eq(source.split(": assert (").count(), 5)
    assert_eq(source.split(": assume (").count(), 2)
    assert_eq(source.split(": cover (").count(), 1)
    assert_false(source.contains("lc_store_nonrising_hold"))
    for label in inputs.memory_bounds {
      assert_false(source.contains(label + ": assert"))
    }
    assert_eq(store_lease_observer(group).split(": assume (").count(), 2)
    assert_true(
      source.contains(
        "lc_store_lease_startup: assume ((lc_seen_edge || lc_reset) === 1'b1);",
      ),
    )
  }
  // The exact definition deliberately retains original modular four-bit math.
  assert_true(store_lease_update_source().contains("CaptureRow + 4'd1"))
  assert_false(store_lease_update_source().contains("5'd1"))
  assert_false(store_lease_exclusion_source().contains("!lc_seen_edge"))
  assert_false(store_lease_exclusion_source().contains("StoreTerminal"))
  assert_false(store_lease_pending_source().contains("ComputeAccept"))
}

///|
test "Store lease collector emits pinned-policy independent tasks without claiming an outcome" {
  let artifacts = store_lease_artifacts()
  assert_eq(artifacts.length(), 7)
  assert_eq(artifacts.map(artifact => artifact.path), [
    "lease-update.sv", "lease-update.sby", "lease-exclusion.sv", "lease-exclusion.sby",
    "pending-protection.sv", "pending-protection.sby", "lease-inputs.txt",
  ])
  for index in [1, 3, 5] {
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
    artifacts[6].content.contains(
      "twelve-original-memory-bound-assertions-removed-only",
    ),
  )
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_LEASE_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "STORE-LEASE-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-LEASE-ARTIFACT \{artifact.path}")
    }
  }
}
