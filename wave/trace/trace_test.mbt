///|
fn sample(
  path : String,
  name : String,
  value : @wave.LogicValue,
) -> @trace.TraceSample {
  @trace.TraceSample::new(path, name, value)
}

///|
test "canonical native trace is byte-stable and changed-only" {
  let recorder = @trace.TraceRecorder::new([
    @trace.TraceSignal::checked("top", "data", 4),
    @trace.TraceSignal::checked("top", "a", 1),
  ])
  recorder.record(0, 0, Initial, [
    sample("top", "data", @wave.LogicValue::from_uint64(width=4, value=3)),
    sample("top", "a", @wave.LogicValue::unknown(width=1)),
  ])
  recorder.record(0, 1, InputDriven("in"), [
    sample("top", "a", @wave.LogicValue::unknown(width=1)),
    sample("top", "data", @wave.LogicValue::from_uint64(width=4, value=5)),
  ])
  let encoded = @trace.serialize(recorder.finish())
  inspect(
    encoded,
    content=(
      #|LUNACHIP-TRACE 1
      #|SIGNALS 2
      #|SIGNAL 0 1 746f70 61
      #|SIGNAL 1 4 746f70 64617461
      #|FRAMES 2
      #|FRAME 0 0 initial - 2
      #|CHANGE 0 0 0
      #|CHANGE 1 3 15
      #|FRAME 0 1 input 696e 1
      #|CHANGE 1 5 15
      #|END
      #|
    ),
  )
  assert_eq(@trace.serialize(@trace.parse(encoded)), encoded)
}

///|
test "VCD export is stable, valid, and preserves unknown values" {
  let recorder = @trace.TraceRecorder::new([
    @trace.TraceSignal::checked("top", "a", 1),
    @trace.TraceSignal::checked("top", "data", 4),
  ])
  recorder.record(0, 0, Initial, [
    sample("top", "a", @wave.LogicValue::unknown(width=1)),
    sample("top", "data", @wave.LogicValue::from_uint64(width=4, value=3)),
  ])
  recorder.record(1, 0, RisingEdge("clk"), [
    sample("top", "a", @wave.LogicValue::unknown(width=1)),
    sample("top", "data", @wave.LogicValue::from_uint64(width=4, value=5)),
  ])
  inspect(
    @trace.to_vcd(recorder.finish()),
    content=(
      #|$version LunaChip LunaWave trace schema 1 $end
      #|$timescale 1ns $end
      #|$scope module lunachip $end
      #|$var wire 1 s0 lunachip_746f70__61 $end
      #|$var wire 4 s1 lunachip_746f70__64617461 $end
      #|$upscope $end
      #|$enddefinitions $end
      #|#0
      #|$comment cycle=0 boundary=0 event=initial argument=- $end
      #|xs0
      #|b0011 s1
      #|#1
      #|$comment cycle=1 boundary=0 event=edge argument=636c6b $end
      #|b0101 s1
      #|
    ),
  )
}

///|
test "trace parser rejects malformed and noncanonical inputs" {
  let missing_first_sample =
    #|LUNACHIP-TRACE 1
    #|SIGNALS 1
    #|SIGNAL 0 1 746f70 61
    #|FRAMES 1
    #|FRAME 0 0 initial - 0
    #|END
    #|
  try @trace.parse(missing_first_sample) catch {
    UnexpectedLine(..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected malformed trace rejection")
  }
  try @trace.parse("LUNACHIP-TRACE 1\nSIGNALS 0\nFRAMES 0\nEND") catch {
    NonCanonical => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected trailing-newline rejection")
  }
}
