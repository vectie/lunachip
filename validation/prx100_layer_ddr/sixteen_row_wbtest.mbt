///|
test "sixteen-row owner reserves128 returns under held consumption" {
  let b = bridge_bench(
    read_ahead=true,
    eight_row=true,
    sixteen_row=true,
    aligned_extent=true,
    period=3,
    staggered=true,
  )
  read_ahead_pattern(b)
  b.read_delay = 600
  begin_read_ahead(b)
  for _ in 0..<900 {
    if b.reads.length() == 128 {
      break
    }
    b.step()
  }
  assert_eq(b.reads.length(), 128)
  assert_eq(b.max_outstanding.val, 128)
  // All unstallable returns must fit even while the source holds ready low.
  // Keep the ordinary packet helper's original timeout unchanged.
  for _ in 0..<900 {
    if b.read_head == 128 {
      break
    }
    b.step()
  }
  assert_eq(b.read_head, 128)
  for i in 0..<128 {
    check_read_ahead_packet(b, i) catch {
      e =>
        fail(
          "Held-return drain packet " +
          i.to_string() +
          ": " +
          Repr(e).to_string(),
        )
    }
  }
  println("PASS initial held-return drain")
  b.reset()
  b.read_delay = 3
  read_ahead_bridge_replay(b)
}

///|
test "sixteen-row full header preserves aligned extent overflow and boundary" {
  let good = @sim.Simulator::prepare(
    @ddr.address_validation_equivalence(sixteen_row=true),
  )
  let bad = @sim.Simulator::prepare(
    @ddr.address_validation_equivalence(sixteen_row=true, negative=true),
  )
  let last = 0xe000000080000080UL | (0x0ffff800UL << 32)
  for
    header in [
      0UL,
      0xffffffffffffffffUL,
      last,
      last + (128UL << 32),
      0xe000000088888880UL,
      0xe000000080000000UL,
      0xe000000080000084UL,
      0xe000000090000100UL,
      0xefffff808fffff80UL,
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
test "sixteen-row owner reduces delivery time versus two eight-row owners" {
  let cycles : Array[Int32] = []
  for sixteen in [false, true] {
    let b = bridge_bench(
      read_ahead=true,
      eight_row=true,
      sixteen_row=sixteen,
      aligned_extent=true,
      period=3,
    )
    read_ahead_pattern(b)
    b.read_delay = 24
    let start = b.tick
    for _ in 0..<(if sixteen { 1 } else { 2 }) {
      begin_read_ahead(b)
      for i in 0..<(if sixteen { 128 } else { 64 }) {
        check_read_ahead_packet(b, i, hold=0)
      }
    }
    cycles.push(b.tick - start)
    assert_eq(b.reads.length(), 128)
  }
  assert_true(
    cycles[1] < cycles[0],
    msg="Complete owner delivery: " + Repr(cycles).to_string(),
  )
}
