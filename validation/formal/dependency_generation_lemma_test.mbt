///|
test "generation lemma exports separate free prestates and exact proof inputs" {
  let artifacts = @formal.generate_dependency_generation_lemma_artifacts()
  assert_eq(artifacts, @formal.generate_dependency_generation_lemma_artifacts())
  assert_eq(artifacts.length(), 13)
  fn content(path : String) -> String raise {
    guard artifacts.filter(artifact => artifact.path() == path) is [artifact] else {
      fail("missing lemma artifact")
    }
    artifact.content()
  }
  let lemma = content("lemma.sv")
  assert_eq(lemma.split("input wire ").count() - 1, 50)
  assert_eq(lemma.split("output wire ").count() - 1, 5)
  assert_true(lemma.contains("assign lc_g_next = ghost_pre_next_ticket;"))
  assert_true(lemma.contains("assign step_obligation = lc_reset || !pre_equal"))
  assert_true(
    lemma.contains(
      "|| (decoder_equal && post_equal && rejection_equal && halted_equal);",
    ),
  )
  assert_true(lemma.contains("dut_decoder_syntax_fault == lc_raw_syntax_fault"))
  assert_true(lemma.contains("dut_decoder_source_0 == lc_raw_source0"))
  assert_true(lemma.contains("dut_decoder_source_1 == lc_raw_source1"))
  assert_true(
    lemma.contains(
      "(!lc_raw_syntax_ok || (dut_decoder_is_writer == lc_raw_is_writer",
    ),
  )
  assert_true(lemma.contains("dut_decoder_writer_slot == lc_raw_writer_slot"))
  assert_true(lemma.contains("dut_decoder_unused_ok == lc_raw_unused_ok"))
  assert_true(
    lemma.contains("dut_decoder_dimensions_ok == lc_raw_dimensions_ok"),
  )
  assert_true(
    lemma.contains(
      "assign base_obligation = !lc_reset || (post_equal && reset_zero && halted_equal);",
    ),
  )
  assert_true(lemma.contains("lc_g_ticket[0] != lc_g_next"))
  assert_true(
    lemma.contains(
      "lc_g_expected_local_fault == 4'd4 || lc_g_expected_local_fault == 4'd5",
    ),
  )
  assert_true(lemma.contains("assign negated_control = !step_obligation;"))
  assert_true(lemma.contains(content("decoder.svfragment")))
  assert_true(lemma.contains(content("reference.svfragment")))
  assert_false(lemma.contains("assume("))
  assert_false(lemma.contains("always_ff"))
  assert_false(lemma.contains("$global_clock"))
  assert_false(lemma.contains("lc_g_had_success"))
  assert_false(lemma.contains("lc_g_authorized"))
  let inventory = content("inputs.txt")
  assert_eq(inventory.split("\nCUT node ").count() - 1, 32)
  assert_eq(inventory.split("\nDECODER ").count() - 1, 7)
  assert_eq(inventory.split("\nSOURCE ").count() - 1, 7)
  let transfer = content("transfer.lcir")
  let original = content("production.lcir")
  assert_true(transfer != original)
  assert_true(
    content("transfer-production.sv") != content("transfer-boolean.sv"),
  )
}
