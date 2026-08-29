///|
/// Checked construction and access failures for LunaChip host aggregates.
pub(all) suberror AggregateError {
  EmptyVec
  EmptyBundle
  EmptyFieldName
  DuplicateFieldName(String)
  VecIndexOutOfBounds(index~ : Int, length~ : Int)
  LeafCountMismatch(expected~ : Int, actual~ : Int)
} derive(Debug, Eq)

///|
/// One typed step from an aggregate root to a ground leaf.
///
/// Bundle field names and vector indices are kept distinct, so debug tools do
/// not need to parse a display string to recover aggregate structure.
pub(all) enum AggregatePathSegment {
  Field(String)
  Index(Int)
} derive(Debug, Eq)

///|
/// An immutable path from an aggregate root to one ground leaf.
///
/// The empty path identifies an aggregate that is itself a single leaf.
pub struct AggregatePath(ReadOnlyArray[AggregatePathSegment]) derive(Debug, Eq)

///|
/// Return a root path with no segments.
pub fn AggregatePath::root() -> AggregatePath {
  AggregatePath(ReadOnlyArray::from_array([]))
}

///|
/// Return the path segments in root-to-leaf order.
pub fn AggregatePath::segments(
  self : AggregatePath,
) -> ReadOnlyArray[AggregatePathSegment] {
  let AggregatePath(segments) = self
  segments
}

///|
/// Whether this path identifies the aggregate root itself.
pub fn AggregatePath::is_root(self : AggregatePath) -> Bool {
  self.segments().is_empty()
}

///|
/// One value and its exact structural identity in deterministic flatten order.
pub struct FlattenedLeaf[T] {
  ordinal : Int
  path : AggregatePath
  value : T
} derive(Debug, Eq)

///|
/// Return this leaf's zero-based depth-first ordinal.
pub fn[T] FlattenedLeaf::ordinal(self : FlattenedLeaf[T]) -> Int {
  self.ordinal
}

///|
/// Return this leaf's typed structural path.
pub fn[T] FlattenedLeaf::path(self : FlattenedLeaf[T]) -> AggregatePath {
  self.path
}

///|
/// Return the payload stored at this leaf.
pub fn[T] FlattenedLeaf::value(self : FlattenedLeaf[T]) -> T {
  self.value
}
