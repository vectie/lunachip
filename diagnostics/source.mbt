///|
/// Checked construction failures for diagnostic metadata.
pub(all) suberror DiagnosticConstructionError {
  InvalidSourcePosition(line~ : Int, column~ : Int, byte_offset~ : Int)
  EmptySourceId
  ReversedSourceSpan
  EmptyDiagnosticMessage
  EmptyRelatedMessage
  EmptyCorrectionMessage
  EmptySemanticPathValue(kind~ : String)
  NegativeSemanticNodeId(Int)
} derive(Debug, Eq)

///|
/// A source position with one-based line/column and zero-based byte offset.
pub struct SourcePosition {
  line : Int
  column : Int
  byte_offset : Int
} derive(Debug, Eq)

///|
/// Construct a valid source position.
pub fn SourcePosition::new(
  line : Int,
  column : Int,
  byte_offset : Int,
) -> SourcePosition raise DiagnosticConstructionError {
  if line < 1 || column < 1 || byte_offset < 0 {
    raise InvalidSourcePosition(line~, column~, byte_offset~)
  }
  { line, column, byte_offset, }
}

///|
pub fn SourcePosition::line(self : SourcePosition) -> Int {
  self.line
}

///|
pub fn SourcePosition::column(self : SourcePosition) -> Int {
  self.column
}

///|
pub fn SourcePosition::byte_offset(self : SourcePosition) -> Int {
  self.byte_offset
}

///|
fn position_after(a : SourcePosition, b : SourcePosition) -> Bool {
  a.byte_offset > b.byte_offset ||
  a.line > b.line ||
  (a.line == b.line && a.column > b.column)
}

///|
/// A half-open source range `[start, end)` in one named source artifact.
pub struct SourceSpan {
  source_id : String
  start : SourcePosition
  end : SourcePosition
} derive(Debug, Eq)

///|
/// Construct a source span, rejecting empty source IDs and reversed ranges.
pub fn SourceSpan::new(
  source_id : String,
  start : SourcePosition,
  end : SourcePosition,
) -> SourceSpan raise DiagnosticConstructionError {
  if source_id.trim().is_empty() {
    raise EmptySourceId
  }
  if position_after(start, end) {
    raise ReversedSourceSpan
  }
  { source_id, start, end, }
}

///|
pub fn SourceSpan::source_id(self : SourceSpan) -> String {
  self.source_id
}

///|
pub fn SourceSpan::start(self : SourceSpan) -> SourcePosition {
  self.start
}

///|
pub fn SourceSpan::end(self : SourceSpan) -> SourcePosition {
  self.end
}

///|
pub extend DiagnosticConstructionError with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend DiagnosticConstructionError with Eq::{not_equal, equal}

///|
pub extend SourcePosition with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SourcePosition with Eq::{not_equal, equal}

///|
pub extend SourceSpan with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SourceSpan with Eq::{not_equal, equal}
