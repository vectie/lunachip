///|
fn ring_control_check_audit(audit : String, cycles : Int32) -> Unit raise {
  for
    required in [
      "LUNACHIP-PHASE6-FIXTURE 1\nPROFILE flux-tile-0/fetched-concurrent\n",
      "FIXTURE fetched-concurrent-1x1-k512-ring-control-recovery\n",
      "DEVICE-ABI 1.0\nDESCRIPTOR 0.2\n",
      "CYCLES \{cycles}\nCYCLE-BOUND 32768\nEPOCHS 7\n",
      "CONFIGURATION-ACCEPTS 7\nPUBLICATION-ACCEPTS 8\nNOOP-PUBLICATIONS 1\n",
      "COMPLETIONS 11\nREQUESTS 1380\nACKNOWLEDGEMENTS 1380\n",
      "DESCRIPTOR-READS 352\nOPERAND-READS 1026\nWORD-WRITES 2\n",
      "DESCRIPTOR-ACKS 352\nOPERAND-ACKS 1026\nWORD-ACKS 2\n",
      "READ-BYTES 1378\nWRITE-BYTES 8\n",
      "BAD-PUBLICATION-CANDIDATE 8\nFAULT-PRODUCER 6\nPACKET-ADMISSION-CONSUMER 3 4\n",
      "COMPLETION-HOLD-CYCLES 32\n",
      "LONG-COUNTERS 512 512 513 0 1\nRECOVERY-COUNTERS 1 1 2 0 1\n",
      "FINAL-PRODUCER 7\nFINAL-CONSUMER 7\n",
      "FINAL-TAG 227\nSTARTUP-RESETS 1\nJOINT-RESETS 6\n",
      "LONG-RESULT 3072\nRECOVERY-RESULT 6\n",
      "HOST-BYTES 4096 match\nORACLE per-write-and-saved-ACK\n",
      "RESET-HOST-BYTES preserved\nTRANSPORT-POISON false\n",
      "SCOPE finite-runtime-ring-control-and-recovery-only\nCLAIM generated-reference-only\nEND\n",
    ] {
    assert_true(audit.contains(required))
  }
  let publications = [0, 0, 0, 2, 1, 3, 2]
  for epoch in 1..<=7 {
    let (completions, descriptor, operand, words, run, capture) = match epoch {
      6 => (4, 128, 1024, 1, 512, 1)
      7 => (7, 224, 2, 1, 1, 1)
      _ => (0, 0, 0, 0, 0, 0)
    }
    assert_eq(descriptor_rejection_audit_record(audit, "EPOCH \{epoch} "), [
      "EPOCH",
      "\{epoch}",
      "CONFIGURATIONS",
      "1",
      "PUBLICATIONS",
      "\{publications[epoch - 1]}",
      "COMPLETIONS",
      "\{completions}",
      "DESCRIPTOR-READS",
      "\{descriptor}",
      "OPERAND-READS",
      "\{operand}",
      "WORD-WRITES",
      "\{words}",
      "DESCRIPTOR-ACKS",
      "\{descriptor}",
      "OPERAND-ACKS",
      "\{operand}",
      "WORD-ACKS",
      "\{words}",
      "RUN-EDGES",
      "\{run}",
      "CAPTURE-EDGES",
      "\{capture}",
      "QUIET-EDGES",
      "8",
    ])
  }
  assert_eq(audit.split("\nEPOCH ").count(), 8)
  let faults = [
    (1, "4097", 0, 0, 0),
    (2, "4064", 0, 0, 0),
    (2, "4294967232", 0, 0, 0),
    (3, "0", 1, 17, 17),
    (3, "0", 1, 17, 17),
    (3, "0", 1, 6, 4),
  ]
  for index, (code, address, configured, producer, consumer) in faults {
    assert_eq(
      descriptor_rejection_audit_record(audit, "RING-FAULT-EPOCH \{index + 1} "),
      [
        "RING-FAULT-EPOCH",
        "\{index + 1}",
        "CODE",
        "\{code}",
        "ADDRESS",
        address,
        "CONFIGURED",
        "\{configured}",
        "PRODUCER",
        "\{producer}",
        "CONSUMER",
        "\{consumer}",
      ],
    )
  }
  assert_eq(audit.split("\nRING-FAULT-EPOCH ").count(), 7)
  let measurements : Map[String, Int32] = Map([])
  for
    key in [
      "STORE-PACKET-FINAL-ACK-CYCLE", "PUBLICATION-FAULT-CYCLE", "PUBLICATION-FAULT-ACTIVE-BEFORE",
      "PUBLICATION-FAULT-ACTIVE-AFTER", "COMPLETION-HOLD-DISCOVERY-CYCLE", "REQUEST-READY-STALL-EDGES",
    ] {
    let cells = descriptor_rejection_audit_record(audit, key + " ")
    assert_eq(cells.length(), 2)
    let value = descriptor_rejection_measured(cells[1])
    assert_true(value > 0 && value <= cycles)
    measurements[key] = value
  }
  assert_true(
    measurements["STORE-PACKET-FINAL-ACK-CYCLE"] <
    measurements["PUBLICATION-FAULT-CYCLE"],
  )
  assert_true(
    measurements["PUBLICATION-FAULT-CYCLE"] <
    measurements["COMPLETION-HOLD-DISCOVERY-CYCLE"],
  )
  assert_true(measurements["PUBLICATION-FAULT-ACTIVE-BEFORE"] < 512)
  assert_eq(
    measurements["PUBLICATION-FAULT-ACTIVE-AFTER"],
    measurements["PUBLICATION-FAULT-ACTIVE-BEFORE"] + 1,
  )
}

