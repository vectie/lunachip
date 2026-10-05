///|
fn sample_descriptor() -> @slotted_descriptor.Descriptor {
  {
    opcode: StoreC,
    id: 0x12345678U,
    rows: 0x0102U,
    columns: 0x0304U,
    reduction: 0x0506U,
    base: 0x89abcdefU,
    stride: 0xfedcba98U,
    a_slot: 1U,
    b_slot: 0U,
    c_slot: 1U,
  }
}

///|
fn expect_decode_error(
  bytes : Bytes,
  expected : @slotted_descriptor.DescriptorError,
) -> Unit raise {
  try @slotted_descriptor.decode(bytes[:]) catch {
    error => assert_eq(error, expected)
  } noraise {
    _ => fail("malformed slotted descriptor accepted")
  }
}

///|
test "slotted descriptor golden fixes version slots and little endian layout" {
  let command = sample_descriptor()
  let bytes = command.encode()
  assert_eq(@slotted_descriptor.byte_length(), 32)
  assert_eq(bytes.to_array().map(byte => byte.to_uint()), [
    0U, 2U, 3U, 0U, 120U, 86U, 52U, 18U, 2U, 1U, 4U, 3U, 6U, 5U, 0U, 0U, 239U, 205U,
    171U, 137U, 152U, 186U, 220U, 254U, 1U, 0U, 1U, 0U, 0U, 0U, 0U, 0U,
  ])
  assert_eq(@slotted_descriptor.decode(bytes[:]), command)
}

///|
test "slotted descriptor round trips all opcodes selections and width endpoints" {
  for opcode in [@descriptor.Opcode::LoadA, LoadB, MatMul, StoreC, Fence] {
    for value in [0U, 1U, 4096U, 8191U] {
      for mask in 0U..<8U {
        let command : @slotted_descriptor.Descriptor = {
          opcode,
          id: 0xffffffffU,
          rows: value,
          columns: value,
          reduction: value,
          base: 0xffffffffU,
          stride: 0U,
          a_slot: mask & 1U,
          b_slot: (mask >> 1) & 1U,
          c_slot: (mask >> 2) & 1U,
        }
        let bytes = command.encode()
        assert_eq(@slotted_descriptor.decode(bytes[:]), command)
        assert_eq(@slotted_descriptor.decode(bytes[:]).encode(), bytes)
      }
    }
  }
}

///|
test "slotted descriptor exact length precedes all other syntax errors" {
  for length in [0, 1, 7, 16, 31, 33, 64] {
    expect_decode_error(
      Bytes::make(length, b'\xff'),
      InvalidLength(actual=length),
    )
  }
}

///|
test "slotted descriptor rejects every unknown version before reserved fields" {
  for offset in [0, 1] {
    for value in 0..<256 {
      if value == (if offset == 0 { 0 } else { 2 }) {
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
test "slotted descriptor old and new codecs reject each other's versions" {
  let old : @descriptor.Descriptor = {
    opcode: Fence,
    id: 7U,
    rows: 0U,
    columns: 0U,
    reduction: 0U,
    base: 0U,
    stride: 0U,
  }
  expect_decode_error(old.encode(), UnsupportedVersion(major=0U, minor=1U))
  let new : @slotted_descriptor.Descriptor = {
    ..sample_descriptor(),
    a_slot: 0U,
    b_slot: 0U,
    c_slot: 0U,
  }
  try @descriptor.decode(new.encode()[:]) catch {
    @descriptor.DescriptorError::UnsupportedVersion(major~, minor~) => {
      assert_eq(major, 0U)
      assert_eq(minor, 2U)
    }
    error => fail("unexpected old codec error: \{Repr(error)}")
  } noraise {
    _ => fail("old codec accepted draft 0.2")
  }
}

///|
test "slotted descriptor reserved bytes and selector bits precede opcode" {
  for offset in [3, 14, 15, 27, 28, 29, 30, 31] {
    for value in [1U, 128U, 255U] {
      let raw = sample_descriptor().encode().to_array()
      raw[offset] = value.to_byte()
      raw[2] = b'\xff'
      expect_decode_error(
        Bytes::from_array(raw[:]),
        ReservedByte(offset~, value~),
      )
    }
  }
  for offset in [24, 25, 26] {
    for value in 2U..<256U {
      let raw = sample_descriptor().encode().to_array()
      raw[offset] = value.to_byte()
      raw[2] = b'\xff'
      expect_decode_error(
        Bytes::from_array(raw[:]),
        ReservedBits(offset~, value~, mask=254U),
      )
    }
  }
  let raw = sample_descriptor().encode().to_array()
  raw[24] = b'\x03'
  raw[25] = b'\xff'
  raw[27] = b'\x01'
  expect_decode_error(
    Bytes::from_array(raw[:]),
    ReservedBits(offset=24, value=3U, mask=254U),
  )
  raw[3] = b'\x01'
  expect_decode_error(
    Bytes::from_array(raw[:]),
    ReservedByte(offset=3, value=1U),
  )
}

///|
test "slotted descriptor rejects opcode before dimension representation" {
  for value in 5U..<256U {
    let raw = sample_descriptor().encode().to_array()
    raw[2] = value.to_byte()
    raw[9] = b'\xff'
    expect_decode_error(Bytes::from_array(raw[:]), UnsupportedOpcode(value~))
  }
}

///|
test "slotted descriptor decoding rejects each high dimension without narrowing" {
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
test "slotted descriptor encoding checks dimension widths before narrowing" {
  for field in ["rows", "columns", "reduction"] {
    for value in [8192U, 65535U, 0xffffffffU] {
      let command : @slotted_descriptor.Descriptor = {
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
      try command.encode() catch {
        DimensionOutOfRange(field=actual_field, value=actual_value) => {
          assert_eq(actual_field, field)
          assert_eq(actual_value, value)
        }
        error => fail("unexpected encode error: \{Repr(error)}")
      } noraise {
        _ => fail("invalid dimension was narrowed")
      }
    }
  }
}

///|
test "slotted descriptor encoding checks all selector widths including unused fields" {
  for field in ["a_slot", "b_slot", "c_slot"] {
    for value in [2U, 255U, 256U, 0xffffffffU] {
      let command : @slotted_descriptor.Descriptor = {
        ..sample_descriptor(),
        opcode: Fence,
        a_slot: if field == "a_slot" {
          value
        } else {
          0U
        },
        b_slot: if field == "b_slot" {
          value
        } else {
          0U
        },
        c_slot: if field == "c_slot" {
          value
        } else {
          0U
        },
      }
      try command.encode() catch {
        SlotOutOfRange(field=actual_field, value=actual_value) => {
          assert_eq(actual_field, field)
          assert_eq(actual_value, value)
        }
        error => fail("unexpected encode error: \{Repr(error)}")
      } noraise {
        _ => fail("invalid selector was narrowed")
      }
    }
  }
}

///|
test "slotted descriptor preserves semantic unused fields and duplicate caller identities" {
  let first : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: 0U,
    rows: 0U,
    columns: 8191U,
    reduction: 4096U,
    base: 3U,
    stride: 1U,
    a_slot: 1U,
    b_slot: 1U,
    c_slot: 1U,
  }
  let second : @slotted_descriptor.Descriptor = { ..first, opcode: LoadA, }
  assert_eq(@slotted_descriptor.decode(first.encode()[:]), first)
  assert_eq(@slotted_descriptor.decode(second.encode()[:]), second)
  assert_eq(first.id, second.id)
}
