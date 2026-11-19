///|
test "all FIFO bundles are deterministic and meet mandatory evidence" {
  for kind in standard_fifo_fixtures() {
    let first = build_bundle(kind, false)
    let second = build_bundle(kind, false)
    assert_eq(first.artifacts, second.artifacts)
    assert_eq(first.stimulus.to_tsv(), second.stimulus.to_tsv())
    assert_eq(first.expected_tsv, second.expected_tsv)
    assert_eq(first.bundle.compare_actual(first.expected_tsv), None)
    assert_eq(
      first.stimulus.domains().map(d => d.id()),
      ReadOnlyArray::from_array([0, 1, 2, 3]),
    )
    for event in first.stimulus.events() {
      for drive in event.drives() {
        assert_false(drive.value().known_mask().contains("0"))
      }
      for domain in event.domains() {
        assert_true(domain == 0 || domain == 3)
      }
    }
    let c = first.coverage
    assert_true(c.write_wraps >= 2)
    assert_true(c.read_wraps >= 2)
    assert_true(c.enqueue_only > 0)
    assert_true(c.dequeue_only > 0)
    assert_true(c.simultaneous > 0)
    assert_true(c.coincidences > 0)
    assert_true(c.backpressure > 0)
    assert_true(c.full_entries > 0)
    assert_true(c.full_exits > 0)
    assert_true(c.empty_entries > 0)
    assert_true(c.empty_exits > 0)
    let mut harness = ""
    for artifact in first.artifacts {
      if artifact.path() == "harness.cpp" {
        harness = artifact.content()
      }
    }
    assert_true(harness.contains("    }\n    top.eval();\n    result << time"))
  }
}

///|
fn artifact_content(bundle : BuiltFifoFixture, path : String) -> String raise {
  for artifact in bundle.artifacts {
    if artifact.path() == path {
      return artifact.content()
    }
  }
  fail("missing artifact \{path}")
}

///|
test "event and post-reset coverage totals are frozen per fixture" {
  for kind in standard_fifo_fixtures() {
    let bundle = build_bundle(kind, false)
    let (events, coverage) = match kind {
      Depth4ScalarTwoStage =>
        (
          222, "enqueues=49\ndequeues=49\nenqueue_only=48\ndequeue_only=48\nsimultaneous=1\ncoincidences=13\nbackpressure=1\nfull_entries=21\nfull_exits=21\nempty_entries=27\nempty_exits=27\nwrite_wraps=12\nread_wraps=12\nsource_reset_assertions=1\nsource_reset_releases=1\ndestination_reset_assertions=1\ndestination_reset_releases=1\n",
        )
      Depth8AggregateThreeStage =>
        (
          145, "enqueues=24\ndequeues=24\nenqueue_only=18\ndequeue_only=18\nsimultaneous=6\ncoincidences=65\nbackpressure=2\nfull_entries=6\nfull_exits=6\nempty_entries=11\nempty_exits=11\nwrite_wraps=3\nread_wraps=3\nsource_reset_assertions=1\nsource_reset_releases=1\ndestination_reset_assertions=1\ndestination_reset_releases=1\n",
        )
      Depth4AsymmetricFourStage =>
        (
          192, "enqueues=12\ndequeues=12\nenqueue_only=11\ndequeue_only=11\nsimultaneous=1\ncoincidences=26\nbackpressure=3\nfull_entries=8\nfull_exits=8\nempty_entries=4\nempty_exits=4\nwrite_wraps=3\nread_wraps=3\nsource_reset_assertions=1\nsource_reset_releases=1\ndestination_reset_assertions=1\ndestination_reset_releases=1\n",
        )
    }
    assert_eq(bundle.stimulus.events().length(), events)
    assert_eq(artifact_content(bundle, "coverage.txt"), coverage)
    let metadata = artifact_content(bundle, "fixture-metadata.txt")
    assert_true(metadata.contains("id=\{kind.id()}\n"))
    assert_true(metadata.contains("depth=\{kind.depth()}\n"))
    assert_true(metadata.contains("stages=\{kind.stages()}\n"))
    assert_true(metadata.contains("events=\{events}\n"))
    assert_true(metadata.contains("ledger=pre-edge-dequeue-before-enqueue\n"))
    // Equal full entries/exits proves the initial reset transition to ready is
    // not incorrectly credited as a full exit.
    assert_false(coverage.contains("full_entries=0"))
  }
}

///|
test "missing assertion and release evidence fails per domain" {
  let valid = build_bundle(Depth4ScalarTwoStage, false).coverage
  let mutants = [
    { ..valid, source_reset_assertions: 0, },
    { ..valid, source_reset_releases: 0, },
    { ..valid, destination_reset_assertions: 0, },
    { ..valid, destination_reset_releases: 0, },
  ]
  for mutant in mutants {
    try require_reset_coverage(mutant) catch {
      IncompleteCoverage(_) => ()
      error => fail("unexpected \{Repr(error)}")
    } noraise {
      _ => fail("accepted incomplete reset coverage")
    }
  }
}

