///|
test "Store p4 basis checks original generation eligibility without physical-history replacement" {
  let source = store_p4_basis_source()
  assert_eq(source.split(": assert (").count(), 13)
  assert_false(source.contains(": assume ("))
  assert_false(source.contains(": cover ("))
  assert_false(source.contains("lc_payload_"))
  assert_false(source.contains("lc_actual_c_"))
  assert_false(source.contains(" <= "))
  assert_true(
    source.contains("lc_expected_read_fault == lc_p4_actual_read_fault"),
  )
  assert_true(
    source.contains(
      "lc_indexed_read_address < 6'd4 && lc_read_written[lc_indexed_read_address[1:0]]",
    ),
  )
  assert_true(source.contains("lc_g_read_basis == (lc_g_read_fault == 2'd0)"))
  assert_true(
    source.contains(
      "lc_p4_saved_read_tracked && lc_p4_saved_read_word == lc_g_read_word",
    ),
  )
  assert_true(
    source.contains("lc_g_read_word == 32'd0 && lc_e_ResponseData == 32'd0"),
  )
  assert_true(
    source.contains(
      "lc_g_read_active && lc_g_read_basis && lc_e_StoreRequestValid",
    ),
  )
  assert_true(source.contains("lc_arb_data == lc_g_dma_word"))
  assert_true(source.contains("lc_memory_request_data == lc_g_dma_word"))
}
