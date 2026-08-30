///|
fn atomic_trace_digest() -> @trace.TraceDigest raise {
  @trace.TraceDigest::checked("fnv1a-64", "0123456789abcdef")
}

///|
fn atomic_trace_change(
  index : Int,
  width : Int,
  value : UInt64,
) -> @trace.TraceChange raise {
  @trace.TraceChange::new(index, @wave.LogicValue::from_uint64(width~, value~))
}

///|
fn atomic_trace_fixture() -> @trace.Trace raise {
  @trace.Trace::checked_atomic(
    "semantics/2",
    atomic_trace_digest(),
    6UL,
    [
      @trace.TraceDomain::checked(1, "clock_b"),
      @trace.TraceDomain::checked(0, "clock_a"),
    ],
    [
      @trace.TraceSignal::checked("top", "a", 1),
      @trace.TraceSignal::checked("top", "data", 4),
    ],
    [
      @trace.AtomicTraceFrame::checked(0UL, 0UL, AtomicInitial, [], [], [
        atomic_trace_change(1, 4, 3UL),
        @trace.TraceChange::new(0, @wave.LogicValue::unknown(width=1)),
      ]),
      @trace.AtomicTraceFrame::checked(
        3UL,
        1UL,
        AtomicBatch,
        ["z", "a"],
        [1, 0],
        [atomic_trace_change(1, 4, 5UL)],
      ),
      @trace.AtomicTraceFrame::checked(
        3UL,
        2UL,
        AtomicMarker("checkpoint"),
        [],
        [],
        [],
      ),
      @trace.AtomicTraceFrame::checked(7UL, 3UL, AtomicBatch, [], [1], [
        atomic_trace_change(0, 1, 1UL),
      ]),
    ],
  )
}

///|
test "schema 2 exact-time trace has a byte-stable full envelope" {
  let trace = atomic_trace_fixture()
  assert_eq(trace.schema(), Atomic2)
  assert_eq(trace.timebase(), Some(6UL))
  assert_eq(trace.domains()[0].id(), 0)
  assert_eq(trace.atomic_frames()[1].drives()[0], "a")
  assert_eq(trace.atomic_frames()[1].active_domains()[0], 0)
  let encoded = @trace.serialize(trace)
  inspect(
    encoded,
    content=(
      #|LUNACHIP-TRACE 2
      #|SEMANTICS 73656d616e746963732f32
      #|IR fnv1a-64 0123456789abcdef
      #|TIMEBASE 6
      #|DOMAINS 2
      #|DOMAIN 0 636c6f636b5f61
      #|DOMAIN 1 636c6f636b5f62
      #|SIGNALS 2
      #|SIGNAL 0 1 746f70 61
      #|SIGNAL 1 4 746f70 64617461
      #|FRAMES 4
      #|TOTALS 2 3 4
      #|FRAME 0 0 initial - 0 0 2
      #|CHANGE 0 0 0
      #|CHANGE 1 3 15
      #|FRAME 3 1 batch - 2 2 1
      #|DRIVE 61
      #|DRIVE 7a
      #|ACTIVE 0
      #|ACTIVE 1
      #|CHANGE 1 5 15
      #|FRAME 3 2 marker 636865636b706f696e74 0 0 0
      #|FRAME 7 3 batch - 0 1 1
      #|ACTIVE 1
      #|CHANGE 0 1 1
      #|END
      #|
    ),
  )
  assert_eq(@trace.serialize(@trace.parse(encoded)), encoded)
  assert_eq(@trace.serialize(atomic_trace_fixture()), encoded)
}

