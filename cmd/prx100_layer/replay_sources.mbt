///|
// Keep module filenames exact for Verilator's DECLFILENAME gate. Concatenating
// these files is byte-identical to the single physical core.sv given to CAD.
fn core_replay_sources(
  root : String,
  e : @sv.EmittedDesign,
  ports : ReadOnlyArray[@v.HarnessPort],
) -> String raise {
  let source = memory_style(normalize(optimized(e.source())))
  let pieces = source.split("`default_nettype none").to_array()
  assert_eq(pieces.length(), 4)
  assert_eq(pieces[0], "")
  let names = [
    e.modules()[0].filename(),
    memory_leaf(32768).module_name + ".sv",
    memory_leaf(32).module_name + ".sv",
  ]
  let contents : Array[String] = []
  for i, name in names {
    let text = "`default_nettype none" + pieces[i + 1].to_owned()
    save(root, name, text)
    contents.push(text)
  }
  assert_eq(contents.join(""), source)
  guard @json.parse(@v.harness_json(e, ports)) is Object(fields) else {
    fail("harness object")
  }
  fields["sources"] = @json.to_json(names)
  @json.to_json(fields).stringify(indent=2) + "\n"
}
