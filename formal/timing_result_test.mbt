///|
test "schema-1 result bytes remain exact for untimed tasks" {
  let result = @formal.BoundedProofResult::checked(bounded_task(), BoundedPass)
  assert_eq(
    result.to_canonical_text(),
    "LUNACHIP-FORMAL-RESULT 1\n" +
    "TASK-MANIFEST sha256 cf645c2a433641c47cdeccd2878bd130b098a9832103e49628d68df7da5cebe6\n" +
    "TASK 6669666f20736166657479206465707468203332\n" +
    "ARTIFACT 72746c2f746f702e7376 sha256 \{digest("a")}\n" +
    "TOOL 736279 302e36302e30\n" +
    "ENGINE 736d74626d6320626f6f6c6563746f72\n" +
    "CLASS bounded\n" +
    "MODE bmc-safety\n" +
    "BOUND 32\n" +
    "ASSUMPTIONS 2\n" +
    "A 0 6c635f70305f6237323635373336353734\n" +
    "A 1 6c635f70315f62363137333733373536643635\n" +
    "PROPERTIES 2\n" +
    "P 0 6c635f70335f62373536653634363537323636366336663737\n" +
    "P 1 6c635f70395f6236663736363537323636366336663737\n" +
    "RESULT bounded-pass\n" +
    "COUNTEREXAMPLE none\n" +
    "WITNESS none\n" +
    "DETAIL none\n" +
    "END\n",
  )
}

///|
test "schema-2 results retain and digest-bind the complete timing contract" {
  let bounded = @formal.BoundedProofResult::checked(
    timed_bounded_task(),
    BoundedPass,
  )
  let bounded_text = bounded.to_canonical_text()
  assert_true(bounded_text.has_prefix("LUNACHIP-FORMAL-RESULT 2\n"))
  assert_true(bounded_text.contains("GLOBAL-TIMESTEP 1\n"))
  assert_true(bounded_text.contains("COINCIDENCE atomic-global-pre-state\n"))
  assert_true(bounded_text.contains("RESULT bounded-pass\n"))
  assert_eq(@formal.parse_proof_result(bounded_text), BoundedResult(bounded))
  let tampered = bounded_text.replace(
    old="GLOBAL-TIMESTEP 1",
    new="GLOBAL-TIMESTEP 2",
  )
  try @formal.parse_proof_result(tampered) catch {
    TaskDigestMismatch(..) => ()
    _ => fail("expected timing change to invalidate task digest")
  } noraise {
    _ => fail("expected timing change to invalidate task digest")
  }
  let unbounded_contract = @formal.FormalTimingContract::checked(
    @formal.GlobalFormalTimestep::checked(1),
    [formal_clock(0, signal("clock"))],
    [],
    [],
    AtomicGlobalPreState,
  )
  let unbounded = @formal.UnboundedProofResult::checked(
    unbounded_task().with_timing_contract(unbounded_contract),
    Proved,
  )
  let unbounded_text = unbounded.to_canonical_text()
  assert_true(unbounded_text.has_prefix("LUNACHIP-FORMAL-RESULT 2\n"))
  assert_true(unbounded_text.contains("RESULT proved\n"))
  assert_eq(
    @formal.parse_proof_result(unbounded_text),
    UnboundedResult(unbounded),
  )
}
