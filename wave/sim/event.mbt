///|
fn sim_compare_text(left : String, right : String) -> Int32 {
  let left_bytes = @utf8.encode(left)
  let right_bytes = @utf8.encode(right)
  let common = left_bytes.length().min(right_bytes.length())
  for index in 0..<common {
    let delta = left_bytes[index].to_int() - right_bytes[index].to_int()
    if delta != 0 {
      return delta
    }
  }
  left_bytes.length() - right_bytes.length()
}
