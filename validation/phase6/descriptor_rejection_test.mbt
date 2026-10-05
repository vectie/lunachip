///|
fn descriptor_rejection_artifact(
  bundle : @phase6.FixtureBundle,
  path : String,
) -> String raise {
  let matches = bundle.artifacts().filter(artifact => artifact.path == path)
  assert_eq(matches.length(), 1)
  matches[0].content
}

///|
fn descriptor_rejection_audit_record(
  audit : String,
  prefix : String,
) -> Array[String] raise {
  let records = audit
    .split("\n")
    .filter(line => line.has_prefix(prefix))
    .to_array()
  assert_eq(records.length(), 1)
  records[0].split(" ").map(cell => cell.to_owned()).to_array()
}

///|
fn descriptor_rejection_measured(value : String) -> Int raise {
  assert_true(value.length() > 0 && value.length() <= 6)
  assert_true(value.length() == 1 || value[0] != '0')
  let mut result = 0
  for digit in value {
    assert_true(digit >= '0' && digit <= '9')
    result = result * 10 + digit.to_int() - '0'.to_int()
  }
  result
}

///|
fn descriptor_rejection_check_audit(audit : String, cycles : Int) -> Unit raise {
  for
    required in [
      "LUNACHIP-PHASE6-FIXTURE 1\n",
      "PROFILE flux-tile-0/fetched-concurrent\nDEVICE-ABI 1.0\nDESCRIPTOR 0.2\n",
      "CYCLES \{cycles}\nCYCLE-BOUND 65536\n",
      "COMPLETIONS 86\nSUCCESS-COMPLETIONS 26\nFAULT-COMPLETIONS 60\n",
      "REQUESTS 2768\nACKNOWLEDGEMENTS 2768\n",
      "READ-BYTES 2759\nWRITE-BYTES 36\nCOMPLETION-PROGRESS 43\n",
      "NEXT-TAG 2768\nLAST-ACCEPTED-TAG 2767\n",
      "DESCRIPTOR-READS 2752\nDESCRIPTOR-READS-ACKS 2752\n",
      "OPERAND-READS 7\nOPERAND-READS-ACKS 7\n",
      "WORD-WRITES 9\nWORD-WRITES-ACKS 9\n",
      "RING-REFILLS 30\nPUBLICATIONS 31\nPRODUCER 86\nCONSUMER 86\n",
      "COMPLETION-HOLD-CYCLES 32\nQUIET-EDGES 8\n",
      "RESULT 6\nUNRELATED-RESULT 35\nRECOVERY-RESULT 27\n",
      "ORACLE per-write-and-saved-ack-match\nHOST-BYTES 4096 match\n",
      "INITIAL-RESET 1\nJOINT-RESETS 0\nHOST-REINITIALIZATIONS 0\n",
      "TRANSPORT-POISON false\n",
      "SCOPE finite-descriptor-location-branch-priority-1x1-k1-arithmetic-on-2x2-k2-profile-no-new-overlap-or-formal-claim\n",
      "CLAIM generated-reference-only\nEND\n",
    ] {
    assert_true(audit.contains(required))
  }
  for fault, count in [26, 5, 19, 5, 4, 6, 1, 2, 3, 0, 0, 0, 1, 11, 3, 0] {
    assert_eq(
      descriptor_rejection_audit_record(audit, "FAULT-COUNT \{fault} "),
      ["FAULT-COUNT", "\{fault}", "\{count}"],
    )
  }
  for (address, count) in [(512, 2), (640, 1), (768, 1), (896, 2), (1024, 1)] {
    assert_true(
      audit.contains(
        "OPERAND-ADDRESS \{address} ACCEPTS \{count} ACKS \{count}\n",
      ),
    )
  }
  for (address, count) in [(1536, 4), (1792, 4), (2048, 1)] {
    assert_true(
      audit.contains(
        "ORACLE-WRITE-ADDRESS \{address} ACCEPTS \{count} ACKS \{count}\n",
      ),
    )
  }
  for
    (first, end, reads) in [
      (6, 26, 640),
      (32, 42, 320),
      (44, 47, 96),
      (49, 60, 352),
      (63, 70, 224),
      (71, 76, 160),
      (77, 81, 128),
    ] {
    let cells = descriptor_rejection_audit_record(
      audit,
      "REJECTION-WINDOW \{first} \{end} ",
    )
    assert_eq(cells.length(), 15)
    assert_eq(cells[3], "EDGES")
    let edges = descriptor_rejection_measured(cells[4])
    assert_true(edges > 0 && edges <= cycles)
    assert_eq(cells[5:], [
      "DESCRIPTOR-READS",
      "\{reads}",
      "ACKS",
      "\{reads}",
      "DATA-REQUESTS",
      "0",
      "DATA-ACKS",
      "0",
      "COUNTER-TUPLE",
      "unchanged",
    ])
  }
  assert_eq(audit.split("REJECTION-WINDOW ").length(), 8)
  let mut previous_capture = 0
  for position in [2, 5, 28, 29, 43, 48, 60, 70, 83] {
    let cells = descriptor_rejection_audit_record(
      audit,
      "MATMUL-POSITION \{position} ",
    )
    assert_eq(cells.length(), 16)
    assert_eq(cells[2], "RUN-EDGE")
    assert_eq(cells[4], "CAPTURE-EDGE")
    let run = descriptor_rejection_measured(cells[3])
    let capture = descriptor_rejection_measured(cells[5])
    assert_true(previous_capture < run && run < capture && capture <= cycles)
    assert_eq(cells[6:], [
      "STEPS", "1", "ACTIVE", "1", "ELAPSED", "2", "STALL", "0", "CAPTURE", "1",
    ])
    previous_capture = capture
  }
  assert_eq(audit.split("MATMUL-POSITION ").length(), 10)
  for
    key in [
      "REQUEST-READY-STALL-EDGES", "RESPONSE-DELAY-EDGES", "RESPONSE-HOLD-EDGES",
      "COMPLETION-HOLD-DISCOVERY-CYCLE",
    ] {
    let cells = descriptor_rejection_audit_record(audit, key + " ")
    assert_eq(cells.length(), 2)
    let measured = descriptor_rejection_measured(cells[1])
    assert_true(measured <= cycles)
    if key != "RESPONSE-HOLD-EDGES" {
      assert_true(measured > 0)
    }
  }
}

