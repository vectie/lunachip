///|
test "Store p4 cursor support preserves UInt13 recurrences and checks truncation" {
  let source = store_p4_cursor_source()
  assert_eq(source.split(": assert (").count(), 18)
  assert_false(source.contains(": assume"))
  assert_false(source.contains(": cover"))
  assert_true(source.contains("lc_o_store_Column + 13'd1"))
  assert_true(source.contains("lc_o_store_Column} + 14'd1"))
  assert_true(source.contains("lc_o_store_Row < lc_o_store_Rows"))
  assert_true(source.contains("lc_o_store_Column < lc_o_store_Columns"))
  assert_true(source.contains("lc_o_store_Row[3:0] < lc_p4_selected_rows"))
  assert_true(
    source.contains("lc_p4_actual_read_fault == lc_expected_read_fault"),
  )
  assert_true(source.contains("lc_p4_full_read_address < 26'd4"))
  assert_true(
    source.contains("{24'd0, lc_c_read_address_1} == lc_p4_full_read_address"),
  )
  assert_true(
    source.contains(
      "|| lc_pre_lc_e_StoreAccept || lc_o_store_Rows == lc_pre_lc_o_store_Rows",
    ),
  )
  assert_false(source.contains("lc_o_store_State == 3'd4"))
}
