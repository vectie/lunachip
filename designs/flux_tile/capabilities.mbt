///|
/// Elaborate the Device ABI 1.0 fetched concurrent profile from its checked
/// capabilities. Descriptor encoding remains 0.2; there are no new hardware
/// ports or registers. This is the same graph as ring_concurrent_tile.
///
/// ```mbt check
/// test {
///   let configuration = @capabilities.Capabilities::new(
///     rows=1,
///     columns=1,
///     max_reduction=2,
///     host_bytes=1024UL,
///     ring_depth=4,
///     queue_depth=3,
///   )
///   assert_eq(
///     @flux_tile.ring_concurrent_from_capabilities(configuration).name(),
///     "FluxTileHostConcurrent",
///   )
/// }
/// ```
pub fn ring_concurrent_from_capabilities(
  configuration : @capabilities.Capabilities,
) -> @ir.Module raise {
  ring_concurrent_tile(
    rows=configuration.rows,
    columns=configuration.columns,
    max_reduction=configuration.max_reduction,
    host_bytes=configuration.host_bytes,
    ring_depth=configuration.ring_depth,
    queue_depth=configuration.queue_depth,
  )
}