///|
test "schema 2 VCD uses actual normalized time and deterministic batch comments" {
  let vcd = @trace.to_vcd(atomic_trace_fixture())
  inspect(
    vcd,
    content=(
      #|$version LunaChip LunaWave trace schema 2 $end
      #|$timescale 1ps $end
      #|$comment lunachip_timebase=6 normalized_ticks_per_source_unit vcd_unit=one_normalized_tick display_timescale=1ps_not_physical $end
      #|$comment domain=0 clock=636c6f636b5f61 $end
      #|$comment domain=1 clock=636c6f636b5f62 $end
      #|$scope module lunachip $end
      #|$var wire 1 s0 lunachip_746f70__61 $end
      #|$var wire 4 s1 lunachip_746f70__64617461 $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0
      #|$comment time=0 boundary=0 event=initial argument=- drives=- domains=- domain_counts=0:0,1:0 $end
      #|xs0
      #|b0011 s1
      #|#3
      #|$comment time=3 boundary=1 event=batch argument=- drives=61,7a domains=0,1 domain_counts=0:1,1:1 $end
      #|b0101 s1
      #|$comment time=3 boundary=2 event=marker argument=636865636b706f696e74 drives=- domains=- domain_counts=0:1,1:1 $end
      #|#7
      #|$comment time=7 boundary=3 event=batch argument=- drives=- domains=1 domain_counts=0:1,1:2 $end
      #|1s0
      #|
    ),
  )
  assert_eq(@trace.to_vcd(atomic_trace_fixture()), vcd)
  assert_false(vcd.contains("cycle="))
  assert_true(vcd.contains("#3\n"))
  assert_true(vcd.contains("#7\n"))
  assert_false(vcd.contains("#6\n"))
}

///|
test "schema 2 parser rejects ordering duplicates unknown domains and zero timebase" {
  let encoded = @trace.serialize(atomic_trace_fixture())
  let reversed_drives = encoded.replace(
    old="DRIVE 61\nDRIVE 7a\n",
    new="DRIVE 7a\nDRIVE 61\n",
  )
  try @trace.parse(reversed_drives) catch {
    NonCanonical => ()
    error => fail("unexpected drive-order error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reordered drives to be noncanonical")
  }
  let duplicate_domain = encoded.replace(old="ACTIVE 1\n", new="ACTIVE 0\n")
  try @trace.parse(duplicate_domain) catch {
    DuplicateActiveTraceDomain(0) => ()
    error => fail("unexpected duplicate-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate active domain rejection")
  }
  let unknown_domain = encoded.replace(
    old="FRAME 7 3 batch - 0 1 1\nACTIVE 1\n",
    new="FRAME 7 3 batch - 0 1 1\nACTIVE 9\n",
  )
  try @trace.parse(unknown_domain) catch {
    UnknownActiveTraceDomain(9) => ()
    error => fail("unexpected unknown-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown active domain rejection")
  }
  let zero_timebase = encoded.replace(old="TIMEBASE 6\n", new="TIMEBASE 0\n")
  try @trace.parse(zero_timebase) catch {
    InvalidTraceTimebase(0UL) => ()
    error => fail("unexpected timebase error: \{Repr(error)}")
  } noraise {
    _ => fail("expected zero timebase rejection")
  }
  let repeated_boundary = encoded.replace(
    old="FRAME 7 3 batch",
    new="FRAME 7 2 batch",
  )
  try @trace.parse(repeated_boundary) catch {
    NonMonotonicAtomicBoundary(previous=2UL, actual=2UL) => ()
    error => fail("unexpected boundary error: \{Repr(error)}")
  } noraise {
    _ => fail("expected repeated boundary rejection")
  }
}

