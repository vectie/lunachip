///|
// The conservative backend's mismatch/unknown loop causes explosive Vivado
// expansion. Standard logical equality has the same four-state truth table:
// a known mismatch wins; otherwise any unknown operand bit yields X.
// Normalize only helpers required by canonical Equal nodes, leaving the IR,
// arithmetic, registers, memories and general emitter unchanged.
fn native_equality(
  source : String,
  hardware : @ir.Module,
) -> String raise BoardError {
  guard source.contains(
      "// LunaChip conservative SystemVerilog-2017 backend v1\n",
    ) ||
    source.contains("// LunaChip conservative SystemVerilog-2017 backend v2\n") else {
    raise MissingMapping(
      "PRX100 equality normalization: unsupported RTL backend",
    )
  }
  let headers : Map[String, Int32] = Map([])
  for node in hardware.nodes() {
    if node.kind() is Equal(left, _) {
      guard hardware.node(left) is Some(operand) else {
        raise MissingMapping("PRX100 equality normalization: operand")
      }
      let width = operand.signal_type().width().bits()
      headers["  function automatic logic lc_fn_eq_w\{width}("] = width
    }
  }
  let counts : Map[String, Int32] = Map([])
  let lines = source.split("\n").map(line => line.to_owned()).to_array()
  let result : Array[String] = []
  for i = 0; i < lines.length(); {
    let line = lines[i]
    if line.has_prefix("  function automatic logic lc_fn_eq_w") {
      guard headers.get(line) is Some(width) && i + 3 < lines.length() else {
        raise MissingMapping("PRX100 equality normalization: helper header")
      }
      guard lines[i + 1] == "    input logic [\{width - 1}:0] a," &&
        lines[i + 2] == "    input logic [\{width - 1}:0] b" &&
        lines[i + 3] == "  );" else {
        raise MissingMapping("PRX100 equality normalization: helper signature")
      }
      let mut ending = i + 4
      while ending < lines.length() && lines[ending] != "  endfunction" {
        ending += 1
      }
      guard ending < lines.length() else {
        raise MissingMapping("PRX100 equality normalization: helper end")
      }
      for header in lines[i:i + 4] {
        result.push(header)
      }
      result.push("    lc_fn_eq_w\{width} = (a == b);")
      result.push("  endfunction")
      counts[line] = counts.get(line).unwrap_or(0) + 1
      continue ending + 1
    }
    result.push(line)
    continue i + 1
  }
  for header, _ in headers {
    guard counts.get(header) == Some(1) else {
      raise MissingMapping("PRX100 equality normalization: helper multiplicity")
    }
  }
  result.join("\n")
}
