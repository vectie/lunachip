///|
fn cli_test_digest() -> @replay.ReplayDigest raise {
  @replay.ReplayDigest::checked("fnv1a-64", "0000000000000000")
}

///|
fn cli_test_legacy_bundle(
  stop : @replay.StopCondition,
  expected : @replay.ReplayDigest,
) -> @replay.ReplayBundle raise {
  let width = @ir.Width::new(4)
  let clock = @ir.NodeId::new(0)
  let input = @ir.NodeId::new(1)
  let one = @ir.NodeId::new(2)
  let sum = @ir.NodeId::new(3)
  let hardware_module = @ir.Module::checked(
    "legacy",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(input, UInt(width), Input("x")),
      @ir.Node::new(one, UInt(width), Constant(1UL)),
      @ir.Node::new(sum, UInt(width), Add(input, one)),
    ],
    [@ir.OutputPort::new("y", UInt(width), sum)],
  )
  @replay.ReplayBundle::checked(
    @ir.Design::single("cli-legacy", hardware_module),
    "lunachip-semantics/1",
    [],
    [
      @replay.ReplayStimulus::drive(0UL, 0UL, [
        @replay.NamedInput::checked(
          "x",
          @wave.LogicValue::from_uint64(width=4, value=3UL),
        ),
      ]),
      @replay.ReplayStimulus::rising_edge(0UL, 1UL, "clock"),
    ],
    stop,
    [@trace.TraceSignal::checked("legacy", "y", 4)],
    expected,
  )
}

///|
fn cli_test_atomic_bundle(
  expected : @replay.ReplayDigest,
) -> @replay.ReplayBundle raise {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let probe = @ir.NodeId::new(2)
  let next_a = @ir.NodeId::new(3)
  let next_b = @ir.NodeId::new(4)
  let state_a = @ir.NodeId::new(5)
  let state_b = @ir.NodeId::new(6)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let eight = @ir.SignalType::UInt(@ir.Width::new(8))
  let hardware_module = @ir.Module::checked_with_metadata(
    "atomic",
    [domain_a, domain_b],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(probe, eight, Input("probe")),
      @ir.Node::new(next_a, eight, Constant(3UL)),
      @ir.Node::new(next_b, eight, Constant(4UL)),
      @ir.Node::new(
        state_a,
        eight,
        Register(@ir.RegisterSpec::new(domain_a, next_a, initial=1UL)),
      ),
      @ir.Node::new(
        state_b,
        eight,
        Register(@ir.RegisterSpec::new(domain_b, next_b, initial=2UL)),
      ),
    ],
    [],
    [
      @ir.OutputPort::new("probe_out", eight, probe),
      @ir.OutputPort::new("state_a", eight, state_a),
      @ir.OutputPort::new("state_b", eight, state_b),
    ],
    @ir.ModuleMetadata::checked_with_timing(
      [],
      [],
      [@ir.InputTimingBinding::new(probe, Asynchronous)],
      [
        @ir.OutputTimingBinding::checked("probe_out", Asynchronous),
        @ir.OutputTimingBinding::checked("state_a", ProducedIn(domain_a.id())),
        @ir.OutputTimingBinding::checked("state_b", ProducedIn(domain_b.id())),
      ],
    ),
  )
  @replay.ReplayBundle::checked_atomic(
    @ir.Design::single("cli-atomic", hardware_module),
    "lunachip-semantics/2",
    [],
    6UL,
    [
      @replay.AtomicReplayEvent::checked(
        5UL,
        1UL,
        [
          @replay.NamedInput::checked(
            "probe",
            @wave.LogicValue::from_masks(
              width=8,
              value_bits=3UL,
              known_mask=3UL,
            ),
          ),
        ],
        [domain_a.id(), domain_b.id()],
      ),
    ],
    AfterBoundary(1UL),
    [
      @trace.TraceSignal::checked("atomic", "probe_out", 8),
      @trace.TraceSignal::checked("atomic", "state_a", 8),
      @trace.TraceSignal::checked("atomic", "state_b", 8),
    ],
    expected,
  )
}

///|
// Only create a previously absent test-owned directory. Never reuse or clear
// stale directories from another run. Simulation artifacts do not depend on it.
fn cli_test_directory(label : String) -> String raise {
  for index in 0..<1024 {
    let directory = ".lunawave-cli-test-\{label}-\{index}"
    if @fs.path_exists(directory) {
      continue
    }
    try @fs.create_dir(directory) catch {
      error => if !@fs.path_exists(directory) { raise error }
    } noraise {
      _ => return directory
    }
  }
  fail("no fresh LunaWave CLI test directory")
}

///|
fn cli_test_cleanup(directory : String) -> Unit raise {
  // These exact names are only created below the directory owned by this test.
  for
    suffix in [
      "/input.replay", "/out/trace.txt", "/out/trace.vcd", "/out/sentinel",
    ] {
    let path = directory + suffix
    if @fs.path_exists(path) {
      @fs.remove_file(path)
    }
  }
  if @fs.path_exists(directory + "/out") {
    if @fs.is_dir(directory + "/out") {
      @fs.remove_dir(directory + "/out")
    } else {
      @fs.remove_file(directory + "/out")
    }
  }
  @fs.remove_dir(directory)
}

///|
fn cli_test_with_directory(
  label : String,
  body : (String) -> Unit raise,
) -> Unit raise {
  let directory = cli_test_directory(label)
  defer cli_test_cleanup(directory)
  body(directory)
}

///|
fn cli_test_write_bundle(
  directory : String,
  bundle : @replay.ReplayBundle,
) -> Unit raise {
  @fs.write_string_to_file(
    directory + "/input.replay",
    @replay.serialize(bundle),
  )
}

///|
fn cli_test_artifacts(
  directory : String,
  result : @replay.ReplayResult,
) -> Unit raise {
  let files = @fs.read_dir(directory + "/out")
  files.sort()
  assert_eq(files, ["trace.txt", "trace.vcd"])
  assert_eq(
    @fs.read_file_to_string(directory + "/out/trace.txt"),
    @trace.serialize(result.trace()),
  )
  assert_eq(
    @fs.read_file_to_string(directory + "/out/trace.vcd"),
    @trace.to_vcd(result.trace()),
  )
}
