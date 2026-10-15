///|
test "fetched dependency fixture and view preserve ordinary graph and prior DMA artifacts" {
  let sequential = fetched_transport_sequential()
  let original = sequential.probe.source
  let view = fetched_dependency_view(sequential)
  assert_eq(
    (view.nodes(), view.domains(), view.memories(), view.metadata()),
    (
      original.nodes(),
      original.domains(),
      original.memories(),
      original.metadata(),
    ),
  )
  assert_eq(fetched_dependency_aliases(original).length(), 48)
  assert_eq(
    @flux_tile.queued_concurrent_dependency_formal_fixture()
    .observations()
    .length(),
    48,
  )
  assert_eq(
    sha256_hex(@ir_codec.serialize(flux_tile_formal_design())),
    "d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79",
  )
  assert_eq(fetched_dma_artifacts().map(item => sha256_hex(item.content)), [
    "97ce49da0b5d6b6d9a3924e79f3576dc9f7f3fc922e54566f9ec148140fa7373", "cb6dcc9b26fa27302d74f62338013ba271d8f05aa1c544f5e239fe1606e3a70e",
    "fc99df4b954879b675dc12f6536798d15880f17625da4704f216abc961f2ca12", "c085132adea4ea90c77a8179a1e7cfc89a51646c3e1fa0e806923c485297036d",
    "cab6681f739fcfc382042fe114d10075d789eafbfe18b7b845c5f5fddb99207d",
  ])
  let plans = hardware => {
    dependency_boolean_helper_plans(
      hardware,
      top_emitted_module(
        @rtl.emit_design(@ir.Design::single("helpers", hardware)),
      ).source(),
    ).map(plan => (plan.function_name, plan.original, plan.replacement))
  }
  assert_eq(plans(original), plans(view))
  assert_eq(plans(view).length(), 20)
}

///|
test "fetched dependency uses original decoder and ghost without direct public assumptions" {
  let support = fetched_dependency_support()
  assert_true(support.contains(dependency_decode_source()))
  assert_true(support.contains(dependency_ghost_source()))
  assert_false(support.contains(": assume ("))
  assert_false(support.contains("anyseq"))
  assert_false(support.contains(": cover ("))
  assert_eq(support.split(": assert (").count() - 1, 13)
  assert_true(
    support.contains(
      "lc_fd_generation_established: assert ((!lc_seen_edge || (",
    ),
  )
  let artifacts = fetched_dependency_artifacts()
  let source = artifacts[0].content
  assert_eq(source.split(": assert (").count() - 1, 104)
  assert_eq(source.split(": assume (").count() - 1, 5)
  assert_eq(source.split("(* anyseq *)").count() - 1, 12)
  assert_eq(source.split(": cover (").count() - 1, 0)
  assert_true(source.contains("lc_checked_request_end <= 34'd1024"))
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_DEPENDENCY_INPUTS_PRINT") ==
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
