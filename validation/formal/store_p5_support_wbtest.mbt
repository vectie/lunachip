///|
test "Store p5 reuses exact original cursor progress terminal and held Done predicate" {
  let source = store_preservation_control_source()
  let checks : Array[String] = [
    "lc_good_ack_exact", "(lc_o_store_Progress == (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 32'd0 : (lc_pre_lc_e_StoreResponseGood ? lc_pre_lc_o_store_Progress + 32'd4 : lc_pre_lc_o_store_Progress)))",
    "(lc_o_store_Row == (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 13'd0 : ((lc_pre_lc_e_StoreResponseGood && lc_pre_last_store_column) ? lc_pre_lc_o_store_Row + 13'd1 : lc_pre_lc_o_store_Row)))",
    "(lc_o_store_Column == (lc_previous_reset || lc_pre_lc_e_StoreAccept ? 13'd0 : (lc_pre_lc_e_StoreResponseGood ? (lc_pre_last_store_column ? 13'd0 : lc_pre_lc_o_store_Column + 13'd1) : lc_pre_lc_o_store_Column)))",
    "(lc_o_store_Tag == (lc_previous_reset ? 32'd0 : (lc_pre_lc_e_StoreRequestAccept ? lc_pre_lc_o_store_Tag + 32'd1 : lc_pre_lc_o_store_Tag)))",
    "(lc_o_store_ExpectedTag == (lc_previous_reset ? 32'd0 : (lc_pre_lc_e_StoreRequestAccept ? lc_pre_lc_o_store_Tag : lc_pre_lc_o_store_ExpectedTag)))",
    "(lc_previous_reset || !lc_pre_lc_e_StoreTerminal || lc_o_store_State == 3'd4)",
    "(lc_previous_reset || lc_pre_lc_e_StoreTerminal || !lc_pre_lc_e_StoreResponseGood || lc_o_store_State == (lc_pre_last_store ? 3'd4 : 3'd1))",
    "(lc_previous_reset || lc_pre_lc_e_StoreTerminal || !lc_pre_lc_e_ReadAccept || lc_o_store_State == 3'd2)",
    "(lc_previous_reset || lc_pre_lc_e_StoreTerminal || !lc_pre_lc_e_StoreRequestAccept || lc_o_store_State == 3'd3)",
    "(lc_previous_reset || !lc_pre_lc_e_StoreTerminal || lc_o_store_Fault == (lc_pre_lc_e_StoreResponseProtocol ? 4'd10 : (lc_pre_lc_e_StoreResponseRemote ? 4'd9 : (lc_pre_lc_e_StoreInternalFault ? 4'd11 : 4'd15))))",
  ]
  let held_fields = [
    "Slot", "Id", "Rows", "Columns", "Base", "Stride", "Row", "Column", "Tag", "ExpectedTag",
    "Progress", "Fault", "FaultAddress",
  ]
  assert_eq(held_fields.length(), 13)
  for field in held_fields {
    checks.push(
      "(lc_previous_reset || lc_pre_lc_o_store_State != 3'd4 || lc_o_store_\{field} == lc_pre_lc_o_store_\{field})",
    )
  }
  assert_eq(checks.length(), 24)
  let predicate = "  wire lc_cursor_progress_and_terminal = !lc_seen_edge || (\{checks.join(" && ")});\n"
  assert_eq(source.split(predicate).count(), 2)
  assert_false(source.contains(": assume"))
  assert_false(source.contains(": assert"))
  // P5 uses the original widened last predicate. The unchanged UInt13 DUT
  // recurrence is related to it by jointly checked p4 active-cursor bounds;
  // do not narrow the original predicate or extend those bounds into Done.
  assert_true(
    source.contains(
      "wire lc_pre_last_store_column = {1'b0, lc_pre_lc_o_store_Column} + 14'd1 == {1'b0, lc_pre_lc_o_store_Columns};",
    ),
  )
  assert_true(
    source.contains(
      "&& ({1'b0, lc_pre_lc_o_store_Row} + 14'd1 == {1'b0, lc_pre_lc_o_store_Rows});",
    ),
  )
  let cursor = store_p4_cursor_source()
  assert_true(
    cursor.contains("lc_o_store_Column + 13'd1 == lc_o_store_Columns"),
  )
  assert_true(cursor.contains("lc_o_store_Row + 13'd1 == lc_o_store_Rows"))
  assert_true(cursor.contains("lc_p4_cursor_last_widened: assert"))
  assert_false(cursor.contains("lc_o_store_State == 3'd4"))
}

///|
test "Store p5 good ACK binds actual consumed bus response and original bridge identity" {
  let source = store_preservation_control_source()
  let good_ack =
    #|  wire lc_good_ack_exact = !lc_e_StoreResponseGood || (!lc_reset && lc_o_store_State == 3'd3
    #|    && lc_arb_state == 2'd2 && lc_arb_owner && lc_memory_response_valid && lc_memory_response_ready
    #|    && lc_memory_response_fault == 0 && lc_memory_response_tag == lc_arb_expected_tag
    #|    && lc_arb_local_tag == lc_o_store_ExpectedTag);
    #|
  assert_eq(source.split(good_ack).count(), 2)
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  assert_eq(
    sha256_hex(inputs.positive),
    "9925e74a3d60045fd21f5fd86733827e2267baeadbbe31f6cf8ab5f5ac494121",
  )
  assert_eq(inputs.positive.split(source).count(), 2)
  guard inputs.properties
    .properties()
    .filter(property => property.source_name() == "cursor_progress_and_terminal")
    is [property] else {
    fail("exactly one original named p5 property required")
  }
  assert_true(
    inputs.positive.contains(
      "\{property.stable_name()}: assert ((lc_cursor_progress_and_terminal) === 1'b1);",
    ),
  )
}
