///|
fn ring_control_configuration() -> @capabilities.Capabilities raise {
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
// Epochs 1..5 offer only runtime ring control, never descriptor packets.
// This table is host-authored independently of observed device requests.
fn ring_control_packet(epoch : Int, position : Int) -> Bytes raise {
  let count = match epoch {
    6 => 6
    7 => 7
    _ => fail("ring-control packets exist only in epochs 6 and 7")
  }
  if position < 0 || position >= count {
    fail("invalid ring-control epoch\{epoch} packet position \{position}")
  }
  let empty : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: ((if epoch == 6 { 501 } else { 601 }) + position).reinterpret_as_uint(),
    rows: 0,
    columns: 0,
    reduction: 0,
    base: 0,
    stride: 0,
    a_slot: 0,
    b_slot: 0,
    c_slot: 0,
  }
  let descriptor : @slotted_descriptor.Descriptor = match (epoch, position) {
    (6, 0) =>
      {
        ..empty,
        opcode: LoadA,
        rows: 1,
        columns: 512,
        base: 512,
        stride: 512,
        a_slot: 1,
      }
    (6, 1) =>
      {
        ..empty,
        opcode: LoadB,
        rows: 512,
        columns: 1,
        base: 1280,
        stride: 1,
        b_slot: 1,
      }
    (6, 2) | (7, 0) =>
      {
        ..empty,
        opcode: MatMul,
        rows: 1,
        columns: 1,
        reduction: 512,
        a_slot: 1,
        b_slot: 1,
        c_slot: 1,
      }
    (6, 3) | (7, 1) =>
      {
        ..empty,
        opcode: StoreC,
        rows: 1,
        columns: 1,
        base: 2816,
        stride: 4,
        c_slot: 1,
      }
    (6, 4) | (6, 5) | (7, 6) => empty
    (7, 2) =>
      { ..empty, opcode: LoadA, rows: 1, columns: 1, base: 32, stride: 1, }
    (7, 3) =>
      { ..empty, opcode: LoadB, rows: 1, columns: 1, base: 64, stride: 1, }
    (7, 4) => { ..empty, opcode: MatMul, rows: 1, columns: 1, reduction: 1, }
    (7, 5) =>
      { ..empty, opcode: StoreC, rows: 1, columns: 1, base: 2800, stride: 4, }
    _ => fail("invalid predefined ring-control command")
  }
  // The ordinary checked draft 0.2 codec supplies version/reserved bytes.
  descriptor.encode()
}

///|
fn ring_control_install(
  memory : Array[Int],
  epoch : Int,
  position : Int,
) -> Unit raise {
  if memory.length() != 4096 {
    fail("ring-control host memory must contain exactly 4096 bytes")
  }
  let packet = ring_control_packet(epoch, position)
  // Runtime origin is 0 in both packet epochs. The stimulus establishes PRE
  // consumer credit and an empty host obligation before physical-slot reuse;
  // neither fetching nor retirement-ready on the same edge grants credit.
  let base = 3072 + position % 4 * 32
  for byte in 0..<packet.length() {
    memory[base + byte] = packet[byte].to_int()
  }
}

///|
fn ring_control_memory() -> Array[Int] {
  let memory = Array::make(4096, 165)
  memory[32] = 2
  memory[64] = 3
  for index in 0..<512 {
    memory[512 + index] = 2
    memory[1280 + index] = 3
  }
  // No initial descriptor is installed. Five isolated ring-control epochs
  // cannot fetch a packet; the successful epoch 6 explicitly installs 0/1.
  memory
}

///|
fn ring_control_assert_completion(
  actual : CompletionSnapshot,
  epoch : Int,
  position : Int,
) -> Unit raise {
  let (first_id, faults, progress) : (Int, Array[UInt64], Array[UInt64]) = match
    epoch {
    6 => (501, [0UL, 0UL, 0UL, 0UL], [512UL, 512UL, 0UL, 4UL])
    7 =>
      (
        601,
        [4UL, 5UL, 0UL, 0UL, 0UL, 0UL, 0UL],
        [0UL, 0UL, 1UL, 1UL, 0UL, 4UL, 0UL],
      )
    _ => fail("ring-control completion appeared in a control-only epoch")
  }
  if position < 0 || position >= faults.length() {
    fail(
      "unexpected ring-control epoch\{epoch} completion position \{position}",
    )
  }
  // Epoch 6 positions 4/5 are installed but never fetched or admitted.
  if actual.id != (first_id + position).to_uint64() ||
    actual.fault != faults[position] ||
    actual.bytes != progress[position] ||
    actual.address != 0UL {
    fail(
      "incorrect ring-control epoch\{epoch} completion at position \{position}",
    )
  }
}

///|
fn ring_control_results() -> Array[Int] raise {
  let long = @flux_tile.matmul_int8_oracle(
    Array::make(512, 2),
    Array::make(512, 3),
    rows=1,
    columns=1,
    reduction=512,
  )
  let recovered = @flux_tile.matmul_int8_oracle(
    [2],
    [3],
    rows=1,
    columns=1,
    reduction=1,
  )
  if long != [3072] || recovered != [6] {
    fail("ring-control independent matrix results differ from 3072 and 6")
  }
  [long[0], recovered[0]]
}

///|
fn ring_control_assert_write(request : Request, epoch : Int) -> Unit raise {
  let (address, result_index) = match epoch {
    6 => (2816UL, 0)
    7 => (2800UL, 1)
    _ => fail("ring-control data write occurred in a control-only epoch")
  }
  let result = ring_control_results()[result_index]
  let bits = result.to_int64().reinterpret_as_uint64() & 0xffffffffUL
  if request.write != 1UL ||
    request.address != address ||
    request.bytes != 4UL ||
    request.mask != 15UL ||
    request.data != bits {
    fail("ring-control epoch\{epoch} write differs from the independent oracle")
  }
}

///|
fn verify_ring_control_memory(memory : Array[Int]) -> Unit raise {
  if memory.length() != 4096 {
    fail("ring-control final host memory must contain exactly 4096 bytes")
  }
  let expected = ring_control_memory()
  // The last recovery refill leaves positions 4,5,6,3 in physical-slot order.
  // Reconstruct from host-authored packets, never device-read descriptor data.
  for position in [4, 5, 6, 3] {
    ring_control_install(expected, 7, position)
  }
  let results = ring_control_results()
  for (base, result) in [(2816, results[0]), (2800, results[1])] {
    let bits = result.to_int64().reinterpret_as_uint64() & 0xffffffffUL
    for byte in 0..<4 {
      expected[base + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
  // Joint reset does not roll back host bytes: epoch 6's long result persists.
  // All source bytes, both result words, ring packets and sentinel padding
  // participate in this exact comparison.
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "ring-control host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}
