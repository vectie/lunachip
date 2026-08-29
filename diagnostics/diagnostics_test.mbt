///|
test "stable diagnostic codes and severity names are explicit" {
  inspect(
    @diagnostics.DiagnosticCode::InvalidWidth.stable_id(),
    content="LC0001",
  )
  inspect(
    @diagnostics.DiagnosticCode::InternalInvariantViolation.stable_id(),
    content="LC9999",
  )
  inspect(@diagnostics.Severity::Warning.stable_name(), content="warning")
  let codes : Array[@diagnostics.DiagnosticCode] = [
    InvalidWidth,
    InvalidReference,
    DuplicateDriver,
    MissingDriver,
    CombinationalCycle,
    TypeMismatch,
    WidthMismatch,
    InvalidClock,
    InvalidConstant,
    UnsupportedFeature,
    InvalidExternalToolManifest,
    InvalidName,
    DuplicateName,
    InvalidSlice,
    InvalidSignedness,
    MissingTopModule,
    InvalidBuilderState,
    InternalInvariantViolation,
  ]
  let seen : Map[String, Unit] = Map([])
  for code in codes {
    let stable_id = code.stable_id()
    assert_false(seen.contains(stable_id))
    seen[stable_id] = ()
  }
  assert_eq(seen.length(), codes.length())
}

///|
test "source coordinates and spans reject invalid states" {
  try @diagnostics.SourcePosition::new(0, 1, 0) catch {
    InvalidSourcePosition(line~, column~, byte_offset~) => {
      assert_eq(line, 0)
      assert_eq(column, 1)
      assert_eq(byte_offset, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid position")
  }
  let start = @diagnostics.SourcePosition::new(2, 3, 12)
  let end = @diagnostics.SourcePosition::new(2, 5, 14)
  let span = @diagnostics.SourceSpan::new("generator/counter.mbt", start, end)
  assert_eq(span.source_id(), "generator/counter.mbt")
  assert_eq(span.start().line(), 2)
  assert_eq(span.end().column(), 5)
  try @diagnostics.SourceSpan::new("generator/counter.mbt", end, start) catch {
    ReversedSourceSpan => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reversed span")
  }
  let contradictory_end = @diagnostics.SourcePosition::new(1, 1, 20)
  try
    @diagnostics.SourceSpan::new(
      "generator/counter.mbt", start, contradictory_end,
    )
  catch {
    ReversedSourceSpan => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected contradictory coordinate rejection")
  }
}

///|
test "semantic paths are immutable validated structure" {
  let input_segments : Array[@diagnostics.SemanticPathSegment] = [
    Design("FluxTile-0"),
    Module("Control"),
    Node(7),
  ]
  let path = @diagnostics.SemanticPath::checked(input_segments)
  input_segments.clear()
  assert_false(path.is_root())
  assert_eq(path.segments().length(), 3)
  try @diagnostics.SemanticPath::checked([Module("")]) catch {
    EmptySemanticPathValue(kind~) => assert_eq(kind, "module")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty path rejection")
  }
}

///|
test "diagnostic carries primary related path and suggested edit" {
  let start = @diagnostics.SourcePosition::new(4, 7, 40)
  let end = @diagnostics.SourcePosition::new(4, 8, 41)
  let span = @diagnostics.SourceSpan::new("alu.mbt", start, end)
  let related = @diagnostics.RelatedSpan::new(span, "other operand is 8 bits")
  let edit = @diagnostics.TextEdit::new(span, "u8")
  let correction = @diagnostics.SuggestedCorrection::new(
    "make both operands eight bits",
    Some(edit),
  )
  let path = @diagnostics.SemanticPath::checked([
    Module("Alu"),
    Operation("add"),
  ])
  let related_spans = [related]
  let diagnostic = @diagnostics.Diagnostic::checked(
    WidthMismatch,
    Error,
    "add operands have different widths",
    Some(span),
    related_spans,
    path,
    Some(correction),
  )
  related_spans.clear()
  assert_eq(diagnostic.code().stable_id(), "LC0007")
  assert_eq(diagnostic.related_spans().length(), 1)
  assert_eq(diagnostic.semantic_path().segments().length(), 2)
  guard diagnostic.suggested_correction() is Some(suggestion) else {
    fail("expected correction")
  }
  assert_eq(suggestion.message(), "make both operands eight bits")
  guard suggestion.edit() is Some(suggested_edit) else {
    fail("expected text edit")
  }
  assert_eq(suggested_edit.replacement(), "u8")
}

///|
test "diagnostic rejects blank messages" {
  try @diagnostics.Diagnostic::simple(UnsupportedFeature, Error, "  ") catch {
    EmptyDiagnosticMessage => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected empty message rejection")
  }
}
