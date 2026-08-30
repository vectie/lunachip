///|
test "asynchronous FIFO synthesis bundles are distinct and canonical" {
  for kind in async_fifo_synthesis_matrix() {
    let first = generate_async_fifo_synthesis_bundle(kind)
    let second = generate_async_fifo_synthesis_bundle(kind)
    assert_eq(first.artifacts(), second.artifacts())
    let shape = first
      .artifacts()
      .iter()
      .find_first(a => a.path == "expected-async-fifo-shape.json")
      .unwrap().content
    assert_true(shape.contains("\"fixture\": \"\{kind.id()}\""))
    assert_true(shape.contains("\"depth\": \{kind.depth()}"))
    assert_true(shape.contains("\"synchronizer_stages\": \{kind.stages()}"))
    assert_true(shape.contains("\"pre_map_rtlil_connectivity\": true"))
    assert_true(shape.contains("\"ram_inference\": false"))
    assert_true(shape.contains("\"timing\": false"))
    assert_true(shape.contains("\"physical_cdc\": false"))
  }
}

///|
test "FIFO shape names every private lane and exact pipeline stage" {
  let aggregate = generate_async_fifo_synthesis_bundle(AggregateDepth4Stages3)
  let shape = aggregate
    .artifacts()
    .iter()
    .find_first(a => a.path == "expected-async-fifo-shape.json")
    .unwrap().content
  assert_true(shape.contains("\"payload_widths\": [13, 3]"))
  assert_true(shape.contains("\"lanes\": [\"lc_f0_l0\", \"lc_f0_l1\"]"))
  assert_eq(shape.split("read_gray_pipeline").length(), 2)
  assert_eq(shape.split("write_gray_pipeline").length(), 2)
}
