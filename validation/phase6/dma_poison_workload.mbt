///|
fn dma_poison_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=8,
    columns=8,
    max_reduction=64,
    host_bytes=16384UL,
    ring_depth=16,
    queue_depth=16,
  )
}

///|
fn dma_poison_packet(position : Int) -> Bytes raise {
  if position < 0 || position >= 11 {
    fail("invalid predefined DMA-poison packet position \{position}")
  }
  let empty : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: (if position < 5 { 10 + position } else { 195 + position }).reinterpret_as_uint(),
    rows: 0,
    columns: 0,
    reduction: 0,
    base: 0,
    stride: 0,
    a_slot: 0,
    b_slot: 0,
    c_slot: 0,
  }
  let descriptor : @slotted_descriptor.Descriptor = match position {
    0 => { ..empty, opcode: LoadA, rows: 8, columns: 5, base: 32, stride: 16, }
    1 => { ..empty, opcode: LoadB, rows: 5, columns: 8, base: 256, stride: 16, }
    2 => { ..empty, opcode: MatMul, rows: 8, columns: 8, reduction: 5, }
    3 =>
      {
        ..empty,
        opcode: LoadA,
        rows: 8,
        columns: 64,
        base: 512,
        stride: 80,
        a_slot: 1,
      }
    4 =>
      {
        ..empty,
        opcode: LoadB,
        rows: 64,
        columns: 8,
        base: 1280,
        stride: 16,
        b_slot: 1,
      }
    5 | 10 => empty
    6 => { ..empty, opcode: LoadA, rows: 8, columns: 64, base: 32, stride: 80, }
    7 =>
      { ..empty, opcode: StoreC, rows: 8, columns: 8, base: 4096, stride: 40, }
    8 =>
      {
        ..empty,
        opcode: MatMul,
        rows: 8,
        columns: 8,
        reduction: 64,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    9 =>
      {
        ..empty,
        opcode: StoreC,
        rows: 8,
        columns: 8,
        base: 5120,
        stride: 40,
        c_slot: 1,
      }
    _ => fail("invalid predefined DMA-poison packet position \{position}")
  }
  descriptor.encode()
}

///|
fn dma_poison_install(memory : Array[Int], position : Int) -> Unit raise {
  if memory.length() != 16384 {
    fail("DMA-poison host memory must contain exactly 16384 bytes")
  }
  let bytes = dma_poison_packet(position)
  for index in 0..<bytes.length() {
    memory[8192 + position * 32 + index] = bytes[index].to_int()
  }
}

///|
fn dma_poison_seed_memory(memory : Array[Int]) -> Unit raise {
  if memory.length() != 16384 {
    fail("DMA-poison host memory must contain exactly 16384 bytes")
  }
  // This is explicit host initialization before an epoch, not reset rollback.
  for index in 0..<16384 {
    memory[index] = 165
  }
  for
    (base, stride, rows, columns, left) in [
      (32, 16, 8, 5, true),
      (256, 16, 5, 8, false),
      (512, 80, 8, 64, true),
      (1280, 16, 64, 8, false),
    ] {
    for row in 0..<rows {
      for column in 0..<columns {
        let index = row * columns + column
        let value = if left {
          (index * 47 + 13) % 256 - 128
        } else {
          (index * 83 + 231) % 256 - 128
        }
        memory[base + row * stride + column] = value & 255
      }
    }
  }
  for position in 0..<3 {
    dma_poison_install(memory, position)
  }
}

///|
fn dma_poison_memory() -> Array[Int] raise {
  let memory = Array::make(16384, 165)
  dma_poison_seed_memory(memory)
  memory
}

///|
fn dma_poison_replacement(memory : Array[Int]) -> Unit raise {
  if memory.length() != 16384 {
    fail("DMA-poison host memory must contain exactly 16384 bytes")
  }
  // Called only after setup drains. This deliberately overlaps old host A1
  // bytes; its already loaded physical bank is not reseeded or replaced.
  for row in 0..<8 {
    for column in 0..<64 {
      memory[32 + row * 80 + column] = -7 & 255
    }
  }
}

///|
fn dma_poison_recovery_packet(position : Int) -> Bytes raise {
  let descriptor : @slotted_descriptor.Descriptor = match position {
    0 =>
      {
        opcode: MatMul,
        id: 92,
        rows: 8,
        columns: 8,
        reduction: 64,
        base: 0,
        stride: 0,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    1 =>
      {
        opcode: Fence,
        id: 93,
        rows: 0,
        columns: 0,
        reduction: 0,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    _ => fail("invalid predefined DMA-poison recovery position \{position}")
  }
  descriptor.encode()
}

///|
fn dma_poison_recovery_install(
  memory : Array[Int],
  position : Int,
) -> Unit raise {
  if memory.length() != 16384 {
    fail("DMA-poison host memory must contain exactly 16384 bytes")
  }
  let bytes = dma_poison_recovery_packet(position)
  for index in 0..<bytes.length() {
    memory[8192 + position * 32 + index] = bytes[index].to_int()
  }
}
