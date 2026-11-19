///|
/// Explicit byte-address aperture for external layer weights and DMA vectors.
/// The default preserves the PRX100 28-bit request port. GiB2 uses a 32-bit
/// request port and rejects every descriptor extending beyond 0x80000000.
pub(all) enum MemoryAperture {
  MiB256
  GiB2
} derive(Eq, Debug)

///|
pub extend MemoryAperture with Eq::{equal, not_equal}

///|
pub extend MemoryAperture with @debug.Debug::{to_repr}

///|
/// Width of the external byte-address request port.
pub fn MemoryAperture::address_width(self : MemoryAperture) -> Int32 {
  match self {
    MiB256 => 28
    GiB2 => 32
  }
}

///|
/// Exclusive upper bound of the external byte-address aperture.
///
/// ```mbt check
/// test {
///   assert_eq(@qwen_layer.MemoryAperture::GiB2.capacity_bytes(), 0x80000000UL)
///   assert_eq(@qwen_layer.MemoryAperture::GiB2.address_width(), 32)
/// }
/// ```
pub fn MemoryAperture::capacity_bytes(self : MemoryAperture) -> UInt64 {
  match self {
    MiB256 => 0x10000000UL
    GiB2 => 0x80000000UL
  }
}

///|
fn Machine::memory_address(
  m : Machine,
  value : @wire.Signal,
) -> @wire.Signal raise {
  match m.memory {
    MiB256 => m.b.truncate(value, 28)
    GiB2 => value
  }
}
