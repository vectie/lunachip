///|
fn unicode_source_trace() -> @trace.Trace raise {
  let recorder = @trace.TraceRecorder::new([
    @trace.TraceSignal::checked("设计/核", "值🔥", 4),
  ])
  recorder.record(0, 0, Initial, [
    @trace.TraceSample::new(
      "设计/核",
      "值🔥",
      @wave.LogicValue::from_uint64(width=4, value=9),
    ),
  ])
  recorder.finish()
}

///|
fn unicode_source_binding() -> @trace.TraceSourceBinding raise {
  let semantic_path = @diagnostics.SemanticPath::checked([
    Design("月芯"),
    Module("核心"),
    Instance("实例🔥"),
    Port("数据"),
    Node(7),
    Field("字段"),
    Operation("采样"),
  ])
  let span = @diagnostics.SourceSpan::new(
    "设计/核🔥.luna",
    @diagnostics.SourcePosition::new(12, 3, 41),
    @diagnostics.SourcePosition::new(14, 9, 97),
  )
  @trace.TraceSourceBinding::new(0, semantic_path, Some(span))
}

///|
test "source map preserves Unicode semantic paths and exact source spans" {
  let trace = unicode_source_trace()
  let source_map = @trace.TraceSourceMap::checked(trace, [
    unicode_source_binding(),
  ])
  let encoded = @trace.serialize_source_map(source_map)
  let decoded = @trace.parse_source_map(encoded)
  assert_eq(@trace.serialize_source_map(decoded), encoded)
  assert_eq(decoded, source_map)
  decoded.validate_trace(trace)
  let entry = decoded.entries()[0]
  assert_eq(entry.signal_index(), 0)
  assert_eq(entry.signal().path(), "设计/核")
  assert_eq(entry.signal().name(), "值🔥")
  assert_eq(entry.semantic_path().segments().length(), 7)
  guard entry.source_span() is Some(span) else { fail("expected source span") }
  assert_eq(span.source_id(), "设计/核🔥.luna")
  assert_eq(span.start().line(), 12)
  assert_eq(span.start().column(), 3)
  assert_eq(span.start().byte_offset(), 41)
  assert_eq(span.end().line(), 14)
  assert_eq(span.end().column(), 9)
  assert_eq(span.end().byte_offset(), 97)
}

///|
test "source map VCD manifest key matches the stable VCD signal identifier" {
  let trace = unicode_source_trace()
  let source_map = @trace.TraceSourceMap::checked(trace, [
    unicode_source_binding(),
  ])
  let entry = source_map.entries()[0]
  assert_eq(entry.vcd_identifier(), "s0")
  assert_true(@trace.serialize_source_map(source_map).contains("VCD s0\n"))
  assert_true(@trace.to_vcd(trace).contains("$var wire 4 s0 "))
}

///|
test "source map preserves an explicit root path without a source span" {
  let trace = unicode_source_trace()
  let source_map = @trace.TraceSourceMap::checked(trace, [
    @trace.TraceSourceBinding::new(0, @diagnostics.SemanticPath::root(), None),
  ])
  let decoded = @trace.parse_source_map(@trace.serialize_source_map(source_map))
  let entry = decoded.entries()[0]
  assert_true(entry.semantic_path().is_root())
  assert_eq(entry.source_span(), None)
}

///|
test "source map rejects duplicate unknown and missing signal bindings" {
  let trace = unicode_source_trace()
  let binding = unicode_source_binding()
  try @trace.TraceSourceMap::checked(trace, [binding, binding]) catch {
    DuplicateSourceMapSignal(0) => ()
    error => fail("unexpected duplicate error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate source binding rejection")
  }
  let unknown = @trace.TraceSourceBinding::new(
    1,
    @diagnostics.SemanticPath::root(),
    None,
  )
  try @trace.TraceSourceMap::checked(trace, [unknown]) catch {
    UnknownSourceMapSignal(1) => ()
    error => fail("unexpected unknown error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown source binding rejection")
  }
  try @trace.TraceSourceMap::checked(trace, []) catch {
    MissingSourceMapSignal(0) => ()
    error => fail("unexpected missing error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing source binding rejection")
  }
}

///|
test "source map parser rejects malformed linkage and source positions" {
  let source_map = @trace.TraceSourceMap::checked(unicode_source_trace(), [
    unicode_source_binding(),
  ])
  let invalid_vcd = @trace.serialize_source_map(source_map).replace(
    old="VCD s0",
    new="VCD broken",
  )
  try @trace.parse_source_map(invalid_vcd) catch {
    InvalidVcdIdentifier(index~, actual~) => {
      assert_eq(index, 0)
      assert_eq(actual, "broken")
    }
    error => fail("unexpected VCD linkage error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid VCD linkage rejection")
  }
  let invalid_position = @trace.serialize_source_map(source_map).replace(
    old=" 12 3 41 ",
    new=" 0 3 41 ",
  )
  try @trace.parse_source_map(invalid_position) catch {
    InvalidSourceMetadata(line=12, field="start") => ()
    error => fail("unexpected position error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid source position rejection")
  }
}
