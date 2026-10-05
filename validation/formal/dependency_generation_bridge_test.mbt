///|
test "sequential bridge preserves startup sampling and makes four checks conclusions not assumptions" {
  let artifacts = @formal.generate_dependency_generation_lemma_artifacts()
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing bridge artifact")
    }
    artifact.content()
  }
  let bridge = content("bridge.sv")
  assert_eq(bridge.split("(* anyseq *)").length() - 1, 14)
  assert_eq(bridge.split(": assume (").length() - 1, 1)
  assert_eq(bridge.split(": assert (").length() - 1, 4)
  assert_true(bridge.contains("logic lc_clock = 1'b0;"))
  assert_true(bridge.contains("always @($global_clock) lc_clock <= ~lc_clock;"))
  assert_true(
    bridge.contains(
      "lc_initial_joint_reset: assume ((lc_seen_edge || lc_reset) === 1'b1);",
    ),
  )
  assert_true(
    bridge.contains(
      "wire lc_generation_matches = lc_reset || lc_all_fields_equal;",
    ),
  )
  assert_true(bridge.contains("logic lc_previous_rising_reset = 1'b0;"))
  assert_true(bridge.contains("!lc_previous_rising_reset || lc_all_reset_zero"))
  assert_true(bridge.contains("wire [671:0] lc_current_pair"))
  assert_true(bridge.contains("logic [671:0] lc_previous_pair;"))
  assert_true(bridge.contains("(!lc_previous_clock && lc_clock)"))
  assert_true(bridge.contains("!lc_seen_edge || lc_all_fields_equal"))
  assert_true(bridge.contains(content("decoder.svfragment")))
  assert_true(bridge.contains("logic [31:0] lc_g_next = 32'd0;"))
  assert_true(bridge.contains("logic [31:0] lc_g_head = 32'd0;"))
  assert_false(bridge.contains("lc_g_authorized"))
  assert_false(bridge.contains("lc_owner_valid"))
  let inventory = content("bridge-inputs.txt")
  assert_eq(inventory.split("\nREGISTER ").length() - 1, 18)
  assert_eq(inventory.split("\nCUT node ").length() - 1, 14)
  assert_eq(inventory.split("\nSOURCE ").length() - 1, 4)
  assert_true(inventory.contains("335-bits-plus-clock-no-event-assumptions"))
  assert_true(content("sequential-production.sv").contains("always_ff"))
  assert_true(
    content("sequential-production.sv") != content("sequential-boolean.sv"),
  )
}
