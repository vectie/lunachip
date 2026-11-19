///|
test "smoke K2 signed matrix UART workload matches independent integer sums" {
  let board = bench()
  for
    (a, b, expected) in [
      ([-7, 5], [9, -4], -83),
      ([-128, 127], [-128, -127], 255),
      ([12, -12], [11, 11], 0),
    ] {
    let mut sum = 0
    for k in 0..<2 {
      sum += a[k] * b[k]
    }
    assert_eq(sum, expected)
    assert_eq(board.command(8).status, 0)
    for
      (op, rows, columns, reduction, base) in [
        (0, 1, 2, 0, 256U),
        (1, 2, 1, 0, 260U),
        (2, 1, 1, 2, 0U),
        (3, 1, 1, 0, 512U),
      ] {
      let bytes = packet(
        op.to_byte(),
        (101 + op).reinterpret_as_uint(),
        rows.to_byte(),
        columns.to_byte(),
        reduction.to_byte(),
        base,
      ).to_array()
      if op == 0 {
        bytes[20] = 2
      }
      board.upload((op * 32).reinterpret_as_uint(), Bytes::from_array(bytes))
    }
    for (address, values) in [(256U, a), (260U, b)] {
      let word = (values[0].reinterpret_as_uint() & 255U) |
        ((values[1].reinterpret_as_uint() & 255U) << 8)
      assert_eq(board.command(1, arg=address, data=word).status, 0)
    }
    assert_eq(board.command(1, arg=512U, data=0x13579bdfU).status, 0)
    assert_eq(board.command(3).status, 0)
    assert_eq(board.command(4, arg=4U).status, 0)
    for _ in 0..<700 {
      board.step()
    }
    assert_eq(board.command(2, arg=512U).status, 4)
    for index in 0..<4 {
      for _ in 0..<150 {
        board.step()
      }
      let completion = board.command(5)
      assert_eq(completion.status, 0)
      assert_eq(
        completion.words,
        ReadOnlyArray::from_array([
          (101 + index).reinterpret_as_uint(),
          0U,
          [2U, 2U, 0U, 4U][index],
          0U,
          0U,
        ]),
      )
    }
    assert_eq(
      board.command(2, arg=512U).words[0],
      expected.reinterpret_as_uint(),
    )
    assert_eq(
      board.command(6).words,
      ReadOnlyArray::from_array([33U, 4U, 4U, 4U, 0U]),
    )
    let counters = board.command(7)
    assert_eq(counters.words[4], 0x00010002U)
    assert_eq(counters.words[2], 2U)
    assert_true(counters.words[0] >= counters.words[2])
    assert_eq(board.command(9).words[0], 0U)
    assert_eq(board.command(5).status, 5)
  }
}
