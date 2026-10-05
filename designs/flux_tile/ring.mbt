///|
/// Fetch provisional 32-byte descriptors from a configured bounded host ring.
/// Depth is 2, 4, 8, or 16. Configuration is accepted once until joint reset.
/// Publication uses wrapping UInt32 counters and pre-edge free capacity; one
/// tagged byte read is outstanding at a time. Packets and faults are held.
/// This standalone reader does not decode commands or arbitrate a shared bus.
/// See PHASE6_RING.md for publication, transport, and ownership requirements.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.descriptor_ring_reader(host_bytes=256UL, ring_depth=4)
///     .memories()
///     .length(),
///     0,
///   )
/// }
/// ```
pub fn descriptor_ring_reader(
  host_bytes~ : UInt64,
  ring_depth~ : Int,
) -> @ir.Module raise {
  ring_validate_parameters(host_bytes, ring_depth)
  let builder = @wire.ModuleBuilder::new("FluxTileRing")
  builder.parameter("host_bytes", Unsigned(host_bytes))
  builder.parameter("ring_depth", Signed(ring_depth.to_int64()))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let ports = ring_inputs(builder)
  let registers = ring_registers(builder, domain, reset)
  let signals = build_ring_graph(
    builder, registers, reset_inactive, ports, host_bytes, ring_depth,
  )
  ring_outputs(builder, signals)
  builder.finish()
}

///|
fn ring_validate_parameters(
  host_bytes : UInt64,
  ring_depth : Int,
) -> Unit raise RingReaderError {
  if host_bytes == 0UL || host_bytes > 4294967296UL {
    raise InvalidHostBytes(value=host_bytes, maximum=4294967296UL)
  }
  if ring_depth != 2 && ring_depth != 4 && ring_depth != 8 && ring_depth != 16 {
    raise InvalidRingDepth(value=ring_depth)
  }
}
