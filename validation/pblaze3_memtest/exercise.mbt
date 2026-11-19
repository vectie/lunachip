///|
fn Bench::until(self : Bench, phase : UInt64) -> Unit raise {
  for _ in 0..<20000 {
    if self.get("phase") == phase {
      return
    }
    self.step()
  }
  fail("memtest phase timeout: " + phase.to_string())
}

///|
fn Bench::terminal(self : Bench, success : Bool) -> Unit raise {
  self.until(if success { 5UL } else { 6UL })
  if success {
    assert_eq(self.writes, 2UL * self.beats)
    assert_eq(self.reads, 2UL * self.beats)
    assert_eq(self.get("completed_writes"), self.beats)
    assert_eq(self.get("checked_reads"), self.beats)
    assert_eq(self.get("status0"), 0xb0000000UL | self.beats)
    assert_eq(self.get("status1"), self.base + self.beats * 16UL)
    assert_eq(self.get("first_error_code"), 0UL)
  } else {
    assert_true(self.get("first_error_code") != 0UL)
    assert_eq(self.get("done"), 0UL)
  }
  let status = self.get("status0")
  let first = self.get("first_error_address")
  let writes = self.writes
  let reads = self.reads
  for _ in 0..<40 {
    self.step()
    assert_eq(self.get("status0"), status)
    assert_eq(self.get("first_error_address"), first)
    assert_eq(self.get("request_valid"), 0UL)
    assert_eq(self.get("response_ready"), 1UL)
  }
  assert_eq(self.writes, writes)
  assert_eq(self.reads, reads)
}

///|
fn exercise(b : Bench) -> Unit raise {
  let mut start = b.cycle
  b.terminal(true)
  b.cases.push({
    "case": "two full rounds, independent random AXI stalls",
    "start": start,
    "end": b.cycle,
  })
  for address_first in [true, false] {
    b.reset()
    start = b.cycle
    b.aw_pause = !address_first
    b.w_pause = address_first
    for _ in 0..<25 {
      b.step()
    }
    assert_eq(b.get("completed_writes"), 0UL)
    b.aw_pause = false
    b.w_pause = false
    b.terminal(true)
    b.cases.push({
      "case": "separate AW/W acceptance",
      "address_first": address_first,
      "start": start,
      "end": b.cycle,
    })
  }
  b.reset()
  start = b.cycle
  b.alias_mask = 0xffffff7fUL
  b.terminal(false)
  assert_eq(b.get("first_error_code"), 1UL)
  assert_eq(b.get("first_error_address"), b.base)
  b.cases.push({
    "case": "half-capacity alias detected after entire write pass",
    "start": start,
    "end": b.cycle,
  })
  for lane in 0..<4 {
    b.reset()
    start = b.cycle
    b.corrupt_address = Some(
      b.base + 16UL * (b.beats - 1UL) + lane.to_uint64() * 4UL,
    )
    b.terminal(false)
    assert_eq(b.get("first_error_code"), 1UL)
    assert_eq(b.get("first_error_address"), b.corrupt_address.unwrap())
    assert_eq(b.get("first_expected") ^ b.get("first_actual"), 0x100UL)
    b.cases.push({
      "case": "last-line corruption detected",
      "lane": lane,
      "start": start,
      "end": b.cycle,
    })
  }
  for read in [false, true] {
    for response in [2UL, 3UL] {
      b.reset()
      start = b.cycle
      if read {
        b.read_fault = response
      } else {
        b.write_fault = response
      }
      b.terminal(false)
      b.cases.push({
        "case": "AXI error never passes",
        "read": read,
        "response": response,
        "start": start,
        "end": b.cycle,
      })
    }
  }
  b.reset()
  start = b.cycle
  b.bad_last = true
  b.terminal(false)
  b.cases.push({
    "case": "missing RLAST never passes",
    "start": start,
    "end": b.cycle,
  })
  b.reset()
  start = b.cycle
  b.aw_pause = true
  b.w_pause = true
  for _ in 0..<20 {
    b.step()
  }
  b.drive("calibrated", 0UL)
  for _ in 0..<10 {
    b.step()
  }
  assert_eq(b.get("phase"), 6UL)
  assert_eq(b.get("first_error_code"), 2UL)
  b.aw_pause = false
  b.w_pause = false
  b.drive("calibrated", 1UL)
  // An already accepted bridge request may drain; no controller restart.
  for _ in 0..<50 {
    b.step()
  }
  b.terminal(false)
  b.cases.push({
    "case": "calibration loss sticky across recovery and drain",
    "start": start,
    "end": b.cycle,
  })
  b.reset()
  start = b.cycle
  b.until(4UL)
  b.reset()
  b.terminal(true)
  b.cases.push({
    "case": "coordinated reset during read, fresh full recovery",
    "start": start,
    "end": b.cycle,
  })
}
