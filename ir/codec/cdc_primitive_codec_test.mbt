///|
fn codec_bit_synchronizer_design() -> @ir.Design raise {
  let clock_source = @ir.NodeId::new(0)
  let clock_destination = @ir.NodeId::new(1)
  let reset = @ir.NodeId::new(2)
  let source = @ir.NodeId::new(3)
  let first = @ir.NodeId::new(4)
  let second = @ir.NodeId::new(5)
  let source_domain = @ir.ClockDomain::rising(clock_source)
  let destination_domain = @ir.ClockDomain::rising(clock_destination)
  let signal_type : @ir.SignalType = Bits(@ir.Width::new(1))
  let reset_spec = @ir.ResetSpec::new(reset, 0UL)
  let primitive = @ir.BitSynchronizerPrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "sync🔥",
    SourceDomain(source_domain.id()),
    source,
    destination_domain.id(),
    [first, second],
    reset=reset_spec,
  )
  let hardware_module = @ir.Module::checked_with_metadata(
    "BitSynchronizer",
    [source_domain, destination_domain],
    [
      @ir.Node::new(clock_source, Clock, Input("clock_source")),
      @ir.Node::new(clock_destination, Clock, Input("clock_destination")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(source, signal_type, Input("source")),
      @ir.Node::new(
        first,
        signal_type,
        Register(
          @ir.RegisterSpec::new(destination_domain, source, reset=reset_spec),
        ),
      ),
      @ir.Node::new(
        second,
        signal_type,
        Register(
          @ir.RegisterSpec::new(destination_domain, first, reset=reset_spec),
        ),
      ),
    ],
    [],
    [@ir.OutputPort::new("synchronized", signal_type, second)],
    @ir.ModuleMetadata::checked_complete([], [], [], [], [
      BitSynchronizer(primitive),
    ]),
  )
  @ir.Design::single("bit-sync", hardware_module)
}

///|
const CDC_PRIMITIVE_GOLDEN : String =
  #|LUNACHIP-IR 4
  #|DESIGN 6269742d73796e63
  #|TOP 42697453796e6368726f6e697a6572
  #|MODULES 1
  #|MODULE 42697453796e6368726f6e697a6572
  #|DOMAINS 2
  #|DOMAIN 0 0 rising
  #|DOMAIN 1 1 rising
  #|PARAMETERS 0
  #|NODES 6
  #|NODE 0 clock input 636c6f636b5f736f75726365
  #|NODE 1 clock input 636c6f636b5f64657374696e6174696f6e
  #|NODE 2 reset input 7265736574
  #|NODE 3 bits:1 input 736f75726365
  #|NODE 4 bits:1 reg 1 3 2 0 synchronous active_high - -
  #|NODE 5 bits:1 reg 1 4 2 0 synchronous active_high - -
  #|MEMORIES 0
  #|OUTPUTS 1
  #|OUTPUT 73796e6368726f6e697a6564 bits:1 5
  #|INPUT_TIMINGS 0
  #|OUTPUT_TIMINGS 0
  #|AGGREGATES 0
  #|PRIMITIVES 1
  #|PRIMITIVE 0 bit_synchronizer 73796e63f09f94a5
  #|SOURCE domain 0 3
  #|DESTINATION 1
  #|RESET synchronous active_high 2 0
  #|STAGES 2
  #|STAGE 0 4
  #|STAGE 1 5
  #|ENDPRIMITIVE
  #|ENDMODULE
  #|END
  #|

///|
test "schema four bit synchronizer has exact canonical bytes" {
  let encoded = @codec.serialize(codec_bit_synchronizer_design())
  assert_eq(encoded, CDC_PRIMITIVE_GOLDEN)
  let decoded = @codec.parse(encoded)
  assert_eq(@codec.serialize(decoded), encoded)
  assert_eq(decoded.top_module().unwrap().cdc_primitives().length(), 1)
}

///|
test "schema four rejects malformed primitive stages domains and fanout" {
  let bad_ordinal = CDC_PRIMITIVE_GOLDEN.replace(
    old="STAGE 1 5",
    new="STAGE 2 5",
  )
  try @codec.parse(bad_ordinal) catch {
    UnexpectedLine(expected~, ..) => assert_eq(expected, "STAGE 1 node")
    error => fail("unexpected stage ordinal error: \{Repr(error)}")
  } noraise {
    _ => fail("expected stage ordinal rejection")
  }
  let unknown_domain = CDC_PRIMITIVE_GOLDEN.replace(
    old="DESTINATION 1",
    new="DESTINATION 9",
  )
  try @codec.parse(unknown_domain) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("UnknownCdcPrimitiveDomain"))
    error => fail("unexpected primitive domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive domain rejection")
  }
  let exposed_stage = CDC_PRIMITIVE_GOLDEN.replace(
    old="OUTPUT 73796e6368726f6e697a6564 bits:1 5",
    new="OUTPUT 73796e6368726f6e697a6564 bits:1 4",
  )
  try @codec.parse(exposed_stage) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("CdcPrimitiveIntermediateFanout"))
    error => fail("unexpected primitive fanout error: \{Repr(error)}")
  } noraise {
    _ => fail("expected intermediate fanout rejection")
  }
}

///|
test "schema four primitive reset modes remain fail closed" {
  let asynchronous = CDC_PRIMITIVE_GOLDEN.replace(
    old="RESET synchronous active_high 2 0",
    new="RESET asynchronous active_high 2 0",
  )
  try @codec.parse(asynchronous) catch {
    UnsupportedAsynchronousReset(line~) => assert_true(line > 0)
    error => fail("unexpected primitive async-reset error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive async reset rejection")
  }
  let active_low = CDC_PRIMITIVE_GOLDEN.replace(
    old="RESET synchronous active_high 2 0",
    new="RESET synchronous active_low 2 0",
  )
  try @codec.parse(active_low) catch {
    UnsupportedResetPolarity(polarity~, ..) => assert_eq(polarity, "active_low")
    error => fail("unexpected primitive polarity error: \{Repr(error)}")
  } noraise {
    _ => fail("expected primitive polarity rejection")
  }
}
