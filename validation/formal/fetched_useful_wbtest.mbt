///|
fn fetched_useful_test_artifact(
  bundle : FetchedUsefulBundle,
  path : String,
) -> String raise {
  guard bundle.artifacts.filter(item => item.path() == path) is [artifact] else {
    fail("missing/repeated fetched useful artifact: " + path)
  }
  artifact.content()
}

///|
test "fetched useful packets encode four legal repeated-ID descriptors and disjoint host regions" {
  let shapes : Array[(UInt32, UInt32, UInt32, UInt32, UInt32)] = [
    (1U, 2U, 0U, 256U, 2U),
    (2U, 1U, 0U, 512U, 1U),
    (1U, 1U, 2U, 0U, 0U),
    (1U, 1U, 0U, 768U, 4U),
  ]
  for index in 0..<4 {
    let bytes : Array[Byte] = []
    for lane in fetched_useful_packet(index) {
      for offset in 0..<8 {
        bytes.push(((lane >> (8 * offset)) & 255UL).to_byte())
      }
    }
    let encoded = Bytes::from_array(bytes)
    let packet = @slotted_descriptor.decode(encoded)
    assert_eq(packet.encode(), encoded)
    assert_eq(packet.id, 73U)
    assert_eq(
      (
        packet.rows,
        packet.columns,
        packet.reduction,
        packet.base,
        packet.stride,
      ),
      shapes[index],
    )
    assert_eq((packet.a_slot, packet.b_slot, packet.c_slot), (0U, 0U, 0U))
  }
  assert_eq(-3 * 5 + 7 * -2, -29)
  assert_eq(128 + 4, 132)
  // Search budget arithmetic is not a DUT deadline assertion. The actual
  // successful cover must qualify reaching the write within this horizon.
  assert_true(128 * 3 + 4 + 5 * 3 + 80 < 512)
  assert_eq(fetched_useful_artifacts_from_id("unknown"), None)
  try fetched_useful_packet(4) catch {
    _ => ()
  } noraise {
    _ => fail("out-of-range packet index")
  }
}

///|
test "fetched useful typed tasks retain original eight conditions at 1024 global steps" {
  let (exported, assumptions, assertions, covers) = fetched_useful_property_export()
  assert_eq(
    (assumptions.length(), assertions.length(), covers.length()),
    (8, 11, 1),
  )
  let old = flux_tile_property_definitions()[:13].to_owned()
  for index, (name, kind) in old {
    assert_eq(exported.properties()[index].source_name(), name)
    assert_eq(exported.properties()[index].kind(), kind)
  }
  let bundle = generate_fetched_useful_bundle()
  assert_eq(
    bundle.artifacts
    .filter(artifact => artifact.path().has_suffix(".lcft"))
    .length(),
    2,
  )
  for
    (suffix, mode) in [
      ("-bmc", @formal_core.BoundedMode::BoundedSafety),
      ("-cover-write-ack-retirement", BoundedCover),
    ] {
    let name = fetched_useful_id() + suffix
    let parsed = @formal_core.parse_proof_task(
      fetched_useful_test_artifact(bundle, name + ".lcft"),
    )
    guard parsed is Bounded(value) else { fail("bounded fetched task") }
    assert_eq(
      (value.name(), value.mode(), value.bound().cycles()),
      (name, mode, 1024),
    )
    assert_eq(value.assumptions().length(), assumptions.length())
    for label in assumptions {
      assert_eq(
        value.assumptions().filter(actual => actual == label).length(),
        1,
      )
    }
    let expected_selected = if mode is BoundedSafety {
      assertions
    } else {
      covers
    }
    assert_eq(value.properties().length(), expected_selected.length())
    for label in expected_selected {
      assert_eq(
        value.properties().filter(actual => actual == label).length(),
        1,
      )
    }
    let execution = fetched_useful_test_artifact(bundle, name + ".lcfg")
    assert_true(
      execution.contains("BOUND-MAPPING 1024-global-steps-512-dut-clocks\n"),
    )
    assert_true(execution.contains("TIMEOUT-SECONDS 600\n"))
    assert_true(execution.contains("EXPECTED-STATUS pass\n"))
    assert_true(execution.contains("EXPECTED-FAILURE none\n"))
  }
}

