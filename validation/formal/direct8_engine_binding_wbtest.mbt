///|
test "direct8 engine bindings follow original wide address cursor capture and lease equations" {
  let fixture = direct8_arbiter_fixture()
  let transfer = direct8_engine_transfer_bindings(
    fixture,
    direct8_arbiter_probe(fixture),
  )
  let compute = direct8_engine_compute_bindings(fixture)
  assert_eq((transfer.length(), compute.length()), (20, 29))
  let bindings = direct8_arbiter_aliases(
      fixture,
      direct8_arbiter_probe(fixture),
    )
    .iter()
    .to_array()
  for binding in transfer {
    bindings.push(binding)
  }
  for binding in compute {
    bindings.push(binding)
  }
  let ownership = direct8_engine_owner_bindings(
    fixture,
    direct8_arbiter_probe(fixture),
  )
  assert_eq(ownership.length(), 43)
  for binding in ownership {
    bindings.push(binding)
  }
  assert_eq(bindings.length(), 257)
  for index, binding in bindings {
    assert_false(bindings[:index].any(old => old.name == binding.name))
    assert_eq(
      fixture.hardware().node(binding.node).unwrap().signal_type(),
      binding.signal_type,
    )
  }
  for
    (name, width) in [
      ("t_reader_address_full", 64),
      ("t_engine_address_full", 64),
      ("t_reader_row", 13),
      ("t_engine_column", 13),
      ("composition_capture_row", 4),
      ("x_core_steps", 13),
      ("x_lease", 1),
    ] {
    guard bindings.filter(binding => binding.name == name) is [binding] else {
      fail("missing original engine role")
    }
    assert_eq(binding.signal_type.width().bits(), width)
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let (source, report) = direct8_arbiter_bindings(
    ReadOnlyArray::from_array(bindings),
    emitted,
  )
  assert_eq(report.split("\nNODE ").count() - 1, 257)
  assert_false(source.contains("anyseq"))
  assert_false(source.contains("lc_dut."))
  // Reject an accidental smaller-profile invocation before it can bind a
  // truncated/incorrect physical memory encoder.
  try fetched_capture_roots(fixture.hardware()) catch {
    _ => ()
  } noraise {
    _ => fail("wrong physical profile must fail")
  }
}
