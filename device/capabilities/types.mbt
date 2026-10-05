///|
/// Checked immutable configuration for the fetched concurrent FluxTile profile.
/// Fields are publicly readable; only `Capabilities::new` constructs a value.
pub struct Capabilities {
  rows : Int
  columns : Int
  max_reduction : Int
  host_bytes : UInt64
  ring_depth : Int
  queue_depth : Int
}

///|
/// Invalid configuration, checked in field declaration order.
pub(all) suberror CapabilityError {
  InvalidRows(value~ : Int)
  InvalidColumns(value~ : Int)
  InvalidMaxReduction(value~ : Int)
  InvalidHostBytes(value~ : UInt64)
  InvalidRingDepth(value~ : Int)
  InvalidQueueDepth(value~ : Int)
} derive(Debug)

///|
pub extend CapabilityError with @debug.Debug::{to_repr}
