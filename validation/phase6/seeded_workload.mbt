///|
fn seeded_master() -> UInt64 {
  0x5eedc0de20261005UL
}

///|
fn seeded_operands() -> Array[Array[Int]] {
  let random = @verilator.DeterministicPrng::new(
    seeded_master() ^ 0x4d4154524958UL,
  )
  let matrices : Array[Array[Int]] = []
  // A0, B0, A1, B1: 512 value draws followed by four edge-position draws.
  for _ in 0..<4 {
    let values = Array::make(128, 0)
    for index in 0..<128 {
      values[index] = (random.next() & 255UL).to_int() - 128
    }
    matrices.push(values)
  }
  for values in matrices {
    let offset = (random.next() % 128UL).to_int()
    for index, value in [-128, 127, 0, -1, 1] {
      values[(offset + 23 * index) % 128] = value
    }
  }
  matrices
}

///|
fn seeded_memory() -> Array[Int] raise {
  let memory = array8_memory()
  let operands = seeded_operands()
  for slot in 0..<2 {
    let left = operands[slot * 2]
    let right = operands[slot * 2 + 1]
    let a_base = if slot == 0 { 512 } else { 768 }
    let a_stride = if slot == 0 { 20 } else { 21 }
    let b_base = if slot == 0 { 1280 } else { 1536 }
    let b_stride = if slot == 0 { 12 } else { 13 }
    for row in 0..<8 {
      for column in 0..<16 {
        memory[a_base + row * a_stride + column] = left[row * 16 + column] & 255
      }
    }
    for row in 0..<16 {
      for column in 0..<8 {
        memory[b_base + row * b_stride + column] = right[row * 8 + column] & 255
      }
    }
  }
  memory
}

///|
fn verify_seeded_memory(memory : Array[Int]) -> (Array[Int], Array[Int]) raise {
  let expected = seeded_memory()
  for position in 6..<10 {
    array8_install(expected, position)
  }
  let operands = seeded_operands()
  let results : Array[Array[Int]] = []
  for slot in 0..<2 {
    let result = @flux_tile.matmul_int8_oracle(
      operands[slot * 2],
      operands[slot * 2 + 1],
      rows=8,
      columns=8,
      reduction=16,
    )
    results.push(result)
    let base = if slot == 0 { 2048 } else { 2560 }
    let stride = if slot == 0 { 40 } else { 44 }
    for row in 0..<8 {
      for column in 0..<8 {
        let bits = result[row * 8 + column].to_int64().reinterpret_as_uint64() &
          0xffffffffUL
        for byte in 0..<4 {
          expected[base + row * stride + column * 4 + byte] = ((
            bits >> (byte * 8)
          ) &
          255UL).to_int()
        }
      }
    }
  }
  if results[0] == results[1] {
    fail("seeded matrices did not distinguish stored result-slot identity")
  }
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "seeded host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
  (results[0], results[1])
}
