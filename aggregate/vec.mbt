///|
/// A nonempty, immutable elaboration-time vector.
///
/// Its length is host metadata rather than runtime hardware state. Construction
/// snapshots the supplied array so later caller mutation cannot change layout.
pub struct Vec[T](ReadOnlyArray[T]) derive(Debug, Eq)

///|
/// Validate and snapshot a nonempty vector.
pub fn[T] Vec::checked(items : ArrayView[T]) -> Vec[T] raise AggregateError {
  if items.is_empty() {
    raise EmptyVec
  }
  Vec(ReadOnlyArray::from_array(items))
}

///|
/// Return the immutable vector length.
pub fn[T] Vec::length(self : Vec[T]) -> Int32 {
  let Vec(items) = self
  items.length()
}

///|
/// Return an element with checked bounds.
pub fn[T] Vec::at(self : Vec[T], index : Int32) -> T raise AggregateError {
  let Vec(items) = self
  if index < 0 || index >= items.length() {
    raise VecIndexOutOfBounds(index~, length=items.length())
  }
  items[index]
}

///|
/// Return the immutable element sequence.
pub fn[T] Vec::items(self : Vec[T]) -> ReadOnlyArray[T] {
  let Vec(items) = self
  items
}

///|
pub extend Vec with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Vec with Eq::{not_equal, equal}
