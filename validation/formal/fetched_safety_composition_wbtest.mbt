///|
test "fetched safety view keeps every real state memory address and inverse component binding" {
  let sequential = fetched_transport_sequential()
  let source = sequential.probe.source
  let view = fetched_safety_view(sequential)
  assert_eq(
    (view.nodes(), view.domains(), view.memories(), view.metadata()),
    (source.nodes(), source.domains(), source.memories(), source.metadata()),
  )
  assert_eq(view.memories().length(), 10)
  assert_eq(
    view.outputs()[:source.outputs().length()].to_owned(),
    source.outputs().iter().to_array(),
  )
  let original_emitted = @rtl.emit_design(flux_tile_formal_design())
  let emitted = @rtl.emit_design(
    @ir.Design::single("FetchedSafetyCompositionView", view),
  )
  let original_plans = dependency_boolean_helper_plans(
    source,
    top_emitted_module(original_emitted).source(),
  )
  let actual_plans = dependency_boolean_helper_plans(
    view,
    top_emitted_module(emitted).source(),
  )
  assert_eq(
    actual_plans.map(plan => {
      (plan.function_name, plan.original, plan.replacement)
    }),
    original_plans.map(plan => {
      (plan.function_name, plan.original, plan.replacement)
    }),
  )
  assert_eq(actual_plans.length(), 20)
  for output in fetched_transport_proof_view(sequential).outputs() {
    guard view.outputs().filter(item => item.name() == output.name())
      is [actual] else {
      fail("one exact alias")
    }
    assert_eq(
      sequential.original_to_local[actual.driver().ordinal()],
      Some(output.driver()),
    )
  }
  // A deliberately broken inverse map must fail before any artifact is emitted.
  let mapping = sequential.original_to_local.iter().to_array()
  mapping[sequential.probe.roots[0].node.ordinal()] = None
  let changed : FetchedTransportSequential = {
    ..sequential,
    original_to_local: ReadOnlyArray::from_array(mapping),
  }
  try fetched_safety_view(changed) catch {
    _ => ()
  } noraise {
    _ => fail("omitted real state accepted")
  }
}

///|
test "whole fetched view preserves native X and high address rejection across later reset" {
  let sequential = fetched_transport_sequential()
  let hardware = sequential.probe.source
  let view = fetched_safety_view(sequential)
  let source = @sim.Simulator::prepare(hardware)
  let observed = @sim.Simulator::prepare(view)
  assert_true(
    hardware
    .nodes()
    .any(node => {
      node.kind() is MemoryRead(..) && !source.value(node.id()).is_fully_known()
    }),
  )
  for edge in 0..<16 {
    for node in hardware.nodes() {
      if node.kind() is Input(name) && name != "clock" {
        let value = match name {
          "reset" => if edge == 0 || edge == 8 { 1UL } else { 0UL }
          "config_valid" => if edge == 1 || edge == 9 { 1UL } else { 0UL }
          "config_base" => if edge < 8 { 0xffffffe0UL } else { 0UL }
          "config_origin" => 0xfffffffeUL
          "publish_valid" => if edge == 11 { 1UL } else { 0UL }
          "publish_producer" => 1UL
          "memory_request_ready" | "completion_ready" => 1UL
          _ => 0UL
        }
        records_put(source, name, node.signal_type().width().bits(), value)
        records_put(observed, name, node.signal_type().width().bits(), value)
      }
    }
    for _phase in 0..<2 {
      source.settle()
      observed.settle()
      for node in hardware.nodes() {
        assert_eq(source.value(node.id()), observed.value(node.id()))
      }
      for output in view.outputs() {
        assert_eq(source.value(output.driver()), observed.output(output.name()))
      }
      if _phase == 0 {
        source.rising_edge("clock")
        observed.rising_edge("clock")
      }
    }
    if edge == 3 {
      assert_eq(records_output(source, "configured"), 0UL)
      assert_eq(records_output(source, "memory_request_valid"), 0UL)
    }
    if edge == 11 {
      assert_eq(records_output(source, "configured"), 1UL)
    }
  }
}

///|
test "fetched safety collector keeps symbolic premises full width predicates and checked supports" {
  let artifacts = fetched_safety_artifacts()
  assert_eq(artifacts.map(item => item.path), [
    "fetched-safety-owner.sv", "fetched-safety-owner.sby", "fetched-safety-full.sv",
    "fetched-safety-full.sby", "proof-view.lcir", "proof-view.names", "composition-inventory.txt",
  ])
  let owner = artifacts[0].content
  let full = artifacts[2].content
  for (source, count) in [(owner, 22), (full, 25)] {
    assert_eq(source.split(": assume (").count(), 6)
    assert_eq(source.split("(* anyseq *)").count(), 13)
    assert_eq(source.split(": cover (").count(), 1)
    // The original emitter also retains its real memory bounds assertions.
    assert_eq(source.split(": assert (").count() - 1, count + 20)
    assert_true(source.contains(fetched_transport_supporting_source()))
    assert_false(source.contains("(* anyseq *) logic cut_n"))
    assert_false(source.contains("lc_fu_"))
    assert_true(source.contains("lc_fetched_descriptor_admission: assert"))
    assert_eq(source.split("lc_seen_edge <= 1'b1;").count(), 2)
    assert_eq(source.split("lc_public_seen_edge <= 1'b1;").count(), 2)
    assert_true(
      source.contains(
        "wire lc_initial_joint_reset = lc_public_seen_edge || lc_reset;",
      ),
    )
  }
  let (_, _, assertions, _) = flux_tile_property_export()
  for label in assertions {
    assert_eq(full.split(label + ": assert (").count(), 2)
  }
  assert_true(full.contains("wire [33:0] lc_checked_request_end"))
  assert_true(full.contains("{31'd0, lc_memory_request_bytes}"))
  assert_true(full.contains("lc_checked_request_end <= 34'd1024"))
  assert_false(owner.contains(assertions[0] + ": assert ("))
  assert_false(owner.contains(assertions[1] + ": assert ("))
  assert_false(owner.contains(assertions[3] + ": assert ("))
  assert_eq(artifacts[1].content, fetched_safety_config("fetched-safety-owner"))
  assert_eq(artifacts[3].content, fetched_safety_config("fetched-safety-full"))
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_SAFETY_INPUTS_PRINT") ==
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
