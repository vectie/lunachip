///|
fn checked_toggle_handshake_module(stages : Int32) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("CheckedToggleHandshake")
  let source_clock = builder.input("source_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let source_reset = builder.synchronous_reset(source_reset_signal, 0UL)
  let destination_reset = builder.synchronous_reset(
    destination_reset_signal, 0UL,
  )
  let source_valid = builder.input("source_valid", @wire.bits(1))
  let source_word = builder.input("source_word", @wire.uint(8))
  let source_tag = builder.input("source_tag", @wire.bits(3))
  let destination_ready = builder.input("destination_ready", @wire.bits(1))
  let payload = @aggregate.Aggregate::record([
    ("word", @aggregate.Aggregate::leaf(source_word)),
    ("tag🔥", @aggregate.Aggregate::leaf(source_tag)),
  ])
  let forward = builder.ready_valid_forward(source_valid, payload)
  let backward = builder.ready_valid_backward(destination_ready)
  let handshake = builder.toggle_handshake(
    "crossing🔥",
    source_domain,
    destination_domain,
    forward,
    backward,
    source_reset,
    destination_reset,
    synchronizer_stages=stages,
  )
  let source_ready_output = builder.output("source_ready", @wire.bits(1))
  let destination_valid_output = builder.output(
    "destination_valid",
    @wire.bits(1),
  )
  let destination_word_output = builder.output(
    "destination_word",
    @wire.uint(8),
  )
  let destination_tag_output = builder.output("destination_tag", @wire.bits(3))
  builder.connect(source_ready_output, handshake.source().ready())
  builder.connect(destination_valid_output, handshake.destination().valid())
  let destination_leaves = handshake.destination().payload().flatten()
  builder.connect(destination_word_output, destination_leaves[0].value())
  builder.connect(destination_tag_output, destination_leaves[1].value())
  for input in [source_reset_signal, source_valid, source_word, source_tag] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, destination_ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready_output, ProducedIn(source_domain.id()))
  for
    output in [
      destination_valid_output, destination_word_output, destination_tag_output,
    ] {
    builder.output_timing(output, ProducedIn(destination_domain.id()))
  }
  builder.finish()
}

