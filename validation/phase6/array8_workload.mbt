///|
fn array8_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=8,
    columns=8,
    max_reduction=16,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
fn array8_packet(position : Int32) -> Bytes raise {
  let descriptor : @slotted_descriptor.Descriptor = match position {
    0 =>
      {
        opcode: LoadA,
        id: 101,
        rows: 8,
        columns: 16,
        reduction: 0,
        base: 512,
        stride: 20,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    1 =>
      {
        opcode: LoadB,
        id: 102,
        rows: 16,
        columns: 8,
        reduction: 0,
        base: 1280,
        stride: 12,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    2 =>
      {
        opcode: MatMul,
        id: 103,
        rows: 8,
        columns: 8,
        reduction: 16,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    3 =>
      {
        opcode: Fence,
        id: 104,
        rows: 0,
        columns: 0,
        reduction: 0,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    4 =>
      {
        opcode: LoadA,
        id: 105,
        rows: 8,
        columns: 16,
        reduction: 0,
        base: 768,
        stride: 21,
        a_slot: 1,
        b_slot: 0,
        c_slot: 0,
      }
    5 =>
      {
        opcode: LoadB,
        id: 106,
        rows: 16,
        columns: 8,
        reduction: 0,
        base: 1536,
        stride: 13,
        a_slot: 0,
        b_slot: 1,
        c_slot: 0,
      }
    6 =>
      {
        opcode: MatMul,
        id: 107,
        rows: 8,
        columns: 8,
        reduction: 16,
        base: 0,
        stride: 0,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    7 =>
      {
        opcode: StoreC,
        id: 108,
        rows: 8,
        columns: 8,
        reduction: 0,
        base: 2048,
        stride: 40,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    8 =>
      {
        opcode: StoreC,
        id: 109,
        rows: 8,
        columns: 8,
        reduction: 0,
        base: 2560,
        stride: 44,
        a_slot: 0,
        b_slot: 0,
        c_slot: 1,
      }
    9 =>
      {
        opcode: Fence,
        id: 110,
        rows: 0,
        columns: 0,
        reduction: 0,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    _ => fail("invalid predefined 8x8 packet position \{position}")
  }
  descriptor.encode()
}

///|
fn array8_install(memory : Array[Int32], position : Int32) -> Unit raise {
  let bytes = array8_packet(position)
  for index in 0..<bytes.length() {
    memory[3072 + position % 4 * 32 + index] = bytes[index].to_int()
  }
}

///|
fn array8_operands(slot : Int32) -> (Array[Int32], Array[Int32]) {
  let left = Array::make(128, 0)
  let right = Array::make(128, 0)
  for index in 0..<128 {
    left[index] = (index * 17 + slot * 31 + 5) % 256 - 128
    right[index] = (index * 29 + slot * 47 + 3) % 256 - 128
  }
  for index, value in [-128, 127, 0, -1] {
    left[index] = value
    right[index] = value
  }
  (left, right)
}

///|
fn array8_memory() -> Array[Int32] raise {
  let memory = Array::make(4096, 165)
  for slot in 0..<2 {
    let (left, right) = array8_operands(slot)
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
  for position in 0..<4 {
    array8_install(memory, position)
  }
  memory
}

///|
fn verify_array8_memory(
  memory : Array[Int32],
) -> (Array[Int32], Array[Int32]) raise {
  let expected = array8_memory()
  for position in 6..<10 {
    array8_install(expected, position)
  }
  let results : Array[Array[Int32]] = []
  for slot in 0..<2 {
    let (left, right) = array8_operands(slot)
    let result = @flux_tile.matmul_int8_oracle(
      left,
      right,
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
    fail("predefined slot matrices did not distinguish stored slot identity")
  }
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "8x8 host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
  (results[0], results[1])
}
