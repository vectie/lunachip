///|
fn hex_digit(value : Int) -> Char {
  match value {
    0 => '0'
    1 => '1'
    2 => '2'
    3 => '3'
    4 => '4'
    5 => '5'
    6 => '6'
    7 => '7'
    8 => '8'
    9 => '9'
    10 => 'a'
    11 => 'b'
    12 => 'c'
    13 => 'd'
    14 => 'e'
    _ => 'f'
  }
}

///|
pub fn width_mask(width : Int) -> UInt64 {
  if width == 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << width) - 1UL
  }
}

///|
pub fn known_value(width : Int, value : UInt64) -> @wave.LogicValue raise {
  @wave.LogicValue::from_uint64(width~, value=value & width_mask(width))
}

///|
pub fn normalized_known(
  width : Int,
  value : UInt64,
) -> @differential.NormalizedValue raise {
  @differential.NormalizedValue::parse(
    known_value(width, value).to_bit_string(),
  )
}

///|
pub fn padded_hex(value : UInt64, width : Int) -> String {
  value.to_string(radix=16).pad_start((width + 3) / 4, '0')
}

///|
pub fn sha256_hex(text : String) -> String {
  let digest = @crypto.sha256(@utf8.encode(text))
  let output = StringBuilder(size_hint=64)
  for byte in digest {
    output.write_char(hex_digit(byte.to_int() >> 4))
    output.write_char(hex_digit(byte.to_int() & 15))
  }
  output.to_string()
}

///|
pub fn utf8_hex(text : String) -> String {
  let output = StringBuilder()
  for byte in @utf8.encode(text) {
    output.write_char(hex_digit(byte.to_int() >> 4))
    output.write_char(hex_digit(byte.to_int() & 15))
  }
  output.to_string()
}

///|
pub fn tsv_header(ports : ArrayView[HarnessPort]) -> String {
  let output = StringBuilder()
  output.write_string("cycle")
  for port in ports {
    output.write_char('\t')
    output.write_string(port.emitted_name)
  }
  output.write_char('\n')
  output.to_string()
}