///|
const TOGGLE_HANDSHAKE_GOLDEN : String =
  #|LUNACHIP-IR 4
  #|DESIGN 746f67676c652d68616e647368616b65
  #|TOP 436865636b6564546f67676c6548616e647368616b65
  #|MODULES 1
  #|MODULE 436865636b6564546f67676c6548616e647368616b65
  #|DOMAINS 2
  #|DOMAIN 0 0 rising
  #|DOMAIN 1 1 rising
  #|PARAMETERS 0
  #|NODES 35
  #|NODE 0 clock input 736f757263655f636c6f636b
  #|NODE 1 clock input 64657374696e6174696f6e5f636c6f636b
  #|NODE 2 reset input 736f757263655f7265736574
  #|NODE 3 reset input 64657374696e6174696f6e5f7265736574
  #|NODE 4 bits:1 input 736f757263655f76616c6964
  #|NODE 5 uint:8 input 736f757263655f776f7264
  #|NODE 6 bits:3 input 736f757263655f746167
  #|NODE 7 bits:1 input 64657374696e6174696f6e5f7265616479
  #|NODE 8 bits:1 reg 0 20 2 0 synchronous active_high - -
  #|NODE 9 bits:1 reg 1 31 3 0 synchronous active_high - -
  #|NODE 10 bits:1 reg 1 34 3 0 synchronous active_high - -
  #|NODE 11 bits:1 reg 1 8 3 0 synchronous active_high - -
  #|NODE 12 bits:1 reg 1 11 3 0 synchronous active_high - -
  #|NODE 13 bits:1 reg 1 12 3 0 synchronous active_high - -
  #|NODE 14 bits:1 reg 0 10 2 0 synchronous active_high - -
  #|NODE 15 bits:1 reg 0 14 2 0 synchronous active_high - -
  #|NODE 16 bits:1 reg 0 15 2 0 synchronous active_high - -
  #|NODE 17 bits:1 eq 8 16
  #|NODE 18 bits:1 and 4 17
  #|NODE 19 bits:1 not 8
  #|NODE 20 bits:1 mux 18 19 8
  #|NODE 21 uint:8 reg 0 5 2 0 synchronous active_high 18 -
  #|NODE 22 bits:3 reg 0 6 2 0 synchronous active_high 18 -
  #|NODE 23 bits:1 eq 13 10
  #|NODE 24 bits:1 not 23
  #|NODE 25 bits:1 and 9 7
  #|NODE 26 bits:1 not 9
  #|NODE 27 bits:1 or 26 7
  #|NODE 28 bits:1 and 24 27
  #|NODE 29 bits:1 not 25
  #|NODE 30 bits:1 and 9 29
  #|NODE 31 bits:1 or 28 30
  #|NODE 32 uint:8 reg 1 21 3 0 synchronous active_high 28 -
  #|NODE 33 bits:3 reg 1 22 3 0 synchronous active_high 28 -
  #|NODE 34 bits:1 mux 28 13 10
  #|MEMORIES 0
  #|OUTPUTS 4
  #|OUTPUT 64657374696e6174696f6e5f746167 bits:3 33
  #|OUTPUT 64657374696e6174696f6e5f76616c6964 bits:1 9
  #|OUTPUT 64657374696e6174696f6e5f776f7264 uint:8 32
  #|OUTPUT 736f757263655f7265616479 bits:1 17
  #|INPUT_TIMINGS 6
  #|INPUT_TIMING 2 sampled_in 0
  #|INPUT_TIMING 3 sampled_in 1
  #|INPUT_TIMING 4 sampled_in 0
  #|INPUT_TIMING 5 sampled_in 0
  #|INPUT_TIMING 6 sampled_in 0
  #|INPUT_TIMING 7 sampled_in 1
  #|OUTPUT_TIMINGS 4
  #|OUTPUT_TIMING 64657374696e6174696f6e5f746167 produced_in 1
  #|OUTPUT_TIMING 64657374696e6174696f6e5f76616c6964 produced_in 1
  #|OUTPUT_TIMING 64657374696e6174696f6e5f776f7264 produced_in 1
  #|OUTPUT_TIMING 736f757263655f7265616479 produced_in 0
  #|AGGREGATES 0
  #|PRIMITIVES 1
  #|PRIMITIVE 0 toggle_handshake 63726f7373696e67f09f94a5
  #|SOURCE_DOMAIN 0
  #|DESTINATION_DOMAIN 1
  #|SOURCE_RESET synchronous active_high 2 0
  #|DESTINATION_RESET synchronous active_high 3 0
  #|SHAPE record 2
  #|FIELD 776f7264
  #|SHAPE leaf uint:8
  #|FIELD 746167f09f94a5
  #|SHAPE leaf bits:3
  #|SOURCE_VALID 4
  #|SOURCE_READY 17
  #|SOURCE_ACCEPT 18
  #|SOURCE_PAYLOADS 2
  #|SOURCE_PAYLOAD 0 5 21
  #|SOURCE_PAYLOAD 1 6 22
  #|REQUEST_TOGGLE 8
  #|REQUEST_STAGES 3
  #|REQUEST_STAGE 0 11
  #|REQUEST_STAGE 1 12
  #|REQUEST_STAGE 2 13
  #|REQUEST_CHANGED 24
  #|DESTINATION_READY 7
  #|DESTINATION_VALID 9
  #|DESTINATION_AVAILABLE 27
  #|DESTINATION_CAPTURE 28
  #|DESTINATION_CONSUME 25
  #|DESTINATION_PAYLOADS 2
  #|DESTINATION_PAYLOAD 0 32
  #|DESTINATION_PAYLOAD 1 33
  #|ACKNOWLEDGE_TOGGLE 10
  #|ACKNOWLEDGE_STAGES 3
  #|ACKNOWLEDGE_STAGE 0 14
  #|ACKNOWLEDGE_STAGE 1 15
  #|ACKNOWLEDGE_STAGE 2 16
  #|ENDPRIMITIVE
  #|ENDMODULE
  #|END
  #|

