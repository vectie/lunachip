///|
test "fetched q2 queue seam and retirement view preserve every original node memory and helper" {
  let sequential = fetched_transport_sequential()
  let original = sequential.probe.source
  let fixture = @flux_tile.ring_concurrent_queue_formal_fixture()
  assert_eq(fixture.hardware(), original)
  assert_eq(fixture.observations().length(), 102)
  let view = fetched_retirement_view(sequential)
  assert_eq(
    (view.nodes(), view.memories(), view.domains(), view.metadata()),
    (
      original.nodes(),
      original.memories(),
      original.domains(),
      original.metadata(),
    ),
  )
  let aliases = fetched_retirement_aliases(original)
  assert_eq(aliases.length(), 102)
  for binding in aliases {
    assert_eq(
      view
      .outputs()
      .filter(output => output.name() == binding.name)
      .map(output => (output.driver(), output.signal_type())),
      [(binding.node, binding.signal_type)],
    )
  }
  let baseline = @rtl.emit_design(flux_tile_formal_design())
  assert_eq(
    @rtl.emit_design(@ir.Design::single("FluxTileFormal", original)).modules()[0].source(),
    baseline.modules()[0].source(),
  )
  let emitted = @rtl.emit_design(
    @ir.Design::single("FetchedRetirementCompositionView", view),
  )
  let plans = design => {
    dependency_boolean_helper_plans(
      design,
      top_emitted_module(
        @rtl.emit_design(@ir.Design::single("helpers", design)),
      ).source(),
    ).map(plan => (plan.function_name, plan.original, plan.replacement))
  }
  assert_eq(plans(original), plans(view))
  assert_eq(plans(view).length(), 20)
  assert_eq(emitted.modules().length(), 1)
}

///|
test "fetched retirement source checks ownership and release without private premises or truncated addresses" {
  assert_eq(fetched_safety_artifacts().map(item => sha256_hex(item.content)), [
    "5f4084c6117789f3f78cabfe19ce487236cedf95351583f4b6cb665c2f6294ed", "8b998dbd447434b6341772793a7d687429c86f24b2f7cf240722011fff359edb",
    "314e955cccea30650a8bc1328b8b95a3e6a19f362c97c46e8cd77dc9b5457966", "4fef232adbba7de917ce92bebded4c32c33cb2d331edea0be119d554757e9252",
    "c4fd380edd70fdb92d78eeeecf7ac636683804d309722afec7c405cde7b62906", "0115335cdfe158f87ec89680a05ad22259f20aa97b0324b0c0e6c7b93dfae42b",
    "b8e0b2895ed63159c0736ce0baee1e6204a2648c0e0614dce30da6415444ed39",
  ])
  let artifacts = fetched_retirement_artifacts()
  let support = fetched_retirement_support()
  assert_false(support.contains("assume"))
  assert_false(support.contains("anyseq"))
  assert_true(support.contains("next_ticket - 32'd2"))
  assert_true(support.contains("retirement_read_pointer < 5'd2"))
  assert_eq(support.split(": assert (").count() - 1, 16)
  for index in [0, 2] {
    let source = artifacts[index].content
    assert_eq(source.split(": assume (").count() - 1, 5)
    assert_eq(source.split("(* anyseq *)").count() - 1, 12)
    assert_eq(source.split(": cover (").count() - 1, 0)
    assert_eq(
      source.split(": assert (").count() - 1,
      if index == 0 {
        64
      } else {
        66
      },
    )
    assert_true(source.contains("wire [33:0] lc_checked_request_end"))
    assert_true(source.contains("lc_checked_request_end <= 34'd1024"))
    assert_true(source.contains("lc_fr_held_completion: assert"))
    assert_true(source.contains("lc_fetched_core_success_shape: assert"))
    let (_, _, labels, _) = flux_tile_property_export()
    assert_true(source.contains(labels[3] + ": assert ("))
  }
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_RETIREMENT_INPUTS_PRINT") ==
    Some("1") {
    for artifact in artifacts {
      println(
        "FETCHED-SAFETY-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-FETCHED-SAFETY-ARTIFACT \{artifact.path}")
    }
  }
}