///|
fn test_uint(value : @differential.NormalizedValue) -> UInt64 {
  let mut out = 0UL
  for c in value.value_bits() {
    out = (out << 1) | (if c == '1' { 1UL } else { 0UL })
  }
  out
}

///|
fn test_drive(
  event : @verilator.AtomicStimulusEvent,
  ports : ReadOnlyArray[@verilator.HarnessPort],
  source : String,
) -> UInt64 {
  let emitted = ports
    .iter()
    .find_first(p => p.source_name() == source)
    .unwrap()
    .emitted_name()
  test_uint(
    event.drives().iter().find_first(d => d.name() == emitted).unwrap().value(),
  )
}

///|
fn test_payload(
  kind : FifoFixtureKind,
  event : @verilator.AtomicStimulusEvent,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> Array[UInt64] {
  if kind == Depth8AggregateThreeStage {
    [
      test_drive(event, ports, "source_word"),
      test_drive(event, ports, "source_tag"),
      test_drive(event, ports, "source_lane0"),
      test_drive(event, ports, "source_lane1"),
      test_drive(event, ports, "source_lane2"),
    ]
  } else {
    [test_drive(event, ports, "source_lane0")]
  }
}

///|
fn test_simulator_event(
  event : @verilator.AtomicStimulusEvent,
  ports : ReadOnlyArray[@verilator.HarnessPort],
) -> @sim.TimestampEvent raise {
  let drives : Array[@sim.InputDrive] = []
  for drive in event.drives() {
    let source = ports
      .iter()
      .find_first(p => p.emitted_name() == drive.name())
      .unwrap()
      .source_name()
    drives.push(
      @sim.InputDrive::checked(
        source,
        @wave.LogicValue::from_uint64(
          width=drive.value().width(),
          value=test_uint(drive.value()),
        ),
      ),
    )
  }
  @sim.TimestampEvent::checked(
    @sim.SimulationTime::from_uint64(event.time()),
    drives,
    event.domains().map(@ir.ClockDomainId::new),
  )
}

///|
test "producer holds valid and every payload leaf through backpressure" {
  for kind in standard_fifo_fixtures() {
    let bundle = build_bundle(kind, false)
    guard bundle.design.top_module() is Some(hardware_module) else {
      fail("missing top")
    }
    let ports = @verilator.collect_ports(
      hardware_module,
      bundle.emitted.manifest(),
    )
    let simulator = @sim.Simulator::prepare(hardware_module)
    let mut holding = false
    let mut held : Array[UInt64] = []
    for event in bundle.stimulus.events() {
      let current = test_payload(kind, event, ports)
      let current_valid = test_drive(event, ports, "source_valid") == 1UL
      if holding {
        assert_true(current_valid)
        assert_eq(current, held)
      }
      let pre_ready = simulator.output("source_ready").is_fully_known() &&
        simulator.output("source_ready").to_uint64() == 1UL
      if event.domains().contains(0) {
        if current_valid && !pre_ready {
          holding = true
          held = current
        } else {
          holding = false
        }
      }
      simulator.apply_event(test_simulator_event(event, ports))
    }
  }
}

///|
test "invalid destination rows mask every visible payload leaf to zero" {
  for kind in standard_fifo_fixtures() {
    let rows = build_bundle(kind, false).expected_tsv.split("\n").to_array()
    let header = rows[1].split("\t").to_array()
    let mut valid_column = 0
    for index, name in header {
      if name == "destination_valid" {
        valid_column = index
      }
    }
    for row_index in 2..<(rows.length() - 1) {
      let row = rows[row_index]
      let fields = row.split("\t").to_array()
      if fields[valid_column] == "0" {
        for index, name in header {
          if name.has_prefix("destination_") && name != "destination_valid" {
            assert_true(fields[index].all(c => c == '0'))
          }
        }
      }
    }
  }
}

///|
test "aggregate lanes preserve exact ordered identities widths and tokens" {
  let bundle = build_bundle(Depth8AggregateThreeStage, false)
  guard bundle.design.top_module() is Some(hardware_module) else {
    fail("missing top")
  }
  guard hardware_module.cdc_primitives()[0] is AsyncFifo(fifo) else {
    fail("missing FIFO")
  }
  let source_names : Array[String] = []
  let source_widths : Array[Int32] = []
  for id in fifo.source_payload() {
    let node = hardware_module.node(id).unwrap()
    guard node.kind() is Input(name) else { fail("source lane is not input") }
    source_names.push(name)
    source_widths.push(node.signal_type().width().bits())
  }
  assert_eq(source_names, [
    "source_word", "source_tag", "source_lane0", "source_lane1", "source_lane2",
  ])
  assert_eq(source_widths, [32, 8, 8, 8, 8])
  assert_eq(source_widths.fold(init=0, (sum, width) => sum + width), 64)
  let destination_names : Array[String] = []
  let destination_widths : Array[Int32] = []
  for id in fifo.destination_payload() {
    let node = hardware_module.node(id).unwrap()
    destination_widths.push(node.signal_type().width().bits())
    guard hardware_module.outputs().iter().find_first(o => o.driver() == id)
      is Some(output) else {
      fail("destination lane is not public")
    }
    destination_names.push(output.name())
  }
  assert_eq(destination_names, [
    "destination_word", "destination_tag", "destination_lane0", "destination_lane1",
    "destination_lane2",
  ])
  assert_eq(destination_widths, [32, 8, 8, 8, 8])
  let lanes = bundle.emitted
    .manifest()
    .mappings()
    .iter()
    .filter(m => m.kind() is AsyncFifoLane)
    .to_array()
  assert_eq(lanes.length(), 5)
  for index, lane in lanes {
    assert_eq(lane.identifier(), "lc_f0_l\{index}")
    assert_eq(lane.source_name(), "transport")
    assert_eq(lane.local_ordinal(), fifo.raw_reads()[index].ordinal())
  }
  // Token one is deliberately distinct in every leaf; the watched-token
  // ledger therefore rejects every source/destination leaf permutation.
  let ports = @verilator.collect_ports(
    hardware_module,
    bundle.emitted.manifest(),
  )
  let mut found = false
  for event in bundle.stimulus.events() {
    if test_payload(Depth8AggregateThreeStage, event, ports) ==
      [0xa5000001UL, 0x14UL, 1UL, 4UL, 7UL] {
      found = true
    }
  }
  assert_true(found)
}

///|
test "sequential bridge has the frozen first mismatch" {
  let bundle = build_bundle(Depth4AsymmetricFourStage, true)
  assert_eq(
    verify_sequential_negative(bundle.sequential_tsv),
    required_sequential_mismatch(),
  )
  let mut harness = ""
  for artifact in bundle.artifacts {
    if artifact.path() == "harness.cpp" {
      harness = artifact.content()
    }
  }
  assert_true(harness.contains("      top.eval();\n    }\n    result << time"))
}

///|
test "result validation rejects noncanonical and malformed rows" {
  let bundle = generate_fifo_fixture(Depth4ScalarTwoStage)
  let bad_identity = bundle.expected_tsv.replace(
    old="LUNACHIP-PHASE5-FIFO-RESULT",
    new="BAD",
  )
  try bundle.compare_actual(bad_identity) catch {
    InvalidActualResult(..) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("accepted bad identity")
  }
  let bad_hex = bundle.expected_tsv.replace(old="\t00\t", new="\t0A\t")
  try bundle.compare_actual(bad_hex) catch {
    InvalidActualResult(..) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("accepted bad hex")
  }
}

///|
fn join_result_lines(lines : Array[String]) -> String {
  let out = StringBuilder()
  for index in 0..<(lines.length() - 1) {
    out.write_string(lines[index])
    out.write_char('\n')
  }
  out.to_string()
}

///|
fn replace_result_cell(
  source : String,
  row : Int32,
  column : Int32,
  value : String,
) -> String {
  let lines = source.split("\n").map(x => x.to_owned()).to_array()
  let fields = lines[row].split("\t").map(x => x.to_owned()).to_array()
  fields[column] = value
  let rebuilt = StringBuilder()
  for index, field in fields {
    if index > 0 {
      rebuilt.write_char('\t')
    }
    rebuilt.write_string(field)
  }
  lines[row] = rebuilt.to_string()
  join_result_lines(lines)
}

///|
fn expect_invalid_result(
  bundle : FifoFixtureBundle,
  actual : String,
) -> Unit raise {
  try bundle.compare_actual(actual) catch {
    InvalidActualResult(..) => ()
    error => fail("unexpected \{Repr(error)}")
  } noraise {
    _ => fail("accepted malformed result after an early mismatch")
  }
}

///|
test "first mismatch is retained only after the entire result validates" {
  let bundle = generate_fifo_fixture(Depth4ScalarTwoStage)
  let early = replace_result_cell(bundle.expected_tsv, 3, 2, "ff")
  expect_invalid_result(bundle, replace_result_cell(early, 20, 2, "GG"))
  let wrong_columns = early.split("\n").map(x => x.to_owned()).to_array()
  wrong_columns[21] = "0\t0"
  expect_invalid_result(bundle, join_result_lines(wrong_columns))
  expect_invalid_result(bundle, replace_result_cell(early, 22, 0, "01"))
  let duplicate_missing = early.split("\n").map(x => x.to_owned()).to_array()
  duplicate_missing[24] = duplicate_missing[23]
  expect_invalid_result(bundle, join_result_lines(duplicate_missing))
  let missing = early.split("\n").map(x => x.to_owned()).to_array()
  ignore(missing.pop())
  ignore(missing.pop())
  missing.push("")
  expect_invalid_result(bundle, join_result_lines(missing))
}
