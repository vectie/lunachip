///|
fn shape_reload_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=8,
    columns=8,
    max_reduction=17,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
fn shape_reload_packet(position : Int) -> Bytes raise {
  let fields : (
    @descriptor.Opcode,
    UInt,
    UInt,
    UInt,
    UInt,
    UInt,
    UInt,
    UInt,
    UInt,
  ) = match position {
    0 => (LoadA, 3, 17, 0, 512, 23, 1, 0, 0)
    1 => (LoadB, 17, 5, 0, 768, 11, 0, 0, 0)
    2 => (MatMul, 3, 5, 17, 0, 0, 1, 0, 0)
    3 => (Fence, 0, 0, 0, 0, 0, 0, 0, 0)
    4 => (LoadA, 8, 1, 0, 1152, 5, 1, 0, 0)
    5 => (LoadB, 1, 8, 0, 1280, 16, 0, 0, 0)
    6 => (MatMul, 8, 8, 1, 0, 0, 1, 0, 1)
    7 => (StoreC, 3, 5, 0, 1536, 28, 0, 0, 0)
    8 => (StoreC, 8, 8, 0, 2048, 44, 0, 0, 1)
    9 => (Fence, 0, 0, 0, 0, 0, 0, 0, 0)
    _ => fail("invalid shape-reload packet position \{position}")
  }
  let (opcode, rows, columns, reduction, base, stride, a_slot, b_slot, c_slot) = fields
  let packet : @slotted_descriptor.Descriptor = {
    opcode,
    id: (501 + position).reinterpret_as_uint(),
    rows,
    columns,
    reduction,
    base,
    stride,
    a_slot,
    b_slot,
    c_slot,
  }
  packet.encode()
}

///|
fn shape_reload_install(memory : Array[Int], position : Int) -> Unit raise {
  let packet = shape_reload_packet(position)
  for index in 0..<packet.length() {
    memory[3072 + position % 4 * 32 + index] = packet[index].to_int()
  }
}

///|
fn shape_reload_operands(second : Bool) -> (Array[Int], Array[Int]) {
  let left = Array::makei(if second { 8 } else { 51 }, index => {
    (index * 37 + (if second { 91 } else { 13 })) % 256 - 128
  })
  let right = Array::makei(if second { 8 } else { 85 }, index => {
    (index * 53 + (if second { 7 } else { 69 })) % 256 - 128
  })
  for index, value in [-128, 127, 0, -1, 1] {
    left[index] = value
    right[index] = [-128, -128, 127, 1, -1][index]
  }
  (left, right)
}

///|
fn shape_reload_memory() -> Array[Int] raise {
  let memory = Array::make(4096, 165)
  for second in [false, true] {
    let (left, right) = shape_reload_operands(second)
    let rows = if second { 8 } else { 3 }
    let columns = if second { 8 } else { 5 }
    let reduction = if second { 1 } else { 17 }
    let a_base = if second { 1152 } else { 512 }
    let b_base = if second { 1280 } else { 768 }
    let a_stride = if second { 5 } else { 23 }
    let b_stride = if second { 16 } else { 11 }
    for row in 0..<rows {
      for k in 0..<reduction {
        memory[a_base + row * a_stride + k] = left[row * reduction + k] & 255
      }
    }
    for k in 0..<reduction {
      for column in 0..<columns {
        memory[b_base + k * b_stride + column] = right[k * columns + column] &
          255
      }
    }
  }
  for position in 0..<4 {
    shape_reload_install(memory, position)
  }
  memory
}

///|
fn shape_reload_verify(memory : Array[Int]) -> Array[Array[Int]] raise {
  let expected = shape_reload_memory()
  for position in 6..<10 {
    shape_reload_install(expected, position)
  }
  let results : Array[Array[Int]] = []
  for second in [false, true] {
    let (left, right) = shape_reload_operands(second)
    let rows = if second { 8 } else { 3 }
    let columns = if second { 8 } else { 5 }
    let result = @flux_tile.matmul_int8_oracle(
      left,
      right,
      rows~,
      columns~,
      reduction=if second { 1 } else { 17 },
    )
    results.push(result)
    let base = if second { 2048 } else { 1536 }
    let stride = if second { 44 } else { 28 }
    for row in 0..<rows {
      for column in 0..<columns {
        let bits = result[row * columns + column]
          .to_int64()
          .reinterpret_as_uint64() &
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
  for index in 0..<memory.length() {
    if memory[index] != expected[index] {
      fail(
        "shape-reload host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
  results
}
