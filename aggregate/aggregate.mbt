///|
/// A recursive immutable host aggregate.
///
/// `Leaf` may hold a signal type, a LunaWire signal, a simulated logic value,
/// or any other host value. Vectors and bundles retain structural metadata and
/// never imply a packed bit representation.
pub(all) enum Aggregate[T] {
  Leaf(T)
  Vector(Vec[Aggregate[T]])
  Record(Bundle[Aggregate[T]])
} derive(Debug, Eq)

///|
pub extend Aggregate with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Aggregate with Eq::{not_equal, equal}

///|
/// Construct a ground aggregate leaf.
pub fn[T] Aggregate::leaf(value : T) -> Aggregate[T] {
  Leaf(value)
}

///|
/// Construct a checked nonempty vector aggregate.
pub fn[T] Aggregate::vector(
  items : ArrayView[Aggregate[T]],
) -> Aggregate[T] raise AggregateError {
  Vector(Vec::checked(items))
}

///|
/// Construct a checked nonempty bundle aggregate.
pub fn[T] Aggregate::record(
  fields : ArrayView[(String, Aggregate[T])],
) -> Aggregate[T] raise AggregateError {
  Record(Bundle::checked(fields))
}

///|
/// Count ground leaves without allocating a flattened representation.
pub fn[T] Aggregate::leaf_count(self : Aggregate[T]) -> Int32 {
  match self {
    Leaf(_) => 1
    Vector(items) =>
      items.items().fold(init=0, (total, item) => total + item.leaf_count())
    Record(fields) =>
      fields
      .fields()
      .fold(init=0, (total, field) => total + field.value().leaf_count())
  }
}

///|
fn[T] flatten_into(
  aggregate : Aggregate[T],
  path : Array[AggregatePathSegment],
  leaves : Array[FlattenedLeaf[T]],
) -> Unit {
  match aggregate {
    Leaf(value) =>
      leaves.push({
        ordinal: leaves.length(),
        path: AggregatePath(ReadOnlyArray::from_array(path)),
        value,
      })
    Vector(items) =>
      for index, item in items.items() {
        path.push(Index(index))
        flatten_into(item, path, leaves)
        ignore(path.pop())
      }
    Record(fields) =>
      for field in fields.fields() {
        path.push(Field(field.name()))
        flatten_into(field.value(), path, leaves)
        ignore(path.pop())
      }
  }
}

///|
/// Flatten leaves in deterministic depth-first layout order.
///
/// Bundle fields follow declaration order and vector elements follow ascending
/// index order. Every returned leaf carries both its ordinal and typed path.
pub fn[T] Aggregate::flatten(
  self : Aggregate[T],
) -> ReadOnlyArray[FlattenedLeaf[T]] {
  let leaves : Array[FlattenedLeaf[T]] = []
  flatten_into(self, [], leaves)
  ReadOnlyArray::from_array(leaves)
}

///|
fn[Template, Value] reconstruct_at(
  template : Aggregate[Template],
  leaves : ArrayView[Value],
  offset : Int32,
) -> (Aggregate[Value], Int32) raise AggregateError {
  match template {
    Leaf(_) => (Leaf(leaves[offset]), offset + 1)
    Vector(items) => {
      let rebuilt : Array[Aggregate[Value]] = []
      let mut next = offset
      for item in items.items() {
        let (value, after) = reconstruct_at(item, leaves, next)
        rebuilt.push(value)
        next = after
      }
      (Vector(Vec::checked(rebuilt)), next)
    }
    Record(fields) => {
      let rebuilt : Array[(String, Aggregate[Value])] = []
      let mut next = offset
      for field in fields.fields() {
        let (value, after) = reconstruct_at(field.value(), leaves, next)
        rebuilt.push((field.name(), value))
        next = after
      }
      (Record(Bundle::checked(rebuilt)), next)
    }
  }
}

///|
/// Reconstruct values under this aggregate's exact shape and field names.
///
/// The leaf count must match exactly; neither missing nor trailing values are
/// accepted. Template leaf payloads are ignored.
pub fn[Template, Value] Aggregate::reconstruct_like(
  self : Aggregate[Template],
  leaves : ArrayView[Value],
) -> Aggregate[Value] raise AggregateError {
  let expected = self.leaf_count()
  let actual = leaves.length()
  if expected != actual {
    raise LeafCountMismatch(expected~, actual~)
  }
  let (rebuilt, consumed) = reconstruct_at(self, leaves, 0)
  if consumed != actual {
    raise LeafCountMismatch(expected=consumed, actual~)
  }
  rebuilt
}
