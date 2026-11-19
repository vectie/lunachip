///|
test "read-ahead reserves32returns and preserves held command and response order" {
  let b = bridge_bench(read_ahead=true, period=3, staggered=true)
  read_ahead_pattern(b)
  b.read_delay = 180
  b.max_outstanding.val = 0
  begin_read_ahead(b)
  for _ in 0..<400 {
    if b.reads.length() >= 7 {
      break
    }
    b.step()
  }
  assert_eq(b.reads.length(), 7)
  b.command_paused = true
  b.step()
  let address = value(b.sim, "app_addr")
  for _ in 0..<19 {
    assert_eq(value(b.sim, "app_en"), 1UL)
    assert_eq(value(b.sim, "app_addr"), address)
    b.step()
  }
  b.command_paused = false
  for _ in 0..<400 {
    if b.reads.length() == 32 {
      break
    }
    b.step()
  }
  assert_eq(b.reads.length(), 32)
  assert_eq(b.max_outstanding.val, 32)
  for _ in 0..<300 {
    b.step()
  }
  assert_eq(b.reads.length(), 32)
  for i in 0..<32 {
    check_read_ahead_packet(b, i)
  }
  read_ahead_bridge_replay(b)
}

///|
test "read-ahead reduces same-stimulus four-row delivery cycles" {
  let times : Array[Int32] = []
  for ahead in [false, true] {
    let b = bridge_bench(
      streaming=true,
      batch=true,
      wide=true,
      read_ahead=ahead,
      period=3,
    )
    read_ahead_pattern(b)
    b.read_delay = 24
    let start = b.tick
    begin_read_ahead(b)
    for i in 0..<32 {
      check_read_ahead_packet(b, i, hold=0)
    }
    times.push(b.tick - start)
  }
  debug_inspect(
    times,
    content=(
      #|[193, 142]
    ),
  )
  assert_true(
    times[1] < times[0],
    msg="Same packet data,random seed,3:1clock,read latency and always-ready receiver",
  )
}
