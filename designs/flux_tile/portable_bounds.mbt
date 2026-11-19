///|
priv struct PortableBounds {
  stride_valid : @wire.Signal
  aligned : @wire.Signal
  in_aperture : @wire.Signal
}

///|
// Base/stride are UInt32 and dimensions are UInt13. With nonzero dimensions,
// this complete exclusive-end expression is below 2^46, so UInt64 arithmetic
// cannot wrap. The public generator checks host_bytes in 1..=2^32 first.
// element_bytes is the statically selected operand byte or INT32 word size.
fn portable_transfer_bounds(
  builder : @wire.ModuleBuilder,
  base : @wire.Signal,
  stride : @wire.Signal,
  transfer_rows : @wire.Signal,
  transfer_columns : @wire.Signal,
  element_bytes : Int32,
  host_bytes : UInt64,
) -> PortableBounds raise {
  let wide = @wire.uint(64)
  let one = builder.constant(wide, 1UL)
  let zero = builder.constant(wide, 0UL)
  let rows = builder.zero_extend(transfer_rows, 64)
  let columns = builder.zero_extend(transfer_columns, 64)
  let base = builder.zero_extend(base, 64)
  let stride = builder.zero_extend(stride, 64)
  let row_bytes = builder.mul_low(
    columns,
    builder.constant(wide, element_bytes.to_uint64()),
  )
  let span = builder.mul_low(builder.sub(rows, one), stride)
  let end_exclusive = builder.add(builder.add(base, span), row_bytes)
  let nonempty = builder.bit_and(
    builder.greater_than(rows, zero),
    builder.greater_than(columns, zero),
  )
  let in_aperture = builder.bit_and(
    nonempty,
    builder.less_equal(end_exclusive, builder.constant(wide, host_bytes)),
  )
  let aligned = if element_bytes == 1 {
    builder.constant(@wire.bits(1), 1UL)
  } else {
    let mask = builder.constant(wide, 3UL)
    builder.bit_and(
      builder.equal(builder.bit_and(base, mask), zero),
      builder.equal(builder.bit_and(stride, mask), zero),
    )
  }
  {
    stride_valid: builder.greater_equal(stride, row_bytes),
    aligned,
    in_aperture,
  }
}

///|
// Call only after the full rectangle has passed portable_transfer_bounds.
// Request cursors remain within that validated rectangle. Narrowing here is
// address encoding, never the range check itself.
fn portable_transfer_address(
  builder : @wire.ModuleBuilder,
  base : @wire.Signal,
  stride : @wire.Signal,
  row : @wire.Signal,
  column : @wire.Signal,
  element_bytes : Int32,
) -> @wire.Signal raise {
  let row_offset = builder.mul_low(
    builder.zero_extend(row, 64),
    builder.zero_extend(stride, 64),
  )
  let column_offset = builder.mul_low(
    builder.zero_extend(column, 64),
    builder.constant(@wire.uint(64), element_bytes.to_uint64()),
  )
  builder.truncate(
    builder.add(
      builder.add(builder.zero_extend(base, 64), row_offset),
      column_offset,
    ),
    32,
  )
}
