///|
fn BridgeBench::begin_line(
  self : BridgeBench,
  address : UInt64,
  burst~ : Bool = false,
) -> Unit raise {
  self.accepted = false
  self.result = None
  set(self.sim, "request_line", 1, 1UL)
  set(self.sim, "request_burst", 1, if burst { 1UL } else { 0UL })
  set(self.sim, "request_write", 1, 0UL)
  set(self.sim, "request_address", 28, address)
  set(self.sim, "request_data", 32, 0UL)
  set(self.sim, "request_valid", 1, 1UL)
  set(self.sim, "response_ready", 1, 0UL)
  for _ in 0..<300 {
    self.step()
    if self.accepted {
      break
    }
  }
  assert_true(self.accepted)
  set(self.sim, "request_valid", 1, 0UL)
}

///|
fn BridgeBench::line_beat(
  self : BridgeBench,
  hold : Int32,
) -> (UInt64, UInt64, UInt64) raise {
  set(self.sim, "response_ready", 1, 0UL)
  for _ in 0..<300 {
    if value(self.sim, "response_valid") == 1UL {
      break
    }
    self.step()
  }
  assert_eq(value(self.sim, "response_valid"), 1UL)
  let before = self.results.length()
  let result = (
    value(self.sim, "response_data"),
    value(self.sim, "response_fault"),
    value(self.sim, "response_last"),
  )
  for _ in 0..<hold {
    self.step()
    assert_eq(value(self.sim, "request_ready"), 0UL)
    assert_eq(value(self.sim, "response_valid"), 1UL)
    assert_eq(
      (
        value(self.sim, "response_data"),
        value(self.sim, "response_fault"),
        value(self.sim, "response_last"),
      ),
      result,
    )
  }
  set(self.sim, "response_ready", 1, 1UL)
  for _ in 0..<4 {
    self.step()
    if self.results.length() > before {
      break
    }
  }
  set(self.sim, "response_ready", 1, 0UL)
  assert_eq(self.results.length(), before + 1)
  assert_eq(self.results[before], result)
  result
}

///|
fn BridgeBench::line_transaction(
  self : BridgeBench,
  address : UInt64,
  hold : Int32,
) -> Array[(UInt64, UInt64, UInt64)] raise {
  self.begin_line(address)
  let words = []
  for _ in 0..<4 {
    words.push(self.line_beat(hold))
  }
  assert_eq(value(self.sim, "request_ready"), 1UL)
  words
}
