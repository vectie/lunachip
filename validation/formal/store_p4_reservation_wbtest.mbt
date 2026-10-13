///|
test "Store p4 reservation support is assertion-only and old-PRE selected" {
  let source = store_p4_reservation_source()
  assert_eq(source.split(": assert (").count() - 1, 20)
  assert_false(source.contains(": assume ("))
  assert_false(source.contains("anyseq"))
  assert_false(source.contains("lc_e_ComputeRelease"))
  assert_false(source.contains("lc_e_StoreTerminal"))
  assert_false(source.contains("lc_e_StoreResponseGood"))
  assert_true(
    source.contains("lc_p4_pre_reserved = lc_pre_lc_o_store_State == 3'd1"),
  )
  assert_true(
    source.contains(
      "|| lc_pre_lc_o_store_State == 3'd2 || lc_pre_lc_o_store_State == 3'd3",
    ),
  )
  assert_false(source.contains("lc_pre_lc_o_store_State == 3'd4"))
  for slot in 0..<2 {
    assert_true(
      source.contains(
        "lc_p4_reservation_selected_write_excluded_\{slot}: assert",
      ),
    )
    assert_true(
      source.contains(
        "lc_p4_reservation_selected_metadata_hold_\{slot}: assert",
      ),
    )
    assert_true(source.contains("lc_pre_lc_o_store_Slot != 1'd\{slot}"))
    for field in ["valid", "rows", "columns"] {
      assert_true(
        source.contains(
          "lc_o_result_\{field}_\{slot} == lc_pre_lc_o_result_\{field}_\{slot}",
        ),
      )
    }
  }
}