///|
test "fetched ring control replay preserves ordinary device identity and detects a valid completion mutation" {
  // Generation validates reference obligations; this is not a Verilator run.
  let bundle = @phase6.generate_ring_control_bundle()
  let repeated = @phase6.generate_ring_control_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-1x1-k512-ring-control-recovery")
  assert_true(bundle.post_reset_cycles() > 1380)
  assert_true(bundle.post_reset_cycles() <= 32768)
  assert_eq(bundle.post_reset_cycles(), repeated.post_reset_cycles())
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.artifacts().length(), 11)
  assert_eq(repeated.artifacts().length(), 11)
  for index, artifact in bundle.artifacts() {
    assert_eq(artifact.path, repeated.artifacts()[index].path)
    assert_eq(artifact.content, repeated.artifacts()[index].content)
    for prior in bundle.artifacts()[0:index] {
      assert_true(artifact.path != prior.path)
    }
  }
  let capabilities = @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=512,
    host_bytes=4096,
    ring_depth=4,
    queue_depth=3,
  )
  assert_eq(
    descriptor_rejection_artifact(bundle, "capabilities.json"),
    capabilities.manifest(),
  )
  let hardware = @flux_tile.ring_concurrent_from_capabilities(capabilities)
  let design = @ir.Design::single("phase6-" + bundle.id(), hardware)
  // Serialization normalizes output order; parsed Module structural equality
  // is not the identity contract. Compare the entire independent canonical IR.
  assert_eq(
    descriptor_rejection_artifact(bundle, "design.lcir"),
    @ir_codec.serialize(design),
  )
  let emitted = @systemverilog.emit_design(design)
  for emitted_module in emitted.modules() {
    assert_eq(
      descriptor_rejection_artifact(bundle, emitted_module.filename()),
      emitted_module.source(),
    )
  }
  assert_eq(
    descriptor_rejection_artifact(bundle, "names.lcnm"),
    emitted.manifest().to_canonical_text(),
  )
  let ports = @verilator.collect_ports(hardware, emitted.manifest())
  assert_eq(bundle.ports().length(), ports.length())
  assert_eq(bundle.ports().length(), repeated.ports().length())
  for index, port in ports {
    assert_eq(bundle.ports()[index], port)
    assert_eq(repeated.ports()[index], port)
  }
  let outputs = bundle.ports().filter(port => port.is_output())
  assert_eq(outputs.length(), 30)
  assert_eq(
    descriptor_rejection_artifact(bundle, "manifest.json"),
    @verilator.harness_json(emitted, ports),
  )
  assert_eq(
    descriptor_rejection_artifact(bundle, "expected.tsv"),
    bundle.expected_tsv(),
  )
  ring_control_check_audit(
    descriptor_rejection_artifact(bundle, "workload.audit"),
    bundle.post_reset_cycles(),
  )
  let protocol = @verilator.ResultProtocol::checked(
    "LUNACHIP-PHASE6-RESULT", "1", "lunachip.flux-tile/device-abi-1.0/descriptor-0.2/fixture-v1",
  )
  let parsed = @verilator.parse_actual_tsv(
    bundle.expected_tsv(),
    ports,
    bundle.post_reset_cycles(),
    protocol,
  )
  assert_eq(parsed.observations().length(), bundle.post_reset_cycles() * 30)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ => fail("ring-control reference trace failed its exact typed comparator")
  }
  let lines = bundle
    .expected_tsv()
    .split("\n")
    .map(line => line.to_owned())
    .to_array()
  assert_eq(lines.length(), bundle.post_reset_cycles() + 3)
  let header = lines[1].split("\t").to_array()
  assert_eq(header.length(), 31)
  let mut completion_column = -1
  let mut valid_column = -1
  for index, port in outputs {
    assert_eq(header[index + 1], port.emitted_name())
    if port.source_name() == "completion_id" {
      assert_eq(port.width(), 32)
      completion_column = index + 1
    }
    if port.source_name() == "completion_valid" {
      assert_eq(port.width(), 1)
      valid_column = index + 1
    }
  }
  assert_true(completion_column > 0 && valid_column > 0)
  let mut changed = false
  for row in 2..<(lines.length() - 1) {
    let cells = lines[row].split("\t").map(cell => cell.to_owned()).to_array()
    if !changed && cells[valid_column] == "1" {
      // Preserve identity, row count, hexadecimal encoding and field width.
      let original = cells[completion_column]
      cells[completion_column] = original[0:original.length() - 1].to_owned() +
        (if original.has_suffix("0") { "1" } else { "0" })
      lines[row] = cells.join("\t")
      changed = true
    }
  }
  assert_true(changed)
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(mismatch) =>
      match mismatch.identity() {
        Value(tap~, ..) => assert_eq(tap, "completion_id")
        _ => fail("valid completion mutation must produce a value mismatch")
      }
    _ => fail("ring-control public completion mutation was not detected")
  }
}
