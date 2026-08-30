///|
test "toggle synthesis bundles are deterministic public-API designs" {
  for kind in @synthesis.toggle_synthesis_matrix() {
    let first = @synthesis.generate_toggle_synthesis_bundle(kind)
    let second = @synthesis.generate_toggle_synthesis_bundle(kind)
    assert_eq(first.kind(), kind)
    assert_eq(first.artifacts(), second.artifacts())
    assert_true(
      first.expected_shape_json().contains("\"fixture\": \"\{kind.id()}\""),
    )
    assert_true(
      first
      .expected_shape_json()
      .contains("\"synchronizer_stages\": \{kind.stage_count()}"),
    )
    let expected_state = kind.stage_count() * 2 +
      3 +
      kind.payload_leaf_count() * 2
    assert_true(
      first.expected_shape_json().contains("\"state_count\": \{expected_state}"),
    )
    guard first.design().top_module() is Some(hardware_module) else {
      fail("expected top module")
    }
    assert_eq(hardware_module.memories().length(), 0)
    guard hardware_module.cdc_primitives() is [ToggleHandshake(spec)] else {
      fail("expected one toggle handshake")
    }
    assert_eq(spec.request_stages().length(), kind.stage_count())
    assert_eq(spec.acknowledge_stages().length(), kind.stage_count())
    assert_eq(spec.held_payload().length(), kind.payload_leaf_count())
    assert_eq(spec.destination_payload().length(), kind.payload_leaf_count())
    assert_eq(
      hardware_module
      .nodes()
      .filter(node => node.kind() is Register(_))
      .length(),
      expected_state,
    )
  }
}