///|
test "fetched descriptor rejection replay is deterministic and detects output and identity mismatches" {
  // These are generated-reference obligations, not executed Verilator results.
  let bundle = @phase6.generate_descriptor_rejection_bundle()
  let repeated = @phase6.generate_descriptor_rejection_bundle()
  assert_eq(bundle.id(), "fetched-concurrent-2x2-k2-descriptor-rejection")
  assert_true(bundle.post_reset_cycles() > 2768)
  assert_true(bundle.post_reset_cycles() <= 65536)
  assert_eq(bundle.post_reset_cycles(), repeated.post_reset_cycles())
  assert_eq(bundle.expected_tsv(), repeated.expected_tsv())
  assert_eq(bundle.ports().length(), repeated.ports().length())
  for index, port in bundle.ports() {
    assert_eq(port, repeated.ports()[index])
  }
  let outputs = bundle.ports().filter(port => port.is_output())
  assert_eq(outputs.length(), 30)
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
    rows=2,
    columns=2,
    max_reduction=2,
    host_bytes=4096,
    ring_depth=4,
    queue_depth=3,
  )
  assert_eq(
    descriptor_rejection_artifact(bundle, "capabilities.json"),
    capabilities.manifest(),
  )
  let design = @ir_codec.parse(
    descriptor_rejection_artifact(bundle, "design.lcir"),
  )
  assert_eq(design.name(), "phase6-" + bundle.id())
  let expected_design = @ir.Design::single(
    "phase6-" + bundle.id(),
    @flux_tile.ring_concurrent_from_capabilities(capabilities),
  )
  // Compare complete canonical identity, including normalized output order.
  assert_eq(
    descriptor_rejection_artifact(bundle, "design.lcir"),
    @ir_codec.serialize(expected_design),
  )
  assert_eq(@ir_codec.serialize(design), @ir_codec.serialize(expected_design))
  assert_eq(
    descriptor_rejection_artifact(bundle, "expected.tsv"),
    bundle.expected_tsv(),
  )
  descriptor_rejection_check_audit(
    descriptor_rejection_artifact(bundle, "workload.audit"),
    bundle.post_reset_cycles(),
  )
  let protocol = @verilator.ResultProtocol::checked(
    "LUNACHIP-PHASE6-RESULT", "1", "lunachip.flux-tile/device-abi-1.0/descriptor-0.2/fixture-v1",
  )
  let parsed = @verilator.parse_actual_tsv(
    bundle.expected_tsv(),
    bundle.ports(),
    bundle.post_reset_cycles(),
    protocol,
  )
  assert_eq(parsed.observations().length(), bundle.post_reset_cycles() * 30)
  match bundle.compare_actual_tsv(bundle.expected_tsv()) {
    Equal => ()
    _ =>
      fail("descriptor rejection reference trace failed its typed comparator")
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
  for index, port in outputs {
    assert_eq(header[index + 1], port.emitted_name())
    if port.source_name() == "completion_id" {
      assert_eq(port.width(), 32)
      completion_column = index + 1
    }
  }
  assert_true(completion_column > 0)
  let cells = lines[2].split("\t").map(cell => cell.to_owned()).to_array()
  let original = cells[completion_column]
  cells[completion_column] = original[0:original.length() - 1].to_owned() +
    (if original.has_suffix("0") { "1" } else { "0" })
  lines[2] = cells.join("\t")
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(mismatch) =>
      match mismatch.identity() {
        Value(tap~, ..) => assert_eq(tap, "completion_id")
        _ => fail("valid public output mutation must produce a value mismatch")
      }
    _ => fail("descriptor rejection public output mutation was not detected")
  }
  // Restore all samples; replace only the identity with another valid fixture.
  lines[2] = bundle.expected_tsv().split("\n").to_array()[2].to_owned()
  let foreign = @phase6.generate_bundle()
  lines[0] = foreign.expected_tsv().split("\n").to_array()[0].to_owned()
  match bundle.compare_actual_tsv(lines.join("\n")) {
    Mismatch(mismatch) => assert_true(mismatch.identity() is Identity(..))
    _ =>
      fail("another fixture identity must not pass descriptor rejection audit")
  }
}
