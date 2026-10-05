///|
/// A syntax-valid draft 0.2 descriptor with explicit two-slot selections.
/// Dimensions fit UInt13 and selectors fit UInt1. Device-dependent shapes,
/// unused fields, dependencies and address bounds are validated by hardware.
pub(all) struct Descriptor {
  opcode : @descriptor.Opcode
  id : UInt
  rows : UInt
  columns : UInt
  reduction : UInt
  base : UInt
  stride : UInt
  a_slot : UInt
  b_slot : UInt
  c_slot : UInt
} derive(Debug, Eq)

///|
/// Decode priority is length, version, reserved fields, opcode, dimensions.
/// Encoding checks dimension and selector widths before narrowing any value.
pub(all) suberror DescriptorError {
  InvalidLength(actual~ : Int)
  UnsupportedVersion(major~ : UInt, minor~ : UInt)
  ReservedByte(offset~ : Int, value~ : UInt)
  ReservedBits(offset~ : Int, value~ : UInt, mask~ : UInt)
  UnsupportedOpcode(value~ : UInt)
  DimensionOutOfRange(field~ : String, value~ : UInt)
  SlotOutOfRange(field~ : String, value~ : UInt)
} derive(Debug, Eq)

///|
pub extend Descriptor with @debug.Debug::{to_repr}

///|
pub extend Descriptor with Eq::{equal, not_equal}

///|
pub extend DescriptorError with @debug.Debug::{to_repr}

///|
pub extend DescriptorError with Eq::{equal, not_equal}
