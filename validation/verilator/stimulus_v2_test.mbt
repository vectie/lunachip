///|
fn contract_value(bits : String) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::from_planes(bits, "1".repeat(bits.length()))
}

///|
fn canonical_atomic_stimulus() -> @verilator.AtomicStimulus raise {
  @verilator.AtomicStimulus::checked(
    6UL,
    [
      @verilator.StimulusDomain::checked(0, "clock_a"),
      @verilator.StimulusDomain::checked(3, "clock_b"),
    ],
    [
      @verilator.AtomicStimulusEvent::checked(
        0UL,
        0UL,
        [
          @verilator.AtomicStimulusDrive::checked("reset", contract_value("1")),
          @verilator.AtomicStimulusDrive::checked(
            "input_value",
            contract_value("0011"),
          ),
        ],
        [0, 3],
      ),
      @verilator.AtomicStimulusEvent::checked(
        3UL,
        1UL,
        [
          @verilator.AtomicStimulusDrive::checked(
            "input_value",
            contract_value("1010"),
          ),
        ],
        [0],
      ),
    ],
  )
}

///|
test "schema-v2 stimulus has exact canonical bytes and coincident edges" {
  let stimulus = canonical_atomic_stimulus()
  let expected =
    #|LUNACHIP-VERILATOR-STIMULUS	2
    #|TIMEBASE	6
    #|DOMAINS	2
    #|DOMAIN	0	clock_a	rising
    #|DOMAIN	3	clock_b	rising
    #|EVENTS	2
    #|EVENT	0	0	0	2	2
    #|DRIVE	input_value	4	0011	1111
    #|DRIVE	reset	1	1	1
    #|DOMAIN	0
    #|DOMAIN	3
    #|EVENT	1	3	1	1	1
    #|DRIVE	input_value	4	1010	1111
    #|DOMAIN	0
    #|END
    #|
  assert_eq(stimulus.to_tsv(), expected)
  let parsed = @verilator.parse_atomic_stimulus(expected)
  assert_eq(parsed, stimulus)
  assert_eq(parsed.events()[0].domains().length(), 2)
}

///|
test "schema-v2 parser rejects malformed and noncanonical records" {
  let canonical = canonical_atomic_stimulus().to_tsv()
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(
        old="LUNACHIP-VERILATOR-STIMULUS\t2",
        new="LUNACHIP-VERILATOR-STIMULUS\t3",
      ),
    )
  catch {
    UnsupportedStimulusVersion("3") => ()
    _ => fail("expected unsupported version")
  } noraise {
    _ => fail("expected unsupported version")
  }
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(old="TIMEBASE\t6", new="TIMEBASE\t06"),
    )
  catch {
    NonCanonicalStimulus => ()
    _ => fail("expected noncanonical integer spelling")
  } noraise {
    _ => fail("expected noncanonical integer spelling")
  }
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(
        old="DRIVE\tinput_value\t4\t0011\t1111\nDRIVE\treset\t1\t1\t1",
        new="DRIVE\treset\t1\t1\t1\nDRIVE\tinput_value\t4\t0011\t1111",
      ),
    )
  catch {
    NonCanonicalStimulus => ()
    _ => fail("expected noncanonical drive order")
  } noraise {
    _ => fail("expected noncanonical drive order")
  }
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(old="DRIVE\treset\t1\t1\t1\n", new=""),
    )
  catch {
    InvalidStimulusLine(..) => ()
    _ => fail("expected malformed member count")
  } noraise {
    _ => fail("expected malformed member count")
  }
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(
        old="DOMAIN\t0\tclock_a\trising\nDOMAIN\t3\tclock_b\trising",
        new="DOMAIN\t3\tclock_b\trising\nDOMAIN\t0\tclock_a\trising",
      ),
    )
  catch {
    NonCanonicalStimulusDomainOrder(previous=3, actual=0) => ()
    _ => fail("expected reordered sparse declarations to fail")
  } noraise {
    _ => fail("expected reordered sparse declaration rejection")
  }
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(
        old="DOMAIN\t0\nDOMAIN\t3\nEVENT\t1",
        new="DOMAIN\t3\nDOMAIN\t0\nEVENT\t1",
      ),
    )
  catch {
    NonCanonicalStimulus => ()
    _ => fail("expected reordered sparse event IDs to fail")
  } noraise {
    _ => fail("expected reordered sparse event ID rejection")
  }
  try
    @verilator.parse_atomic_stimulus(
      canonical.replace(
        old="DOMAIN\t0\nDOMAIN\t3\nEVENT\t1",
        new="DOMAIN\t0\nDOMAIN\t5\nEVENT\t1",
      ),
    )
  catch {
    UnknownAtomicStimulusDomain(5) => ()
    _ => fail("expected unknown sparse event ID to fail")
  } noraise {
    _ => fail("expected unknown sparse event ID rejection")
  }
}

