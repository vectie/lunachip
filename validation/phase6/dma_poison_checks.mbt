///|
fn dma_poison_old_result() -> Array[Int32] raise {
  let left = Array::makei(40, index => (index * 47 + 13) % 256 - 128)
  let right = Array::makei(40, index => (index * 83 + 231) % 256 - 128)
  @flux_tile.matmul_int8_oracle(left, right, rows=8, columns=8, reduction=5)
}

///|
// Verify one fully observed fault epoch before joint reset or host reseeding.
// Accepted writes, including a malformed response's preceding request, have
// byte side effects. Their presence does not imply successful ACK progress.
fn verify_dma_poison_memory(
  memory : Array[Int32],
  accepted_writes : Array[Request],
) -> Unit raise {
  if memory.length() != 16384 {
    fail("DMA-poison final host memory must contain exactly 16384 bytes")
  }
  let expected = dma_poison_memory()
  for position in 3..<11 {
    dma_poison_install(expected, position)
  }
  dma_poison_replacement(expected)
  let old_result = dma_poison_old_result()
  let stored = Array::make(64, false)
  for request in accepted_writes {
    if request.write != 1UL ||
      request.bytes != 4UL ||
      request.mask != 15UL ||
      request.address < 4096UL ||
      request.address >= 4416UL {
      fail("DMA-poison accepted an unowned or malformed result write")
    }
    let offset = (request.address - 4096UL).to_int()
    let row = offset / 40
    let within_row = offset % 40
    if within_row >= 32 || within_row % 4 != 0 {
      fail("DMA-poison wrote C0 padding or an unaligned result word")
    }
    let index = row * 8 + within_row / 4
    if stored[index] {
      fail("DMA-poison accepted the same C0 result word twice")
    }
    stored[index] = true
    let bits = old_result[index].to_int64().reinterpret_as_uint64() &
      0xffffffffUL
    if request.data != bits {
      fail(
        "DMA-poison C0 word \{index} differs from the independent old oracle",
      )
    }
    let address = request.address.to_int()
    for byte in 0..<4 {
      expected[address + byte] = ((bits >> (byte * 8)) & 255UL).to_int()
    }
  }
  // No C1 store is allowed. Every unaccepted C0 word, both destination pads,
  // all signed operands, the deliberately replaced bytes and complete host
  // ring installations must retain their separately derived expected bytes.
  for index in 0..<16384 {
    if memory[index] != expected[index] {
      fail(
        "DMA-poison host byte \{index}: expected \{expected[index]}, actual \{memory[index]}",
      )
    }
  }
}
