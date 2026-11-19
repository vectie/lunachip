///|
fn writer_fault_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
fn writer_fault_packet(position : Int32) -> Bytes raise {
  if position < 0 || position >= 17 {
    fail("invalid predefined writer-fault packet position \{position}")
  }
  let empty : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: (101 + position).reinterpret_as_uint(),
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
    0 | 6 | 9 =>
      {
        ..empty,
        opcode: LoadA,
        rows: 1,
        columns: 1,
        base: 512,
        stride: if position == 9 {
          0
        } else {
          1
        },
      }
    1 => { ..empty, opcode: LoadB, rows: 1, columns: 1, base: 640, stride: 1, }
    2 | 7 | 10 | 14 =>
      { ..empty, opcode: MatMul, rows: 1, columns: 1, reduction: 1, }
    3 =>
      {
        ..empty,
        opcode: LoadA,
        rows: 1,
        columns: 1,
        base: 768,
        stride: 1,
        a_slot: 1,
      }
    4 =>
      {
        ..empty,
        opcode: LoadB,
        rows: 1,
        columns: 1,
        base: 896,
        stride: 1,
        b_slot: 1,
      }
    5 =>
      {
        ..empty,
        opcode: MatMul,
        rows: 1,
        columns: 1,
        reduction: 1,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    8 | 11 =>
      { ..empty, opcode: StoreC, rows: 1, columns: 1, base: 1536, stride: 4, }
    12 =>
      {
        ..empty,
        opcode: StoreC,
        rows: 1,
        columns: 1,
        base: 1792,
        stride: 4,
        c_slot: 1,
      }
    13 =>
      { ..empty, opcode: LoadA, rows: 1, columns: 1, base: 1024, stride: 1, }
    15 =>
      { ..empty, opcode: StoreC, rows: 1, columns: 1, base: 2048, stride: 4, }
    16 => empty
    _ => fail("invalid predefined writer-fault packet position \{position}")
  }
  let bytes = descriptor.encode().to_array()
  // The malformed minor version is the only raw-byte mutation. Stride zero
  // remains a normal syntax-valid descriptor for semantic preflight rejection.
  if position == 6 {
    bytes[1] = b'\x01'
  }
  Bytes::from_array(bytes[:])
}

///|
fn writer_fault_install(memory : Array[Int32], position : Int32) -> Unit raise {
  let bytes = writer_fault_packet(position)
  for index in 0..<bytes.length() {
    memory[3072 + position % 4 * 32 + index] = bytes[index].to_int()
  }
}

///|
fn writer_fault_memory() -> Array[Int32] raise {
  let memory = Array::make(4096, 165)
  for (address, value) in [(512, 2), (640, 3), (768, 5), (896, 7), (1024, 9)] {
    memory[address] = value
  }
  // Later descriptors must be installed by the stimulus only after consumer
  // credit establishes that their physical ring slots are free.
  for position in 0..<3 {
    writer_fault_install(memory, position)
  }
  memory
}
