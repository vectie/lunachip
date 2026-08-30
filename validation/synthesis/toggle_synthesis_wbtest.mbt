///|
test "toggle synthesis expected state binds every register exactly once" {
  for kind in toggle_synthesis_matrix() {
    let bundle = generate_toggle_synthesis_bundle(kind)
    let manifest = bundle.expected_shape_json()
    guard bundle.design().top_module() is Some(hardware_module) else {
      fail("expected top module")
    }
    for node in hardware_module.nodes() {
      if node.kind() is Register(_) {
        let identifier = emitted_identifier(
          bundle.emitted(),
          Node,
          node.id().ordinal(),
        )
        assert_eq(manifest.split(identifier).length(), 2)
      }
    }
  }
}
