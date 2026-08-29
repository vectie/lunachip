///|
test "standard memory differential plan exceeds 100,000 cycles" {
  let plans = @phase4.standard_plan()
  let copied : Array[@phase4.FixturePlan] = []
  for plan in plans {
    copied.push(plan)
  }
  assert_eq(plans.length(), 8)
  assert_eq(@phase4.total_post_reset_cycles(copied), 104000)
}

///|
test "all memory policy bundles are deterministic and fully observable" {
  let kinds : Array[@phase4.FixtureKind] = [
    WholeReadOld,
    WholeReadNew,
    NoChange,
    UndefinedSafe,
    MaskedWrite,
    NonPowerOfTwo,
    Enables,
    LowerPortIdWins,
  ]
  for index, kind in kinds {
    let plan = @phase4.FixturePlan::checked(
      kind,
      0x1020304050607080UL + index.to_uint64(),
      12,
    )
    let first = @phase4.generate_bundle(plan)
    let second = @phase4.generate_bundle(plan)
    assert_eq(first.artifacts(), second.artifacts())
    assert_true(first.harness_json().contains("\"result\": \"actual.tsv\""))
    assert_true(first.harness_cpp().contains("LUNACHIP-PHASE4-RESULT"))
    assert_true(first.expected_tsv().has_prefix("LUNACHIP-PHASE4-RESULT\t1\t"))
    assert_true(first.compare_actual_tsv(first.expected_tsv()) is Equal)
    assert_eq(first.expected().observations().length(), 24)
    for observation in first.expected().observations() {
      assert_false(observation.value().to_text().contains("X"))
    }
  }
}

///|
test "dynamic Reject faults LunaWave before commit and emits an assertion" {
  let hardware_module = @phase4.dynamic_reject_module()
  let simulator = @sim.Simulator::prepare(hardware_module)
  simulator.set_input("address0", @verilator.known_value(2, 2UL))
  simulator.set_input("address1", @verilator.known_value(2, 2UL))
  simulator.set_input("data0", @verilator.known_value(8, 0xa5UL))
  simulator.set_input("data1", @verilator.known_value(8, 0x5aUL))
  simulator.set_input("enable0", @verilator.known_value(1, 1UL))
  simulator.set_input("enable1", @verilator.known_value(1, 1UL))
  try simulator.rising_edge("clock") catch {
    @sim.SimulatorError::MemoryWriteCollision(
      memory="storage",
      address=2UL,
      first_port=0,
      second_port=1
    ) => ()
    error => fail("unexpected collision error: \{Repr(error)}")
  } noraise {
    _ => fail("expected dynamic collision fault")
  }
  assert_eq(simulator.cycle().value(), 0UL)
  let source = @systemverilog.emit_design(
    @ir.Design::single("phase4-reject", hardware_module),
  ).modules()[0].source()
  assert_true(source.contains("assert"))
  assert_true(
    source.contains("lc_mem0_write0_write1_collision: assert (1'b0);"),
  )
}

///|
test "Undefined coverage hides only X payloads and checks recovery" {
  let bundle = @phase4.generate_bundle(
    @phase4.FixturePlan::checked(UndefinedSafe, 77UL, 40),
  )
  let hardware_module = bundle.design().top_module().unwrap()
  let memory = hardware_module.memories()[0]
  assert_eq(memory.depth().elements(), 3)
  assert_eq(memory.bounds_policy(), Undefined)
  let mut invalid_read = false
  let mut hidden_invalid = false
  let mut recovered_sentinel = false
  for stimulus in bundle.stimulus().stimuli() {
    match stimulus.action() {
      Drive(tap="read_address", value~) if stimulus.cycle() == 19UL =>
        invalid_read = value.to_text() == "11"
      Drive(tap="result_valid", value~) if stimulus.cycle() == 19UL =>
        hidden_invalid = value.to_text() == "0"
      Drive(tap="result_valid", value~) if stimulus.cycle() == 20UL =>
        recovered_sentinel = value.to_text() == "1"
      _ => ()
    }
  }
  assert_true(invalid_read)
  assert_true(hidden_invalid)
  assert_true(recovered_sentinel)
  for observation in bundle.expected().observations() {
    assert_false(observation.value().to_text().contains("X"))
  }
}

///|
test "LowerPortIdWins uses overlapping and disjoint granular masks" {
  let bundle = @phase4.generate_bundle(
    @phase4.FixturePlan::checked(LowerPortIdWins, 88UL, 8),
  )
  let memory = bundle.design().top_module().unwrap().memories()[0]
  assert_eq(memory.write_ports().length(), 2)
  assert_true(memory.write_ports()[0].mask() is Granular(_))
  assert_true(memory.write_ports()[1].mask() is Granular(_))
  let mut disjoint0 = false
  let mut disjoint1 = false
  let mut overlap0 = false
  let mut overlap1 = false
  for stimulus in bundle.stimulus().stimuli() {
    match stimulus.action() {
      Drive(tap="mask0", value~) if stimulus.cycle() == 5UL =>
        disjoint0 = value.to_text() == "0011"
      Drive(tap="mask1", value~) if stimulus.cycle() == 5UL =>
        disjoint1 = value.to_text() == "1100"
      Drive(tap="mask0", value~) if stimulus.cycle() == 6UL =>
        overlap0 = value.to_text() == "0101"
      Drive(tap="mask1", value~) if stimulus.cycle() == 6UL =>
        overlap1 = value.to_text() == "1111"
      _ => ()
    }
  }
  assert_true(disjoint0 && disjoint1 && overlap0 && overlap1)
}

///|
test "external negative bundles drive the declared assertion failures" {
  let kinds : Array[@phase4.NegativeFixtureKind] = [
    FaultOutOfBounds,
    DynamicRejectCollision,
  ]
  for kind in kinds {
    let first = @phase4.generate_negative_bundle(kind)
    let second = @phase4.generate_negative_bundle(kind)
    assert_eq(first.artifacts(), second.artifacts())
    assert_true(first.harness_json().contains("\"stimulus\": \"stimulus.tsv\""))
    assert_true(first.stimulus_tsv().contains("\n0\t"))
    assert_true(first.stimulus_tsv().contains("\n1\t"))
    let mut found_marker = false
    for artifact in first.artifacts() {
      if artifact.path == "expected-failure.txt" {
        found_marker = artifact.content.contains(kind.failure_marker())
      }
    }
    assert_true(found_marker)
  }
}
