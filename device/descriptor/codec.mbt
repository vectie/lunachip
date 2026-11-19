///|
/// Return the fixed byte length of provisional descriptor format 0.1.
pub fn byte_length() -> Int32 {
  32
}

///|
fn read_le(bytes : BytesView, offset : Int32, count : Int32) -> UInt32 {
  let mut value = 0U
  for index in 0..<count {
    value = value | (bytes[offset + index].to_uint() << (index * 8))
  }
  value
}

///|
fn write_le(
  bytes : Array[Byte],
  offset : Int32,
  count : Int32,
  value : UInt32,
) -> Unit {
  for index in 0..<count {
    bytes[offset + index] = (value >> (index * 8)).to_byte()
  }
}

///|
fn check_dimension(
  field : String,
  value : UInt32,
) -> Unit raise DescriptorError {
  if value > 8191U {
    raise DimensionOutOfRange(field~, value~)
  }
}

///|
fn Opcode::encoding(self : Opcode) -> UInt32 {
  match self {
    LoadA => 0U
    LoadB => 1U
    MatMul => 2U
    StoreC => 3U
    Fence => 4U
  }
}

///|
/// Encode one canonical little-endian descriptor, setting version 0.1 and
/// every reserved byte to zero. Reject dimensions rather than truncating.
pub fn Descriptor::encode(self : Descriptor) -> Bytes raise DescriptorError {
  check_dimension("rows", self.rows)
  check_dimension("columns", self.columns)
  check_dimension("reduction", self.reduction)
  let bytes = Array::make(32, b'\x00')
  bytes[1] = b'\x01'
  bytes[2] = self.opcode.encoding().to_byte()
  write_le(bytes, 4, 4, self.id)
  write_le(bytes, 8, 2, self.rows)
  write_le(bytes, 10, 2, self.columns)
  write_le(bytes, 12, 2, self.reduction)
  write_le(bytes, 16, 4, self.base)
  write_le(bytes, 20, 4, self.stride)
  Bytes::from_array(bytes[:])
}

///|
/// Decode exactly 32 bytes without repairing unknown versions, reserved
/// fields, opcodes, or dimensions. Context-dependent validity is hardware's
/// responsibility, not part of this provider-neutral syntax codec.
pub fn decode(bytes : BytesView) -> Descriptor raise DescriptorError {
  if bytes.length() != byte_length() {
    raise InvalidLength(actual=bytes.length())
  }
  let major = bytes[0].to_uint()
  let minor = bytes[1].to_uint()
  if major != 0U || minor != 1U {
    raise UnsupportedVersion(major~, minor~)
  }
  for offset in [3, 14, 15, 24, 25, 26, 27, 28, 29, 30, 31] {
    let value = bytes[offset].to_uint()
    if value != 0U {
      raise ReservedByte(offset~, value~)
    }
  }
  let opcode_value = bytes[2].to_uint()
  let opcode = match opcode_value {
    0U => LoadA
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
  }
}