///|
test "schema-v2 rejects duplicate domains drives and split coincident time" {
  try
    @verilator.AtomicStimulusEvent::checked(
      0UL,
      0UL,
      [
        @verilator.AtomicStimulusDrive::checked("x", contract_value("0")),
        @verilator.AtomicStimulusDrive::checked("x", contract_value("1")),
      ],
      [],
    )
  catch {
    @verilator.StimulusContractError::DuplicateAtomicStimulusDrive("x") => ()
    _ => fail("expected duplicate drive")
  } noraise {
    _ => fail("expected duplicate drive")
  }
  try @verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [0, 0]) catch {
    DuplicateAtomicStimulusDomain(0) => ()
    _ => fail("expected duplicate domain")
  } noraise {
    _ => fail("expected duplicate domain")
  }
  try
    @verilator.AtomicStimulus::checked(
      1UL,
      [
        @verilator.StimulusDomain::checked(0, "clock_a"),
        @verilator.StimulusDomain::checked(3, "clock_b"),
      ],
      [
        @verilator.AtomicStimulusEvent::checked(2UL, 0UL, [], [0]),
        @verilator.AtomicStimulusEvent::checked(2UL, 1UL, [], [3]),
      ],
    )
  catch {
    NonMonotonicAtomicStimulusTime(previous=2UL, actual=2UL) => ()
    _ => fail("expected coincident events to require one atomic batch")
  } noraise {
    _ => fail("expected coincident event rejection")
  }
}

///|
test "schema-v2 rejects bad order unknown domains and unknown values" {
  let domains = [
    @verilator.StimulusDomain::checked(0, "clock_a"),
    @verilator.StimulusDomain::checked(3, "clock_b"),
  ]
  try @verilator.AtomicStimulus::checked(1UL, [], []) catch {
    EmptyStimulusDomains => ()
    _ => fail("expected empty domain rejection")
  } noraise {
    _ => fail("expected empty domain rejection")
  }
  let sparse = @verilator.AtomicStimulus::checked(
    1UL,
    [
      @verilator.StimulusDomain::checked(10, "clock_c"),
      @verilator.StimulusDomain::checked(5, "clock_b"),
    ],
    [@verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [5, 10])],
  )
  assert_eq(sparse.domains()[0].id(), 5)
  assert_eq(sparse.domains()[1].id(), 10)
  try
    @verilator.AtomicStimulus::checked(
      1UL,
      [
        @verilator.StimulusDomain::checked(5, "clock_b"),
        @verilator.StimulusDomain::checked(5, "clock_c"),
      ],
      [],
    )
  catch {
    DuplicateStimulusDomainId(5) => ()
    _ => fail("expected duplicate sparse domain ID")
  } noraise {
    _ => fail("expected duplicate sparse domain ID rejection")
  }
  try
    @verilator.AtomicStimulus::checked(
      1UL,
      [
        @verilator.StimulusDomain::checked(0, "clock"),
        @verilator.StimulusDomain::checked(3, "clock"),
      ],
      [],
    )
  catch {
    DuplicateStimulusClockPort("clock") => ()
    _ => fail("expected unique clock ports")
  } noraise {
    _ => fail("expected duplicate clock port rejection")
  }
  try
    @verilator.AtomicStimulus::checked(1UL, domains, [
      @verilator.AtomicStimulusEvent::checked(2UL, 2UL, [], [0]),
      @verilator.AtomicStimulusEvent::checked(3UL, 1UL, [], [3]),
    ])
  catch {
    NonMonotonicAtomicStimulusBoundary(previous=2UL, actual=1UL) => ()
    _ => fail("expected boundary ordering failure")
  } noraise {
    _ => fail("expected boundary ordering failure")
  }
  try
    @verilator.AtomicStimulus::checked(1UL, domains, [
      @verilator.AtomicStimulusEvent::checked(0UL, 0UL, [], [2]),
    ])
  catch {
    UnknownAtomicStimulusDomain(2) => ()
    _ => fail("expected unknown domain")
  } noraise {
    _ => fail("expected unknown domain")
  }
  try
    @verilator.AtomicStimulusDrive::checked(
      "x",
      @differential.NormalizedValue::from_planes("0", "0"),
    )
  catch {
    @verilator.StimulusContractError::UnknownVerilatorStimulusValue(name="x") =>
      ()
    _ => fail("expected two-state unknown rejection")
  } noraise {
    _ => fail("expected unknown value rejection")
  }
}
