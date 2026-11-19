///|
fn mapped(
  e : @sv.EmittedDesign,
  name : String,
  kind : @sv.SymbolKind,
) -> String raise {
  for item in e.manifest().mappings() {
    if item.kind() == kind && item.source_name() == name {
      return item.identifier()
    }
  }
  fail("missing mapping " + name)
}

///|
// Exact target-only normalization previously qualified on PRX100. Portable
// canonical IR and conservative emitter remain unchanged and are retained.
fn normalize(source : String) -> String raise {
  let lines = source.split("\n").to_array()
  let out : Array[String] = []
  for i = 0; i < lines.length(); {
    let line = lines[i]
    if line.has_prefix("  function automatic logic lc_fn_eq_w") {
      for j = i; j < i + 4; j = j + 1 {
        out.push(lines[j].to_owned())
      }
      let name = line.split("logic ").to_array()[1].split("(").to_array()[0].to_owned()
      out.push("    " + name + " = (a == b);")
      let mut last = i + 4
      while last < lines.length() && lines[last] != "  endfunction" {
        last = last + 1
      }
      guard last < lines.length() else { fail("unterminated equality helper") }
      out.push("  endfunction")
      continue last + 1
    }
    out.push(
      if line.has_prefix("  input logic ") {
        "  input wire logic " + line[14:].to_owned()
      } else {
        line.to_owned()
      },
    )
    continue i + 1
  }
  out.join("\n")
}
