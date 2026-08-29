///|
fn diagnostic_code(error : @wire.WireError) -> @diagnostics.DiagnosticCode {
  match error {
    BuilderFinished => InvalidBuilderState
    ForeignSignal | ForeignOutput | ForeignRegister => InvalidReference
    DuplicateDriver(_) | DuplicateNextDriver(_) => DuplicateDriver
    UndrivenOutput(_) | UndrivenRegister(_) => MissingDriver
  }
}

///|
fn diagnostic_message(error : @wire.WireError) -> String {
  match error {
    BuilderFinished => "module builder has already been finalized"
    ForeignSignal => "signal belongs to another module builder"
    ForeignOutput => "output belongs to another module builder"
    ForeignRegister => "register belongs to another module builder"
    DuplicateDriver(name) => "output \{name} already has a driver"
    UndrivenOutput(name) => "output \{name} has no driver"
    DuplicateNextDriver(node) =>
      "register node \{node} already has a next-state driver"
    UndrivenRegister(node) => "register node \{node} has no next-state driver"
  }
}

///|
fn semantic_path(
  error : @wire.WireError,
) -> @diagnostics.SemanticPath raise @diagnostics.DiagnosticConstructionError {
  match error {
    DuplicateDriver(name) | UndrivenOutput(name) =>
      @diagnostics.SemanticPath::checked([Port(name)])
    DuplicateNextDriver(node) | UndrivenRegister(node) =>
      @diagnostics.SemanticPath::checked([Node(node)])
    _ => @diagnostics.SemanticPath::root()
  }
}

///|
/// Convert a LunaWire construction failure into the stable diagnostic model.
pub fn from_wire_error(
  error : @wire.WireError,
  primary_span? : @diagnostics.SourceSpan,
) -> @diagnostics.Diagnostic raise @diagnostics.DiagnosticConstructionError {
  @diagnostics.Diagnostic::checked(
    diagnostic_code(error),
    Error,
    diagnostic_message(error),
    primary_span,
    [],
    semantic_path(error),
    None,
  )
}
