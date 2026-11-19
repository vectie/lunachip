///|
fn emitted_fifo_design() -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("UnsupportedFifo")
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
  let valid = builder.input("valid", @wire.bits(1))
  let data = builder.input("data", @wire.uint(8))
  let ready = builder.input("ready", @wire.bits(1))
  let fifo = builder.asynchronous_fifo(
    "fifo",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(data)),
    builder.ready_valid_backward(ready),
    source_reset,
    destination_reset,
    4,
  )
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  let destination_data = builder.output("destination_data", @wire.uint(8))
  builder.connect(source_ready, fifo.source().ready())
  builder.connect(destination_valid, fifo.destination().valid())
  builder.connect(
    destination_data,
    fifo.destination().payload().flatten()[0].value(),
  )
  for input in [source_reset_signal, valid, data] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  builder.output_timing(destination_valid, ProducedIn(destination_domain.id()))
  builder.output_timing(destination_data, ProducedIn(destination_domain.id()))
  @wire.single_design("unsupported-fifo", builder.finish())
}

///|
fn emitted_sparse_aggregate_fifo_design() -> @ir.Design raise {
  let builder = @wire.ModuleBuilder::new("AggregateFifo")
  let source_clock = builder.input("source_clock", @wire.clock())
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset_signal = builder.input("source_reset", @wire.reset())
  let destination_reset_signal = builder.input(
    "destination_reset",
    @wire.reset(),
  )
  let valid = builder.input("valid", @wire.bits(1))
  let word = builder.input("word", @wire.uint(8))
  let tag = builder.input("tag", @wire.bits(3))
  let ready = builder.input("ready", @wire.bits(1))
  let source_reset = builder.synchronous_reset(source_reset_signal, 0UL)
  let destination_reset = builder.synchronous_reset(
    destination_reset_signal, 0UL,
  )
  let synchronized = builder.bit_synchronizer(
    "prefix",
    valid,
    destination_domain,
    2,
    source_domain~,
    reset=destination_reset,
  )
  let fifo = builder.asynchronous_fifo(
    "queue🔥",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(
      valid,
      @aggregate.Aggregate::record([
        ("word", @aggregate.Aggregate::leaf(word)),
        ("tag", @aggregate.Aggregate::leaf(tag)),
      ]),
    ),
    builder.ready_valid_backward(ready),
    source_reset,
    destination_reset,
    8,
    synchronizer_stages=3,
  )
  let sync_output = builder.output("sync", @wire.bits(1))
  let source_ready = builder.output("source_ready", @wire.bits(1))
  let destination_valid = builder.output("destination_valid", @wire.bits(1))
  let destination_word = builder.output("destination_word", @wire.uint(8))
  let destination_tag = builder.output("destination_tag", @wire.bits(3))
  builder.connect(sync_output, synchronized)
  builder.connect(source_ready, fifo.source().ready())
  builder.connect(destination_valid, fifo.destination().valid())
  let leaves = fifo.destination().payload().flatten()
  builder.connect(destination_word, leaves[0].value())
  builder.connect(destination_tag, leaves[1].value())
  for input in [source_reset_signal, valid, word, tag] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset_signal, ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(sync_output, ProducedIn(destination_domain.id()))
  builder.output_timing(source_ready, ProducedIn(source_domain.id()))
  builder.output_timing(destination_valid, ProducedIn(destination_domain.id()))
  builder.output_timing(destination_word, ProducedIn(destination_domain.id()))
  builder.output_timing(destination_tag, ProducedIn(destination_domain.id()))
  @wire.single_design("aggregate-fifo", builder.finish())
}

///|
test "valid asynchronous FIFO emits one private lane and guarded write process" {
  let emitted = @systemverilog.emit_design(emitted_fifo_design())
  let source = emitted.modules()[0].source()
  assert_true(source.contains("logic [7:0] lc_f0_l0 [0:3];"))
  assert_true(source.contains("assign lc_n38 = lc_f0_l0[lc_n37];"))
  assert_true(source.contains("always_ff @(posedge lc_n0) begin"))
  assert_true(
    source.contains("if ((lc_n14 === 1'b1) && (lc_fk0(lc_n35) === 1'b1)) begin"),
  )
  assert_true(source.contains("lc_f0_l0[lc_n35] <= lc_n5;"))
  assert_eq(source.split("lc_f0_l0[lc_n35] <=").count(), 2)
  assert_true(
    emitted
    .manifest()
    .to_canonical_text()
    .contains("MAP async-fifo-lane 0 38 66_69_66_6f lc_f0_l0"),
  )
}

///|
test "CDC-tampered asynchronous FIFO is rejected before emission" {
  let encoded = @codec.serialize(emitted_fifo_design())
  let tampered = @codec.parse(
    encoded.replace(
      old="INPUT_TIMING 4 sampled_in 0",
      new="INPUT_TIMING 4 sampled_in 1",
    ),
  )
  try @systemverilog.emit_design(tampered) catch {
    CdcRejected(UnsafeDependency(sink=FifoSourceValid(primitive), ..)) =>
      assert_eq(primitive.ordinal(), 0)
    error => fail("unexpected tampered FIFO emission error: \{Repr(error)}")
  } noraise {
    _ => fail("expected tampered FIFO CDC rejection")
  }
}

///|
test "sparse aggregate FIFO emits deterministic lanes in one write process" {
  let emitted = @systemverilog.emit_design(
    emitted_sparse_aggregate_fifo_design(),
  )
  let source = emitted.modules()[0].source()
  assert_true(source.contains("backend v3"))
  assert_true(source.contains("logic [7:0] lc_f1_l0 [0:7];"))
  assert_true(source.contains("logic [2:0] lc_f1_l1 [0:7];"))
  assert_eq(source.split("lc_f1_l0[").count(), 3)
  assert_eq(source.split("lc_f1_l1[").count(), 3)
  let lane_mappings = emitted
    .manifest()
    .mappings()
    .iter()
    .filter(mapping => mapping.kind() is AsyncFifoLane)
    .to_array()
  assert_eq(lane_mappings.length(), 2)
  assert_eq(lane_mappings[0].identifier(), "lc_f1_l0")
  assert_eq(lane_mappings[1].identifier(), "lc_f1_l1")
  assert_eq(lane_mappings[0].source_name(), "queue🔥")
  assert_true(
    emitted
    .manifest()
    .to_canonical_text()
    .has_prefix("LUNACHIP-SYSTEMVERILOG-NAMES 3\n"),
  )
}

///|
test "FIFO backend versioning does not perturb legacy memory-free artifacts" {
  let fifo = @systemverilog.emit_design(emitted_fifo_design())
  assert_true(fifo.source().contains("backend v3"))
  assert_true(
    fifo
    .source()
    .contains("// FIFO lane cells intentionally have no initializer."),
  )
  assert_false(fifo.source().contains("// Memory cells and read results"))
}
