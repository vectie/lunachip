///|
/// A secondary source location that explains how it relates to the primary
/// diagnostic.
pub struct RelatedSpan {
  span : SourceSpan
  message : String
} derive(Debug, Eq)

///|
pub fn RelatedSpan::new(
  span : SourceSpan,
  message : String,
) -> RelatedSpan raise DiagnosticConstructionError {
  if message.trim().is_empty() {
    raise EmptyRelatedMessage
  }
  { span, message }
}

///|
pub fn RelatedSpan::span(self : RelatedSpan) -> SourceSpan {
  self.span
}

///|
pub fn RelatedSpan::message(self : RelatedSpan) -> String {
  self.message
}

///|
/// A concrete edit that a frontend may offer to apply. The replacement is
/// exact text; an empty replacement means deletion.
pub struct TextEdit {
  span : SourceSpan
  replacement : String
} derive(Debug, Eq)

///|
pub fn TextEdit::new(span : SourceSpan, replacement : String) -> TextEdit {
  { span, replacement }
}

///|
pub fn TextEdit::span(self : TextEdit) -> SourceSpan {
  self.span
}

///|
pub fn TextEdit::replacement(self : TextEdit) -> String {
  self.replacement
}

///|
/// A human explanation with an optional exact source edit.
pub struct SuggestedCorrection {
  message : String
  edit : TextEdit?
} derive(Debug, Eq)

///|
pub fn SuggestedCorrection::new(
  message : String,
  edit : TextEdit?,
) -> SuggestedCorrection raise DiagnosticConstructionError {
  if message.trim().is_empty() {
    raise EmptyCorrectionMessage
  }
  { message, edit }
}

///|
pub fn SuggestedCorrection::message(self : SuggestedCorrection) -> String {
  self.message
}

///|
pub fn SuggestedCorrection::edit(self : SuggestedCorrection) -> TextEdit? {
  self.edit
}

///|
/// The stable diagnostic envelope shared by elaboration, validation,
/// simulation, and backend packages.
pub struct Diagnostic {
  code : DiagnosticCode
  severity : Severity
  message : String
  primary_span : SourceSpan?
  related_spans : ReadOnlyArray[RelatedSpan]
  semantic_path : SemanticPath
  suggested_correction : SuggestedCorrection?
} derive(Debug, Eq)

///|
/// Construct a fully specified diagnostic and copy related spans into
/// immutable storage.
pub fn Diagnostic::checked(
  code : DiagnosticCode,
  severity : Severity,
  message : String,
  primary_span : SourceSpan?,
  related_spans : ArrayView[RelatedSpan],
  semantic_path : SemanticPath,
  suggested_correction : SuggestedCorrection?,
) -> Diagnostic raise DiagnosticConstructionError {
  if message.trim().is_empty() {
    raise EmptyDiagnosticMessage
  }
  {
    code,
    severity,
    message,
    primary_span,
    related_spans: ReadOnlyArray::from_array(related_spans),
    semantic_path,
    suggested_correction,
  }
}

///|
/// Construct a diagnostic without source metadata or correction.
pub fn Diagnostic::simple(
  code : DiagnosticCode,
  severity : Severity,
  message : String,
) -> Diagnostic raise DiagnosticConstructionError {
  Diagnostic::checked(
    code,
    severity,
    message,
    None,
    [],
    SemanticPath::root(),
    None,
  )
}

///|
pub fn Diagnostic::code(self : Diagnostic) -> DiagnosticCode {
  self.code
}

///|
pub fn Diagnostic::severity(self : Diagnostic) -> Severity {
  self.severity
}

///|
pub fn Diagnostic::message(self : Diagnostic) -> String {
  self.message
}

///|
pub fn Diagnostic::primary_span(self : Diagnostic) -> SourceSpan? {
  self.primary_span
}

///|
pub fn Diagnostic::related_spans(
  self : Diagnostic,
) -> ReadOnlyArray[RelatedSpan] {
  self.related_spans
}

///|
pub fn Diagnostic::semantic_path(self : Diagnostic) -> SemanticPath {
  self.semantic_path
}

///|
pub fn Diagnostic::suggested_correction(
  self : Diagnostic,
) -> SuggestedCorrection? {
  self.suggested_correction
}
