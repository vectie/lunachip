///|
/// PRX100 projection profile using the opt-in portable word-read interface.
pub fn core() -> @ir.Module raise {
  @flux_tile.ring_concurrent_word_tile(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}