///|
test "schema 2 parser enforces explicit resource limits before allocation" {
  let oversized_signals =
    #|LUNACHIP-TRACE 2
    #|SEMANTICS 73
    #|IR fnv1a-64 0123456789abcdef
    #|TIMEBASE 1
    #|DOMAINS 0
    #|SIGNALS 65537
    #|FRAMES 0
    #|END
    #|
  try @trace.parse(oversized_signals) catch {
    TraceResourceLimitExceeded(kind="signals", maximum=65536, actual=65537) =>
      ()
    error => fail("unexpected signal-limit error: \{Repr(error)}")
  } noraise {
    _ => fail("expected signal resource limit rejection")
  }
  let oversized_members =
    #|LUNACHIP-TRACE 2
    #|SEMANTICS 73
    #|IR fnv1a-64 0123456789abcdef
    #|TIMEBASE 1
    #|DOMAINS 0
    #|SIGNALS 0
    #|FRAMES 1
    #|TOTALS 65537 0 0
    #|FRAME 0 0 batch - 65537 0 0
    #|END
    #|
  try @trace.parse(oversized_members) catch {
    TraceResourceLimitExceeded(kind="frame drives", maximum=65536, actual=65537) =>
      ()
    error => fail("unexpected member-limit error: \{Repr(error)}")
  } noraise {
    _ => fail("expected event member limit rejection")
  }
  let oversized_aggregate =
    #|LUNACHIP-TRACE 2
    #|SEMANTICS 73
    #|IR fnv1a-64 0123456789abcdef
    #|TIMEBASE 1
    #|DOMAINS 0
    #|SIGNALS 0
    #|FRAMES 0
    #|TOTALS 1048576 1 0
    #|END
    #|
  try @trace.parse(oversized_aggregate) catch {
    TraceResourceLimitExceeded(
      kind="total event members",
      maximum=1048576,
      actual=1048577
    ) => ()
    error => fail("unexpected aggregate-limit error: \{Repr(error)}")
  } noraise {
    _ => fail("expected aggregate event-member limit rejection")
  }
}

///|
test "schema 2 rejects signal sorting that would silently rebind change indices" {
  try
    @trace.Trace::checked_atomic(
      "semantics/2",
      atomic_trace_digest(),
      1UL,
      [],
      [
        @trace.TraceSignal::checked("top", "z", 1),
        @trace.TraceSignal::checked("top", "a", 1),
      ],
      [
        @trace.AtomicTraceFrame::checked(0UL, 0UL, AtomicInitial, [], [], [
          atomic_trace_change(0, 1, 0UL),
          atomic_trace_change(1, 1, 1UL),
        ]),
      ],
    )
  catch {
    @trace.TraceError::NonCanonical => ()
    error => fail("unexpected signal-order error: \{Repr(error)}")
  } noraise {
    _ => fail("expected noncanonical signal table rejection")
  }
}

///|
test "schema 1 migration preserves order without treating cycles as time" {
  let recorder = @trace.TraceRecorder::new([
    @trace.TraceSignal::checked("top", "data", 4),
  ])
  recorder.record(0UL, 4UL, Initial, [
    @trace.TraceSample::new(
      "top",
      "data",
      @wave.LogicValue::from_uint64(width=4, value=1UL),
    ),
  ])
  recorder.record(99UL, 1UL, RisingEdge("clock_a"), [
    @trace.TraceSample::new(
      "top",
      "data",
      @wave.LogicValue::from_uint64(width=4, value=2UL),
    ),
  ])
  let legacy = recorder.finish()
  let legacy_bytes = @trace.serialize(legacy)
  let migrated = @trace.migrate_schema1(
    legacy,
    "semantics/legacy-migration",
    atomic_trace_digest(),
  )
  assert_eq(@trace.serialize(legacy), legacy_bytes)
  assert_eq(migrated.schema(), Atomic2)
  assert_eq(migrated.timebase(), Some(1UL))
  inspect(migrated.atomic_frames()[0].time(), content="0")
  inspect(migrated.atomic_frames()[1].time(), content="1")
  inspect(migrated.atomic_frames()[0].boundary(), content="0")
  inspect(migrated.atomic_frames()[1].boundary(), content="1")
  assert_eq(migrated.atomic_frames()[1].event(), Legacy(RisingEdge("clock_a")))
  let encoded = @trace.serialize(migrated)
  assert_eq(@trace.serialize(@trace.parse(encoded)), encoded)
  assert_true(@trace.to_vcd(migrated).contains("#1\n"))
  assert_false(@trace.to_vcd(migrated).contains("#99\n"))
}
