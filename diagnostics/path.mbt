///|
/// A typed component in a semantic location. These values identify hardware
/// concepts and remain independent of filesystem layout and emitted RTL names.
pub(all) enum SemanticPathSegment {
  Design(String)
  Module(String)
  Instance(String)
  Port(String)
  Node(Int32)
  Memory(Int32)
  Field(String)
  Operation(String)
} derive(Debug, Eq)

///|
fn segment_error(segment : SemanticPathSegment) -> DiagnosticConstructionError? {
  match segment {
    Design(value) if value.trim().is_empty() =>
      Some(EmptySemanticPathValue(kind="design"))
    Module(value) if value.trim().is_empty() =>
      Some(EmptySemanticPathValue(kind="module"))
    Instance(value) if value.trim().is_empty() =>
      Some(EmptySemanticPathValue(kind="instance"))
    Port(value) if value.trim().is_empty() =>
      Some(EmptySemanticPathValue(kind="port"))
    Field(value) if value.trim().is_empty() =>
      Some(EmptySemanticPathValue(kind="field"))
    Operation(value) if value.trim().is_empty() =>
      Some(EmptySemanticPathValue(kind="operation"))
    Node(id) if id < 0 => Some(NegativeSemanticNodeId(id))
    Memory(id) if id < 0 => Some(NegativeSemanticNodeId(id))
    _ => None
  }
}

///|
/// An immutable, validated semantic route from design root to the diagnosed
/// object. An empty path denotes the root.
pub struct SemanticPath(ReadOnlyArray[SemanticPathSegment]) derive(Debug, Eq)

///|
pub fn SemanticPath::root() -> SemanticPath {
  SemanticPath(ReadOnlyArray::from_array([]))
}

///|
/// Validate and copy path segments into immutable storage.
pub fn SemanticPath::checked(
  segments : ArrayView[SemanticPathSegment],
) -> SemanticPath raise DiagnosticConstructionError {
  for segment in segments {
    match segment_error(segment) {
      Some(error) => raise error
      None => ()
    }
  }
  SemanticPath(ReadOnlyArray::from_array(segments))
}

///|
pub fn SemanticPath::segments(
  self : SemanticPath,
) -> ReadOnlyArray[SemanticPathSegment] {
  let SemanticPath(segments) = self
  segments
}

///|
pub fn SemanticPath::is_root(self : SemanticPath) -> Bool {
  self.segments().is_empty()
}

///|
pub extend SemanticPathSegment with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SemanticPathSegment with Eq::{not_equal, equal}

///|
pub extend SemanticPath with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SemanticPath with Eq::{not_equal, equal}
