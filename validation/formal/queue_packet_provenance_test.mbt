///|
test "packet provenance adds one checked obligation without changing production or prior properties" {
  let positive = @formal.generate_queue_formal_bundle(PacketProvenance)
  let negative = @formal.generate_queue_formal_bundle(NegativePacketProvenance)
  let previous = @formal.generate_queue_formal_bundle(RetirementRecords)
  let manifest = @formal_core.parse_formal_property_manifest(
    queue_formal_artifact(positive, "properties.lcfp"),
  )
  let old_manifest = @formal_core.parse_formal_property_manifest(
    queue_formal_artifact(previous, "properties.lcfp"),
  )
  assert_eq(manifest.properties().length(), 14)
  for index in 0..<12 {
    assert_eq(manifest.properties()[index], old_manifest.properties()[index])
  }
  assert_eq(manifest.properties()[12].name(), "packet_provenance_ok")
  assert_eq(manifest.properties()[12].kind(), Assertion)
  assert_eq(
    manifest.properties()[13].name(),
    "packet_provenance_transfer_cover",
  )
  assert_eq(manifest.properties()[13].kind(), Cover)
  for property in manifest.properties() {
    assert_eq(property.domain().point(), PreEdge)
  }
  let labels = manifest.properties().map(property => property.stable_name())
  assert_eq(positive.tasks().length(), 2)
  assert_eq(negative.tasks().length(), 1)
  assert_eq(positive.expected_failure(), "none")
  assert_eq(negative.expected_failure(), labels[12])
  // Canonical selection sorts labels lexically rather than numerically.
  queue_formal_check_task(
    positive,
    positive.tasks()[0],
    manifest,
    [
      labels[10],
      labels[12],
      labels[4],
      labels[5],
      labels[6],
      labels[8],
      labels[9],
    ],
    cover=false,
    negative=false,
  )
  queue_formal_check_task(
    positive,
    positive.tasks()[1],
    manifest,
    [labels[13]],
    cover=true,
    negative=false,
  )
  queue_formal_check_task(
    negative,
    negative.tasks()[0],
    manifest,
    [labels[12]],
    cover=false,
    negative=true,
  )
  for bundle in [positive, negative] {
    assert_eq(bundle, @formal.generate_queue_formal_bundle(bundle.fixture()))
    assert_eq(
      @formal.QueueFormalFixture::from_id(bundle.fixture().id()),
      Some(bundle.fixture()),
    )
    assert_eq(
      @formal.regenerate_formal_artifacts(
        queue_formal_artifact(bundle, "source-set.lcfs"),
      ),
      bundle.artifacts(),
    )
    let paths = bundle.artifacts().map(artifact => artifact.path())
    for index, path in paths {
      assert_false(paths[0:index].contains(path))
    }
    let source_set = queue_formal_artifact(bundle, "source-set.lcfs")
    assert_eq(source_set.split("OBSERVATION ").count(), 116)
    assert_true(source_set.contains("FAIRNESS none\n"))
    assert_true(
      source_set.contains("PILOT-BOUND global-steps 256 dut-clocks 128\n"),
    )
    for artifact in previous.artifacts() {
      if artifact.path() == "design.lcir" ||
        artifact.path() == "formal-dut.sv" ||
        artifact.path().has_prefix("production-") {
        assert_eq(
          queue_formal_artifact(bundle, artifact.path()),
          artifact.content(),
        )
      }
    }
    for family in ["flux-tile-dependency", "flux-tile-public-transport"] {
      try
        @formal.regenerate_formal_artifacts(
          "LUNACHIP-PHASE6-FORMAL-SOURCE-SET 1\nFAMILY \{family}\nFIXTURE \{bundle.fixture().id()}\n",
        )
      catch {
        @formal.InvalidFormalBundleIdentity(_) => ()
        _ => fail("unexpected packet-provenance cross-family error")
      } noraise {
        _ => fail("another family accepted a packet-provenance fixture")
      }
    }
  }
  assert_eq(
    queue_formal_artifact(positive, "properties.lcfp"),
    queue_formal_artifact(negative, "properties.lcfp"),
  )
  let harness = queue_formal_artifact(positive, "formal-harness.sv")
  let changed = queue_formal_artifact(negative, "formal-harness.sv")
  assert_eq(harness.split("assume (").count(), 5)
  assert_eq(harness.split("assert (").count(), 8)
  assert_eq(harness.split("cover (").count(), 4)
  assert_eq(changed.split("assume (").count(), 5)
  let original = "  wire [255:0] lc_pp_checked_response_packet = lc_pp_saved_packet;\n"
  let mutation = "  wire [255:0] lc_pp_checked_response_packet = (lc_pp_saved_packet ^ (lc_pp_genuine_response ? (256'd1 << 128) : 256'd0));\n"
  assert_eq(harness.split(original).count(), 2)
  assert_eq(changed.split(mutation).count(), 2)
  assert_eq(changed.replace(old=mutation, new=original), harness)
}