///|
test "toggle handshake constructs checked aggregate response buffer" {
  for stage_count in [2, 3, 4] {
    let hardware_module = checked_toggle_handshake_module(stage_count)
    assert_eq(hardware_module.cdc_primitives().length(), 1)
    guard hardware_module.cdc_primitives()[0] is ToggleHandshake(spec) else {
      fail("expected toggle handshake primitive")
    }
    assert_eq(spec.id().ordinal(), 0)
    assert_eq(spec.name(), "crossing🔥")
    assert_eq(spec.source_domain().ordinal(), 0)
    assert_eq(spec.destination_domain().ordinal(), 1)
    assert_eq(spec.request_stages().length(), stage_count)
    assert_eq(spec.acknowledge_stages().length(), stage_count)
    assert_eq(spec.source_payload().length(), 2)
    assert_eq(spec.held_payload().length(), 2)
    assert_eq(spec.destination_payload().length(), 2)
    assert_eq(spec.payload_shape().flatten().map(leaf => leaf.value()), [
      @wire.uint(8),
      @wire.bits(3),
    ])
    guard hardware_module.nodes()[spec.acknowledge_toggle().ordinal()].kind()
      is Register(acknowledge) else {
      fail("expected acknowledge state")
    }
    guard hardware_module.nodes()[acknowledge.next().ordinal()].kind()
      is Mux(select~, when_true~, when_false~) else {
      fail("expected acknowledge capture mux")
    }
    assert_eq(select, spec.destination_capture())
    assert_eq(
      when_true,
      spec.request_stages()[spec.request_stages().length() - 1],
    )
    assert_eq(when_false, spec.acknowledge_toggle())
  }
}

///|
test "toggle handshake schema four roundtrip is deterministic" {
  let first = @wire.single_design(
    "toggle-handshake",
    checked_toggle_handshake_module(3),
  )
  let second = @wire.single_design(
    "toggle-handshake",
    checked_toggle_handshake_module(3),
  )
  let encoded = @codec.serialize(first)
  assert_eq(encoded, TOGGLE_HANDSHAKE_GOLDEN)
  assert_eq(encoded, @codec.serialize(second))
  assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
  assert_true(
    encoded.contains("PRIMITIVE 0 toggle_handshake 63726f7373696e67f09f94a5\n"),
  )
  assert_true(encoded.contains("REQUEST_STAGES 3\n"))
  assert_true(encoded.contains("ACKNOWLEDGE_STAGES 3\n"))
  assert_true(encoded.contains("SOURCE_PAYLOAD 1 6 22\n"))
  assert_true(encoded.contains("DESTINATION_PAYLOAD 1 33\n"))
}

///|
test "toggle handshake rejects equal domains stages and non-idle reset" {
  let builder = @wire.ModuleBuilder::new("InvalidToggleHandshake")
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let nonzero_reset = builder.synchronous_reset(reset_signal, 1UL)
  let valid = builder.input("valid", @wire.bits(1))
  let payload_signal = builder.input("payload", @wire.uint(8))
  let ready = builder.input("ready", @wire.bits(1))
  let source = builder.ready_valid_forward(
    valid,
    @aggregate.Aggregate::leaf(payload_signal),
  )
  let destination = builder.ready_valid_backward(ready)
  try
    builder.toggle_handshake(
      "same", domain, domain, source, destination, reset, reset,
    )
  catch {
    @ir.IrError::EqualToggleHandshakeDomains(primitive~, domain~) => {
      assert_eq(primitive, 0)
      assert_eq(domain, 0)
    }
    error => fail("unexpected equal-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected equal-domain rejection")
  }
  let other_clock = builder.input("other_clock", @wire.clock())
  let other_domain = builder.rising_edge(other_clock)
  for count in [1, 5] {
    try
      builder.toggle_handshake(
        "count",
        domain,
        other_domain,
        source,
        destination,
        reset,
        reset,
        synchronizer_stages=count,
      )
    catch {
      @ir.IrError::InvalidToggleHandshakeStageCount(primitive~, actual~) => {
        assert_eq(primitive, 0)
        assert_eq(actual, count)
      }
      error => fail("unexpected stage-count error: \{Repr(error)}")
    } noraise {
      _ => fail("expected stage-count rejection")
    }
  }
  try
    builder.toggle_handshake(
      "reset", domain, other_domain, source, destination, nonzero_reset, reset,
    )
  catch {
    @ir.IrError::ToggleHandshakeResetMismatch(role~, ..) =>
      assert_eq(role, "source_reset")
    error => fail("unexpected reset error: \{Repr(error)}")
  } noraise {
    _ => fail("expected coordinated-idle reset rejection")
  }
}

