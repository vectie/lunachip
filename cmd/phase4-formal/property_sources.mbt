///|
fn compiled_source_roster(
  job_text : String,
) -> (String, Array[(String, String)]) raise {
  guard @json.parse(job_text)
    is { "top_module": String(top), "sources": Array(sources), .. } else {
    fail("compiled formal source roster required")
  }
  let roster : Array[(String, String)] = []
  for source in sources {
    guard source is { "path": String(path), "sha256": String(hash), .. } else {
      fail("digest-bound compiled source required")
    }
    assert_true(safe_relative_path(path) && path.has_suffix(".sv"))
    assert_false(roster.any(previous => previous.0 == path))
    roster.push((path, hash))
  }
  assert_false(roster.is_empty())
  (top, roster)
}

///|
fn verify_compiled_property_sources(
  bundle : String,
  job_text : String,
  properties : @formal_core.FormalPropertyManifest,
) -> Unit raise {
  let (top, roster) = compiled_source_roster(job_text)
  let sources : Array[(String, String)] = []
  for (path, expected) in roster {
    let source = @fs.read_file_to_string(bundle + "/" + path)
    assert_eq(digest(path, source), expected)
    sources.push((path, source))
  }
  verify_property_placement(top, sources, properties)
}

///|
// Legacy predicates still require the wrapper label. The one newly supported
// child scope must be the actual lc_dut instance of the single compiled DUT
// module, not an uncompiled production artifact or a label moved to the wrapper.
fn verify_property_placement(
  top : String,
  sources : ArrayView[(String, String)],
  properties : @formal_core.FormalPropertyManifest,
) -> Unit raise {
  guard sources.filter(source => source.0 == "formal-harness.sv")
    is [(_, harness)] else {
    fail("one compiled formal harness required")
  }
  for property in properties.properties() {
    let label = property.stable_name() + ":"
    let occurrences = sources
      .iter()
      .fold(init=0, (count, source) => count + source.1.split(label).count() - 1)
    assert_eq(occurrences, 1)
    if property.predicate() is Named(path~, ..) && path == top + ".lc_dut" {
      assert_false(property.kind() is Assumption)
      guard sources.filter(source => source.0 == "formal-dut.sv") is [(_, dut)] else {
        fail("child property requires its compiled DUT source")
      }
      let headers = dut
        .split("\n")
        .filter(line => line.has_prefix("module "))
        .to_array()
      guard headers is [header] else {
        fail("one original DUT module required")
      }
      let declaration = header["module ".length():].to_owned()
      let identifier = declaration.split("(").to_array()[0].trim().to_owned()
      assert_false(
        identifier.is_empty() ||
        identifier.contains(" ") ||
        identifier.contains(";"),
      )
      assert_eq(harness.split(identifier + " lc_dut (").count() - 1, 1)
      let modules = dut.split("endmodule").to_array()
      assert_eq(modules.length(), 2)
      assert_eq(modules[0].split(label).count() - 1, 1)
      assert_eq(harness.split(label).count() - 1, 0)
    } else {
      assert_eq(harness.split(label).count() - 1, 1)
    }
  }
}
