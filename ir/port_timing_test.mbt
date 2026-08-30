///|
fn timing_uint(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn input_timing(
  input : Int,
  timing : @ir.InputTiming,
) -> @ir.InputTimingBinding raise @ir.IrError {
  @ir.InputTimingBinding::new(@ir.NodeId::new(input), timing)
}

///|
fn output_timing(
  output : String,
  timing : @ir.OutputTiming,
) -> @ir.OutputTimingBinding raise @ir.IrError {
  @ir.OutputTimingBinding::checked(output, timing)
}

///|
fn timing_metadata(
  inputs : ArrayView[@ir.InputTimingBinding],
  outputs : ArrayView[@ir.OutputTimingBinding],
) -> @ir.ModuleMetadata raise @ir.IrError {
  @ir.ModuleMetadata::checked_with_timing([], [], inputs, outputs)
}

///|
test "port timing metadata canonicalizes sparse domains and includes Reset" {
  let uint8 = timing_uint(8)
  let clock_a = @ir.NodeId::new(0)
  let data = @ir.NodeId::new(1)
  let reset = @ir.NodeId::new(2)
  let constant = @ir.NodeId::new(3)
  let clock_b = @ir.NodeId::new(4)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  assert_eq(domain_b.id().ordinal(), 4)
  let metadata = timing_metadata(
    [
      input_timing(reset.ordinal(), Asynchronous),
      input_timing(data.ordinal(), SampledIn(domain_b.id())),
    ],
    [
      output_timing("静的🔥", Static),
      output_timing("result", ProducedIn(domain_b.id())),
    ],
  )
  let hardware_module = @ir.Module::checked_with_metadata(
    "Timed",
    [domain_b, domain_a],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(data, uint8, Input("data")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(constant, uint8, Constant(0UL)),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
    ],
    [],
    [
      @ir.OutputPort::new("result", uint8, data),
      @ir.OutputPort::new("静的🔥", uint8, constant),
    ],
    metadata,
  )
  assert_eq(hardware_module.domains().map(item => item.id().ordinal()), [0, 4])
  assert_eq(
    hardware_module.input_timings().map(item => item.input().ordinal()),
    [1, 2],
  )
  assert_eq(hardware_module.input_timings().map(item => item.timing()), [
    SampledIn(domain_b.id()),
    Asynchronous,
  ])
  assert_eq(hardware_module.output_timings().map(item => item.output()), [
    "result", "静的🔥",
  ])
  assert_eq(hardware_module.output_timings().map(item => item.timing()), [
    ProducedIn(domain_b.id()),
    Static,
  ])
  assert_true(hardware_module.metadata().declares_port_timing())
  assert_false(hardware_module.metadata().is_empty())
}

///|
test "timing metadata rejects duplicate keys and empty output names" {
  let domain = @ir.ClockDomainId::new(3)
  try
    timing_metadata(
      [input_timing(2, Asynchronous), input_timing(2, SampledIn(domain))],
      [],
    )
  catch {
    DuplicateInputTiming(input~) => assert_eq(input, 2)
    error => fail("unexpected duplicate input timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate input timing rejection")
  }
  try
    timing_metadata([], [
      output_timing("same", Static),
      output_timing("same", Asynchronous),
    ])
  catch {
    DuplicateOutputTiming(output) => assert_eq(output, "same")
    error => fail("unexpected duplicate output timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate output timing rejection")
  }
  try output_timing("", Static) catch {
    EmptyName(kind~) => assert_eq(kind, "timed output")
    error => fail("unexpected empty timed output error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty timed output rejection")
  }
}

///|
fn completeness_module(
  metadata : @ir.ModuleMetadata,
) -> @ir.Module raise @ir.IrError {
  let clock = @ir.NodeId::new(0)
  let data = @ir.NodeId::new(1)
  let reset = @ir.NodeId::new(2)
  let ty = timing_uint(8)
  let domain = @ir.ClockDomain::rising(clock)
  @ir.Module::checked_with_metadata(
    "Completeness",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(data, ty, Input("data")),
      @ir.Node::new(reset, Reset, Input("reset")),
    ],
    [],
    [@ir.OutputPort::new("result", ty, data)],
    metadata,
  )
}

