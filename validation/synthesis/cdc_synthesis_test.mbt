///|
test "CDC synthesis bundles use public LunaWire and exact resetless shapes" {
  for stage_count in @synthesis.cdc_bit_synchronizer_stage_counts() {
    let first = @synthesis.generate_bit_synchronizer_bundle(stage_count)
    let second = @synthesis.generate_bit_synchronizer_bundle(stage_count)
    assert_eq(first.stage_count(), stage_count)
    assert_eq(first.artifacts(), second.artifacts())
    assert_true(
      first.expected_shape_json().contains("\"stage_count\": \{stage_count}"),
    )
    assert_true(first.expected_shape_json().contains("\"reset\": false"))
    guard first.design().top_module() is Some(hardware_module) else {
      fail("expected top module")
    }
    assert_eq(hardware_module.memories().length(), 0)
    assert_eq(hardware_module.cdc_primitives().length(), 1)
    let BitSynchronizer(spec) = hardware_module.cdc_primitives()[0]
    assert_eq(spec.source_domain(), AsynchronousSource)
    assert_eq(spec.reset(), None)
    assert_eq(spec.stages().length(), stage_count)
    assert_eq(
      hardware_module
      .nodes()
      .filter(node => node.kind() is Register(_))
      .length(),
      stage_count,
    )
  }
}

///|
test "CDC expected shape manifests are byte stable" {
  debug_inspect(
    [
      for stage_count in @synthesis.cdc_bit_synchronizer_stage_counts() => {
        @synthesis.generate_bit_synchronizer_bundle(stage_count).expected_shape_json()
      }
    ],
    content=(
      #|[
      #|  "{\n  \"$schema\": \"https://lunachip.dev/schema/cdc-synthesis-shape-v1.json\",\n  \"schema_version\": \"lunachip.cdc-synthesis-shape/v1\",\n  \"fixture\": \"bit-synchronizer-2-stage\",\n  \"top_module\": \"lc_m0_b53_b79_b6e_b74_b68_b65_b73_b69_b73_b42_b69_b74_b53_b79_b6e_b63_b68_b72_b6f_b6e_b69_b7a_b65_b72_b32_b53_b74_b61_b67_b65\",\n  \"stage_count\": 2,\n  \"clock_signal\": \"lc_n0\",\n  \"source_signal\": \"lc_n1\",\n  \"stage_signals\": [\"lc_n2\", \"lc_n3\"],\n  \"output_signal\": \"lc_o0_b73_b79_b6e_b63_b68_b72_b6f_b6e_b69_b7a_b65_b64\",\n  \"edge\": \"positive\",\n  \"width\": 1,\n  \"reset\": false\n}\n",
      #|  "{\n  \"$schema\": \"https://lunachip.dev/schema/cdc-synthesis-shape-v1.json\",\n  \"schema_version\": \"lunachip.cdc-synthesis-shape/v1\",\n  \"fixture\": \"bit-synchronizer-3-stage\",\n  \"top_module\": \"lc_m0_b53_b79_b6e_b74_b68_b65_b73_b69_b73_b42_b69_b74_b53_b79_b6e_b63_b68_b72_b6f_b6e_b69_b7a_b65_b72_b33_b53_b74_b61_b67_b65\",\n  \"stage_count\": 3,\n  \"clock_signal\": \"lc_n0\",\n  \"source_signal\": \"lc_n1\",\n  \"stage_signals\": [\"lc_n2\", \"lc_n3\", \"lc_n4\"],\n  \"output_signal\": \"lc_o0_b73_b79_b6e_b63_b68_b72_b6f_b6e_b69_b7a_b65_b64\",\n  \"edge\": \"positive\",\n  \"width\": 1,\n  \"reset\": false\n}\n",
      #|  "{\n  \"$schema\": \"https://lunachip.dev/schema/cdc-synthesis-shape-v1.json\",\n  \"schema_version\": \"lunachip.cdc-synthesis-shape/v1\",\n  \"fixture\": \"bit-synchronizer-4-stage\",\n  \"top_module\": \"lc_m0_b53_b79_b6e_b74_b68_b65_b73_b69_b73_b42_b69_b74_b53_b79_b6e_b63_b68_b72_b6f_b6e_b69_b7a_b65_b72_b34_b53_b74_b61_b67_b65\",\n  \"stage_count\": 4,\n  \"clock_signal\": \"lc_n0\",\n  \"source_signal\": \"lc_n1\",\n  \"stage_signals\": [\"lc_n2\", \"lc_n3\", \"lc_n4\", \"lc_n5\"],\n  \"output_signal\": \"lc_o0_b73_b79_b6e_b63_b68_b72_b6f_b6e_b69_b7a_b65_b64\",\n  \"edge\": \"positive\",\n  \"width\": 1,\n  \"reset\": false\n}\n",
      #|]
    ),
  )
}

///|
test "CDC synthesis bundle rejects stage counts outside the public contract" {
  for stage_count in [1, 5] {
    try @synthesis.generate_bit_synchronizer_bundle(stage_count) catch {
      @ir.IrError::InvalidBitSynchronizerStageCount(actual~, ..) =>
        assert_eq(actual, stage_count)
      error => fail("unexpected stage-count error: \{Repr(error)}")
    } noraise {
      _ => fail("expected stage-count rejection")
    }
  }
}
