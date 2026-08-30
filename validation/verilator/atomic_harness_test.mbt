///|
fn wide_ports() -> ReadOnlyArray[@verilator.HarnessPort] raise {
  ReadOnlyArray::from_array([
    {
      source_name: "source_clock",
      emitted_name: "clock_exact",
      direction: Input,
      width: 1,
      signal_type: Clock,
    },
    {
      source_name: "payload_in",
      emitted_name: "payload_in_exact",
      direction: Input,
      width: 64,
      signal_type: Bits(@ir.Width::new(64)),
    },
    {
      source_name: "payload_out",
      emitted_name: "payload_out_exact",
      direction: Output,
      width: 64,
      signal_type: Bits(@ir.Width::new(64)),
    },
    {
      source_name: "tag_out",
      emitted_name: "tag_out_exact",
      direction: Output,
      width: 5,
      signal_type: UInt(@ir.Width::new(5)),
    },
  ])
}

///|
fn wide_stimulus(
  value : @differential.NormalizedValue,
) -> @verilator.AtomicStimulus raise {
  @verilator.AtomicStimulus::checked(
    3UL,
    [@verilator.StimulusDomain::checked(7, "clock_exact")],
    [
      @verilator.AtomicStimulusEvent::checked(
        9UL,
        4UL,
        [@verilator.AtomicStimulusDrive::checked("payload_in_exact", value)],
        [7],
      ),
    ],
  )
}

///|
test "atomic harness is width-aware through 64 bits and uses exact clock ports" {
  let stimulus = wide_stimulus(
    @verilator.normalized_known(64, 0xfedcba9876543210UL),
  )
  let cpp = @verilator.atomic_harness_cpp(
    wide_ports(),
    stimulus,
    "WIDE-RESULT\n",
    AtomicEdges,
  )
  assert_true(cpp.contains("parse_value(row, 64, value)"))
  assert_true(
    cpp.contains("if (id == 7U) top.clock_exact = 1;\n      else return 68;"),
  )
  assert_true(
    cpp.contains(
      "render_hex(static_cast<std::uint64_t>(top.payload_out_exact), 64)",
    ),
  )
  assert_true(
    cpp.contains("render_hex(static_cast<std::uint64_t>(top.tag_out_exact), 5)"),
  )
  assert_false(cpp.contains("top.payload_out_exact) & 1U"))
  assert_true(cpp.contains("row[3].size() != static_cast<std::size_t>(width)"))
  assert_true(cpp.contains("row[4][static_cast<std::size_t>(index)] != '1'"))
  assert_true(
    cpp.contains(
      "value &= width == 64 ? std::numeric_limits<std::uint64_t>::max() : ((std::uint64_t{1} << width) - 1U);",
    ),
  )
}

///|
test "atomic harness supports a clock-only input surface" {
  let ports : ReadOnlyArray[@verilator.HarnessPort] = ReadOnlyArray::from_array([
      {
        source_name: "clock",
        emitted_name: "clock_exact",
        direction: Input,
        width: 1,
        signal_type: Clock,
      },
      {
        source_name: "observed",
        emitted_name: "observed_exact",
        direction: Output,
        width: 1,
        signal_type: Bits(@ir.Width::new(1)),
      },
    ],
  )
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [@verilator.StimulusDomain::checked(0, "clock_exact")],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [0])],
  )
  let cpp = @verilator.atomic_harness_cpp(
    ports,
    stimulus,
    "CLOCK-ONLY\n",
    AtomicEdges,
  )
  assert_true(cpp.contains("std::uint64_t value = 0;\n      return 67;"))
  assert_false(cpp.contains("std::uint64_t value = 0;\n      else return 67;"))
}

