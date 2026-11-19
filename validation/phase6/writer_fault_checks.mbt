///|
fn writer_fault_assert_completion(
  actual : CompletionSnapshot,
  position : Int32,
) -> Unit raise {
  let faults : Array[UInt64] = [
    0UL, 0UL, 0UL, 0UL, 0UL, 0UL, 12UL, 0UL, 0UL, 6UL, 4UL, 5UL, 0UL, 0UL, 0UL, 0UL,
    0UL,
  ]
  let progress : Array[UInt64] = [
    1UL, 1UL, 0UL, 1UL, 1UL, 0UL, 0UL, 0UL, 4UL, 0UL, 0UL, 0UL, 4UL, 1UL, 0UL, 4UL,
    0UL,
  ]
  if position < 0 || position >= faults.length() {
    fail("invalid writer-fault completion position \{position}")
  }
  if actual.id != (101 + position).to_uint64() ||
    actual.fault != faults[position] ||
    actual.bytes != progress[position] ||
    actual.address != 0UL {
    fail("unexpected writer-fault completion at position \{position}")
  }
}

///|
fn verify_writer_fault_memory(memory : Array[Int32]) -> Unit raise {
  if memory.length() != 4096 {
    fail("writer-fault final host memory must contain exactly 4096 bytes")
  }
  let expected = writer_fault_memory()
  for position in 3..<17 {
    writer_fault_install(expected, position)
  }
  // These host computations use the independent unscheduled matrix oracle,
  // not simulator results or any observed result-memory payload.
  for
    (base, left, right, value) in [
      (1536, 2, 3, 6),
      (1792, 5, 7, 35),
      (2048, 9, 3, 27),
    ] {
    let result = @flux_tile.matmul_int8_oracle(
      [left],
      [right],
      rows=1,
      columns=1,
      reduction=1,
    )
    if result != [value] {
      fail("writer-fault independent scalar result did not equal \{value}")
    }
    let bits = result[0].to_int64().reinterpret_as_uint64() & 0xffffffffUL
    for byte in 0..<4 {
      expected[base + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
  // C0's failed Store at position11 must leave the earlier result6 intact;
  // C1 and recovered C0 are distinct. All padding, operands and final ring
  // replacements are compared as well as the three stored words.
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "writer-fault host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}
