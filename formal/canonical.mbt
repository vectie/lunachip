///|
fn require_nonempty(field : String, value : String) -> Unit raise FormalError {
  if value.is_empty() {
    raise EmptyField(field)
  }
}

///|
fn validate_digest(
  role : DigestRole,
  digest : String,
) -> Unit raise FormalError {
  if digest.length() != 64 {
    raise InvalidDigestLength(role~, length=digest.length())
  }
  for index in 0..<digest.length() {
    let symbol = digest[index]
    let valid = (symbol >= '0' && symbol <= '9') ||
      (symbol >= 'a' && symbol <= 'f')
    if !valid {
      raise InvalidDigestSymbol(role~, index~, symbol~)
    }
  }
}

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
fn encode_text(text : String) -> String {
  let bytes = @utf8.encode(text)
  let output = StringBuilder(size_hint=bytes.length() * 2)
  for byte in bytes {
    let value = byte.to_int()
    output.write_char(hex_digit(value >> 4))
    output.write_char(hex_digit(value & 15))
  }
  output.to_string()
}

///|
fn hex_nibble(symbol : UInt16) -> Int? {
  let value = symbol.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else if value >= 97 && value <= 102 {
    Some(value - 97 + 10)
  } else {
    None
  }
}

///|
fn decode_text(line : Int, encoded : String) -> String raise FormalError {
  if encoded.is_empty() || encoded.length() % 2 != 0 {
    raise InvalidCanonicalText(line~, value=encoded)
  }
  let bytes : Array[Byte] = []
  for index in 0..<(encoded.length() / 2) {
    guard hex_nibble(encoded[index * 2]) is Some(high) else {
      raise InvalidCanonicalText(line~, value=encoded)
    }
    guard hex_nibble(encoded[index * 2 + 1]) is Some(low) else {
      raise InvalidCanonicalText(line~, value=encoded)
    }
    bytes.push(((high << 4) | low).to_byte())
  }
  @utf8.decode(Bytes::from_array(bytes)) catch {
    _ => raise InvalidCanonicalText(line~, value=encoded)
  }
}

///|
fn sha256_hex(text : String) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(text)))
}

///|
fn compare_canonical_text(left : String, right : String) -> Int {
  let left_bytes = @utf8.encode(left)
  let right_bytes = @utf8.encode(right)
  let common = if left_bytes.length() < right_bytes.length() {
    left_bytes.length()
  } else {
    right_bytes.length()
  }
  for index in 0..<common {
    let left_byte = left_bytes[index].to_int()
    let right_byte = right_bytes[index].to_int()
    if left_byte < right_byte {
      return -1
    }
    if left_byte > right_byte {
      return 1
    }
  }
  left_bytes.length() - right_bytes.length()
}

///|
priv struct CanonicalReader {
  lines : Array[String]
  mut cursor : Int
}

///|
fn CanonicalReader::new(source : String) -> CanonicalReader raise FormalError {
  if !source.has_suffix("\n") {
    raise NonCanonicalArtifact
  }
  {
    lines: source.split("\n").map(part => part.to_owned()).to_array(),
    cursor: 0,
  }
}

///|
fn CanonicalReader::tokens(
  self : CanonicalReader,
  expected : String,
) -> (Int, Array[String]) raise FormalError {
  if self.cursor >= self.lines.length() - 1 {
    raise InvalidCanonicalLine(
      line=self.cursor + 1,
      expected~,
      actual="end of input",
    )
  }
  let line = self.cursor + 1
  let actual = self.lines[self.cursor]
  let tokens = actual.split(" ").map(part => part.to_owned()).to_array()
  self.cursor += 1
  (line, tokens)
}

///|
fn require_tokens(
  line : Int,
  tokens : ArrayView[String],
  keyword : String,
  count : Int,
  expected : String,
) -> Unit raise FormalError {
  if tokens.length() != count || tokens[0] != keyword {
    raise InvalidCanonicalLine(line~, expected~, actual=tokens.join(" "))
  }
}

///|
fn parse_int(
  line : Int,
  field : String,
  value : String,
) -> Int raise FormalError {
  @strconv.from_str(value) catch {
    _ => raise InvalidCanonicalInteger(line~, field~, value~)
  }
}

///|
fn read_header(
  reader : CanonicalReader,
  kind : String,
) -> Unit raise FormalError {
  let (line, tokens) = reader.tokens("\{kind} version")
  require_tokens(line, tokens, kind, 2, "\{kind} version")
  if tokens[1] != "1" {
    raise UnsupportedCanonicalVersion(kind~, version=tokens[1])
  }
}

///|
fn finish_canonical(
  reader : CanonicalReader,
  source : String,
  canonical : String,
) -> Unit raise FormalError {
  let (line, tokens) = reader.tokens("END")
  require_tokens(line, tokens, "END", 1, "END")
  if reader.cursor != reader.lines.length() - 1 || canonical != source {
    raise NonCanonicalArtifact
  }
}