///|
test "clock-only wide output still emits masked hex support" {
  let ports : ReadOnlyArray[@verilator.HarnessPort] = ReadOnlyArray::from_array([
      {
        source_name: "clock",
        emitted_name: "clock_exact",
        direction: Input,
        width: 1,
        signal_type: Clock,
      },
      {
        source_name: "wide_observed",
        emitted_name: "wide_observed_exact",
        direction: Output,
        width: 64,
        signal_type: Bits(@ir.Width::new(64)),
      },
    ],
  )
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [@verilator.StimulusDomain::checked(0, "clock_exact")],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [0])],
  )
  let cpp = @verilator.atomic_harness_cpp(
    ports,
    stimulus,
    "CLOCK-WIDE\n",
    AtomicEdges,
  )
  assert_true(cpp.contains("static std::string render_hex"))
  assert_true(
    cpp.contains(
      "render_hex(static_cast<std::uint64_t>(top.wide_observed_exact), 64)",
    ),
  )
  assert_true(cpp.contains("std::uint64_t value = 0;\n      return 67;"))
}

///|
test "atomic harness escapes unambiguous output names for C++" {
  let ports : ReadOnlyArray[@verilator.HarnessPort] = ReadOnlyArray::from_array([
      {
        source_name: "clock",
        emitted_name: "clock_exact",
        direction: Input,
        width: 1,
        signal_type: Clock,
      },
      {
        source_name: "quote\"slash\\name",
        emitted_name: "observed_exact",
        direction: Output,
        width: 1,
        signal_type: Bits(@ir.Width::new(1)),
      },
    ],
  )
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [@verilator.StimulusDomain::checked(0, "clock_exact")],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [0])],
  )
  let cpp = @verilator.atomic_harness_cpp(
    ports,
    stimulus,
    "OUTPUT-NAME\n",
    AtomicEdges,
  )
  assert_true(cpp.contains("time\\tboundary\\tquote\\\"slash\\\\name\\n"))
  let ambiguous : ReadOnlyArray[@verilator.HarnessPort] = ReadOnlyArray::from_array([
      ports[0],
      {
        source_name: "bad\tname",
        emitted_name: "bad_exact",
        direction: Output,
        width: 1,
        signal_type: Bits(@ir.Width::new(1)),
      },
    ],
  )
  try
    @verilator.atomic_harness_cpp(
      ambiguous,
      stimulus,
      "OUTPUT-NAME\n",
      AtomicEdges,
    )
  catch {
    InvalidAtomicOutputName("bad\tname") => ()
    _ => fail("expected ambiguous output-name rejection")
  } noraise {
    _ => fail("expected ambiguous output-name rejection")
  }
  let duplicate_source : ReadOnlyArray[@verilator.HarnessPort] = ReadOnlyArray::from_array([
      ports[0],
      ports[1],
      {
        source_name: "quote\"slash\\name",
        emitted_name: "other_observed_exact",
        direction: Output,
        width: 1,
        signal_type: Bits(@ir.Width::new(1)),
      },
    ],
  )
  try
    @verilator.atomic_harness_cpp(
      duplicate_source,
      stimulus,
      "OUTPUT-NAME\n",
      AtomicEdges,
    )
  catch {
    DuplicateAtomicOutputName("quote\"slash\\name") => ()
    _ => fail("expected duplicate result-column rejection")
  } noraise {
    _ => fail("expected duplicate result-column rejection")
  }
}

///|
test "atomic result prefix rejects unsafe controls but permits tab and newline" {
  let ports : ReadOnlyArray[@verilator.HarnessPort] = ReadOnlyArray::from_array([
      {
        source_name: "clock",
        emitted_name: "clock_exact",
        direction: Input,
        width: 1,
        signal_type: Clock,
      },
    ],
  )
  let stimulus = @verilator.AtomicStimulus::checked(
    1UL,
    [@verilator.StimulusDomain::checked(0, "clock_exact")],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [0])],
  )
  ignore(
    @verilator.atomic_harness_cpp(
      ports,
      stimulus,
      "SAFE\tPREFIX\n",
      AtomicEdges,
    ),
  )
  let bad_prefix = StringBuilder()
  bad_prefix.write_string("UNSAFE")
  bad_prefix.write_char('\u0001')
  bad_prefix.write_char('\n')
  try
    @verilator.atomic_harness_cpp(
      ports,
      stimulus,
      bad_prefix.to_string(),
      AtomicEdges,
    )
  catch {
    InvalidAtomicResultPrefix(reason="unsafe control character") => ()
    _ => fail("expected unsafe result-prefix control rejection")
  } noraise {
    _ => fail("expected unsafe result-prefix control rejection")
  }
}

