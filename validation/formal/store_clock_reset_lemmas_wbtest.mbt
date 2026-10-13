///|
test "Store clock/reset lemmas bind exact complete original state without storage initialization" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let inventory = store_clock_reset_inventory(inputs.projection, inputs.emitted)
  assert_eq(inventory.registers.length(), 162)
  assert_eq(inventory.reset_checks.length(), 162)
  assert_eq(inventory.memory.length(), 26)
  assert_eq(inventory.memory_enables.length(), 12)
  assert_eq(inventory.register_bits, 2427)
  assert_eq(inventory.memory_bits, 1344)
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  let standalone = store_preservation_adapter(
    inputs.projection,
    inputs.emitted,
    "",
  )
  let body = store_clock_reset_without_bounds(standalone, inputs.memory_bounds)
  assert_eq(standalone.split(": assert (").count(), 13)
  assert_eq(body.split(": assert (").count(), 1)
  guard body.split("endmodule\n").to_array() is [prefix, suffix] else {
    fail("one complete original standalone module required")
  }
  for group in store_clock_reset_groups() {
    let source = store_clock_reset_source(inputs, group)
    assert_true(source.has_prefix(prefix))
    assert_true(source.has_suffix("endmodule\n" + suffix.to_owned()))
    assert_eq(source.split(": assert (").count(), 2)
    assert_eq(source.split(": assume (").count(), 2)
    assert_false(source.contains(": cover ("))
    assert_true(source.contains("(lc_seen_edge || lc_reset) === 1'b1"))
    assert_false(source.contains("lc_g_"))
    if group == "reset-ports" {
      assert_true(source.contains("!lc_reset || !("))
    } else if group.has_prefix("reset-") {
      assert_true(source.contains("!lc_seen_edge || !lc_previous_reset ||"))
    } else {
      assert_true(
        source.contains(
          "!lc_seen_global || (!lc_previous_clock && lc_clock) ||",
        ),
      )
    }
  }
}

///|
test "Store clock/reset collector produces standalone unbounded tasks without a new proof receipt" {
  let artifacts = store_clock_reset_artifacts()
  assert_eq(artifacts.map(artifact => artifact.path), [
    "reset-ports.sv", "reset-ports.sby", "reset-registers.sv", "reset-registers.sby",
    "reset-memory.sv", "reset-memory.sby", "clock-registers.sv", "clock-registers.sby",
    "clock-memory.sv", "clock-memory.sby",
  ])
  assert_eq(artifacts.length(), 10)
  for index, artifact in artifacts {
    if index % 2 == 1 {
      assert_true(
        artifact.content.contains(
          "mode prove\ndepth 20\ntimeout 600\nmulticlock on\n",
        ),
      )
      assert_true(artifact.content.contains("logger -werror .*\n"))
      assert_true(artifact.content.contains("smtbmc bitwuzla\n"))
      assert_false(artifact.content.contains("chformal"))
    }
  }
  if @env.get_env_var("LUNACHIP_PHASE6_STORE_CLOCK_RESET_INPUTS_PRINT") ==
    Some("1") {
    for artifact in artifacts {
      println(
        "STORE-CLOCK-RESET-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-STORE-CLOCK-RESET-ARTIFACT \{artifact.path}")
    }
  }
}
