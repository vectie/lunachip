///|
/// Commands supported by the provisional FluxTile descriptor format 0.1.
/// This format is not a frozen device ABI or a host-memory DMA ring.
pub(all) enum Opcode {
  LoadA
  LoadB
  MatMul
  StoreC
  Fence
} derive(Debug, Eq)

///|
/// A syntax-valid descriptor. Dimensions are representable UInt13 values,
/// not necessarily legal for the device or command. Hardware checks shape,
/// unused fields, dependencies, strides, and aperture before issuing work.
pub(all) struct Descriptor {
  opcode : Opcode
  id : UInt32
  rows : UInt32
  columns : UInt32
  reduction : UInt32
  base : UInt32
  stride : UInt32
} derive(Debug, Eq)

///|
/// Strict syntax errors, in decode priority: length, version, reserved bytes,
/// opcode, then dimension representation. Reserved offsets are byte offsets.
pub(all) suberror DescriptorError {
  InvalidLength(actual~ : Int32)
  UnsupportedVersion(major~ : UInt32, minor~ : UInt32)
  ReservedByte(offset~ : Int32, value~ : UInt32)
  UnsupportedOpcode(value~ : UInt32)
  DimensionOutOfRange(field~ : String, value~ : UInt32)
} derive(Debug, Eq)

///|
pub extend Opcode with @debug.Debug::{to_repr}

///|
pub extend Opcode with Eq::{equal, not_equal}

///|
pub extend Descriptor with @debug.Debug::{to_repr}

///|
pub extend Descriptor with Eq::{equal, not_equal}

///|
pub extend DescriptorError with @debug.Debug::{to_repr}

///|
pub extend DescriptorError with Eq::{equal, not_equal}
