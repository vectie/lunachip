///|
test "two-client arbiter candidate report inspection" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let probe = two_client_arbiter_probe(fixture)
  let report = two_client_arbiter_probe_report(probe)
  assert_eq(
    report,
    two_client_arbiter_probe_report(two_client_arbiter_probe(fixture)),
  )
  assert_true(
    report.has_prefix("CANDIDATE-PROBE ONLY-not-accepted-projection-or-proof\n"),
  )
  assert_true(report.contains("ESSENTIAL roots 11 bits172\n"))
  assert_eq(
    probe.boundaries
    .iter()
    .fold(init=0, (count, boundary) => count + boundary.roles.length()),
    22,
  )
  assert_eq(
    probe.boundaries
    .filter(boundary => boundary.original.kind() is Constant(_))
    .length(),
    7,
  )
  assert_eq(probe.candidates.length(), 15)
  assert_eq(probe.events.length(), 17)
  // Root intentionally captures this full inspection output before accepting
  // any inventory hash, projection, symbolic cuts or external proof inputs.
  println(report)
}

///|
test "two-client arbiter discovery rejects wrong types state masks and latch events" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = fixture.hardware()
  let probe = two_client_arbiter_probe(fixture)
  let state = probe.roots.filter(root => root.name == "state")[0]
  let offer = probe.events.filter(event => event.name == "offer")[0]
  let (_, inactive) = dependency_generation_decoder_and(hardware, offer.node)
  try
    two_client_arbiter_output(hardware, "memory_request_data", @wire.uint(32))
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected output type rejection")
  } noraise {
    _ => fail("wrong typed public driver accepted")
  }
  try two_client_arbiter_state_gate(hardware, offer.node, inactive, 2UL) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected state mask rejection")
  } noraise {
    _ => fail("Offer mislabeled as Wait")
  }
  let address = probe.roots.filter(root => root.name == "address")[0]
  let accept = probe.events.filter(event => event.name == "request_accept")[0]
  try two_client_arbiter_hold(hardware, address, accept.node) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected latch event rejection")
  } noraise {
    _ => fail("grant latch mislabeled as acceptance latch")
  }
  assert_eq(state.signal_type, @wire.uint(2))
}

///|
test "two-client arbiter closed probe rejects missing state interface and event shadow" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let hardware = fixture.hardware()
  let probe = two_client_arbiter_probe(fixture)
  try
    two_client_arbiter_probe_closure(
      hardware,
      probe.roots[1:],
      probe.candidates,
      probe.events,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected missing-state rejection")
  } noraise {
    _ => fail("incomplete essential state accepted")
  }
  try
    two_client_arbiter_probe_closure(
      hardware,
      probe.roots,
      probe.candidates[1:],
      probe.events,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected missing-interface rejection")
  } noraise {
    _ => fail("unlisted original input leaf accepted")
  }
  let masked = probe.events.filter(event => event.name == "grant")[0]
  let shadows = probe.candidates.iter().to_array()
  shadows.push({
    original: dependency_generation_node(hardware, masked.node),
    roles: ["forbidden_grant"],
  })
  try
    two_client_arbiter_probe_closure(
      hardware,
      probe.roots,
      shadows,
      probe.events,
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected event-shadow rejection")
  } noraise {
    _ => fail("arbiter grant became an independent interface")
  }
  let control : Array[TwoClientArbiterCandidate] = []
  try
    two_client_arbiter_boundary(
      hardware,
      control,
      probe.clock,
      Clock,
      "forbidden_clock",
    )
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("unexpected control boundary rejection")
  } noraise {
    _ => fail("clock became a raw data interface")
  }
}
