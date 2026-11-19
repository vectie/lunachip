///|
test "eight-row owner reserves64 returns and drains every packet reset prefix" {
  let b = bridge_bench(
    read_ahead=true,
    eight_row=true,
    period=3,
    staggered=true,
  )
  read_ahead_pattern(b)
  b.read_delay = 400
  begin_read_ahead(b)
  for _ in 0..<600 {
    if b.reads.length() == 64 {
      break
    }
    b.step()
  }
  assert_eq(b.reads.length(), 64)
  assert_eq(b.max_outstanding.val, 64)
  for i in 0..<64 {
    check_read_ahead_packet(b, i)
  }
  b.reset()
  b.read_delay = 3
  read_ahead_bridge_replay(b)
}

///|
test "aligned extent preserves every boundary and rejects the negative limit" {
  let good = @sim.Simulator::prepare(@ddr.address_validation_equivalence())
  let bad = @sim.Simulator::prepare(
    @ddr.address_validation_equivalence(negative=true),
  )
  let last = 0xe000000080000080UL | (0x0ffffc00UL << 32)
  for
    header in [
      0UL,
      0xffffffffffffffffUL,
      last,
      last + (1UL << 32),
      0xe000000080000080UL | (0x0fffff80UL << 32),
      0xe000000089249280UL,
      0xe000000080000000UL,
      0xe000000080000084UL,
      0xe000000090000100UL,
    ] {
    set(good, "header", 64, header)
    good.settle()
    assert_eq(
      value(good, "legacy"),
      value(good, "aligned"),
      msg=header.to_string(),
    )
  }
  set(bad, "header", 64, last)
  bad.settle()
  assert_eq(value(bad, "legacy"), 0UL)
  assert_eq(value(bad, "aligned"), 1UL)
}

///|
test "aligned eight-row bridge retains staggered flags reset drain and faults" {
  let b = bridge_bench(
    read_ahead=true,
    eight_row=true,
    aligned_extent=true,
    period=3,
    staggered=true,
  )
  read_ahead_bridge_replay(b)
}

///|
test "eight-row request amortizes delivery without changing word work" {
  let cycles : Array[Int32] = []
  for eight in [false, true] {
    let b = bridge_bench(read_ahead=true, eight_row=eight, period=3)
    read_ahead_pattern(b)
    b.read_delay = 24
    let start = b.tick
    if eight {
      begin_read_ahead(b)
      for i in 0..<64 {
        check_read_ahead_packet(b, i, hold=0)
      }
    } else {
      for _ in 0..<2 {
        begin_read_ahead(b)
        for i in 0..<32 {
          check_read_ahead_packet(b, i, hold=0)
        }
      }
    }
    cycles.push(b.tick - start)
    assert_eq(b.reads.length(), 64)
  }
  assert_true(
    cycles[1] < cycles[0],
    msg="Eight rows versus two four-row owners: " + Repr(cycles).to_string(),
  )
}
