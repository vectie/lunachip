///|
fn concurrent_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=512,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
fn concurrent_packet(position : Int32) -> Bytes raise {
  let descriptor : @slotted_descriptor.Descriptor = match position {
    0 =>
      {
        opcode: LoadA,
        id: 61,
        rows: 1,
        columns: 1,
        reduction: 0,
        base: 32,
        stride: 1,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    1 =>
      {
        opcode: LoadB,
        id: 62,
        rows: 1,
        columns: 1,
        reduction: 0,
        base: 64,
        stride: 1,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    2 =>
      {
        opcode: MatMul,
        id: 63,
        rows: 1,
        columns: 1,
        reduction: 1,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    3 =>
      {
        opcode: LoadA,
        id: 64,
        rows: 1,
        columns: 512,
        reduction: 0,
        base: 512,
        stride: 512,
        a_slot: 1,
        b_slot: 0,
        c_slot: 0,
      }
    4 =>
      {
        opcode: LoadB,
        id: 65,
        rows: 512,
        columns: 1,
        reduction: 0,
        base: 1280,
        stride: 1,
        a_slot: 0,
        b_slot: 1,
        c_slot: 0,
      }
    5 =>
      {
        opcode: MatMul,
        id: 77,
        rows: 1,
        columns: 1,
        reduction: 512,
        base: 0,
        stride: 0,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    6 =>
      {
        opcode: StoreC,
        id: 77,
        rows: 1,
        columns: 1,
        reduction: 0,
        base: 2800,
        stride: 4,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    7 =>
      {
        opcode: LoadA,
        id: 77,
        rows: 1,
        columns: 512,
        reduction: 0,
        base: 2048,
        stride: 512,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    8 =>
      {
        opcode: Fence,
        id: 78,
        rows: 0,
        columns: 0,
        reduction: 0,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    9 =>
      {
        opcode: StoreC,
        id: 79,
        rows: 1,
        columns: 1,
        reduction: 0,
        base: 2816,
        stride: 4,
        a_slot: 0,
        b_slot: 0,
        c_slot: 1,
      }
    _ => fail("invalid predefined descriptor position \{position}")
  }
  descriptor.encode()
}

///|
fn concurrent_install(memory : Array[Int32], position : Int32) -> Unit raise {
  let bytes = concurrent_packet(position)
  for index in 0..<bytes.length() {
    memory[3072 + position % 4 * 32 + index] = bytes[index].to_int()
  }
}

///|
fn concurrent_operands() -> (Array[Int32], Array[Int32], Array[Int32]) {
  let left = Array::make(512, 0)
  let right = Array::make(512, 0)
  let reload = Array::make(512, 0)
  for index in 0..<512 {
    left[index] = (index * 17 + 5) % 256 - 128
    right[index] = (index * 29 + 3) % 256 - 128
    reload[index] = (index * 11 + 1) % 256 - 128
  }
  (left, right, reload)
}

///|
fn concurrent_memory() -> Array[Int32] raise {
  let memory = Array::make(4096, 165)
  memory[32] = 2
  memory[64] = 3
  let (left, right, reload) = concurrent_operands()
  for index in 0..<512 {
    memory[512 + index] = left[index] & 255
    memory[1280 + index] = right[index] & 255
    memory[2048 + index] = reload[index] & 255
  }
  for position in 0..<3 {
    concurrent_install(memory, position)
  }
  memory
}

///|
fn verify_concurrent_memory(memory : Array[Int32]) -> (Int32, Int32) raise {
  let old_result = @flux_tile.matmul_int8_oracle(
      [2],
      [3],
      rows=1,
      columns=1,
      reduction=1,
    )[0]
  let (left, right, _) = concurrent_operands()
  let new_result = @flux_tile.matmul_int8_oracle(
      left,
      right,
      rows=1,
      columns=1,
      reduction=512,
    )[0]
  let expected = concurrent_memory()
  // Last accepted producer positions own the final physical descriptor bytes.
  for position in 6..<10 {
    concurrent_install(expected, position)
  }
  for (address, result) in [(2800, old_result), (2816, new_result)] {
    let bits = result.to_int64().reinterpret_as_uint64() & 0xffffffffUL
    for byte in 0..<4 {
      expected[address + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "concurrent host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
  (old_result, new_result)
}
