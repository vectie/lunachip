///|
fn replay_design() -> @ir.Design raise {
  let width = @ir.Width::new(4)
  let clock_id = @ir.NodeId::new(0)
  let input_id = @ir.NodeId::new(1)
  let constant_id = @ir.NodeId::new(2)
  let sum_id = @ir.NodeId::new(3)
  let hardware_module = @ir.Module::checked(
    "top",
    [
      @ir.Node::new(clock_id, Clock, Input("clk")),
      @ir.Node::new(input_id, UInt(width), Input("x")),
      @ir.Node::new(constant_id, UInt(width), Constant(1)),
      @ir.Node::new(sum_id, UInt(width), Add(input_id, constant_id)),
    ],
    [@ir.OutputPort::new("y", UInt(width), sum_id)],
  )
  @ir.Design::single("replay", hardware_module)
}

///|
fn replay_bundle() -> @replay.ReplayBundle raise {
  let stimulus = @replay.ReplayStimulus::drive(0, 0, [
    @replay.NamedInput::checked(
      "x",
      @wave.LogicValue::from_uint64(width=4, value=3),
    ),
  ])
  let edge = @replay.ReplayStimulus::rising_edge(0, 1, "clk")
  @replay.ReplayBundle::checked(
    replay_design(),
    "lunachip-semantics/1",
    [
      @replay.ReplayOption::checked("unknown-policy", "conservative"),
      @replay.ReplayOption::checked("arithmetic", "width-bounded"),
    ],
    [stimulus, edge],
    AtCycle(1),
    [
      @trace.TraceSignal::checked("top", "y", 4),
      @trace.TraceSignal::checked("top", "x", 4),
    ],
    @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000"),
  )
}

///|
test "canonical replay artifact is byte-stable and round trips" {
  let encoded = @replay.serialize(replay_bundle())
  inspect(
    encoded,
    content=(
      #|LUNACHIP-REPLAY 1
      #|SEMANTICS 6c756e61636869702d73656d616e746963732f31
      #|OPTIONS 2
      #|OPTION 61726974686d65746963 77696474682d626f756e646564
      #|OPTION 756e6b6e6f776e2d706f6c696379 636f6e736572766174697665
      #|IR fnv1a-64 e4e6f4b984d93d10 4c554e41434849502d495220320a44455349474e203732363537303663363137390a544f50203734366637300a4d4f44554c455320310a4d4f44554c45203734366637300a4e4f44455320340a4e4f4445203020636c6f636b20696e707574203633366336620a4e4f444520312075696e743a3420696e7075742037380a4e4f444520322075696e743a3420636f6e737420310a4e4f444520332075696e743a3420616464203120320a4f55545055545320310a4f55545055542037392075696e743a3420330a454e444d4f44554c450a454e440a
      #|STIMULI 2
      #|DRIVE 0 0 1
      #|INPUT 78 4 3 15
      #|EDGE 0 1 636c6b
      #|STOP at_cycle 1
      #|TAPS 2
      #|TAP 4 746f70 78
      #|TAP 4 746f70 79
      #|EXPECTED fnv1a-64 0000000000000000
      #|END
      #|
    ),
  )
  assert_eq(@replay.serialize(@replay.parse(encoded)), encoded)
}

///|
test "replay parser rejects digest tampering and noncanonical text" {
  let bundle = replay_bundle()
  let encoded = @replay.serialize(bundle)
  let tampered = encoded.replace(
    old=bundle.ir_digest().hex(),
    new="0000000000000000",
  )
  try @replay.parse(tampered) catch {
    IrDigestMismatch(..) => ()
    error => fail("unexpected digest error: \{Repr(error)}")
  } noraise {
    _ => fail("expected IR digest rejection")
  }
  let truncated = encoded[:encoded.length() - 1].to_owned()
  try @replay.parse(truncated) catch {
    NonCanonical => ()
    error => fail("unexpected canonicality error: \{Repr(error)}")
  } noraise {
    _ => fail("expected trailing-newline rejection")
  }
}

///|
test "replay construction rejects ordering and duplicate names" {
  let late = @replay.ReplayStimulus::rising_edge(1, 0, "clk")
  let early = @replay.ReplayStimulus::rising_edge(0, 0, "clk")
  let design = replay_design()
  let digest = @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000")
  try
    @replay.ReplayBundle::checked(
      design,
      "semantics/1",
      [],
      [late, early],
      AtCycle(1),
      [],
      digest,
    )
  catch {
    NonMonotonicStimulus => ()
    error => fail("unexpected ordering error: \{Repr(error)}")
  } noraise {
    _ => fail("expected ordering rejection")
  }
  let zero = @replay.NamedInput::checked("x", @wave.LogicValue::zero(width=1))
  let one = @replay.NamedInput::checked("x", @wave.LogicValue::one(width=1))
  try @replay.ReplayStimulus::drive(0, 0, [zero, one]) catch {
    DuplicateInput("x") => ()
    error => fail("unexpected duplicate error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate input rejection")
  }
}

///|
test "trace result digest is fixed-width and byte-stable" {
  let trace = @trace.parse(
    (
      #|LUNACHIP-TRACE 1
      #|SIGNALS 1
      #|SIGNAL 0 1 746f70 61
      #|FRAMES 1
      #|FRAME 0 0 initial - 1
      #|CHANGE 0 0 0
      #|END
      #|
    ),
  )
  debug_inspect(
    @replay.trace_result_digest(trace),
    content=(
      #|{ algorithm: "fnv1a-64", hex: "3971ed187e396af3" }
    ),
  )
}

///|
test "replay execution reproduces event trace and mismatch digest" {
  let first = @replay.execute(replay_bundle())
  let second = @replay.execute(replay_bundle())
  assert_true(first.stop_reached())
  assert_false(first.expected_matches())
  assert_eq(first.digest(), second.digest())
  assert_eq(@trace.serialize(first.trace()), @trace.serialize(second.trace()))
  inspect(first.trace().frames().length(), content="3")
  inspect(first.trace().frames()[2].cycle(), content="1")
}
