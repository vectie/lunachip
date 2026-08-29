///|
fn sha256_hex(text : String) -> String {
  let digest = @crypto.sha256(@utf8.encode(text))
  let output = StringBuilder(size_hint=64)
  for byte in digest {
    output.write_char(hex_digit(byte.to_int() >> 4))
    output.write_char(hex_digit(byte.to_int() & 15))
  }
  output.to_string()
}

///|
fn utf8_hex(text : String) -> String {
  let output = StringBuilder()
  for byte in @utf8.encode(text) {
    output.write_char(hex_digit(byte.to_int() >> 4))
    output.write_char(hex_digit(byte.to_int() & 15))
  }
  output.to_string()
}
