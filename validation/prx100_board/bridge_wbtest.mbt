///|
test "CRC standard check and transport envelope corruption" {
  assert_eq(@prx100.crc8(b"123456789"[:]), 0xf4)
  let frame = @prx100.request(1, 0x1234, 4092U, 0x89abcdefU)
  assert_eq(frame.length(), 16)
  assert_eq(frame[4], 0x34)
  assert_eq(frame[5], 0x12)
  assert_eq(frame[10], 0xef)
  let board = bench()
  assert_eq(board.command(1, arg=4092U, data=42U).status, 0)
  let bad = frame.to_array()
  bad[14] = (bad[14].to_uint() ^ 1U).to_byte()
  assert_eq(board.exchange(Bytes::from_array(bad)).status, 1)
  assert_eq(board.command(2, arg=4092U).words[0], 42U)
  assert_eq(board.command(0).words[0], 0x50525831U)
  assert_eq(board.command(0).sequence, 0x1234)
}

///|
test "full address guards, unused fields and BRAM reset persistence" {
  let board = bench()
  assert_eq(board.command(1, arg=4092U, data=0x89abcdefU).status, 0)
  assert_eq(board.command(2, arg=4092U).words[0], 0x89abcdefU)
  for address in [1U, 4093U, 4096U, 0xfffffffCU] {
    assert_eq(board.command(1, arg=address, data=77U).status, 3)
    assert_eq(board.command(2, arg=address).status, 3)
  }
  assert_eq(board.command(0, data=1U).status, 2)
  assert_eq(board.command(77).status, 2)
  assert_eq(board.command(5).status, 5)
  assert_eq(board.command(8).status, 0)
  assert_eq(board.command(2, arg=4092U).words[0], 0x89abcdefU)
}

///|
test "real fetched signed workload, retirement hold and repeated batch" {
  let board = bench()
  board.workload()
  // UART-side requests are allowed to lag indefinitely. Core payload remains
  // held, and the host cannot overwrite data in a published batch.
  for _ in 0..<700 {
    board.step()
  }
  assert_eq(read(board.core_sim, "completion_valid"), 1UL)
  let id = read(board.core_sim, "completion_id")
  for _ in 0..<30 {
    board.step()
  }
  assert_eq(read(board.core_sim, "completion_id"), id)
  assert_eq(board.command(1, arg=256U, data=123U).status, 4)
  for index in 0..<4 {
    for _ in 0..<150 {
      board.step()
    }
    let completion = board.command(5)
    assert_eq(completion.status, 0)
    assert_eq(completion.words[0], (11 + index).reinterpret_as_uint())
    assert_eq(completion.words[1], 0U)
    if index == 3 {
      assert_eq(completion.words[2], 4U)
    }
  }
  assert_eq(board.command(2, arg=512U).words[0], 0xffffffc1U) // -63
  assert_eq(board.command(6).words[3], 4U)
  assert_eq(board.command(7).words[4], 0x00010001U)
  assert_eq(board.command(8).status, 0)
  board.workload()
  for _ in 0..<700 {
    board.step()
  }
  for _ in 0..<4 {
    assert_eq(board.command(5).status, 0)
    for _ in 0..<150 {
      board.step()
    }
  }
  assert_eq(board.command(2, arg=512U).words[0], 0xffffffc1U)
}

///|
test "reset cancels an active batch without erasing memory" {
  let board = bench()
  board.workload()
  // Begin a reset request immediately; during its frame, the fetched reader
  // owns local memory transactions. Reset must jointly discard both sides.
  assert_eq(board.command(8).status, 0)
  assert_eq(board.command(6).words[1], 0U)
  assert_eq(read(board.core_sim, "completion_valid"), 0UL)
  assert_eq(read(board.shell_sim, "memory_response_valid"), 0UL)
  assert_eq(board.command(2, arg=256U).words[0], 249U)
}

///|
test "reply payload is stable under transmit backpressure" {
  let board = bench()
  for byte in @prx100.request(0, 55, 0U, 0U) {
    board.step(byte~, ready=false)
  }
  board.step(ready=false)
  board.step(ready=false)
  assert_eq(read(board.shell_sim, "tx_valid"), 1UL)
  let held = read(board.shell_sim, "tx_data")
  for _ in 0..<40 {
    board.step(ready=false)
    assert_eq(read(board.shell_sim, "tx_data"), held)
  }
  board.received.clear()
  for _ in 0..<40 {
    board.step()
  }
  assert_eq(
    @prx100.decode_reply(Bytes::from_array(board.received)[:]).sequence,
    55,
  )
}
