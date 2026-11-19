///|
test "eight-word delivery retains every native line and all joined FIFO reservations" {
  let b = bridge_bench(
    read_ahead=true,
    eight_row=true,
    sixteen_row=true,
    aligned_extent=true,
    delivery=true,
    period=3,
    staggered=true,
  )
  assert_eq(b.joined.length(), 16)
  read_ahead_pattern(b)
  b.read_delay = 600
  begin_read_ahead(b)
  for _ in 0..<1800 {
    if b.read_head == 128 {
      break
    }
    b.step()
  }
  assert_eq(b.reads.length(), 128)
  assert_eq(b.read_head, 128)
  assert_eq(b.max_outstanding.val, 128)
  for i in 0..<64 {
    check_read_ahead_packet(b, i)
  }
  b.reset()
  b.read_delay = 3
  b.max_outstanding.val = 0
  wide_bridge_replay(b)
  read_ahead_bridge_replay(b)
}

///|
test "eight-word delivery waits for both constituent lines and reduces complete-owner time" {
  let elapsed : Array[Int32] = []
  for delivery in [false, true] {
    let b = bridge_bench(
      read_ahead=true,
      eight_row=true,
      sixteen_row=true,
      aligned_extent=true,
      delivery~,
      period=3,
    )
    read_ahead_pattern(b)
    b.read_delay = 24
    let begin = b.tick
    begin_read_ahead(b)
    for i in 0..<(512 / b.packet_words) {
      check_read_ahead_packet(b, i, hold=0)
    }
    assert_eq(b.reads.length(), 128)
    elapsed.push(b.tick - begin)
  }
  assert_true(
    elapsed[1] < elapsed[0],
    msg="Complete-owner delivery ticks: \{Repr(elapsed)}",
  )
}

///|
test "eight-word response remains absent with only its first native line returned" {
  let b = bridge_bench(
    read_ahead=true,
    eight_row=true,
    sixteen_row=true,
    aligned_extent=true,
    delivery=true,
    period=3,
  )
  read_ahead_pattern(b)
  b.read_delay = 60
  begin_read_ahead(b)
  while b.reads.length() < 2 {
    b.step()
  }
  assert_eq(b.read_head, 0)
  let second = b.reads[1]
  b.reads[1] = (b.tick + 300, second.1)
  while b.read_head < 1 {
    b.step()
  }
  for _ in 0..<100 {
    assert_eq(value(b.sim, "response_valid"), 0UL)
    assert_eq(b.read_head, 1)
    b.step()
  }
  for i in 0..<64 {
    check_read_ahead_packet(b, i, hold=i % 5)
  }
}

///|
test "rejected wide read drains exactly its owner before a following line write" {
  for delivery in [false, true] {
    let b = bridge_bench(
      read_ahead=true,
      eight_row=true,
      sixteen_row=true,
      aligned_extent=true,
      delivery~,
      period=3,
    )
    rejected_wide_owner_replay(b)
  }
}
