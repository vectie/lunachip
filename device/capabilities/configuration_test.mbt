///|
fn capability_test_config(
  rows~ : Int32 = 2,
  columns~ : Int32 = 3,
  max_reduction~ : Int32 = 5,
  host_bytes~ : UInt64 = 4096UL,
  ring_depth~ : Int32 = 4,
  queue_depth~ : Int32 = 3,
) -> @capabilities.Capabilities raise @capabilities.CapabilityError {
  @capabilities.Capabilities::new(
    rows~,
    columns~,
    max_reduction~,
    host_bytes~,
    ring_depth~,
    queue_depth~,
  )
}

///|
test "capabilities accept supported endpoints and every ring depth" {
  for
    (rows, columns, reduction, host, ring, queue) in [
      (1, 1, 1, 1UL, 2, 2),
      (8, 8, 4096, 4294967296UL, 16, 16),
    ] {
    let config = capability_test_config(
      rows~,
      columns~,
      max_reduction=reduction,
      host_bytes=host,
      ring_depth=ring,
      queue_depth=queue,
    )
    assert_eq(config.rows, rows)
    assert_eq(config.columns, columns)
    assert_eq(config.max_reduction, reduction)
    assert_eq(config.host_bytes, host)
    assert_eq(config.ring_depth, ring)
    assert_eq(config.queue_depth, queue)
  }
  for ring_depth in [2, 4, 8, 16] {
    assert_eq(capability_test_config(ring_depth~).ring_depth, ring_depth)
  }
}

///|
test "capabilities reject out-of-range array dimensions with exact field errors" {
  for value in [-1, 0, 9] {
    try capability_test_config(rows=value) catch {
      InvalidRows(value=actual) => assert_eq(actual, value)
      other => fail("unexpected row error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid rows accepted")
    }
    try capability_test_config(columns=value) catch {
      InvalidColumns(value=actual) => assert_eq(actual, value)
      other => fail("unexpected column error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid columns accepted")
    }
  }
}

///|
test "capabilities reject capacity and aperture outside inclusive bounds" {
  for value in [-1, 0, 4097] {
    try capability_test_config(max_reduction=value) catch {
      InvalidMaxReduction(value=actual) => assert_eq(actual, value)
      other => fail("unexpected reduction error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid reduction accepted")
    }
  }
  for value in [0UL, 4294967297UL] {
    try capability_test_config(host_bytes=value) catch {
      InvalidHostBytes(value=actual) => assert_eq(actual, value)
      other => fail("unexpected aperture error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid aperture accepted")
    }
  }
}

///|
test "capabilities reject unsupported ring and queue depths" {
  for value in [-1, 0, 1, 3, 17] {
    try capability_test_config(ring_depth=value) catch {
      InvalidRingDepth(value=actual) => assert_eq(actual, value)
      other => fail("unexpected ring error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid ring depth accepted")
    }
  }
  for value in [-1, 0, 1, 17] {
    try capability_test_config(queue_depth=value) catch {
      InvalidQueueDepth(value=actual) => assert_eq(actual, value)
      other => fail("unexpected queue error: \{Repr(other)}")
    } noraise {
      _ => fail("invalid queue depth accepted")
    }
  }
}

///|
test "capability validation uses declared field order" {
  try
    capability_test_config(
      rows=0,
      columns=0,
      max_reduction=0,
      host_bytes=0UL,
      ring_depth=0,
      queue_depth=0,
    )
  catch {
    InvalidRows(value=0) => ()
    other => fail("unexpected validation priority: \{Repr(other)}")
  } noraise {
    _ => fail("invalid configuration accepted")
  }
}
