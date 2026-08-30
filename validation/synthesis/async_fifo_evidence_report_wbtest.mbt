///|
fn evidence_test_audit(
  issues : Array[AsyncFifoPreMapIssue],
) -> AsyncFifoPreMapReport {
  {
    fixture: "async-fifo-test",
    top_module: "fifo_top",
    creator: "Yosys 0.68+1",
    checks: [
      "identity", "roles", "ports", "owned_state", "registers", "pipelines", "transfers",
      "binary_next", "gray_next", "full", "nonempty", "addresses", "memory_shape",
      "memory_write", "memory_read", "visible_payload", "dependency_cutsets", "crossing_fanout",
      "payload_barriers", "lane_isolation", "graph_closure",
    ],
    issues,
    sequential_bits: 26,
    memory_bits: 52,
  }
}

///|
test "final evidence pass binds all sources and promotes only structural claims" {
  let report = async_fifo_synthesis_evidence_from_audit(
    evidence_test_audit([]),
    "inventory",
    "pre-map-json",
    "pre-map-rtlil",
    "yosys-lock",
  )
  assert_true(report.passed())
  let json = report.to_canonical_json()
  assert_true(
    json.contains(
      "\"schema_version\": \"lunachip.async-fifo-synthesis-evidence/v1\"",
    ),
  )
  assert_true(json.contains("\"yosys_creator\": \"Yosys 0.68+1\""))
  assert_true(json.contains("\"sha256:\{sha256_hex("inventory")}\""))
  assert_true(json.contains("\"pre_map_typed_graph\":true"))
  assert_true(json.contains("\"two_state_role_equivalence\":true"))
  assert_true(json.contains("\"owned_state_exact\":true"))
  assert_true(json.contains("\"memory_topology\":true"))
  assert_true(json.contains("\"ram_mapping\":false"))
  assert_true(json.contains("\"timing\":false"))
  assert_true(json.contains("\"physical_cdc\":false"))
  assert_true(json.contains("\"metastability\":false"))
  assert_true(json.contains("\"four_state_equivalence\":false"))
  assert_true(json.contains("\"checks_total\":25"))
  assert_true(json.contains("\"checks_passed\":25"))
  assert_true(json.contains("\"issues\":0"))
  assert_true(json.contains("\"result\": \"pass\""))
  assert_eq(json, report.to_canonical_json())
}

///|
test "evidence input length is UTF-8 bytes" {
  let binding = async_fifo_evidence_binding("🌙")
  assert_eq(binding.bytes, 4)
  assert_true(binding.nonempty)
  assert_eq(binding.sha256, "sha256:\{sha256_hex("🌙")}")
}

///|
test "empty provenance fails closed without promoting structural claims" {
  let report = async_fifo_synthesis_evidence_from_audit(
    evidence_test_audit([]),
    "inventory",
    "pre-map-json",
    "pre-map-rtlil",
    "",
  )
  assert_false(report.passed())
  assert_true(
    report
    .issues()
    .any(issue => {
      issue.code() == "provenance.empty" && issue.role() == "yosys_lock"
    }),
  )
  let json = report.to_canonical_json()
  assert_true(json.contains("\"provenance.yosys_lock\",\"status\":\"fail\""))
  assert_true(json.contains("\"pre_map_typed_graph\":false"))
  assert_true(json.contains("\"memory_topology\":false"))
  assert_true(json.contains("\"result\": \"fail\""))
  assert_true(json.contains("\"pass\": false"))
}

///|
test "audit issues fail atomically and serialize in canonical order" {
  let report = async_fifo_synthesis_evidence_from_audit(
    evidence_test_audit([
      {
        code: "memory.write",
        role: "lane_0",
        expected: "one writer",
        observed: "two",
      },
      {
        code: "graph.bypass",
        role: "payload",
        expected: "barrier",
        observed: "direct",
      },
    ]),
    "inventory",
    "pre-map-json",
    "pre-map-rtlil",
    "yosys-lock",
  )
  assert_false(report.passed())
  let json = report.to_canonical_json()
  assert_true(
    json.find("graph.bypass").unwrap() < json.find("memory.write").unwrap(),
  )
  assert_true(json.contains("\"audit.identity\",\"status\":\"fail\""))
  assert_true(json.contains("\"checks_failed\":21"))
  assert_true(json.contains("\"issues\":2"))
  assert_true(json.contains("\"pre_map_typed_graph\":false"))
}
