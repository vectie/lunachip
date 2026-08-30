///|
fn async_fifo_inventory_text(kind : AsyncFifoSynthesisKind) -> String raise {
  generate_async_fifo_synthesis_bundle(kind)
  .artifacts()
  .iter()
  .find_first(a => a.path == "async-fifo-role-inventory.json")
  .unwrap().content
}

///|
fn async_fifo_inventory_object(text : String) -> Map[String, Json] raise {
  guard @json.parse(text) is Object(fields) else {
    fail("role inventory must be a JSON object")
  }
  fields
}

///|
fn async_fifo_nested_object(
  fields : Map[String, Json],
  name : String,
) -> Map[String, Json] raise {
  guard fields.get(name) is Some(Object(nested)) else {
    fail("expected object field: \{name}")
  }
  nested
}

///|
fn async_fifo_has_exact_keys(
  fields : Map[String, Json],
  expected : Array[String],
) -> Bool {
  if fields.length() != expected.length() {
    return false
  }
  expected.all(key => fields.contains(key))
}

///|
test "asynchronous FIFO synthesis bundles are distinct and canonical" {
  for kind in async_fifo_synthesis_matrix() {
    let first = generate_async_fifo_synthesis_bundle(kind)
    let second = generate_async_fifo_synthesis_bundle(kind)
    assert_eq(first.artifacts(), second.artifacts())
    let shape = async_fifo_inventory_text(kind)
    ignore(async_fifo_inventory_object(shape))
    assert_true(shape.contains("\"fixture\": \"\{kind.id()}\""))
    assert_true(
      shape.contains(
        "\"schema_version\": \"lunachip.async-fifo-role-inventory/v2\"",
      ),
    )
    assert_true(
      shape.contains(
        "\"artifact_kind\": \"async-fifo-pre-map-expected-contract\"",
      ),
    )
    assert_true(shape.contains("\"depth\": \{kind.depth()}"))
    assert_true(shape.contains("\"address_width\": \{kind.address_width()}"))
    assert_true(
      shape.contains("\"pointer_width\": \{kind.address_width() + 1}"),
    )
    assert_true(shape.contains("\"synchronizer_stages\": \{kind.stages()}"))
    assert_true(
      shape.contains("\"kind\": \"canonical-ir-role-inventory-only\""),
    )
    assert_true(shape.contains("\"pre_map_typed_graph\": false"))
    assert_true(shape.contains("\"ram_mapping\": false"))
    assert_true(shape.contains("\"timing\": false"))
    assert_true(shape.contains("\"physical_cdc\": false"))
    assert_true(shape.contains("\"metastability\": false"))
    assert_true(shape.contains("\"four_state_equivalence\": false"))
    assert_false(first.artifacts().any(a => a.path.contains("shape")))
    assert_false(shape.contains("payload_widths"))
    assert_false(shape.contains("claim_boundary"))
    assert_false(shape.contains("pre_map_rtlil_topology"))
    assert_false(shape.contains("exact-async-fifo-pre-map-topology"))
  }
}

///|
test "FIFO role inventory names every private lane and pipeline stage" {
  let shape = async_fifo_inventory_text(AggregateDepth4Stages3)
  assert_true(
    shape.contains("{ \"index\": 0, \"memory\": \"lc_f0_l0\", \"width\": 13,"),
  )
  assert_true(
    shape.contains("{ \"index\": 1, \"memory\": \"lc_f0_l1\", \"width\": 3,"),
  )
  for role in ["source_payload", "raw_read", "visible_payload"] {
    assert_eq(shape.split("\"\{role}\"").length(), 3)
  }
  assert_eq(shape.split("read_gray_pipeline").length(), 2)
  assert_eq(shape.split("write_gray_pipeline").length(), 2)
}

///|
test "FIFO role inventory freezes typed domains handshakes and contract keys" {
  let shape = async_fifo_inventory_text(ScalarDepth4Stages2)
  let root = async_fifo_inventory_object(shape)
  assert_true(
    async_fifo_has_exact_keys(root, [
      "address_width", "artifact_kind", "depth", "destination_domain", "destination_ready",
      "destination_transfer", "destination_valid", "expected_contract", "fixture",
      "full", "full_next", "lanes", "nonempty", "nonempty_next", "pointer_width",
      "read_address", "read_binary", "read_binary_next", "read_gray", "read_gray_next",
      "read_gray_pipeline", "schema_version", "source_domain", "source_ready", "source_transfer",
      "source_valid", "synchronizer_stages", "top_module", "write_address", "write_binary",
      "write_binary_next", "write_gray", "write_gray_next", "write_gray_pipeline",
    ]),
  )
  for name in ["source_domain", "destination_domain"] {
    let domain = async_fifo_nested_object(root, name)
    assert_true(async_fifo_has_exact_keys(domain, ["clock", "edge", "reset"]))
    let reset = async_fifo_nested_object(domain, "reset")
    assert_true(
      async_fifo_has_exact_keys(reset, ["kind", "polarity", "signal", "value"]),
    )
    assert_eq(reset["kind"], Json::string("synchronous"))
    assert_eq(reset["polarity"], Json::string("high"))
    assert_eq(reset["value"], Json::string("zero"))
    assert_eq(domain["edge"], Json::string("positive"))
  }
  let contract = async_fifo_nested_object(root, "expected_contract")
  assert_true(
    async_fifo_has_exact_keys(contract, [
      "four_state_equivalence", "kind", "metastability", "physical_cdc", "pre_map_typed_graph",
      "ram_mapping", "timing",
    ]),
  )
}
