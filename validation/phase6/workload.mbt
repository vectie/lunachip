///|
fn configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=2,
    host_bytes=1024UL,
    ring_depth=4,
    queue_depth=2,
  )
}

///|
fn packet(
  opcode : @descriptor.Opcode,
  id : UInt32,
  rows~ : UInt32 = 0,
  columns~ : UInt32 = 0,
  reduction~ : UInt32 = 0,
  base~ : UInt32 = 0,
  stride~ : UInt32 = 0,
) -> Bytes raise {
  let descriptor : @slotted_descriptor.Descriptor = {
    opcode,
    id,
    rows,
    columns,
    reduction,
    base,
    stride,
    a_slot: 0,
    b_slot: 0,
    c_slot: 0,
  }
  descriptor.encode()
}

///|
fn install_packet(memory : Array[Int32], slot : Int32, bytes : Bytes) -> Unit {
  for index in 0..<bytes.length() {
    memory[512 + slot * 32 + index] = bytes[index].to_int()
  }
}

///|
fn fence_packet() -> Bytes raise {
  packet(Fence, 45)
}

///|
fn workload_memory(reused : Bool) -> Array[Int32] raise {
  let memory = Array::make(1024, 165)
  memory[32] = 128
  memory[33] = 127
  memory[64] = 2
  memory[67] = 253
  let packets = [
    packet(LoadA, 41, rows=1, columns=2, base=32, stride=3),
    packet(LoadB, 42, rows=2, columns=1, base=64, stride=3),
    packet(MatMul, 43, rows=1, columns=1, reduction=2),
    packet(StoreC, 44, rows=1, columns=1, base=128, stride=8),
  ]
  for slot, bytes in packets {
    install_packet(memory, slot, bytes)
  }
  if reused {
    install_packet(memory, 0, fence_packet())
  }
  memory
}

///|
fn verify_workload(memory : Array[Int32]) -> Int32 raise {
  let oracle = @flux_tile.matmul_int8_oracle(
      [-128, 127],
      [2, -3],
      rows=1,
      columns=1,
      reduction=2,
    )[0]
  let expected = workload_memory(true)
  let bits = oracle.to_int64().reinterpret_as_uint64() & 0xffffffffUL
  for byte in 0..<4 {
    expected[128 + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
  }
  for index in 0..<1024 {
    if memory[index] != expected[index] {
      fail(
        "host memory mismatch at byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
  oracle
}
