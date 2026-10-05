///|
/// Return the fixed byte length of provisional descriptor format 0.2.
pub fn byte_length() -> Int {
  32
}

///|
fn read_le(bytes : BytesView, offset : Int, count : Int) -> UInt {
  let mut value = 0U
  for index in 0..<count {
    value = value | (bytes[offset + index].to_uint() << (index * 8))
  }
  value
}

///|
fn write_le(
  bytes : Array[Byte],
  offset : Int,
  count : Int,
  value : UInt,
) -> Unit {
  for index in 0..<count {
    bytes[offset + index] = (value >> (index * 8)).to_byte()
  }
}

///|
fn check_dimension(field : String, value : UInt) -> Unit raise DescriptorError {
  if value > 8191U {
    raise DimensionOutOfRange(field~, value~)
  }
}

///|
fn check_slot(field : String, value : UInt) -> Unit raise DescriptorError {
  if value > 1U {
    raise SlotOutOfRange(field~, value~)
  }
}

///|
fn opcode_encoding(opcode : @descriptor.Opcode) -> UInt {
  match opcode {
    LoadA => 0U
    LoadB => 1U
    MatMul => 2U
    StoreC => 3U
    Fence => 4U
  }
}

///|
/// Encode canonical draft 0.2 bytes with zero reserved bits. Width validation
/// is syntax-only: nonzero operation-specific unused fields are preserved.
pub fn Descriptor::encode(self : Descriptor) -> Bytes raise DescriptorError {
  check_dimension("rows", self.rows)
  check_dimension("columns", self.columns)
  check_dimension("reduction", self.reduction)
  check_slot("a_slot", self.a_slot)
  check_slot("b_slot", self.b_slot)
  check_slot("c_slot", self.c_slot)
  let bytes = Array::make(32, b'\x00')
  bytes[1] = b'\x02'
  bytes[2] = opcode_encoding(self.opcode).to_byte()
  write_le(bytes, 4, 4, self.id)
  write_le(bytes, 8, 2, self.rows)
  write_le(bytes, 10, 2, self.columns)
  write_le(bytes, 12, 2, self.reduction)
  write_le(bytes, 16, 4, self.base)
  write_le(bytes, 20, 4, self.stride)
  bytes[24] = self.a_slot.to_byte()
  bytes[25] = self.b_slot.to_byte()
  bytes[26] = self.c_slot.to_byte()
  Bytes::from_array(bytes[:])
}

///|
/// Decode exactly 32 draft 0.2 bytes without accepting old versions or
/// repairing reserved bits. Hardware checks operation-specific validity.
pub fn decode(bytes : BytesView) -> Descriptor raise DescriptorError {
  if bytes.length() != byte_length() {
    raise InvalidLength(actual=bytes.length())
  }
  let major = bytes[0].to_uint()
  let minor = bytes[1].to_uint()
  if major != 0U || minor != 2U {
    raise UnsupportedVersion(major~, minor~)
  }
  for offset in [3, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31] {
    let value = bytes[offset].to_uint()
    let selector = offset >= 24 && offset <= 26
    let mask = if selector { 0xfeU } else { 0xffU }
    if (value & mask) != 0U {
      if selector {
        raise ReservedBits(offset~, value~, mask~)
      } else {
        raise ReservedByte(offset~, value~)
      }
    }
  }
  let opcode_value = bytes[2].to_uint()
  let opcode = match opcode_value {
    0U => @descriptor.Opcode::LoadA
    1U => LoadB
    2U => MatMul
    3U => StoreC
    4U => Fence
    _ => raise UnsupportedOpcode(value=opcode_value)
  }
  let rows = read_le(bytes, 8, 2)
  let columns = read_le(bytes, 10, 2)
  let reduction = read_le(bytes, 12, 2)
  check_dimension("rows", rows)
  check_dimension("columns", columns)
  check_dimension("reduction", reduction)
  {
    opcode,
    id: read_le(bytes, 4, 4),
    rows,
    columns,
    reduction,
    base: read_le(bytes, 16, 4),
    stride: read_le(bytes, 20, 4),
    a_slot: bytes[24].to_uint(),
    b_slot: bytes[25].to_uint(),
    c_slot: bytes[26].to_uint(),
  }
}
