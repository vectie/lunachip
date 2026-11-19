///|
/// Checked immutable configuration for the fetched concurrent FluxTile profile.
/// Fields are publicly readable; only `Capabilities::new` constructs a value.
pub struct Capabilities {
  rows : Int32
  columns : Int32
  max_reduction : Int32
  host_bytes : UInt64
  ring_depth : Int32
  queue_depth : Int32
}

///|
/// Invalid configuration, checked in field declaration order.
pub(all) suberror CapabilityError {
  InvalidRows(value~ : Int32)
  InvalidColumns(value~ : Int32)
  InvalidMaxReduction(value~ : Int32)
  InvalidHostBytes(value~ : UInt64)
  InvalidRingDepth(value~ : Int32)
  InvalidQueueDepth(value~ : Int32)
} derive(Debug)

///|
pub extend CapabilityError with @debug.Debug::{to_repr}
