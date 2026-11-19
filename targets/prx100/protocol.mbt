///|
/// CRC-8/ATM: polynomial 0x07, initial zero, no reflection/xor-out.
pub fn crc8(bytes : BytesView) -> Byte {
  let mut crc = 0U
  for byte in bytes {
    crc = crc ^ byte.to_uint()
    for _ in 0..<8 {
      crc = if (crc & 128U) != 0U { (crc << 1) ^ 7U } else { crc << 1 }
      crc = crc & 255U
    }
  }
  crc.to_byte()
}

///|
/// Encode transport0.1; semantic errors are returned by hardware replies.
pub fn request(
  opcode : Byte,
  sequence : UInt16,
  argument : UInt32,
  data : UInt32,
) -> Bytes {
  let bytes : Array[Byte] = [
    0xa5,
    0x5a,
    1,
    opcode,
    sequence.to_uint().to_byte(),
    (sequence.to_uint() >> 8).to_byte(),
  ]
  for value in [argument, data] {
    for offset in 0..<4 {
      bytes.push((value >> (offset * 8)).to_byte())
    }
  }
  bytes.push(crc8(Bytes::from_array(bytes)[2:]))
  bytes.push(0x0d)
  Bytes::from_array(bytes)
}

///|
pub(all) struct Reply {
  opcode : Byte
  sequence : UInt16
  status : Byte
  words : ReadOnlyArray[UInt32]
} derive(Eq, @debug.Debug)

///|
/// Validate every envelope field before exposing response words.
pub fn decode_reply(bytes : BytesView) -> Reply raise BoardError {
  guard bytes.length() == 32 else { raise InvalidFrame("reply length") }
  guard bytes[0] == 0xa5 &&
    bytes[1] == 0x5a &&
    bytes[2] == 1 &&
    (bytes[3].to_uint() & 128U) != 0U &&
    bytes[6] <= 5 &&
    bytes[7] == 0 &&
    bytes[28] == 0 &&
    bytes[29] == 0 &&
    bytes[31] == 0x0d else {
    raise InvalidFrame("reply envelope")
  }
  guard crc8(bytes[2:30]) == bytes[30] else { raise InvalidFrame("reply CRC") }
  let words : Array[UInt32] = []
  for word in 0..<5 {
    let mut value = 0U
    for offset in 0..<4 {
      value = value | (bytes[8 + word * 4 + offset].to_uint() << (offset * 8))
    }
    words.push(value)
  }
  {
    opcode: (bytes[3].to_uint() & 127U).to_byte(),
    sequence: (bytes[4].to_uint() | (bytes[5].to_uint() << 8)).to_uint16(),
    status: bytes[6],
    words: ReadOnlyArray::from_array(words),
  }
}

///|
pub extend Reply with Eq::{equal, not_equal}

///|
pub extend Reply with @debug.Debug::{to_repr}

///|
fn crc_step(
  b : @wire.ModuleBuilder,
  crc : @wire.Signal,
  byte : @wire.Signal,
) -> @wire.Signal raise {
  let mut value = b.bit_xor(crc, byte)
  for _ in 0..<8 {
    let shifted = b.shift_left(value, number(b, 1, 1UL))
    value = b.mux(
      same(b, b.slice(value, 7, 7), 1UL),
      b.bit_xor(shifted, number(b, 8, 7UL)),
      shifted,
    )
  }
  value
}
