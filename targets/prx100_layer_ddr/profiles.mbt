///|
/// Bounded eight-read DDR pipeline, retaining the source word/line ABI.
/// FIFO endpoints are reset together with MIG; job reset never resets them.
pub fn bridge() -> @ir.Module raise {
  build_bridge([])
}

///|
/// Native-width responses for marked bursts. Ordinary word/line requests keep
/// the serial word contract, including scalar fallback and host portals.
pub fn wide_bridge() -> @ir.Module raise {
  build_bridge([], wide=true)
}

///|
/// Four ordered strided 128-byte rows share one source request/response owner.
pub fn batched_bridge() -> @ir.Module raise {
  build_bridge([], wide=true, batch=true)
}

///|
/// Four-row bursts with two interleaved reserved response FIFO banks.
/// Payload, reset and fault contracts match `batched_bridge`.
pub fn streaming_bridge() -> @ir.Module raise {
  build_bridge([], wide=true, batch=true, streaming=true)
}

///|
/// Reserve and prefetch all four rows without waiting for each row's send.
/// Word order, ownership and fault drainage match `streaming_bridge`.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @prx100_layer_ddr.read_ahead_bridge().outputs().length(),
///     @prx100_layer_ddr.streaming_bridge().outputs().length(),
///   )
/// }
/// ```
pub fn read_ahead_bridge() -> @ir.Module raise {
  build_bridge([], wide=true, batch=true, streaming=true, read_ahead=true)
}

///|
/// Eight-row target with 64 native return slots; pair with its matching
/// sixteen-row core and eight-row controller. Legacy markers remain four-row.
pub fn eight_row_bridge() -> @ir.Module raise {
  build_bridge(
    [],
    wide=true,
    batch=true,
    streaming=true,
    read_ahead=true,
    eight_row=true,
  )
}

///|
/// Eight-row bridge with the same full header checks and cycle contract.
/// Explicitly discard seven alignment bits only inside the extent arithmetic;
/// the original alignment and reserved-bit rejection predicates remain intact.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @prx100_layer_ddr.aligned_eight_row_bridge().outputs().length(),
///     @prx100_layer_ddr.eight_row_bridge().outputs().length(),
///   )
/// }
/// ```
pub fn aligned_eight_row_bridge() -> @ir.Module raise {
  build_bridge(
    [],
    wide=true,
    batch=true,
    streaming=true,
    read_ahead=true,
    eight_row=true,
    aligned_extent=true,
  )
}

///|
/// Sixteen strided rows share one owner with all 128 native returns reserved.
/// Example: `let design = @prx100_layer_ddr.sixteen_row_bridge()`.
pub fn sixteen_row_bridge() -> @ir.Module raise {
  build_bridge(
    [],
    wide=true,
    batch=true,
    streaming=true,
    read_ahead=true,
    eight_row=true,
    aligned_extent=true,
    sixteen_row=true,
  )
}

///|
/// Sixteen-row transport delivering two native lines per core response.
/// Pair only with the eight-word controller and feedback core profile.
pub fn delivery_bridge() -> @ir.Module raise {
  build_bridge(
    [],
    wide=true,
    batch=true,
    streaming=true,
    read_ahead=true,
    eight_row=true,
    aligned_extent=true,
    sixteen_row=true,
    delivery=true,
  )
}
