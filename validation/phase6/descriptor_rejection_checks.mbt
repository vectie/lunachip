///|
fn descriptor_rejection_assert_completion(
  actual : CompletionSnapshot,
  position : Int,
) -> Unit raise {
  if position < 0 || position >= 86 {
    fail("invalid descriptor-rejection completion position \{position}")
  }
  // Independent fixed expectations, not decoded from the offered packet or
  // inferred from engine state. All local rejection addresses/progress are 0.
  let fault : UInt64 = match position {
    6 => 12UL
    7..=17 => 13UL
    18..=22 => 1UL
    23..=25 => 14UL
    32..=34 | 37..=39 | 44 | 45 | 49..=59 => 2UL
    63..=66 | 78 => 3UL
    35 | 40 | 67 | 79 => 4UL
    36 | 41 | 46 | 68 | 69 | 80 => 5UL
    71 => 6UL
    72 | 73 => 7UL
    74 | 75 | 77 => 8UL
    _ => 0UL
  }
  let progress : UInt64 = match position {
    0 | 1 | 3 | 4 | 42 | 47 | 82 => 1UL
    26 | 27 | 30 | 31 | 61 | 62 | 76 | 81 | 84 => 4UL
    _ => 0UL
  }
  if actual.id != (201 + position).to_uint64() ||
    actual.fault != fault ||
    actual.bytes != progress ||
    actual.address != 0UL {
    fail(
      "descriptor-rejection completion \{position}: expected id \{201 + position}, fault \{fault}, bytes \{progress}, address 0; actual id \{actual.id}, fault \{actual.fault}, bytes \{actual.bytes}, address \{actual.address}",
    )
  }
}

///|
fn descriptor_rejection_word(left : Int, right : Int) -> UInt64 raise {
  let result = @flux_tile.matmul_int8_oracle(
    [left],
    [right],
    rows=1,
    columns=1,
    reduction=1,
  )
  if result != [left * right] {
    fail("descriptor-rejection independent scalar oracle disagrees")
  }
  result[0].to_int64().reinterpret_as_uint64() & 0xffffffffUL
}

///|
fn descriptor_rejection_assert_write(
  request : Request,
  write_ordinal : Int,
) -> Unit raise {
  // Ordinal follows actual accepted word writes, not caller ID or a later live
  // bus payload. The caller also checks owned ACKs using each saved request.
  let stores = [
    (26, 1536, 2, 3),
    (27, 1792, 5, 7),
    (30, 1536, 2, 3),
    (31, 1792, 5, 7),
    (61, 1536, 2, 3),
    (62, 1792, 5, 7),
    (76, 1536, 2, 3),
    (81, 1792, 5, 7),
    (84, 2048, 9, 3),
  ]
  if write_ordinal < 0 || write_ordinal >= stores.length() {
    fail("unexpected descriptor-rejection write ordinal \{write_ordinal}")
  }
  let (position, address, left, right) = stores[write_ordinal]
  let word = descriptor_rejection_word(left, right)
  if request.write != 1UL ||
    request.address != address.to_uint64() ||
    request.bytes != 4UL ||
    request.mask != 15UL ||
    request.data != word {
    fail(
      "descriptor-rejection Store position \{position} has an invalid word request",
    )
  }
}

///|
fn verify_descriptor_rejection_memory(memory : Array[Int]) -> Unit raise {
  if memory.length() != 4096 {
    fail(
      "descriptor-rejection final host memory must contain exactly 4096 bytes",
    )
  }
  let expected = descriptor_rejection_memory()
  for position in 3..<86 {
    descriptor_rejection_install(expected, position)
  }
  // Independently derive all three result words; rejected writes must leave
  // every other byte untouched. Final ring slot order is 84,85,82,83.
  for (base, left, right) in [(1536, 2, 3), (1792, 5, 7), (2048, 9, 3)] {
    let word = descriptor_rejection_word(left, right)
    for byte in 0..<4 {
      expected[base + byte] = ((word >> (byte * 8)) & 255UL).to_int()
    }
  }
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "descriptor-rejection host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}
