///|
// The fixed eight-row profile widens existing counters and address extent;
// assertions retain the same environment and 128-frame window. Fail closed
// if the original checked expressions change before this specialization.
fn eight_row_properties(source : String) -> String raise {
  let mut result = source
  for
    (old, new) in [
      ("reg [6:0] f_beat=0;", "reg [7:0] f_beat=0;"),
      ("f_batch ? 124:", "f_batch ? 252:"),
      ("? 32:8", "? 64:8"),
      ("? 128:32", "? 256:32"),
      ("{26'b0,obs_issued_lines[4:3]}", "{25'b0,obs_issued_lines[5:3]}"),
      ("{20'b0,obs_line_index,3'b0}", "{19'b0,obs_line_index,3'b0}"),
    ] {
    assert_true(
      result.contains(old),
      msg="Required eight-row property input " + old,
    )
    result = result.replace_all(old~, new~)
  }
  result
}
