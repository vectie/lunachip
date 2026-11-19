///|
/// Opt-in fetched concurrent core with aligned four-byte descriptor and
/// operand reads. The host must support bytes=4/mask=15 little-endian reads.
/// Operand bursts never cross a row; unaligned addresses and tails use bytes.
/// Arithmetic, descriptor encoding, arbitration and stores retain their rules.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.ring_concurrent_word_tile(
///       rows=1,
///       columns=1,
///       max_reduction=4,
///       host_bytes=1024UL,
///       ring_depth=4,
///       queue_depth=3,
///     )
///     .memories()
///     .length(),
///     10,
///   )
/// }
/// ```
pub fn ring_concurrent_word_tile(
  rows~ : Int32,
  columns~ : Int32,
  max_reduction~ : Int32,
  host_bytes~ : UInt64,
  ring_depth~ : Int32,
  queue_depth~ : Int32,
) -> @ir.Module raise {
  build_ring_concurrent_tile(
    rows~,
    columns~,
    max_reduction~,
    host_bytes~,
    ring_depth~,
    queue_depth~,
    word_reads=true,
  )
}

///|
fn concurrent_loader_word_request(
  builder : @wire.ModuleBuilder,
  state : ConcurrentLoaderState,
  requesting : @wire.Signal,
  permitted : @wire.Signal,
) -> ArbiterRequest raise {
  let transfer = state.transfer
  let address = portable_transfer_address(
    builder,
    transfer.base.value(),
    transfer.stride.value(),
    transfer.row.value(),
    transfer.column.value(),
    1,
  )
  // Avoid subtract-underflow assumptions: full-width addition precedes the
  // comparison. Admission already validates the complete rectangle/aperture.
  let word = builder.bit_and(
    builder.equal(
      builder.slice(address, 1, 0),
      builder.constant(@wire.bits(2), 0UL),
    ),
    builder.less_equal(
      builder.add(
        builder.zero_extend(transfer.column.value(), 14),
        execute_constant(builder, 14, 4),
      ),
      builder.zero_extend(transfer.columns.value(), 14),
    ),
  )
  {
    valid: builder.bit_and(requesting, permitted),
    write: builder.constant(@wire.bits(1), 0UL),
    address,
    bytes: builder.mux(
      word,
      execute_constant(builder, 3, 4),
      execute_constant(builder, 3, 1),
    ),
    mask: builder.mux(
      word,
      builder.constant(@wire.bits(4), 15UL),
      builder.constant(@wire.bits(4), 1UL),
    ),
    data: builder.constant(@wire.bits(32), 0UL),
    tag: transfer.tag.value(),
  }
}