///|
test "toggle handshake codec rejects reset stage structure and hidden payload fanout" {
  let encoded = @codec.serialize(
    @wire.single_design("toggle-handshake", checked_toggle_handshake_module(3)),
  )
  let active_low = encoded.replace(
    old="SOURCE_RESET synchronous active_high 2 0",
    new="SOURCE_RESET synchronous active_low 2 0",
  )
  try @codec.parse(active_low) catch {
    UnsupportedResetPolarity(polarity~, ..) => assert_eq(polarity, "active_low")
    error => fail("unexpected reset codec error: \{Repr(error)}")
  } noraise {
    _ => fail("expected active-low handshake reset rejection")
  }
  let bad_stage = encoded.replace(
    old="REQUEST_STAGE 2 13",
    new="REQUEST_STAGE 3 13",
  )
  try @codec.parse(bad_stage) catch {
    UnexpectedLine(expected~, ..) => assert_eq(expected, "REQUEST_STAGE 2 node")
    error => fail("unexpected stage codec error: \{Repr(error)}")
  } noraise {
    _ => fail("expected stage ordinal rejection")
  }
  let acknowledge_on_consume = encoded.replace(
    old="NODE 34 bits:1 mux 28 13 10",
    new="NODE 34 bits:1 mux 25 13 10",
  )
  try @codec.parse(acknowledge_on_consume) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("acknowledge_toggle_next"))
    error => fail("unexpected acknowledge structure error: \{Repr(error)}")
  } noraise {
    _ => fail("expected acknowledge-on-consume rejection")
  }
  let hidden_payload = encoded.replace(
    old="OUTPUT 64657374696e6174696f6e5f746167 bits:3 33",
    new="OUTPUT 64657374696e6174696f6e5f746167 bits:3 22",
  )
  try @codec.parse(hidden_payload) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("ToggleHandshakeHiddenFanout"))
    error => fail("unexpected hidden payload error: \{Repr(error)}")
  } noraise {
    _ => fail("expected hidden payload fanout rejection")
  }
}

///|
test "toggle handshake codec rejects missing duplicate and unbounded records" {
  let missing = TOGGLE_HANDSHAKE_GOLDEN.replace(old="SOURCE_VALID 4\n", new="")
  try @codec.parse(missing) catch {
    UnexpectedLine(expected~, actual~, ..) => {
      assert_eq(expected, "SOURCE_VALID")
      assert_eq(actual, "SOURCE_READY 17")
    }
    error => fail("unexpected missing-record error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing-record rejection")
  }
  let duplicate = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="SOURCE_VALID 4\n",
    new="SOURCE_VALID 4\nSOURCE_VALID 4\n",
  )
  try @codec.parse(duplicate) catch {
    UnexpectedLine(expected~, actual~, ..) => {
      assert_eq(expected, "SOURCE_READY")
      assert_eq(actual, "SOURCE_VALID 4")
    }
    error => fail("unexpected duplicate-record error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate-record rejection")
  }
  let source_count = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="SOURCE_PAYLOADS 2",
    new="SOURCE_PAYLOADS 1",
  )
  try @codec.parse(source_count) catch {
    UnexpectedLine(expected~, ..) => assert_eq(expected, "SOURCE_PAYLOADS 2")
    error => fail("unexpected source-count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected source-count preflight rejection")
  }
  let destination_count = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="DESTINATION_PAYLOADS 2",
    new="DESTINATION_PAYLOADS 2147483647",
  )
  try @codec.parse(destination_count) catch {
    UnexpectedLine(expected~, ..) =>
      assert_eq(expected, "DESTINATION_PAYLOADS 2")
    error => fail("unexpected destination-count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected destination-count preflight rejection")
  }
  let request_count = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="REQUEST_STAGES 3",
    new="REQUEST_STAGES 1",
  )
  try @codec.parse(request_count) catch {
    InvalidCount(field~, value~, ..) => {
      assert_eq(field, "handshake request stage")
      assert_eq(value, 1)
    }
    error => fail("unexpected request-count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected request-count preflight rejection")
  }
  let acknowledge_count = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="ACKNOWLEDGE_STAGES 3",
    new="ACKNOWLEDGE_STAGES 4",
  )
  try @codec.parse(acknowledge_count) catch {
    UnexpectedLine(expected~, ..) => assert_eq(expected, "ACKNOWLEDGE_STAGES 3")
    error => fail("unexpected acknowledge-count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected acknowledge-count preflight rejection")
  }
}

