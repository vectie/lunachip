///|
fn sample_descriptor() -> @descriptor.Descriptor {
  {
    opcode: StoreC,
    id: 0x12345678U,
    rows: 0x0102U,
    columns: 0x0304U,
    reduction: 0x0506U,
    base: 0x89abcdefU,
    stride: 0xfedcba98U,
  }
}

///|
fn expect_decode_error(
  bytes : Bytes,
  expected : @descriptor.DescriptorError,
) -> Unit raise {
  try @descriptor.decode(bytes[:]) catch {
    error => assert_eq(error, expected)
  } noraise {
    _ => fail("malformed descriptor accepted")
  }
}

///|
test "descriptor golden fixes little endian byte layout and zero reserved fields" {
  let bytes = sample_descriptor().encode()
  assert_eq(@descriptor.byte_length(), 32)
  assert_eq(bytes.to_array().map(byte => byte.to_uint()), [
    0U, 1U, 3U, 0U, 120U, 86U, 52U, 18U, 2U, 1U, 4U, 3U, 6U, 5U, 0U, 0U, 239U, 205U,
    171U, 137U, 152U, 186U, 220U, 254U, 0U, 0U, 0U, 0U, 0U, 0U, 0U, 0U,
  ])
  assert_eq(@descriptor.decode(bytes[:]), sample_descriptor())
}

///|
test "descriptor round trips all opcodes and UInt13 and UInt32 endpoints" {
  for opcode in [@descriptor.Opcode::LoadA, LoadB, MatMul, StoreC, Fence] {
    for value in [0U, 1U, 4096U, 8191U] {
      let descriptor : @descriptor.Descriptor = {
        opcode,
        id: 0xffffffffU,
        rows: value,
        columns: value,
        reduction: value,
        base: 0xffffffffU,
        stride: 0U,
      }
      let bytes = descriptor.encode()
      assert_eq(@descriptor.decode(bytes[:]), descriptor)
      assert_eq(@descriptor.decode(bytes[:]).encode(), bytes)
    }
  }
}

///|
test "descriptor exact length rejects truncated and extra bytes first" {
  for length in [0, 1, 7, 16, 31, 33, 64] {
    expect_decode_error(
      Bytes::make(length, b'\xff'),
      InvalidLength(actual=length),
    )
  }
}

///|
test "descriptor rejects every unknown major and minor version before reserved fields" {
  for offset in [0, 1] {
    for value in 0..<256 {
      if value == (if offset == 0 { 0 } else { 1 }) {
        continue
      }
      let raw = sample_descriptor().encode().to_array()
      raw[offset] = value.to_byte()
      raw[3] = b'\xff'
      expect_decode_error(
        Bytes::from_array(raw[:]),
        UnsupportedVersion(major=raw[0].to_uint(), minor=raw[1].to_uint()),
      )
    }
  }
}

///|
test "descriptor rejects every reserved byte and flag before opcode" {
  for offset in [3, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31] {
    for value in [1, 128, 255] {
      let raw = sample_descriptor().encode().to_array()
      raw[offset] = value.to_byte()
      raw[2] = b'\xff'
      expect_decode_error(
        Bytes::from_array(raw[:]),
        ReservedByte(offset~, value=value.reinterpret_as_uint()),
      )
    }
  }
  let raw = sample_descriptor().encode().to_array()
  raw[3] = b'\x02'
  raw[14] = b'\x01'
  expect_decode_error(
    Bytes::from_array(raw[:]),
    ReservedByte(offset=3, value=2U),
  )
}

///|
test "descriptor rejects unsupported opcode before dimension representation" {
  for value in 5..<256 {
    let raw = sample_descriptor().encode().to_array()
    raw[2] = value.to_byte()
    raw[9] = b'\xff'
    expect_decode_error(
      Bytes::from_array(raw[:]),
      UnsupportedOpcode(value=value.reinterpret_as_uint()),
    )
  }
}

///|
test "descriptor decoder rejects high dimension bits rather than truncating" {
  for (offset, field) in [(8, "rows"), (10, "columns"), (12, "reduction")] {
    for value in [8192U, 16384U, 32768U, 65535U] {
      let raw = sample_descriptor().encode().to_array()
      raw[offset] = value.to_byte()
      raw[offset + 1] = (value >> 8).to_byte()
      expect_decode_error(
        Bytes::from_array(raw[:]),
        DimensionOutOfRange(field~, value~),
      )
    }
  }
}

///|
test "descriptor encoder rejects out of range dimensions without narrowing" {
  for field in ["rows", "columns", "reduction"] {
    for value in [8192U, 65535U, 0xffffffffU] {
      let descriptor : @descriptor.Descriptor = {
        ..sample_descriptor(),
        rows: if field == "rows" {
          value
        } else {
          1U
        },
        columns: if field == "columns" {
          value
        } else {
          1U
        },
        reduction: if field == "reduction" {
          value
        } else {
          1U
        },
      }
      try descriptor.encode() catch {
        DimensionOutOfRange(field=actual_field, value=actual_value) => {
          assert_eq(actual_field, field)
          assert_eq(actual_value, value)
        }
        error => fail("unexpected error: \{Repr(error)}")
      } noraise {
        _ => fail("encoder narrowed an invalid dimension")
      }
    }
  }
}

///|
test "descriptor syntax deliberately preserves context-invalid but representable commands" {
  let descriptor : @descriptor.Descriptor = {
    opcode: Fence,
    id: 7U,
    rows: 0U,
    columns: 8191U,
    reduction: 4096U,
    base: 3U,
    stride: 1U,
  }
  assert_eq(@descriptor.decode(descriptor.encode()[:]), descriptor)
}
