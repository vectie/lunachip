///|
fn capacity_wrap_configuration() -> @capabilities.Capabilities raise {
  @capabilities.Capabilities::new(
    rows=1,
    columns=1,
    max_reduction=1,
    host_bytes=4096UL,
    ring_depth=2,
    queue_depth=2,
  )
}

///|
fn capacity_wrap_packet(position : Int32) -> Bytes raise {
  if position < 0 || position >= 8 {
    fail("invalid predefined capacity/wrap packet position \{position}")
  }
  let descriptor : @slotted_descriptor.Descriptor = {
    opcode: Fence,
    id: (401 + position).reinterpret_as_uint(),
    rows: 0,
    columns: 0,
    reduction: 0,
    base: 0,
    stride: 0,
    a_slot: 0,
    b_slot: 0,
    c_slot: 0,
  }
  descriptor.encode()
}

///|
fn capacity_wrap_install(memory : Array[Int32], position : Int32) -> Unit raise {
  if memory.length() != 4096 {
    fail("capacity/wrap host memory must contain exactly 4096 bytes")
  }
  let packet = capacity_wrap_packet(position)
  // Origin 0xfffffffe is even, so the actual wrapped sequence's low bit
  // equals position's low bit. Callers establish committed consumer credit
  // before reusing either physical slot; fetching alone grants no credit.
  let base = 3072 + position % 2 * 32
  for index in 0..<packet.length() {
    memory[base + index] = packet[index].to_int()
  }
}

///|
fn capacity_wrap_memory() -> Array[Int32] raise {
  let memory = Array::make(4096, 165)
  for position in 0..<2 {
    capacity_wrap_install(memory, position)
  }
  memory
}

///|
fn capacity_wrap_assert_completion(
  actual : CompletionSnapshot,
  position : Int32,
) -> Unit raise {
  if position < 0 || position >= 8 {
    fail("invalid capacity/wrap completion position \{position}")
  }
  if actual.id != (401 + position).to_uint64() ||
    actual.fault != 0UL ||
    actual.bytes != 0UL ||
    actual.address != 0UL {
    fail("unexpected capacity/wrap completion at position \{position}")
  }
}

///|
fn capacity_wrap_compare_memory(
  memory : Array[Int32],
  expected : Array[Int32],
) -> Unit raise {
  if memory.length() != 4096 {
    fail("capacity/wrap host memory must contain exactly 4096 bytes")
  }
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "capacity/wrap host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}

///|
fn capacity_wrap_verify_blocked(memory : Array[Int32]) -> Unit raise {
  // No command writes host memory. The third legitimate pair replacement
  // leaves position4 in slot0 and the fetched, unadmitted position5 in slot1.
  // This expectation uses the fixed workload, not observed memory requests.
  let expected = Array::make(4096, 165)
  for position in 4..<6 {
    capacity_wrap_install(expected, position)
  }
  capacity_wrap_compare_memory(memory, expected)
}

///|
fn capacity_wrap_verify_final(memory : Array[Int32]) -> Unit raise {
  // The last pair is installed only after all first-six obligations retire
  // and consumer reaches4. All bytes outside these two packets stay sentinel.
  let expected = Array::make(4096, 165)
  for position in 6..<8 {
    capacity_wrap_install(expected, position)
  }
  capacity_wrap_compare_memory(memory, expected)
}
