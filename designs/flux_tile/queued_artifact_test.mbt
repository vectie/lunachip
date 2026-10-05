///|
test "queued tile canonical graph has a fixed pre-ring golden digest" {
  let design = @wire.single_design(
    "Queued",
    @flux_tile.queued_tile(
      rows=2,
      columns=3,
      max_reduction=5,
      host_bytes=4096UL,
      queue_depth=3,
    ),
  )
  inspect(
    @crypto.bytes_to_hex_string(
      @crypto.sha256(@utf8.encode(@codec.serialize(design))),
    ),
    content=(
      #|fdd8b6c621f9d4ec5787bffbdd452c60298d2841c256b013a1d74f8c0c5bf981
    ),
  )
}
