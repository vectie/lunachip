///|
test "queue retirement record exports preserve old IDs and isolate held payload sensitivity" {
  // Export expectations are source contracts, not executed proof results.
  let positive = @formal.generate_queue_formal_bundle(RetirementRecords)
  let negative = @formal.generate_queue_formal_bundle(NegativeHeldPayload)
  let old = @formal.generate_queue_formal_bundle(Conservation)
  assert_eq(positive.fixture().id(), "phase6-queue-retirement-records")
  assert_eq(negative.fixture().id(), "phase6-queue-negative-held-payload")
  assert_eq(
    @formal.standard_queue_formal_bundles().map(bundle => bundle.fixture().id()),
    [
      "phase6-queue-conservation", "phase6-queue-negative-population", "phase6-queue-retirement-records",
      "phase6-queue-negative-held-payload", "phase6-queue-packet-provenance", "phase6-queue-negative-packet-provenance",
    ],
  )
  for bundle in [positive, negative] {
    assert_eq(bundle, @formal.generate_queue_formal_bundle(bundle.fixture()))
    assert_eq(
      @formal.QueueFormalFixture::from_id(bundle.fixture().id()),
      Some(bundle.fixture()),
    )
    assert_eq(
      bundle.artifacts().length(),
      if bundle.fixture() is RetirementRecords {
        11
      } else {
        9
      },
    )
    for index, artifact in bundle.artifacts() {
      for prior in bundle.artifacts()[0:index] {
        assert_true(artifact.path() != prior.path())
      }
    }
    assert_eq(
      @formal.regenerate_formal_artifacts(
        queue_formal_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts(),
    )
    for family in ["flux-tile-dependency", "flux-tile-public-transport"] {
      try
        @formal.regenerate_formal_artifacts(
          "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY \{family}\nFIXTURE \{bundle.fixture().id()}\n",
        )
      catch {
        @formal.InvalidFormalBundleIdentity(_) => ()
        _ => fail("unexpected retirement-record cross-family error")
      } noraise {
        _ => fail("another family accepted a retirement-record fixture")
      }
    }
  }
  let properties = @formal_core.parse_formal_property_manifest(
    queue_formal_artifact(positive, "properties.lcfp"),
  )
  let old_properties = @formal_core.parse_formal_property_manifest(
    queue_formal_artifact(old, "properties.lcfp"),
  )
  assert_eq(properties.properties().length(), 12)
  assert_eq(old_properties.properties().length(), 8)
  for index in 0..<8 {
    assert_eq(
      properties.properties()[index],
      old_properties.properties()[index],
    )
  }
  assert_eq(properties.properties().map(item => item.name()), [
    "initial_joint_reset", "host_descriptor_stable_until_accept", "host_response_stable_until_accept",
    "host_response_flushed_during_reset", "lane_atomicity_and_response", "packet_population_conserved",
    "retirement_event_ownership", "reachable_full_refill_capture", "terminal_entry_immutable",
    "oldest_terminal_selected", "held_completion_immutable", "reachable_held_oldest_younger_collector",
  ])
  for index, item in properties.properties() {
    assert_eq(
      item.kind(),
      if index < 4 {
        Assumption
      } else if index == 7 || index == 11 {
        Cover
      } else {
        Assertion
      },
    )
    assert_eq(item.domain().point(), PreEdge)
    assert_eq(
      item.domain().clock(),
      @property.PropertySignal::named("lc_formal_queue_top", "clock"),
    )
    assert_eq(
      item.predicate(),
      @property.PropertySignal::named("lc_formal_queue_top", item.name()),
    )
  }
  let labels = properties.properties().map(item => item.stable_name())
  assert_eq(positive.tasks().length(), 2)
  assert_eq(negative.tasks().length(), 1)
  assert_eq(positive.tasks()[0].name(), "phase6-queue-retirement-records-bmc")
  assert_eq(
    positive.tasks()[1].name(),
    "phase6-queue-retirement-records-cover-held-younger-collector",
  )
  assert_eq(
    negative.tasks()[0].name(),
    "phase6-queue-negative-held-payload-bmc",
  )
  assert_eq(positive.expected_failure(), "none")
  assert_eq(negative.expected_failure(), labels[10])
  queue_formal_check_task(
    positive,
    positive.tasks()[0],
    properties,
    // Canonical task labels sort lexically, so p10 precedes p4.
    [labels[10], labels[4], labels[5], labels[6], labels[8], labels[9]],
    cover=false,
    negative=false,
  )
  queue_formal_check_task(
    positive,
    positive.tasks()[1],
    properties,
    [labels[11]],
    cover=true,
    negative=false,
  )
  queue_formal_check_task(
    negative,
    negative.tasks()[0],
    properties,
    [labels[10]],
    cover=false,
    negative=true,
  )
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let design = @ir.Design::single(
    "QueuedConcurrentQueueConservationPilot",
    fixture.hardware(),
  )
  let canonical = @ir_codec.serialize(design)
  assert_eq(queue_formal_artifact(positive, "design.lcir"), canonical)
  assert_eq(@ir_codec.serialize(@ir_codec.parse(canonical)), canonical)
  let emitted = @rtl.emit_design(design)
  let production = emitted.modules()[0]
  let production_path = "production-" + production.filename()
  assert_eq(
    queue_formal_artifact(positive, production_path),
    production.source(),
  )
  for
    path in ["design.lcir", production_path, "formal-dut.sv", "properties.lcfp"] {
    assert_eq(
      queue_formal_artifact(positive, path),
      queue_formal_artifact(negative, path),
    )
  }
  for path in ["design.lcir", production_path, "formal-dut.sv"] {
    assert_eq(
      queue_formal_artifact(positive, path),
      queue_formal_artifact(old, path),
    )
  }
  let adapter = queue_formal_artifact(positive, "formal-dut.sv")
  let harness = queue_formal_artifact(positive, "formal-harness.sv")
  let changed = queue_formal_artifact(negative, "formal-harness.sv")
  let source_set = queue_formal_artifact(positive, "source-set.lcfs")
  assert_eq(fixture.observations().length(), 115)
  assert_eq(source_set.split("OBSERVATION ").length(), 116)
  for index, reference in fixture.observations() {
    let (name, signal_type) = queue_formal_expected_binding(reference.role())
    assert_eq(reference.signal_type(), signal_type)
    for prior in fixture.observations()[0:index] {
      assert_true(prior.role() != reference.role())
    }
    guard fixture.hardware().node(reference.node()) is Some(node) else {
      fail("retirement-record observation lacks its production node")
    }
    assert_eq(node.signal_type(), signal_type)
    let mappings = emitted
      .manifest()
      .mappings()
      .filter(mapping => {
        mapping.kind() is Node &&
        mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
        mapping.local_ordinal() == reference.node().ordinal()
      })
    assert_eq(mappings.length(), 1)
    assert_eq(
      adapter
      .split("assign lc_formal_observe_\{name} = \{mappings[0].identifier()};")
      .length(),
      2,
    )
    assert_eq(
      harness.split(".lc_formal_observe_\{name}(lc_o_\{name})").length(),
      2,
    )
    let kind = match signal_type {
      UInt(_) => "UInt"
      Bits(_) => "Bits"
      _ => fail("unexpected queue observation type")
    }
    assert_true(
      source_set.contains(
        "OBSERVATION \{name} node \{reference.node().ordinal()} width \{signal_type.width().bits()} type \{kind}\n",
      ),
    )
  }
  for mapping in emitted.manifest().mappings() {
    if mapping.module_ordinal() == emitted.manifest().top_module_ordinal() &&
      (mapping.kind() is InputPort || mapping.kind() is OutputPort) {
      assert_eq(
        harness
        .split(".\{mapping.identifier()}(lc_\{mapping.source_name()})")
        .length(),
        2,
      )
    }
  }
  let original = "  wire [31:0] lc_rr_checked_saved_id = lc_rr_previous_payload[99:68];\n"
  let mutation = "  wire [31:0] lc_rr_checked_saved_id = (lc_rr_previous_payload[99:68] ^ (lc_rr_raw_stable_hold ? 32'd1 : 32'd0));\n"
  assert_eq(harness.split(original).length(), 2)
  assert_eq(changed.split(mutation).length(), 2)
  assert_eq(changed.replace(old=mutation, new=original), harness)
  assert_eq(harness.split("assume (").length(), 5)
  assert_eq(harness.split("assert (").length(), 7)
  assert_eq(harness.split("cover (").length(), 3)
  for label in labels {
    assert_true(harness.contains(label))
    assert_true(changed.contains(label))
  }
  assert_true(source_set.contains("FAIRNESS none\n"))
  assert_true(
    source_set.contains(
      "COVERS positive-requires-adjacent-held-oldest-younger-collector-witness-old-full-refill-declared-unselected\n",
    ),
  )
  assert_true(
    queue_formal_artifact(negative, "source-set.lcfs").contains(
      "MUTATION comparison-only-saved-caller-id-bit-zero-flip-after-genuine-stable-hold\n",
    ),
  )
}
