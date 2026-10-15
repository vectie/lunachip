///|
test "fetched DMA aliases follow actual wide encoders without changing nodes memory or prior artifacts" {
  let sequential = fetched_transport_sequential()
  let original = sequential.probe.source
  let view = fetched_dma_view(sequential)
  assert_eq(
    (view.nodes(), view.memories(), view.domains(), view.metadata()),
    (
      original.nodes(),
      original.memories(),
      original.domains(),
      original.metadata(),
    ),
  )
  let aliases = fetched_dma_roots(sequential)
  assert_eq(aliases.length(), 17)
  for binding in aliases {
    assert_eq(
      view
      .outputs()
      .filter(output => output.name() == binding.name)
      .map(output => (output.driver(), output.signal_type())),
      [(binding.node, binding.signal_type)],
    )
  }
  assert_eq(
    aliases
    .filter(binding => binding.name.has_suffix("address_full"))
    .map(binding => binding.signal_type.width().bits()),
    [64, 64],
  )
  assert_eq(
    aliases
    .filter(binding => {
      binding.name.has_suffix("_row") ||
      binding.name.has_suffix("_column") ||
      binding.name.has_suffix("_rows") ||
      binding.name.has_suffix("_columns")
    })
    .map(binding => binding.signal_type.width().bits()),
    Array::make(8, 13),
  )
  assert_eq(
    fetched_retirement_artifacts().map(item => sha256_hex(item.content)),
    [
      "306997f4ef92cd8df02eda09fbe7746de8ec92ae731059c68cd9d3d17440a61d", "62921a7277cee6ec88f5a96c78d826b4dbd3f0a9215b3a32409a6013333812d8",
      "ae2c2fde926f2b41ddff7866ecfd0bf981d3fa9443053a51e74c2555632cfea0", "b8420660f75371bc368e9d4b94d0ef7c0c0777da27c42767a63472bf45e0d3bd",
      "74ae8a7c839f31efe69a104094dede48de6cac230503e3b5c140c064d1e64cc8", "27553e96c7f85d0ff61f42f24f359061e40ebe93d8c6198f163378048811897c",
      "6af08cfedfdeb0aa7ab0872ac76845cdf601f19f80771b36553c682c55ce2a44",
    ],
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
}

///|
test "fetched DMA source retains all public assertions and only original public premises" {
  let artifacts = fetched_dma_artifacts()
  let source = artifacts[0].content
  assert_eq(source.split(": assert (").count() - 1, 91)
  assert_eq(source.split(": assume (").count() - 1, 5)
  assert_eq(source.split("(* anyseq *)").count() - 1, 12)
  assert_eq(source.split(": cover (").count() - 1, 0)
  for label in flux_tile_property_export().2 {
    assert_eq(source.split(label + ": assert (").count(), 2)
  }
  assert_true(source.contains("lc_checked_request_end <= 34'd1024"))
  assert_true(
    source.contains("lc_dma_storer_address_full") ||
    source.contains("composition_dma_storer_address_full"),
  )
  let support = fetched_dma_support()
  assert_false(support.contains("assume"))
  assert_false(support.contains("anyseq"))
  assert_eq(support.split(": assert (").count() - 1, 15)
  assert_true(
    support.contains("lc_dma_saved_word <= lc_dut_composition_dma_store_word"),
  )
  assert_true(
    support.contains(
      "lc_dma_saved_address <= lc_dut_composition_dma_storer_address_full",
    ),
  )
  assert_true(support.contains("lc_dma_loader_rows - 64'd1"))
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_DMA_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "FETCHED-SAFETY-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-FETCHED-SAFETY-ARTIFACT \{artifact.path}")
    }
  }
}
