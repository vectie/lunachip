///|
/// User-supplied source metadata for one canonical trace signal index.
///
/// A source map accepts bindings independently from declaration order, then
/// canonicalizes them into trace signal-table order.
pub struct TraceSourceBinding {
  signal_index : Int
  semantic_path : @diagnostics.SemanticPath
  source_span : @diagnostics.SourceSpan?
} derive(Debug, Eq)

///|
pub fn TraceSourceBinding::new(
  signal_index : Int,
  semantic_path : @diagnostics.SemanticPath,
  source_span : @diagnostics.SourceSpan?,
) -> TraceSourceBinding {
  { signal_index, semantic_path, source_span }
}

///|
pub fn TraceSourceBinding::signal_index(self : TraceSourceBinding) -> Int {
  self.signal_index
}

///|
pub fn TraceSourceBinding::semantic_path(
  self : TraceSourceBinding,
) -> @diagnostics.SemanticPath {
  self.semantic_path
}

///|
pub fn TraceSourceBinding::source_span(
  self : TraceSourceBinding,
) -> @diagnostics.SourceSpan? {
  self.source_span
}

///|
/// One canonical trace identity bound to its semantic and source metadata.
pub struct TraceSourceEntry {
  signal_index : Int
  signal : TraceSignal
  semantic_path : @diagnostics.SemanticPath
  source_span : @diagnostics.SourceSpan?
} derive(Debug, Eq)

///|
pub fn TraceSourceEntry::signal_index(self : TraceSourceEntry) -> Int {
  self.signal_index
}

///|
pub fn TraceSourceEntry::signal(self : TraceSourceEntry) -> TraceSignal {
  self.signal
}

///|
pub fn TraceSourceEntry::semantic_path(
  self : TraceSourceEntry,
) -> @diagnostics.SemanticPath {
  self.semantic_path
}

///|
pub fn TraceSourceEntry::source_span(
  self : TraceSourceEntry,
) -> @diagnostics.SourceSpan? {
  self.source_span
}

///|
/// Return the stable VCD identifier used by `to_vcd` for this signal.
pub fn TraceSourceEntry::vcd_identifier(self : TraceSourceEntry) -> String {
  vcd_identifier(self.signal_index)
}

///|
/// A complete immutable source map for one canonical trace signal table.
pub struct TraceSourceMap {
  entries : ReadOnlyArray[TraceSourceEntry]
} derive(Debug, Eq)

///|
pub fn TraceSourceMap::entries(
  self : TraceSourceMap,
) -> ReadOnlyArray[TraceSourceEntry] {
  self.entries
}

///|
/// Construct a complete source map in canonical trace signal-table order.
///
/// Every signal index must occur exactly once. Out-of-order bindings are
/// accepted, but unknown, duplicate, and missing indices are rejected.
pub fn TraceSourceMap::checked(
  trace : Trace,
  bindings : ArrayView[TraceSourceBinding],
) -> TraceSourceMap raise TraceError {
  let signals = trace.signals()
  let ordered : Array[TraceSourceBinding?] = Array::make(signals.length(), None)
  for binding in bindings {
    let index = binding.signal_index()
    if index < 0 || index >= signals.length() {
      raise UnknownSourceMapSignal(index)
    }
    if ordered[index] is Some(_) {
      raise DuplicateSourceMapSignal(index)
    }
    ordered[index] = Some(binding)
  }
  let entries : Array[TraceSourceEntry] = []
  for index, signal in signals {
    guard ordered[index] is Some(binding) else {
      raise MissingSourceMapSignal(index)
    }
    entries.push({
      signal_index: index,
      signal,
      semantic_path: binding.semantic_path(),
      source_span: binding.source_span(),
    })
  }
  { entries: ReadOnlyArray::from_array(entries) }
}

///|
/// Verify that this source map describes exactly the supplied trace table.
pub fn TraceSourceMap::validate_trace(
  self : TraceSourceMap,
  trace : Trace,
) -> Unit raise TraceError {
  let signals = trace.signals()
  if self.entries.length() != signals.length() {
    let missing = self.entries.length().min(signals.length())
    raise SourceMapSignalMismatch(missing)
  }
  for index, entry in self.entries {
    if entry.signal_index() != index || entry.signal() != signals[index] {
      raise SourceMapSignalMismatch(index)
    }
  }
}