///|
test "fetched useful binds unchanged whole source and restores exact original public monitor" {
  let design = flux_tile_formal_design()
  let canonical = @ir_codec.serialize(design)
  assert_eq(
    sha256_hex(canonical),
    "d47c7cccaa7dc7d8021b0fabc6a4eb7d4977bb53c1c5fa06416bbbb5e531cf79",
  )
  guard design.top_module() is Some(hardware) else { fail("original top") }
  let emitted = @rtl.emit_design(design)
  let production = flux_tile_formal_dut(hardware, emitted)
  let (adapted, _) = dependency_boolean_helpers(hardware, production.source)
  let dut : FluxTileFormalDut = {
    identifier: production.identifier,
    filename: "formal-dut.sv",
    source: adapted,
    ports: production.ports,
  }
  let (exported, _, _, _) = fetched_useful_property_export()
  let bundle = generate_fetched_useful_bundle()
  assert_eq(fetched_useful_test_artifact(bundle, "design.lcir"), canonical)
  assert_eq(
    fetched_useful_test_artifact(bundle, "production-" + production.filename),
    production.source,
  )
  assert_eq(fetched_useful_test_artifact(bundle, "formal-dut.sv"), adapted)
  assert_eq(
    fetched_useful_test_artifact(bundle, "names.lcnm"),
    emitted.manifest().to_canonical_text(),
  )
  let harness = fetched_useful_test_artifact(bundle, "formal-harness.sv")
  let added = fetched_useful_host_source() +
    fetched_useful_monitor_source() +
    exported.source()
  assert_eq(harness.split(added).count(), 2)
  assert_eq(
    harness
    .replace(old=added, new="")
    .replace(
      old="module lc_formal_fetched_useful_top;\n",
      new="module lc_formal_flux_tile_top;\n",
    ),
    flux_tile_harness(PublicTransport, dut, ""),
  )
  assert_false(harness.contains("cut_n"))
  assert_false(harness.contains("lc_o_"))
  assert_eq(harness.split("(* anyseq *)").count(), 13)
  for port in production.ports {
    assert_true(harness.contains(".\{port.identifier}(lc_\{port.role})"))
  }
  let source_set = fetched_useful_test_artifact(bundle, "source-set.lcfs")
  assert_eq(
    source_set.split("ADDRESS-KNOWNNESS two-state-formal-all-binary\n").count(),
    2,
  )
  for
    path in [
      "design.lcir", "formal-dut.sv", "formal-harness.sv", "properties.lcfp", "names.lcnm",
    ] {
    assert_true(
      source_set.contains(
        "\{path} sha256 \{sha256_hex(fetched_useful_test_artifact(bundle,path))}\n",
      ),
    )
  }
  assert_eq(bundle.artifacts.length(), 12)
  for artifact in bundle.artifacts {
    assert_eq(
      bundle.artifacts.filter(other => other.path() == artifact.path()).length(),
      1,
    )
  }
  assert_eq(
    fetched_useful_artifacts_from_id(fetched_useful_id()),
    Some(bundle.artifacts),
  )
}

///|
test "fetched useful host preserves independent owned ACKs and finite numeric cover only" {
  let host = fetched_useful_host_source()
  let monitor = fetched_useful_monitor_source()
  assert_true(host.contains("if (lc_request_accept && !lc_fu_owned) begin"))
  assert_true(
    host.contains("(lc_memory_response_valid == (!lc_reset && lc_fu_owned))"),
  )
  assert_true(host.contains("lc_fu_host_data(lc_fu_owned_address)"))
  assert_false(host.contains("lc_memory_response_ready"))
  assert_true(host.contains("lc_publish_producer == 32'd4"))
  assert_true(
    monitor.contains("lc_fu_descriptor_acks[lc_fu_owned_address[6:0]] <= 1'b1"),
  )
  assert_true(
    monitor.contains("lc_fu_operand_acks[lc_fu_operand_index] <= 1'b1"),
  )
  assert_true(monitor.contains("lc_fu_owned_data == 32'hffffffe3"))
  let retirement = direct_completion_test_predicate(
    monitor, "fu_retirement_identity",
  )
  let write = direct_completion_test_predicate(monitor, "fu_write_identity")
  assert_false(write.contains("ffffffe3"))
  assert_false(retirement.contains("ffffffe3"))
  assert_true(monitor.contains("lc_fu_retirements == 3'd4"))
  assert_true(
    monitor.contains(
      "lc_fu_read_accepts == 8'd132 && lc_fu_read_acks == 8'd132",
    ),
  )
  assert_false(monitor.contains("assume"))
  assert_false(monitor.contains("deadline"))
}
