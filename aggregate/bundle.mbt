///|
/// One named value in an elaboration-time `Bundle`.
pub struct BundleField[T] {
  name : String
  value : T
} derive(Debug, Eq)

///|
/// Return the exact, case-sensitive UTF-8 field name.
pub fn[T] BundleField::name(self : BundleField[T]) -> String {
  self.name
}

///|
/// Return the field payload.
pub fn[T] BundleField::value(self : BundleField[T]) -> T {
  self.value
}

///|
/// A nonempty, immutable, declaration-ordered record.
///
/// Field order is layout order. Names are exact, nonempty, and unique; no map
/// iteration participates in flattening or reconstruction.
pub struct Bundle[T](ReadOnlyArray[BundleField[T]]) derive(Debug, Eq)

///|
/// Validate named values and snapshot them in declaration order.
pub fn[T] Bundle::checked(
  fields : ArrayView[(String, T)],
) -> Bundle[T] raise AggregateError {
  if fields.is_empty() {
    raise EmptyBundle
  }
  let checked : Array[BundleField[T]] = []
  for index, field in fields {
    let (name, value) = field
    if name.is_empty() {
      raise EmptyFieldName
    }
    for prior in 0..<index {
      if checked[prior].name == name {
        raise DuplicateFieldName(name)
      }
    }
    checked.push({ name, value, })
  }
  Bundle(ReadOnlyArray::from_array(checked))
}

///|
/// Return the number of fields.
pub fn[T] Bundle::length(self : Bundle[T]) -> Int32 {
  let Bundle(fields) = self
  fields.length()
}

///|
/// Return the immutable declaration-ordered fields.
pub fn[T] Bundle::fields(self : Bundle[T]) -> ReadOnlyArray[BundleField[T]] {
  let Bundle(fields) = self
  fields
}

///|
/// Find a field by its exact name.
pub fn[T] Bundle::field(self : Bundle[T], name : String) -> BundleField[T]? {
  for field in self.fields() {
    if field.name() == name {
      return Some(field)
    }
  }
  None
}

///|
pub extend BundleField with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BundleField with Eq::{not_equal, equal}

///|
pub extend Bundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Bundle with Eq::{not_equal, equal}