///|
test "toggle handshake checker rejects missing domains types resets and bypasses" {
  let unknown_domain = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="DESTINATION_DOMAIN 1",
    new="DESTINATION_DOMAIN 99",
  )
  try @codec.parse(unknown_domain) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("UnknownToggleHandshakeDomain"))
    error => fail("unexpected missing-domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected missing-domain rejection")
  }
  let wrong_type = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="SOURCE_VALID 4",
    new="SOURCE_VALID 5",
  )
  try @codec.parse(wrong_type) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("ToggleHandshakeNodeTypeMismatch"))
    error => fail("unexpected control-type error: \{Repr(error)}")
  } noraise {
    _ => fail("expected control-type rejection")
  }
  let wrong_reset = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="SOURCE_RESET synchronous active_high 2 0",
    new="SOURCE_RESET synchronous active_high 2 1",
  )
  try @codec.parse(wrong_reset) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("ToggleHandshakeResetMismatch"))
    error => fail("unexpected reset-structure error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reset-structure rejection")
  }
  let request_bypass = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="NODE 11 bits:1 reg 1 8 3 0 synchronous active_high - -",
    new="NODE 11 bits:1 reg 1 4 3 0 synchronous active_high - -",
  )
  try @codec.parse(request_bypass) catch {
    IrRejected(reason~) => assert_true(reason.contains("request_stage_0"))
    error => fail("unexpected request-bypass error: \{Repr(error)}")
  } noraise {
    _ => fail("expected request-bypass rejection")
  }
  let acknowledge_bypass = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="NODE 14 bits:1 reg 0 10 2 0 synchronous active_high - -",
    new="NODE 14 bits:1 reg 0 8 2 0 synchronous active_high - -",
  )
  try @codec.parse(acknowledge_bypass) catch {
    IrRejected(reason~) => assert_true(reason.contains("acknowledge_stage_0"))
    error => fail("unexpected acknowledge-bypass error: \{Repr(error)}")
  } noraise {
    _ => fail("expected acknowledge-bypass rejection")
  }
}

///|
test "toggle handshake checker rejects payload mismatch and output bypass" {
  let payload_mismatch = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="SOURCE_PAYLOAD 1 6 22",
    new="SOURCE_PAYLOAD 1 5 22",
  )
  try @codec.parse(payload_mismatch) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("ToggleHandshakeNodeTypeMismatch"))
    error => fail("unexpected payload-mismatch error: \{Repr(error)}")
  } noraise {
    _ => fail("expected payload-mismatch rejection")
  }
  let output_bypass = TOGGLE_HANDSHAKE_GOLDEN.replace(
    old="OUTPUT 736f757263655f7265616479 bits:1 17",
    new="OUTPUT 736f757263655f7265616479 bits:1 8",
  )
  try @codec.parse(output_bypass) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("ToggleHandshakeHiddenFanout"))
    error => fail("unexpected output-bypass error: \{Repr(error)}")
  } noraise {
    _ => fail("expected output-bypass rejection")
  }
}

///|
test "toggle handshake CDC admission rejects mistimed controls and payload" {
  let encoded = @codec.serialize(
    @wire.single_design("toggle-handshake", checked_toggle_handshake_module(2)),
  )
  let cases = [
    (
      encoded.replace(
        old="INPUT_TIMING 4 sampled_in 0",
        new="INPUT_TIMING 4 sampled_in 1",
      ),
      0,
    ),
    (
      encoded.replace(
        old="INPUT_TIMING 5 sampled_in 0",
        new="INPUT_TIMING 5 sampled_in 1",
      ),
      1,
    ),
    (
      encoded.replace(
        old="INPUT_TIMING 7 sampled_in 1",
        new="INPUT_TIMING 7 sampled_in 0",
      ),
      2,
    ),
  ]
  for item in cases {
    let hardware_module = @codec.parse(item.0).top_module().unwrap()
    try @cdc.validate_module(hardware_module) catch {
      UnsafeDependency(sink~, ..) =>
        match item.1 {
          0 => {
            guard sink is ToggleSourceValid(primitive) else {
              fail("expected source-valid sink")
            }
            assert_eq(primitive.ordinal(), 0)
          }
          1 => {
            guard sink is ToggleSourcePayload(primitive~, leaf~) else {
              fail("expected source-payload sink")
            }
            assert_eq(primitive.ordinal(), 0)
            assert_eq(leaf, 0)
          }
          _ => {
            guard sink is ToggleDestinationReady(primitive) else {
              fail("expected destination-ready sink")
            }
            assert_eq(primitive.ordinal(), 0)
          }
        }
      error => fail("unexpected handshake CDC error: \{Repr(error)}")
    } noraise {
      _ => fail("expected mistimed handshake endpoint rejection")
    }
  }
}
