///|
fn read_bf16(path : String) -> Array[Float] raise {
  let bytes = @fs.read_file_to_bytes(path)
  guard bytes.length() % 2 == 0 else { fail("BF16 byte count") }
  Array::makei(bytes.length() / 2, i => {
    Float::reinterpret_from_uint(
      (bytes[2 * i].to_uint() | (bytes[2 * i + 1].to_uint() << 8)) << 16,
    )
  })
}

///|
fn float_bytes(values : ArrayView[Float]) -> Bytes {
  let bytes = Array::make(values.length() * 4, b'\x00')
  for i, x in values {
    let word = x.reinterpret_as_uint()
    for j in 0..<4 {
      bytes[4 * i + j] = (word >> (8 * j)).to_byte()
    }
  }
  Bytes::from_array(bytes)
}

///|
fn word_bytes(values : ArrayView[UInt32]) -> Bytes {
  let bytes = Array::make(values.length() * 4, b'\x00')
  for i, x in values {
    for j in 0..<4 {
      bytes[4 * i + j] = (x >> (8 * j)).to_byte()
    }
  }
  Bytes::from_array(bytes)
}

///|
fn bf16_bytes(values : ArrayView[Float]) -> Bytes raise {
  let bytes = Array::make(values.length() * 2, b'\x00')
  for i, x in values {
    let w = x.reinterpret_as_uint()
    assert_eq(w & 65535U, 0U)
    bytes[2 * i] = (w >> 16).to_byte()
    bytes[2 * i + 1] = (w >> 24).to_byte()
  }
  Bytes::from_array(bytes)
}

///|
fn gemv(
  weights : ArrayView[Float],
  x : ArrayView[Float],
  rows : Int32,
) -> Array[Float] raise {
  assert_eq(weights.length(), rows * x.length())
  Array::makei(rows, row => {
    let mut sum : Float = 0.0
    for k in 0..<x.length() {
      let product = weights[row * x.length() + k] * x[k]
      sum = sum + product
    }
    sum
  })
}

///|
fn rms(x : ArrayView[Float], gamma : ArrayView[Float]) -> Array[Float] raise {
  assert_eq(x.length(), gamma.length())
  let mut sum : Float = 0.0
  for v in x {
    let product = v * v
    sum = sum + product
  }
  let mean = sum * Float::from_double(1.0 / x.length().to_double())
  let variance = mean + (0.000001 : Float)
  let scale = Float::from_double(1.0 / variance.to_double().sqrt())
  Array::makei(x.length(), i => {
    let normalized = x[i] * scale
    normalized * gamma[i]
  })
}

///|
fn rope_coefficients(position : Int32) -> (Array[Float], Array[Float]) {
  let cos = Array::makei(64, i => {
    Float::from_double(
      @math.cos(
        position.to_double() *
        @math.pow(1000000.0, -2.0 * i.to_double() / 128.0),
      ),
    )
  })
  let sin = Array::makei(64, i => {
    Float::from_double(
      @math.sin(
        position.to_double() *
        @math.pow(1000000.0, -2.0 * i.to_double() / 128.0),
      ),
    )
  })
  (cos, sin)
}

///|
fn rotate(values : ArrayView[Float], position : Int32) -> Array[Float] {
  let (cos, sin) = rope_coefficients(position)
  let out = Array::make(values.length(), (0.0 : Float))
  for head in 0..<(values.length() / 128) {
    for i in 0..<64 {
      let a = values[head * 128 + i]
      let b = values[head * 128 + 64 + i]
      let ac = a * cos[i]
      let bs = b * -sin[i]
      let asine = a * sin[i]
      let bc = b * cos[i]
      out[head * 128 + i] = ac + bs
      out[head * 128 + 64 + i] = bc + asine
    }
  }
  out
}

///|
fn vector_add(a : ArrayView[Float], b : ArrayView[Float]) -> Array[Float] raise {
  assert_eq(a.length(), b.length())
  Array::makei(a.length(), i => a[i] + b[i])
}

///|
fn hash(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}
