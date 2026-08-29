///|
test "result protocol and deterministic PRNG are stable" {
  let protocol = @verilator.ResultProtocol::checked(
    "LUNACHIP-TEST-RESULT", "1", "lunachip.test/v1",
  )
  assert_eq(protocol.magic(), "LUNACHIP-TEST-RESULT")
  let first = @verilator.DeterministicPrng::new(0UL)
  let second = @verilator.DeterministicPrng::new(0UL)
  for _ in 0..<8 {
    assert_eq(first.next(), second.next())
  }
}
