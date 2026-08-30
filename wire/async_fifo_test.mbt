///|
fn checked_async_fifo_module(stages : Int, depth : Int) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new("CheckedAsyncFifo")
  let source_clock = builder.input("source_clock", @wire.clock())
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
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
    ("tag", @aggregate.Aggregate::leaf(source_tag)),
  ])
  let fifo = builder.asynchronous_fifo(
    "queue🔥",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(source_valid, payload),
    builder.ready_valid_backward(destination_ready),
    source_reset,
    destination_reset,
    depth,
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
  builder.connect(source_ready_output, fifo.source().ready())
  builder.connect(destination_valid_output, fifo.destination().valid())
  let leaves = fifo.destination().payload().flatten()
  builder.connect(destination_word_output, leaves[0].value())
  builder.connect(destination_tag_output, leaves[1].value())
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
test "asynchronous FIFO constructs checked aggregate endpoints" {
  for stages in [2, 3, 4] {
    let hardware_module = checked_async_fifo_module(stages, 8)
    assert_eq(hardware_module.cdc_primitives().length(), 1)
    guard hardware_module.cdc_primitives()[0] is AsyncFifo(spec) else {
      fail("expected asynchronous FIFO primitive")
    }
    assert_eq(spec.name(), "queue🔥")
    assert_eq(spec.depth(), 8)
    assert_eq(spec.pointer_width(), 4)
    assert_eq(spec.synchronizer_stages(), stages)
    assert_eq(spec.read_gray_stages().length(), stages)
    assert_eq(spec.write_gray_stages().length(), stages)
    assert_eq(spec.source_payload().length(), 2)
    assert_eq(spec.raw_reads().length(), 2)
    assert_eq(spec.destination_payload().length(), 2)
    assert_eq(spec.destination_valid(), spec.nonempty())
    let analysis = @cdc.analyze_module(hardware_module)
    for index, raw in spec.raw_reads() {
      guard hardware_module.node(raw) is Some(node) &&
        node.kind() is AsyncFifoRead(primitive~, leaf~) else {
        fail("expected private FIFO read")
      }
      assert_eq(primitive, spec.id())
      assert_eq(leaf, index)
      let raw_analysis = analysis.node(raw).unwrap()
      assert_eq(raw_analysis.provenance().domains().length(), 1)
      assert_eq(
        raw_analysis.provenance().domains()[0],
        spec.destination_domain(),
      )
      guard raw_analysis.domain_witnesses()[0].witness().origin()
        is AsyncFifoReadState(primitive=origin_primitive, leaf=origin_leaf, ..) else {
        fail("expected private FIFO read provenance")
      }
      assert_eq(origin_primitive, spec.id())
      assert_eq(origin_leaf, index)
      let visible = hardware_module
        .node(spec.destination_payload()[index])
        .unwrap()
      guard visible.kind() is Mux(select~, when_true~, when_false~) else {
        fail("expected visible FIFO payload mask")
      }
      assert_eq(select, spec.nonempty())
      assert_eq(when_true, raw)
      guard hardware_module.node(when_false).unwrap().kind() is Constant(0UL) else {
        fail("expected exact invalid-payload zero")
      }
    }
  }
}

///|
test "asynchronous FIFO schema four round trips exact private storage grammar" {
  let hardware_module = checked_async_fifo_module(3, 8)
  let encoded = @codec.serialize(
    @wire.single_design("async-fifo", hardware_module),
  )
  assert_true(encoded.contains("NODE "))
  assert_true(encoded.contains(" async_fifo_read 0 0\n"))
  assert_true(encoded.contains(" async_fifo_read 0 1\n"))
  assert_true(encoded.contains("PRIMITIVE 0 async_fifo 7175657565f09f94a5\n"))
  assert_true(
    encoded.contains("DEPTH 8\nPOINTER_WIDTH 4\nSYNCHRONIZER_STAGES 3\n"),
  )
  assert_true(encoded.contains("RESET_POLICY coordinated_idle\n"))
  assert_true(encoded.contains("READ_GRAY_STAGES 3\n"))
  assert_true(encoded.contains("WRITE_GRAY_STAGES 3\n"))
  inspect(
    encoded,
    content=(
      #|LUNACHIP-IR 4
      #|DESIGN 6173796e632d6669666f
      #|TOP 436865636b65644173796e634669666f
      #|MODULES 1
      #|MODULE 436865636b65644173796e634669666f
      #|DOMAINS 2
      #|DOMAIN 0 0 rising
      #|DOMAIN 1 1 rising
      #|PARAMETERS 0
      #|NODES 47
      #|NODE 0 clock input 736f757263655f636c6f636b
      #|NODE 1 clock input 64657374696e6174696f6e5f636c6f636b
      #|NODE 2 reset input 736f757263655f7265736574
      #|NODE 3 reset input 64657374696e6174696f6e5f7265736574
      #|NODE 4 bits:1 input 736f757263655f76616c6964
      #|NODE 5 uint:8 input 736f757263655f776f7264
      #|NODE 6 bits:3 input 736f757263655f746167
      #|NODE 7 bits:1 input 64657374696e6174696f6e5f7265616479
      #|NODE 8 uint:4 reg 0 19 2 0 synchronous active_high - -
      #|NODE 9 uint:4 reg 0 21 2 0 synchronous active_high - -
      #|NODE 10 bits:1 reg 0 34 2 0 synchronous active_high - -
      #|NODE 11 uint:4 reg 1 23 3 0 synchronous active_high - -
      #|NODE 12 uint:4 reg 1 25 3 0 synchronous active_high - -
      #|NODE 13 bits:1 reg 1 36 3 0 synchronous active_high - -
      #|NODE 14 bits:1 not 10
      #|NODE 15 bits:1 and 4 14
      #|NODE 16 bits:1 and 13 7
      #|NODE 17 uint:4 const 1
      #|NODE 18 uint:4 add 8 17
      #|NODE 19 uint:4 mux 15 18 8
      #|NODE 20 uint:4 lshr 19 17
      #|NODE 21 uint:4 xor 19 20
      #|NODE 22 uint:4 add 11 17
      #|NODE 23 uint:4 mux 16 22 11
      #|NODE 24 uint:4 lshr 23 17
      #|NODE 25 uint:4 xor 23 24
      #|NODE 26 uint:4 reg 0 12 2 0 synchronous active_high - -
      #|NODE 27 uint:4 reg 0 26 2 0 synchronous active_high - -
      #|NODE 28 uint:4 reg 0 27 2 0 synchronous active_high - -
      #|NODE 29 uint:4 reg 1 9 3 0 synchronous active_high - -
      #|NODE 30 uint:4 reg 1 29 3 0 synchronous active_high - -
      #|NODE 31 uint:4 reg 1 30 3 0 synchronous active_high - -
      #|NODE 32 uint:4 const 12
      #|NODE 33 uint:4 xor 28 32
      #|NODE 34 bits:1 eq 21 33
      #|NODE 35 bits:1 eq 25 31
      #|NODE 36 bits:1 not 35
      #|NODE 37 bits:3 slice 8 2 0
      #|NODE 38 uint:3 reinterpret 37
      #|NODE 39 bits:3 slice 11 2 0
      #|NODE 40 uint:3 reinterpret 39
      #|NODE 41 uint:8 async_fifo_read 0 0
      #|NODE 42 uint:8 const 0
      #|NODE 43 uint:8 mux 13 41 42
      #|NODE 44 bits:3 async_fifo_read 0 1
      #|NODE 45 bits:3 const 0
      #|NODE 46 bits:3 mux 13 44 45
      #|MEMORIES 0
      #|OUTPUTS 4
      #|OUTPUT 64657374696e6174696f6e5f746167 bits:3 46
      #|OUTPUT 64657374696e6174696f6e5f76616c6964 bits:1 13
      #|OUTPUT 64657374696e6174696f6e5f776f7264 uint:8 43
      #|OUTPUT 736f757263655f7265616479 bits:1 14
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
      #|PRIMITIVE 0 async_fifo 7175657565f09f94a5
      #|SOURCE_DOMAIN 0
      #|DESTINATION_DOMAIN 1
      #|DEPTH 8
      #|POINTER_WIDTH 4
      #|SYNCHRONIZER_STAGES 3
      #|RESET_POLICY coordinated_idle
      #|SOURCE_RESET synchronous active_high 2 0
      #|DESTINATION_RESET synchronous active_high 3 0
      #|SHAPE record 2
      #|FIELD 776f7264
      #|SHAPE leaf uint:8
      #|FIELD 746167
      #|SHAPE leaf bits:3
      #|SOURCE_VALID 4
      #|SOURCE_READY 14
      #|SOURCE_TRANSFER 15
      #|SOURCE_PAYLOADS 2
      #|SOURCE_PAYLOAD 0 5
      #|SOURCE_PAYLOAD 1 6
      #|DESTINATION_READY 7
      #|DESTINATION_VALID 13
      #|DESTINATION_TRANSFER 16
      #|DESTINATION_PAYLOADS 2
      #|DESTINATION_PAYLOAD 0 41 43
      #|DESTINATION_PAYLOAD 1 44 46
      #|WRITE_BINARY 8
      #|WRITE_BINARY_NEXT 19
      #|READ_BINARY 11
      #|READ_BINARY_NEXT 23
      #|WRITE_GRAY 9
      #|WRITE_GRAY_NEXT 21
      #|READ_GRAY 12
      #|READ_GRAY_NEXT 25
      #|READ_GRAY_STAGES 3
      #|READ_GRAY_STAGE 0 26
      #|READ_GRAY_STAGE 1 27
      #|READ_GRAY_STAGE 2 28
      #|WRITE_GRAY_STAGES 3
      #|WRITE_GRAY_STAGE 0 29
      #|WRITE_GRAY_STAGE 1 30
      #|WRITE_GRAY_STAGE 2 31
      #|FULL 10
      #|FULL_NEXT 34
      #|NONEMPTY 13
      #|NONEMPTY_NEXT 36
      #|WRITE_ADDRESS 38
      #|READ_ADDRESS 40
      #|ENDPRIMITIVE
      #|ENDMODULE
      #|END
      #|
    ),
  )
  let decoded = @codec.parse(encoded)
  assert_eq(@codec.serialize(decoded), encoded)
}

///|
test "asynchronous FIFO rejects unsupported shape and clock contracts early" {
  let builder = @wire.ModuleBuilder::new("InvalidAsyncFifo")
  let clock_a = builder.input("clock_a", @wire.clock())
  let clock_b = builder.input("clock_b", @wire.clock())
  let domain_a = builder.rising_edge(clock_a)
  let domain_b = builder.rising_edge(clock_b)
  let reset_a = builder.synchronous_reset(
    builder.input("reset_a", @wire.reset()),
    0UL,
  )
  let reset_b = builder.synchronous_reset(
    builder.input("reset_b", @wire.reset()),
    0UL,
  )
  let forward = builder.ready_valid_forward(
    builder.input("valid", @wire.bits(1)),
    @aggregate.Aggregate::leaf(builder.input("data", @wire.uint(8))),
  )
  let backward = builder.ready_valid_backward(
    builder.input("ready", @wire.bits(1)),
  )
  try
    builder.asynchronous_fifo(
      "bad_depth", domain_a, domain_b, forward, backward, reset_a, reset_b, 6,
    )
  catch {
    @ir.IrError::InvalidAsyncFifoDepth(actual~, ..) => assert_eq(actual, 6)
    error => fail("unexpected depth error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid FIFO depth")
  }
  try
    builder.asynchronous_fifo(
      "bad_stage",
      domain_a,
      domain_b,
      forward,
      backward,
      reset_a,
      reset_b,
      4,
      synchronizer_stages=5,
    )
  catch {
    @ir.IrError::InvalidAsyncFifoStageCount(actual~, ..) => assert_eq(actual, 5)
    error => fail("unexpected stage error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid FIFO stage count")
  }
  try
    builder.asynchronous_fifo(
      "same_domain", domain_a, domain_a, forward, backward, reset_a, reset_a, 4,
    )
  catch {
    @ir.IrError::EqualAsyncFifoDomains(domain~, ..) =>
      assert_eq(domain, domain_a.id().ordinal())
    error => fail("unexpected domain error: \{Repr(error)}")
  } noraise {
    _ => fail("expected equal FIFO domain rejection")
  }
}

///|
test "asynchronous FIFO codec rejects policy stages and private-read owner" {
  let hardware_module = checked_async_fifo_module(2, 4)
  let encoded = @codec.serialize(
    @wire.single_design("async-fifo", hardware_module),
  )
  for
    malformed in [
      encoded.replace(
        old="RESET_POLICY coordinated_idle",
        new="RESET_POLICY independent",
      ),
      encoded.replace(old="READ_GRAY_STAGES 2", new="READ_GRAY_STAGES 5"),
      encoded.replace(old=" async_fifo_read 0 0", new=" async_fifo_read 9 0"),
      encoded.replace(
        old="NODE 40 uint:8 const 0",
        new="NODE 40 uint:8 async_fifo_read 0 0",
      ),
      encoded.replace(
        old="OUTPUT 64657374696e6174696f6e5f776f7264 uint:8 41",
        new="OUTPUT 64657374696e6174696f6e5f776f7264 uint:8 39",
      ),
      encoded.replace(
        old="OUTPUT 736f757263655f7265616479 bits:1 14",
        new="OUTPUT 736f757263655f7265616479 bits:1 33",
      ),
    ] {
    try @codec.parse(malformed) catch {
      _ => ()
    } noraise {
      _ => fail("expected malformed FIFO rejection")
    }
  }
}
