///|
test "evidence observations preserve exact production module and core identities" {
  let (controller, observations) = @projection.controller_evidence()
  assert_eq(controller, @projection.controller())
  assert_eq(observations.length(), 21)
  let (bridge, observations) = @projection.bridge_evidence()
  assert_eq(bridge, @projection.bridge())
  assert_eq(observations.length(), 15)
  let design = @ir.Design::single(
    "phase6-fetched-concurrent-8x8-k16-two-slots",
    @board.core(Array8),
  )
  assert_eq(
    @verilator.sha256_hex(@codec.serialize(design)),
    "37c1a39acc22bcf7730c377f97009e7798fe2bdc1418476a3f00825c1c08ffc8",
  )
  let emitted = @systemverilog.emit_design(design)
  assert_eq(
    @verilator.sha256_hex(emitted.modules()[0].source()),
    "b0f4967cbafb776c711bbe577119b88dcfd77215cf7eafc990247e8fb32b9615",
  )
  assert_eq(
    @verilator.sha256_hex(emitted.manifest().to_canonical_text()),
    "e0e18939ab6c87679df57c61a4084032b24dd2c3ebe2def57ca423ad4e29330b",
  )
  assert_true(@projection.core() != @board.core(Array8))
  assert_eq(
    @verilator.sha256_hex(
      @codec.serialize(
        @ir.Design::single(
          "phase6-fetched-concurrent-word32-8x8-k16-two-slots",
          @projection.core(),
        ),
      ),
    ),
    "d2a2ed67292880d8f5199c2a60ec81d4f002ca1fee8bab78f4578760249c3f3a",
  )
}
