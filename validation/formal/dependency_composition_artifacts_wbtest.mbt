///|
test "compute generation private inventory binds source and reference hashes" {
  let artifacts = generate_dependency_compute_generation_artifacts()
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing composition artifact")
    }
    artifact.content()
  }
  let inventory = content("bridge-inputs.txt")
  for artifact in artifacts {
    if artifact.path() != "bridge-inputs.txt" {
      assert_true(
        inventory.contains(
          "SOURCE \{artifact.path()} sha256 \{sha256_hex(artifact.content())}",
        ),
      )
    }
  }
  for
    (name, source) in [
      ("decoder", dependency_decode_source()),
      ("generation-compute", dependency_generation_compute_reference_source()),
      ("full-ghost", dependency_ghost_source()),
    ] {
    assert_true(
      inventory.contains("REFERENCE \{name} sha256 \{sha256_hex(source)}"),
    )
  }
  let fixture = @flux_tile.queued_concurrent_dependency_formal_fixture()
  let production = @ir_codec.serialize(
    @ir.Design::single("QueuedConcurrentDependencyPilot", fixture.hardware()),
  )
  assert_true(inventory.contains("PRODUCTION sha256 \{sha256_hex(production)}"))
}

///|
test "compute generation bridge has six conclusions and only the original reset premise" {
  let artifacts = generate_dependency_compute_generation_artifacts()
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing composition artifact")
    }
    artifact.content()
  }
  let bridge = content("bridge.sv")
  assert_eq(bridge.split("(* anyseq *)").length() - 1, 18)
  assert_eq(bridge.split(": assume (").length() - 1, 1)
  assert_eq(bridge.split(": assert (").length() - 1, 6)
  for
    label in [
      "lc_composition_relation", "lc_composition_reset_zero", "lc_composition_established",
      "lc_composition_nonrising_hold", "lc_inner_compute_preserves_saved_authorization",
      "lc_compute_terminal_ticket_matches_accepted_owner",
    ] {
    assert_eq(bridge.split(label + ": assert (").length() - 1, 1)
  }
  assert_true(bridge.contains("logic lc_clock = 1'b0;"))
  assert_true(bridge.contains("always @($global_clock) lc_clock <= ~lc_clock;"))
  assert_true(
    bridge.contains(
      "lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);",
    ),
  )
  assert_true(bridge.contains("wire [859:0] lc_current_pair"))
  assert_true(bridge.contains("logic [859:0] lc_previous_pair;"))
  assert_true(bridge.contains("!lc_previous_rising_reset || lc_all_reset_zero"))
  assert_true(bridge.contains("(!lc_previous_clock && lc_clock)"))
  assert_true(bridge.contains("!lc_seen_edge || lc_all_fields_equal"))
  assert_true(
    bridge.contains(
      "wire lc_composition_matches = lc_reset || lc_all_fields_equal;",
    ),
  )
  assert_true(
    bridge.contains("(lc_g_compute_owned == (lc_o_compute_state != 2'd0))"),
  )
  assert_true(
    bridge.contains("(lc_g_authorized == (lc_o_compute_state == 2'd1))"),
  )
  assert_true(bridge.contains("(lc_o_compute_ticket == lc_g_compute_ticket)"))
  assert_true(
    bridge.contains("(lc_o_compute_ticket == lc_g_authorized_ticket)"),
  )
  assert_true(bridge.contains(dependency_decode_source()))
  assert_true(bridge.contains(dependency_generation_compute_reference_source()))
  assert_false(bridge.contains("logic lc_g_load_owned"))
  assert_false(bridge.contains("logic lc_g_store_owned"))
  let negative = content("negative-inner.sv")
  let original = "  wire [12:0] lc_checked_inner_reduction = lc_o_compute_latched_reduction;\n"
  let changed = "  wire [12:0] lc_checked_inner_reduction = (lc_o_compute_latched_reduction ^ (lc_inner_accept ? 13'd1 : 13'd0));\n"
  assert_eq(bridge.split(original).length() - 1, 1)
  assert_eq(negative.split(changed).length() - 1, 1)
  assert_eq(negative.replace(old=changed, new=original), bridge)
}
