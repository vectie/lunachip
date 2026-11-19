///|
// All original properties remain, specialized to the explicit larger owner.
// No assertion is removed, assumed, shortened or checked on a different DUT.
fn sixteen_row_properties(source : String) -> String raise {
  let mut result = source
  for
    (old, new) in [
      ("reg [7:0] f_beat=0;", "reg [8:0] f_beat=0;"),
      ("f_batch ? 252:", "f_batch ? 508:"),
      ("? 64:8", "? 128:8"),
      ("? 256:32", "? 512:32"),
      ("{25'b0,obs_issued_lines[5:3]}", "{24'b0,obs_issued_lines[6:3]}"),
      ("{19'b0,obs_line_index,3'b0}", "{18'b0,obs_line_index,3'b0}"),
    ] {
    assert_true(
      result.contains(old),
      msg="Required sixteen-row property input " + old,
    )
    result = result.replace_all(old~, new~)
  }
  result
}
