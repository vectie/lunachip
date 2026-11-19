///|
fn optimized(source : String) -> String raise {
  let lines = source.split("\n").to_array()
  let result : Array[String] = []
  for i = 0; i < lines.length(); {
    let line = lines[i]
    if line.has_prefix("  function automatic logic ") && line.contains("lc_fn_") {
      let name = line.split("(").to_array()[0]
        .split(" ")
        .to_array()
        .last()
        .unwrap()
        .to_owned()
      let expression = if name.has_prefix("lc_fn_eq_") {
        "(a == b)"
      } else if name.has_prefix("lc_fn_add_") {
        "(a + b)"
      } else if name.has_prefix("lc_fn_sub_") {
        "(a - b)"
      } else if name.has_prefix("lc_fn_lt_s_") {
        "($signed(a) < $signed(b))"
      } else if name.has_prefix("lc_fn_lt_u_") {
        "(a < b)"
      } else {
        abort("unrecognized synthesis helper " + name)
      }
      for j in i..<(i + 4) {
        result.push(lines[j].to_owned())
      }
      result.push("    " + name + " = " + expression + ";")
      let mut end = i + 4
      while end < lines.length() && lines[end] != "  endfunction" {
        end += 1
      }
      assert_true(end < lines.length())
      result.push("  endfunction")
      continue end + 1
    }
    result.push(line.to_owned())
    continue i + 1
  }
  result.join("\n")
}
