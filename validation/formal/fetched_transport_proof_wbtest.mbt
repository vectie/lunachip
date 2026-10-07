///|
test "fetched transport proof view adds five actual aliases without changing core state or cuts" {
  let sequential = fetched_transport_sequential()
  let view = fetched_transport_proof_view(sequential)
  let core = sequential.hardware
  assert_eq(
    (
      view.name(),
      view.nodes(),
      view.domains(),
      view.memories(),
      view.metadata(),
    ),
    (
      core.name(),
      core.nodes(),
      core.domains(),
      core.memories(),
      core.metadata(),
    ),
  )
  assert_eq(
    view.outputs()[:core.outputs().length()].to_owned(),
    core.outputs().iter().to_array(),
  )
  assert_eq(view.outputs().length(), core.outputs().length() + 5)
  let aliases = fetched_transport_proof_view_aliases(sequential)
  assert_eq(aliases.map(view_alias => view_alias.name), [
    "reader_valid", "reader_ready", "reader_address", "config_ready", "publish_ready",
  ])
  for view_alias in aliases {
    let mapped = dependency_generation_mapped(
      sequential.original_to_local,
      view_alias.node,
    )
    guard view
      .outputs()
      .filter(output => output.name() == "proof_" + view_alias.name)
      is [output] else {
      fail("missing original alias")
    }
    assert_eq(
      (output.driver(), output.signal_type()),
      (mapped, view_alias.signal_type),
    )
    assert_true(core.node(mapped) is Some(_))
  }
  let source = @sim.Simulator::prepare(sequential.probe.source)
  let projection = @sim.Simulator::prepare(view)
  for node in sequential.probe.source.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  // Actual reset/config/publication/reader grant/request/Wait transitions.
  // PRE inputs remain fixed through both commits; never clock source twice.
  for edge in 0..<12 {
    records_put(source, "reset", 1, if edge == 0 { 1UL } else { 0UL })
    records_put(source, "config_valid", 1, if edge == 1 { 1UL } else { 0UL })
    records_put(source, "publish_valid", 1, if edge == 3 { 1UL } else { 0UL })
    records_put(source, "publish_producer", 32, 1UL)
    records_put(source, "memory_request_ready", 1, 1UL)
    source.settle()
    fetched_transport_native_compare(sequential, source, projection)
    for view_alias in aliases {
      assert_eq(
        source.value(view_alias.node),
        projection.value(
          dependency_generation_mapped(
            sequential.original_to_local,
            view_alias.node,
          ),
        ),
      )
    }
    source.rising_edge("clock")
    projection.rising_edge("clock")
    source.settle()
    fetched_transport_native_compare(sequential, source, projection)
    for view_alias in aliases {
      assert_eq(
        source.value(view_alias.node),
        projection.value(
          dependency_generation_mapped(
            sequential.original_to_local,
            view_alias.node,
          ),
        ),
      )
    }
  }
}

///|
test "fetched transport proof histories preserve actual three client identity and independent byte ordinal" {
  let arbiter = fetched_transport_proof_arbiter_source()
  let reader = fetched_transport_proof_reader_source()
  let edges = fetched_transport_proof_edge_source(fetched_transport_probe())
  assert_true(
    arbiter.contains("logic [1:0] lc_saved_owner, lc_accepted_owner;"),
  )
  assert_true(
    arbiter.contains(
      "lc_i_loader_valid ? 2'd1 : (lc_i_storer_valid ? 2'd2 : 2'd0)",
    ),
  )
  assert_true(
    arbiter.contains(
      "lc_i_storer_valid ? 2'd2 : (lc_i_reader_valid ? 2'd0 : 2'd1)",
    ),
  )
  for role in ["reader", "loader", "storer"] {
    assert_true(arbiter.contains("lc_dut_\{role}_request_ready =="))
    assert_true(arbiter.contains("lc_dut_\{role}_response_valid =="))
  }
  assert_true(
    reader.contains(
      "lc_byte_shadow[lc_byte_count * 8 +: 8] <= lc_i_response_data[7:0]",
    ),
  )
  assert_true(reader.contains("lc_byte_count <= lc_byte_count + 6'd1"))
  assert_false(reader.contains("lc_byte_count <= lc_o_reader_cursor"))
  assert_false(reader.contains("lc_byte_shadow <= lc_raw_lanes"))
  assert_true(
    reader.contains("lc_dut_reader_response_good == lc_good_reader_byte"),
  )
  assert_true(
    reader.contains("lc_dut_reader_publication_ok == lc_publication_good"),
  )
  assert_true(
    edges.contains(
      "lc_pre_arbiter_owner == 2'd2 ? 2'd0 : lc_pre_arbiter_owner + 2'd1",
    ),
  )
  assert_true(
    edges.contains("lc_o_reader_state == lc_reader_next_state_expected"),
  )
  assert_false((arbiter + reader + edges).contains("assume"))
}

///|
test "fetched transport proof blocks unreviewed report and otherwise isolates one checked lane expression" {
  let sequential = fetched_transport_sequential()
  if fetched_transport_proof_report_pin().has_prefix("REVIEW_REQUIRED") ||
    fetched_transport_proof_ir_pin().has_prefix("REVIEW_REQUIRED") {
    try fetched_transport_proof_require(sequential) catch {
      InvalidFormalBundleIdentity(_) => ()
      other => fail("unexpected inventory guard: \{Repr(other)}")
    } noraise {
      _ => fail("unreviewed inventory exported")
    }
  } else {
    let design = @ir.Design::single(
      "FetchedTransportProofView",
      fetched_transport_proof_view(sequential),
    )
    let emitted = @rtl.emit_design(design)
    let positive = fetched_transport_proof_source(sequential, emitted)
    let negative = fetched_transport_proof_source(
      sequential,
      emitted,
      negative=true,
    )
    let original = "wire [255:0] lc_checked_lanes = lc_raw_lanes;"
    let changed = "wire [255:0] lc_checked_lanes = (lc_raw_lanes ^ (lc_genuine_complete_packet ? 256'd1 : 256'd0));"
    assert_eq(negative.split(changed).count(), 2)
    assert_eq(negative.replace(old=changed, new=original), positive)
    assert_eq(positive.split(": assume").count(), 2)
    assert_eq(positive.split(": assert").count(), 13)
    assert_eq(positive.split(": cover").count(), 2)
    assert_true(positive.contains("wire [665:0] lc_actual_pair"))
    assert_true(
      positive.contains(
        "lc_fetched_established: assert ((!lc_seen_edge || lc_raw_established)",
      ),
    )
    assert_false(positive.contains("assume (lc_raw_established"))
    assert_eq(fetched_transport_proof_assertions().length(), 12)
    if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_PROOF_INPUTS_PRINT") ==
      Some("1") {
      for artifact in fetched_transport_proof_artifacts() {
        println(
          "FETCHED-TRANSPORT-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
        )
        println(artifact.content)
        println("END-FETCHED-TRANSPORT-ARTIFACT \{artifact.path}")
      }
    }
  }
}
