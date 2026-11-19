///|
fn remote_fault_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=1,
    columns=2,
    max_reduction=2,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=3,
  )
}

///|
fn remote_fault_packet(position : Int32) -> Bytes raise {
  if position < 0 || position >= 16 {
    fail("invalid predefined remote-fault packet position \{position}")
  }
  let empty : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: (301 + position).reinterpret_as_uint(),
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
    0 => { ..empty, opcode: LoadA, rows: 1, columns: 2, base: 512, stride: 3, }
    1 => { ..empty, opcode: LoadB, rows: 2, columns: 2, base: 640, stride: 3, }
    2 | 9 | 13 =>
      { ..empty, opcode: MatMul, rows: 1, columns: 2, reduction: 2, }
    3 =>
      {
        ..empty,
        opcode: LoadA,
        rows: 1,
        columns: 2,
        base: 896,
        stride: 3,
        a_slot: 1,
      }
    4 =>
      {
        ..empty,
        opcode: MatMul,
        rows: 1,
        columns: 2,
        reduction: 2,
        a_slot: 1,
        c_slot: 1,
      }
    5 | 6 =>
      { ..empty, opcode: StoreC, rows: 1, columns: 2, base: 1536, stride: 12, }
    7 | 11 =>
      {
        ..empty,
        opcode: StoreC,
        rows: 1,
        columns: 2,
        base: 1792,
        stride: 12,
        c_slot: 1,
      }
    8 | 12 =>
      { ..empty, opcode: LoadB, rows: 2, columns: 2, base: 768, stride: 3, }
    10 =>
      { ..empty, opcode: StoreC, rows: 1, columns: 2, base: 1920, stride: 12, }
    14 =>
      { ..empty, opcode: StoreC, rows: 1, columns: 2, base: 2048, stride: 12, }
    15 => empty
    _ => fail("invalid predefined remote-fault packet position \{position}")
  }
  // Remote faults belong to actual host responses, never mutated packets.
  descriptor.encode()
}

///|
fn remote_fault_install(memory : Array[Int32], position : Int32) -> Unit raise {
  if memory.length() != 4096 {
    fail("remote-fault host memory must contain exactly 4096 bytes")
  }
  let packet = remote_fault_packet(position)
  for index in 0..<packet.length() {
    memory[3072 + position % 4 * 32 + index] = packet[index].to_int()
  }
}

///|
fn remote_fault_memory() -> Array[Int32] raise {
  let memory = Array::make(4096, 165)
  for
    (address, value) in [
      (512, 2),
      (513, -3),
      (640, 5),
      (641, -7),
      (643, 11),
      (644, 13),
      (896, -4),
      (897, 5),
      (768, -2),
      (769, 9),
      (771, 4),
      (772, -5),
    ] {
    memory[address] = value & 255
  }
  // Later packets are installed only after the prior group has drained and
  // consumer credit releases their physical ring slots. No reseeding follows.
  for position in 0..<3 {
    remote_fault_install(memory, position)
  }
  memory
}
