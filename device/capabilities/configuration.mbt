///|
/// Construct a supported logical configuration, without elaborating hardware.
/// Host ring address validation remains a runtime configuration operation.
///
/// ```mbt check
/// test {
///   let config = @capabilities.Capabilities::new(
///     rows=2,
///     columns=3,
///     max_reduction=5,
///     host_bytes=4096UL,
///     ring_depth=4,
///     queue_depth=3,
///   )
///   assert_eq(config.rows, 2)
///   assert_eq(config.host_bytes, 4096UL)
/// }
/// ```
pub fn Capabilities::new(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
  host_bytes~ : UInt64,
  ring_depth~ : Int,
  queue_depth~ : Int,
) -> Capabilities raise CapabilityError {
  if rows < 1 || rows > 8 {
    raise InvalidRows(value=rows)
  }
  if columns < 1 || columns > 8 {
    raise InvalidColumns(value=columns)
  }
  if max_reduction < 1 || max_reduction > 4096 {
    raise InvalidMaxReduction(value=max_reduction)
  }
  if host_bytes < 1UL || host_bytes > 4294967296UL {
    raise InvalidHostBytes(value=host_bytes)
  }
  if ring_depth != 2 && ring_depth != 4 && ring_depth != 8 && ring_depth != 16 {
    raise InvalidRingDepth(value=ring_depth)
  }
  if queue_depth < 2 || queue_depth > 16 {
    raise InvalidQueueDepth(value=queue_depth)
  }
  { rows, columns, max_reduction, host_bytes, ring_depth, queue_depth, }
}
