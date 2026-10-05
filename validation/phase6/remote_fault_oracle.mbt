///|
fn remote_fault_assert_completion(
  actual : CompletionSnapshot,
  position : Int,
) -> Unit raise {
  let faults : Array[UInt64] = [
    0UL, 0UL, 0UL, 0UL, 0UL, 9UL, 0UL, 0UL, 9UL, 4UL, 5UL, 0UL, 0UL, 0UL, 0UL, 0UL,
  ]
  let progress : Array[UInt64] = [
    2UL, 4UL, 0UL, 2UL, 0UL, 4UL, 8UL, 8UL, 2UL, 0UL, 0UL, 8UL, 4UL, 0UL, 8UL, 0UL,
  ]
  if position < 0 || position >= faults.length() {
    fail("invalid remote-fault completion position \{position}")
  }
  let address = match position {
    5 => 1540UL
    8 => 771UL
    _ => 0UL
  }
  if actual.id != (301 + position).to_uint64() ||
    actual.fault != faults[position] ||
    actual.bytes != progress[position] ||
    actual.address != address {
    fail("unexpected remote-fault completion at position \{position}")
  }
}

///|
fn remote_fault_old_words() -> Array[Int] raise {
  @flux_tile.matmul_int8_oracle(
    [2, -3],
    [5, -7, 11, 13],
    rows=1,
    columns=2,
    reduction=2,
  )
}

///|
// Independent unscheduled arithmetic from the fixed signed operand values.
// Neither observed request data nor simulator result SRAM supplies expectations.
fn remote_fault_expected_results() -> Array[Array[Int]] raise {
  let old = remote_fault_old_words()
  let independent = @flux_tile.matmul_int8_oracle(
    [-4, 5],
    [5, -7, 11, 13],
    rows=1,
    columns=2,
    reduction=2,
  )
  let recovered = @flux_tile.matmul_int8_oracle(
    [2, -3],
    [-2, 9, 4, -5],
    rows=1,
    columns=2,
    reduction=2,
  )
  if old != [-23, -53] || independent != [35, 93] || recovered != [-16, 33] {
    fail(
      "remote-fault independent signed matrix oracle differs from the contract",
    )
  }
  [old, independent, recovered]
}

///|
fn remote_fault_compare_bytes(
  memory : Array[Int],
  expected : Array[Int],
) -> Unit raise {
  for index in 0..<4096 {
    if memory[index] != expected[index] {
      fail(
        "remote-fault host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}

///|
// Called after position5 retires, before any position6+ packet is installed.
fn remote_fault_verify_partial(memory : Array[Int]) -> Unit raise {
  if memory.length() != 4096 {
    fail("remote-fault partial host memory must contain exactly 4096 bytes")
  }
  let expected = remote_fault_memory()
  for position in 3..<6 {
    remote_fault_install(expected, position)
  }
  let old = remote_fault_expected_results()[0]
  for word in 0..<2 {
    let bits = old[word].to_int64().reinterpret_as_uint64() & 0xffffffffUL
    let count = if word == 0 { 4 } else { 2 }
    for byte in 0..<count {
      expected[1536 + word * 4 + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
  // The failing word's high two bytes and all padding remain sentinel165.
  // This checkpoint precedes retry, which would otherwise erase the evidence.
  remote_fault_compare_bytes(memory, expected)
}

///|
fn remote_fault_verify_final(memory : Array[Int]) -> Unit raise {
  if memory.length() != 4096 {
    fail("remote-fault final host memory must contain exactly 4096 bytes")
  }
  let expected = remote_fault_memory()
  for position in 3..<16 {
    remote_fault_install(expected, position)
  }
  let results = remote_fault_expected_results()
  for
    (base, words) in [
      (1536, results[0]),
      (1792, results[1]),
      (2048, results[2]),
    ] {
    for word in 0..<2 {
      let bits = words[word].to_int64().reinterpret_as_uint64() & 0xffffffffUL
      for byte in 0..<4 {
        expected[base + word * 4 + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
      }
    }
  }
  // Position10's rejected Store cannot change destination1920. Both stores
  // of C1 leave its distinct words; all operands, padding and ring bytes agree.
  remote_fault_compare_bytes(memory, expected)
}

///|
// Return observed final host words in old-C0, independent-C1, recovered-C0 order.
fn remote_fault_result_words(memory : Array[Int]) -> Array[Int] raise {
  if memory.length() != 4096 {
    fail("remote-fault result host memory must contain exactly 4096 bytes")
  }
  let result : Array[Int] = []
  for base in [1536, 1540, 1792, 1796, 2048, 2052] {
    let mut bits = 0UL
    for byte in 0..<4 {
      let value = memory[base + byte]
      if value < 0 || value > 255 {
        fail("remote-fault result contains a non-byte host value")
      }
      bits = bits | (value.to_uint64() << (byte * 8))
    }
    result.push(
      if bits >= 0x80000000UL {
        (bits.reinterpret_as_int64() - 4294967296L).to_int()
      } else {
        bits.to_int()
      },
    )
  }
  result
}
