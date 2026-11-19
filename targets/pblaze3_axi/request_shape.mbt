///|
// Validate the untruncated 32-bit address and the complete sixteen-row extent.
// A wide row's base and stride must be multiples of its transfer length
// (128 or 512 bytes). This keeps each burst within one 4 KiB page.
fn invalid_request(
  b : @wire.ModuleBuilder,
  address : @wire.Signal,
  data : @wire.Signal,
  write : @wire.Signal,
  line : @wire.Signal,
  burst : @wire.Signal,
  wide : @wire.Signal,
  wide1024~ : Bool = false,
  deep_batch~ : Bool = false,
  strided_rows~ : Bool = false,
  group64~ : @wire.Signal? = None,
  slice1k~ : @wire.Signal? = None,
  prefetch~ : @wire.Signal? = None,
) -> @wire.Signal raise {
  let batch = both(b, [
    wide,
    burst,
    line,
    b.bit_not(write),
    b.slice(data, 31, 31),
  ])
  let stride = b.zero_extend(
    u(b, b.slice(data, if wide1024 { 29 } else { 30 }, 0)),
    36,
  )
  let long = if wide1024 { Some(b.slice(data, 30, 30)) } else { None }
  let end = b.add(
    b.add(b.zero_extend(address, 36), b.mul_low(stride, n(b, 36, 15UL))),
    if long is Some(flag) {
      b.mux(flag, n(b, 36, 511UL), n(b, 36, 127UL))
    } else {
      n(b, 36, 127UL)
    },
  )
  let end = if deep_batch {
    b.mux(
      eq(b, data, 0xe0000200UL),
      b.add(b.zero_extend(address, 36), n(b, 36, 32767UL)),
      end,
    )
  } else {
    end
  }
  // The last byte is 15 row strides plus 2047 bytes from this stripe's base.
  let end = if strided_rows {
    let base = b.zero_extend(address, 36)
    b.mux(
      eq(b, data, 0xe0001000UL),
      b.add(base, n(b, 36, 63487UL)),
      b.mux(eq(b, data, 0xe0001800UL), b.add(base, n(b, 36, 94207UL)), end),
    )
  } else {
    end
  }
  let end = if group64 is Some(g) {
    // Inclusive last byte of the 64th 512-byte slice. Keep the address
    // calculation wide so a crossing of the 2 GiB aperture cannot wrap.
    let extent = b.mux(
      eq(b, data, 0xf0000800UL),
      n(b, 36, 63UL * 2048UL + 511UL),
      b.mux(
        eq(b, data, 0xf0001000UL),
        n(b, 36, 63UL * 4096UL + 511UL),
        n(b, 36, 63UL * 6144UL + 511UL),
      ),
    )
    b.mux(g, b.add(b.zero_extend(address, 36), extent), end)
  } else {
    end
  }
  let end = if slice1k is Some(w) {
    // A 1 KiB row burst must stay on one 4 KiB page. On bad alignment
    // force the inclusive endpoint outside the aperture.
    let extent = b.mux(
      eq(b, data, 0xf8000800UL),
      n(b, 36, 31UL * 2048UL + 1023UL),
      b.mux(
        eq(b, data, 0xf8001000UL),
        n(b, 36, 31UL * 4096UL + 1023UL),
        n(b, 36, 31UL * 6144UL + 1023UL),
      ),
    )
    let extent = if prefetch is Some(early) {
      let full = b.mux(
        eq(b, data, 0xfc000800UL),
        n(b, 36, 511UL * 2048UL + 1023UL),
        b.mux(
          eq(b, data, 0xfc001000UL),
          n(b, 36, 511UL * 4096UL + 1023UL),
          n(b, 36, 511UL * 6144UL + 1023UL),
        ),
      )
      b.mux(early, full, extent)
    } else {
      extent
    }
    let last_byte = b.add(b.zero_extend(address, 36), extent)
    b.mux(
      w,
      b.mux(b.slice(address, 9, 9), n(b, 36, 0x80000000UL), last_byte),
      end,
    )
  } else {
    end
  }
  any(b, [
    b.slice(address, 31, 31),
    b.bit_not(eq(b, b.slice(address, 1, 0), 0UL)),
    both(b, [line, b.bit_not(eq(b, b.slice(address, 3, 0), 0UL))]),
    both(b, [
      burst,
      any(b, [
        b.bit_not(line),
        write,
        b.bit_not(eq(b, b.slice(address, 6, 0), 0UL)),
      ]),
    ]),
    both(b, [wide, b.bit_not(both(b, [burst, line, b.bit_not(write)]))]),
    both(b, [
      batch,
      any(b, [
        if long is Some(flag) {
          b.bit_or(
            eq(b, stride, 0UL),
            both(b, [
              flag,
              any(b, [
                b.bit_not(eq(b, b.slice(address, 8, 0), 0UL)),
                b.bit_not(eq(b, b.slice(data, 8, 0), 0UL)),
              ]),
            ]),
          )
        } else {
          eq(b, stride, 0UL)
        },
        b.bit_not(eq(b, b.slice(data, 6, 0), 0UL)),
        b.greater_equal(end, n(b, 36, 0x80000000UL)),
      ]),
    ]),
  ])
}