///|
test "declaring any timing makes every non-Clock port timing complete" {
  let domain = @ir.ClockDomainId::new(0)
  try
    completeness_module(
      timing_metadata([input_timing(1, SampledIn(domain))], [
        output_timing("result", ProducedIn(domain)),
      ]),
    )
  catch {
    MissingInputTiming(input) => assert_eq(input, 2)
    error => fail("unexpected missing input timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing Reset timing rejection")
  }
  try
    completeness_module(
      timing_metadata(
        [input_timing(1, SampledIn(domain)), input_timing(2, Asynchronous)],
        [],
      ),
    )
  catch {
    MissingOutputTiming(output) => assert_eq(output, "result")
    error => fail("unexpected missing output timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing output timing rejection")
  }
  let complete = completeness_module(
    timing_metadata(
      [input_timing(1, SampledIn(domain)), input_timing(2, Asynchronous)],
      [output_timing("result", ProducedIn(domain))],
    ),
  )
  assert_eq(complete.input_timings().length(), 2)
  assert_eq(complete.output_timings().length(), 1)
}

///|
test "legacy empty metadata remains valid and carries no inferred timing" {
  let legacy = completeness_module(@ir.ModuleMetadata::empty())
  assert_true(legacy.metadata().is_empty())
  assert_false(legacy.metadata().declares_port_timing())
  assert_true(legacy.input_timings().is_empty())
  assert_true(legacy.output_timings().is_empty())
}

///|
fn module_rejecting_input_binding(
  binding : @ir.InputTimingBinding,
) -> @ir.Module raise @ir.IrError {
  let clock = @ir.NodeId::new(0)
  let constant = @ir.NodeId::new(1)
  let domain = @ir.ClockDomain::rising(clock)
  let ty = timing_uint(8)
  @ir.Module::checked_with_metadata(
    "InvalidInputTiming",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(constant, ty, Constant(0UL)),
    ],
    [],
    [],
    timing_metadata([binding], []),
  )
}

///|
test "input timing validates node role Clock exclusion and domain identity" {
  try module_rejecting_input_binding(input_timing(9, Asynchronous)) catch {
    UnknownInputTimingNode(input) => assert_eq(input, 9)
    error => fail("unexpected unknown timed input error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown timed input rejection")
  }
  try module_rejecting_input_binding(input_timing(1, Asynchronous)) catch {
    InputTimingOnNonInput(input) => assert_eq(input, 1)
    error => fail("unexpected non-input timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-input timing rejection")
  }
  try module_rejecting_input_binding(input_timing(0, Asynchronous)) catch {
    InputTimingOnClock(input) => assert_eq(input, 0)
    error => fail("unexpected Clock timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected Clock timing rejection")
  }
  let clock = @ir.NodeId::new(0)
  let data = @ir.NodeId::new(1)
  let domain = @ir.ClockDomain::rising(clock)
  try
    @ir.Module::checked_with_metadata(
      "UnknownInputDomain",
      [domain],
      [
        @ir.Node::new(clock, Clock, Input("clock")),
        @ir.Node::new(data, timing_uint(8), Input("data")),
      ],
      [],
      [],
      timing_metadata([input_timing(1, SampledIn(@ir.ClockDomainId::new(7)))], []),
    )
  catch {
    UnknownInputTimingDomain(input~, domain=actual) => {
      assert_eq(input, 1)
      assert_eq(actual, 7)
    }
    error => fail("unexpected input domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown input timing domain rejection")
  }
}

///|
fn module_rejecting_output_binding(
  binding : @ir.OutputTimingBinding,
  clock_output : Bool,
) -> @ir.Module raise @ir.IrError {
  let clock = @ir.NodeId::new(0)
  let data = @ir.NodeId::new(1)
  let domain = @ir.ClockDomain::rising(clock)
  let ty = timing_uint(8)
  let output = if clock_output {
    @ir.OutputPort::new("clock_out", Clock, clock)
  } else {
    @ir.OutputPort::new("result", ty, data)
  }
  @ir.Module::checked_with_metadata(
    "InvalidOutputTiming",
    [domain],
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(data, ty, Constant(0UL)),
    ],
    [],
    [output],
    timing_metadata([], [binding]),
  )
}

///|
test "output timing validates exact port Clock exclusion and domain identity" {
  try
    module_rejecting_output_binding(output_timing("missing", Static), false)
  catch {
    UnknownTimedOutput(output) => assert_eq(output, "missing")
    error => fail("unexpected unknown timed output error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown timed output rejection")
  }
  try
    module_rejecting_output_binding(
      output_timing("clock_out", Asynchronous),
      true,
    )
  catch {
    OutputTimingOnClock(output) => assert_eq(output, "clock_out")
    error => fail("unexpected Clock output timing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected Clock output timing rejection")
  }
  try
    module_rejecting_output_binding(
      output_timing("result", ProducedIn(@ir.ClockDomainId::new(11))),
      false,
    )
  catch {
    UnknownOutputTimingDomain(output~, domain~) => {
      assert_eq(output, "result")
      assert_eq(domain, 11)
    }
    error => fail("unexpected output domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown output timing domain rejection")
  }
}
