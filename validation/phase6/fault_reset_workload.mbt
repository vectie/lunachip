///|
fn fault_reset_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=64,
    host_bytes=4096UL,
    ring_depth=4,
    queue_depth=2,
  )
}

///|
fn fault_reset_packet(which : Int) -> Bytes raise {
  let descriptor : @slotted_descriptor.Descriptor = match which {
    0 =>
      {
        opcode: LoadA,
        id: 81,
        rows: 1,
        columns: 16,
        reduction: 0,
        base: 512,
        stride: 16,
        a_slot: 1,
        b_slot: 0,
        c_slot: 0,
      }
    1 =>
      {
        opcode: LoadB,
        id: 82,
        rows: 16,
        columns: 1,
        reduction: 0,
        base: 1280,
        stride: 1,
        a_slot: 0,
        b_slot: 1,
        c_slot: 0,
      }
    2 =>
      {
        opcode: LoadA,
        id: 83,
        rows: 1,
        columns: 64,
        reduction: 0,
        base: 2048,
        stride: 64,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    3 =>
      {
        opcode: MatMul,
        id: 84,
        rows: 1,
        columns: 1,
        reduction: 16,
        base: 0,
        stride: 0,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    4 =>
      {
        opcode: Fence,
        id: 85,
        rows: 0,
        columns: 0,
        reduction: 0,
        base: 0,
        stride: 0,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    5 =>
      {
        opcode: LoadA,
        id: 91,
        rows: 1,
        columns: 64,
        reduction: 0,
        base: 2048,
        stride: 64,
        a_slot: 0,
        b_slot: 0,
        c_slot: 0,
      }
    6 =>
      {
        opcode: MatMul,
        id: 92,
        rows: 1,
        columns: 1,
        reduction: 16,
        base: 0,
        stride: 0,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    7 =>
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
    _ => fail("invalid predefined fault/reset packet \{which}")
  }
  descriptor.encode()
}

///|
fn fault_reset_install(
  memory : Array[Int],
  position : Int,
  which : Int,
) -> Unit raise {
  let bytes = fault_reset_packet(which)
  for index in 0..<bytes.length() {
    memory[3072 + position % 4 * 32 + index] = bytes[index].to_int()
  }
}

///|
fn fault_reset_memory() -> Array[Int] raise {
  let memory = Array::make(4096, 165)
  for index in 0..<16 {
    memory[512 + index] = (index * 17 + 5) % 256
    memory[1280 + index] = (index * 29 + 3) % 256
  }
  for index in 0..<64 {
    memory[2048 + index] = (index * 11 + 1) % 256
  }
  fault_reset_install(memory, 0, 0)
  fault_reset_install(memory, 1, 1)
  memory
}

///|
fn verify_fault_reset_memory(memory : Array[Int]) -> Unit raise {
  let expected = fault_reset_memory()
  for position in 2..<5 {
    fault_reset_install(expected, position, position)
  }
  fault_reset_install(expected, 0, 5)
  fault_reset_install(expected, 0, 6)
  fault_reset_install(expected, 1, 7)
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "fault/reset host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}
