///|
test "slotted host mixed sources preserve two padded signed rectangular and 8x8 results" {
  for (rows, columns, reduction) in [(3, 2, 5), (8, 8, 3)] {
    let host = PortableHost::new()
    let simulator = slotted_host_prepare(8, 8, 5)
    let a0 = Array::makei(rows * reduction, index => {
      (index * 47 + 13) % 256 - 128
    })
    let a1 = Array::makei(rows * reduction, index => {
      (index * 31 + 127) % 256 - 128
    })
    let b0 = Array::makei(reduction * columns, index => {
      (index * 83 + 231) % 256 - 128
    })
    let b1 = Array::makei(reduction * columns, index => {
      (index * 19 + 7) % 256 - 128
    })
    slotted_host_load(host, simulator, 0, 0, rows, reduction, 32UL, 13UL, a0)
    slotted_host_load(host, simulator, 0, 1, rows, reduction, 128UL, 13UL, a1)
    slotted_host_load(
      host, simulator, 1, 0, reduction, columns, 256UL, 17UL, b0,
    )
    slotted_host_load(
      host, simulator, 1, 1, reduction, columns, 512UL, 17UL, b1,
    )
    let before_compute = host.requests.length()
    slotted_host_success(
      host,
      simulator,
      2,
      110,
      rows,
      columns,
      reduction,
      0UL,
      0UL,
      0UL,
      b=1,
    )
    slotted_host_success(
      host,
      simulator,
      2,
      111,
      rows,
      columns,
      reduction,
      0UL,
      0UL,
      0UL,
      a=1,
      c=1,
    )
    assert_eq(host.requests.length(), before_compute)
    assert_eq(
      execute_read(simulator, "active_cycles"),
      (reduction + rows + columns - 2).to_uint64(),
    )
    assert_eq(
      execute_read(simulator, "capture_cycles"),
      (rows * columns).to_uint64(),
    )
    let c0 = @flux_tile.matmul_int8_oracle(a0, b1, rows~, columns~, reduction~)
    let c1 = @flux_tile.matmul_int8_oracle(a1, b0, rows~, columns~, reduction~)
    for slot in [1, 0, 1] {
      slotted_host_store_check(
        host,
        simulator,
        slot,
        rows,
        columns,
        if slot == 0 {
          1024UL
        } else {
          1536UL
        },
        if slot == 0 {
          c0
        } else {
          c1
        },
      )
    }
    let count = host.requests.length()
    slotted_host_success(host, simulator, 4, 112, 0, 0, 0, 0UL, 0UL, 0UL)
    assert_eq(host.requests.length(), count)
  }
}

///|
test "slotted host exact smaller reloads replace only selected source and result shapes" {
  let host = PortableHost::new()
  let simulator = slotted_host_prepare(3, 3, 5)
  let left = [1, -2, 3, -4, 5, -6]
  let right = [7, -8, 9, -10, 11, -12]
  for slot in [0, 1] {
    slotted_host_load(host, simulator, 0, slot, 2, 3, 32UL, 13UL, left)
    slotted_host_load(host, simulator, 1, slot, 3, 2, 256UL, 17UL, right)
    slotted_host_success(
      host,
      simulator,
      2,
      120 + slot,
      2,
      2,
      3,
      0UL,
      0UL,
      0UL,
      a=slot,
      b=slot,
      c=slot,
    )
  }
  let preserved = @flux_tile.matmul_int8_oracle(
    left,
    right,
    rows=2,
    columns=2,
    reduction=3,
  )
  slotted_host_load(host, simulator, 0, 1, 1, 1, 128UL, 1UL, [-128])
  slotted_host_load(host, simulator, 1, 1, 1, 1, 512UL, 1UL, [127])
  let count = host.requests.length()
  assert_eq(
    slotted_host_command(
      host,
      simulator,
      2,
      122,
      2,
      2,
      3,
      0UL,
      0UL,
      a=1,
      b=1,
      c=1,
    ),
    (4UL, 0UL, 0UL),
  )
  portable_ack(host, simulator, true)
  assert_eq(host.requests.length(), count)
  // Rejected compute did not invalidate the old selected C1.
  slotted_host_store_check(host, simulator, 1, 2, 2, 1536UL, preserved)
  slotted_host_success(
    host,
    simulator,
    2,
    123,
    1,
    1,
    1,
    0UL,
    0UL,
    0UL,
    a=1,
    b=1,
    c=1,
  )
  let count = host.requests.length()
  assert_eq(
    slotted_host_command(host, simulator, 3, 124, 2, 2, 0, 1536UL, 40UL, c=1),
    (5UL, 0UL, 0UL),
  )
  portable_ack(host, simulator, true)
  assert_eq(host.requests.length(), count)
  slotted_host_store_check(host, simulator, 1, 1, 1, 1536UL, [-16256])
  slotted_host_store_check(host, simulator, 0, 2, 2, 1024UL, preserved)
}
