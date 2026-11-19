///|
/// A syntax-valid draft 0.2 descriptor with explicit two-slot selections.
/// Dimensions fit UInt13 and selectors fit UInt1. Device-dependent shapes,
/// unused fields, dependencies and address bounds are validated by hardware.
pub(all) struct Descriptor {
  opcode : @descriptor.Opcode
  id : UInt32
  rows : UInt32
  columns : UInt32
  reduction : UInt32
  base : UInt32
  stride : UInt32
  a_slot : UInt32
  b_slot : UInt32
  c_slot : UInt32
} derive(Debug, Eq)

///|
/// Decode priority is length, version, reserved fields, opcode, dimensions.
/// Encoding checks dimension and selector widths before narrowing any value.
pub(all) suberror DescriptorError {
  InvalidLength(actual~ : Int32)
  UnsupportedVersion(major~ : UInt32, minor~ : UInt32)
  ReservedByte(offset~ : Int32, value~ : UInt32)
  ReservedBits(offset~ : Int32, value~ : UInt32, mask~ : UInt32)
  UnsupportedOpcode(value~ : UInt32)
  DimensionOutOfRange(field~ : String, value~ : UInt32)
  SlotOutOfRange(field~ : String, value~ : UInt32)
} derive(Debug, Eq)

///|
pub extend Descriptor with @debug.Debug::{to_repr}

///|
pub extend Descriptor with Eq::{equal, not_equal}

///|
pub extend DescriptorError with @debug.Debug::{to_repr}

///|
pub extend DescriptorError with Eq::{equal, not_equal}