///|
test "atomic harness rejects width and clock binding drift" {
  try
    @verilator.atomic_harness_cpp(
      wide_ports(),
      wide_stimulus(@verilator.normalized_known(63, 1UL)),
      "RESULT\n",
      AtomicEdges,
    )
  catch {
    @verilator.HarnessError::AtomicStimulusPortWidthMismatch(
      name="payload_in_exact",
      expected=64,
      actual=63
    ) => ()
    _ => fail("expected exact drive width rejection")
  } noraise {
    _ => fail("expected exact drive width rejection")
  }
  let wrong_clock = @verilator.AtomicStimulus::checked(
    1UL,
    [@verilator.StimulusDomain::checked(7, "payload_in_exact")],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [7])],
  )
  try
    @verilator.atomic_harness_cpp(
      wide_ports(),
      wrong_clock,
      "RESULT\n",
      AtomicEdges,
    )
  catch {
    @verilator.HarnessError::InvalidAtomicStimulusClockPort("payload_in_exact") =>
      ()
    _ => fail("expected exact clock-port rejection")
  } noraise {
    _ => fail("expected exact clock-port rejection")
  }
  let mismatched = wide_ports().iter().to_array()
  mismatched[1] = {
    source_name: "payload_in",
    emitted_name: "payload_in_exact",
    direction: Input,
    width: 63,
    signal_type: Bits(@ir.Width::new(64)),
  }
  try
    @verilator.atomic_harness_cpp(
      ReadOnlyArray::from_array(mismatched),
      wide_stimulus(@verilator.normalized_known(64, 1UL)),
      "RESULT\n",
      AtomicEdges,
    )
  catch {
    @verilator.HarnessError::AtomicPortSignalWidthMismatch(
      name="payload_in_exact",
      port=63,
      signal=64
    ) => ()
    _ => fail("expected port/signal width rejection")
  } noraise {
    _ => fail("expected port/signal width rejection")
  }
  let duplicate = wide_ports().iter().to_array()
  duplicate[3] = {
    source_name: "tag_out",
    emitted_name: "payload_out_exact",
    direction: Output,
    width: 5,
    signal_type: UInt(@ir.Width::new(5)),
  }
  try
    @verilator.atomic_harness_cpp(
      ReadOnlyArray::from_array(duplicate),
      wide_stimulus(@verilator.normalized_known(64, 1UL)),
      "RESULT\n",
      AtomicEdges,
    )
  catch {
    @verilator.HarnessError::DuplicateAtomicPortName("payload_out_exact") => ()
    _ => fail("expected duplicate emitted-name rejection")
  } noraise {
    _ => fail("expected duplicate emitted-name rejection")
  }
  let two_clocks = wide_ports().iter().to_array()
  two_clocks.push({
    source_name: "other_clock",
    emitted_name: "other_clock_exact",
    direction: Input,
    width: 1,
    signal_type: Clock,
  })
  try
    @verilator.atomic_harness_cpp(
      ReadOnlyArray::from_array(two_clocks),
      wide_stimulus(@verilator.normalized_known(64, 1UL)),
      "RESULT\n",
      AtomicEdges,
    )
  catch {
    @verilator.HarnessError::MissingAtomicClockDomain("other_clock_exact") => ()
    _ => fail("expected undeclared clock-input rejection")
  } noraise {
    _ => fail("expected undeclared clock-input rejection")
  }
}
