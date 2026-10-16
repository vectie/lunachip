///|
test "direct8 arbiter discovery reads original equations and preserves old small-profile probes" {
  let fixture = direct8_arbiter_fixture()
  let probe = direct8_arbiter_probe(fixture)
  assert_eq(fixture.hardware(), direct8_fair_hardware())
  let aliases = direct8_arbiter_aliases(fixture, probe)
  assert_eq(aliases.length(), 165)
  for
    role in [
      "r_address", "r_local_tag", "i_reader_address", "i_engine_address", "i_reader_tag",
      "i_engine_tag",
    ] {
    guard aliases.filter(binding => binding.name == role) is [binding] else {
      fail("original role missing")
    }
    assert_eq(binding.signal_type.width().bits(), 32)
  }
  let emitted = @rtl.emit_design(
    @ir.Design::single(
      "QueuedConcurrentDirect8CompletionPilot",
      fixture.hardware(),
    ),
  )
  let (bindings, report) = direct8_arbiter_bindings(aliases, emitted)
  assert_eq(report.split("\nNODE ").count() - 1, 165)
  assert_false(bindings.contains("anyseq"))
  assert_false(bindings.contains("lc_dut."))
  assert_false(bindings.contains("input "))
  let old = two_client_arbiter_probe(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  assert_eq(
    sha256_hex(two_client_arbiter_probe_report(old)),
    "cc867599656fda1bc3897b42d971feb75736de72e22112a6ef1d0364af32d138",
  )
}
