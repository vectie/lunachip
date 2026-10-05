///|
fn partial_id(ordinal : Int) -> @ir.NodeId raise @ir.IrError {
  @ir.NodeId::new(ordinal)
}

///|
fn partial_u(width : Int) -> @ir.SignalType raise @ir.IrError {
  UInt(@ir.Width::new(width))
}

///|
fn partial_slice_module(
  lower : Int,
  upper : Int,
  full_output : Bool,
) -> @ir.Module raise {
  let source = partial_id(0)
  let selected = partial_id(1)
  let selected_type : @ir.SignalType = Bits(@ir.Width::new(upper - lower + 1))
  let outputs = [@ir.OutputPort::new("selected", selected_type, selected)]
  if full_output {
    outputs.push(@ir.OutputPort::new("full", partial_u(8), source))
  }
  @ir.Module::checked(
    "PartialSlice",
    [
      @ir.Node::new(source, partial_u(8), Input("source")),
      @ir.Node::new(
        selected,
        selected_type,
        Slice(value=source, msb=upper, lsb=lower),
      ),
    ],
    outputs,
  )
}

///|
test "explicit low high and interior slices retain their interval" {
  for (lower, upper) in [(0, 3), (4, 7), (2, 5)] {
    let hardware_module = partial_slice_module(lower, upper, false)
    let ranges = module_partial_use_ranges(hardware_module)
    assert_eq(ranges[0], Some((lower, upper)))
    assert_eq(ranges[1], None)
    let declaration = partial_use_declaration(
      hardware_module.nodes()[0],
      ranges[0],
    )
    assert_true(declaration.contains("lc_n0[\{upper}:\{lower}] only."))
    assert_true(declaration.contains("/* verilator lint_off UNUSEDSIGNAL */"))
    assert_true(declaration.contains("/* verilator lint_on UNUSEDSIGNAL */"))
    assert_true(declaration.contains("  logic [7:0] lc_n0;\n"))
  }
}

///|
test "truncate covers the widths reported by the real fetched fixture" {
  for (source_width, result_width) in [(64, 32), (13, 4), (13, 1), (8, 1)] {
    let source = partial_id(0)
    let truncated = partial_id(1)
    let hardware_module = @ir.Module::checked(
      "PartialTruncate",
      [
        @ir.Node::new(source, partial_u(source_width), Input("source")),
        @ir.Node::new(truncated, partial_u(result_width), Truncate(source)),
      ],
      [@ir.OutputPort::new("result", partial_u(result_width), truncated)],
    )
    assert_eq(
      module_partial_use_ranges(hardware_module)[0],
      Some((0, result_width - 1)),
    )
  }
}

///|
test "interval hull never annotates a union spanning both endpoints" {
  let source = partial_id(0)
  let low = partial_id(1)
  let high = partial_id(2)
  let pair_type : @ir.SignalType = Bits(@ir.Width::new(2))
  let hardware_module = @ir.Module::checked(
    "PartialHull",
    [
      @ir.Node::new(source, partial_u(8), Input("source")),
      @ir.Node::new(low, pair_type, Slice(value=source, msb=1, lsb=0)),
      @ir.Node::new(high, pair_type, Slice(value=source, msb=7, lsb=6)),
    ],
    [
      @ir.OutputPort::new("low", pair_type, low),
      @ir.OutputPort::new("high", pair_type, high),
    ],
  )
  assert_eq(module_partial_use_ranges(hardware_module)[0], None)
}

///|
test "multiple selection consumers combine into one conservative hull" {
  let source = partial_id(0)
  let lower = partial_id(1)
  let upper = partial_id(2)
  let pair_type : @ir.SignalType = Bits(@ir.Width::new(2))
  let hardware_module = @ir.Module::checked(
    "PartialInteriorHull",
    [
      @ir.Node::new(source, partial_u(8), Input("source")),
      @ir.Node::new(lower, pair_type, Slice(value=source, msb=3, lsb=2)),
      @ir.Node::new(upper, pair_type, Slice(value=source, msb=5, lsb=4)),
    ],
    [
      @ir.OutputPort::new("lower", pair_type, lower),
      @ir.OutputPort::new("upper", pair_type, upper),
    ],
  )
  assert_eq(module_partial_use_ranges(hardware_module)[0], Some((2, 5)))
}

///|
test "output and nonselection consumers preserve full width lint" {
  assert_eq(
    module_partial_use_ranges(partial_slice_module(0, 3, true))[0],
    None,
  )
  let source = partial_id(0)
  let low = partial_id(1)
  let full = partial_id(2)
  let hardware_module = @ir.Module::checked(
    "PartialAndFull",
    [
      @ir.Node::new(source, partial_u(8), Input("source")),
      @ir.Node::new(low, partial_u(4), Truncate(source)),
      @ir.Node::new(full, partial_u(8), BitNot(source)),
    ],
    [
      @ir.OutputPort::new("low", partial_u(4), low),
      @ir.OutputPort::new("full", partial_u(8), full),
    ],
  )
  assert_eq(module_partial_use_ranges(hardware_module)[0], None)
  assert_eq(
    partial_use_declaration(hardware_module.nodes()[0], None),
    "  logic [7:0] lc_n0;\n",
  )
}

///|
test "implicit enabled register hold is a full width consumer" {
  let clock = partial_id(0)
  let enable = partial_id(1)
  let next = partial_id(2)
  let state = partial_id(3)
  let low = partial_id(4)
  let hardware_module = @ir.Module::checked(
    "PartialRegisterHold",
    [
      @ir.Node::new(clock, Clock, Input("clock")),
      @ir.Node::new(enable, Bits(@ir.Width::new(1)), Input("enable")),
      @ir.Node::new(next, partial_u(8), Input("next")),
      @ir.Node::new(
        state,
        partial_u(8),
        Register(
          @ir.RegisterSpec::new(@ir.ClockDomain::rising(clock), next, enable~),
        ),
      ),
      @ir.Node::new(low, partial_u(4), Truncate(state)),
    ],
    [@ir.OutputPort::new("low", partial_u(4), low)],
  )
  assert_eq(module_partial_use_ranges(hardware_module)[3], None)
}

///|
test "memory write roots and implicit read result holds stay full" {
  let builder = @wire.ModuleBuilder::new("PartialMemory")
  let clock = builder.input("clock", @wire.clock())
  let address = builder.input("address", @wire.uint(2))
  let data = builder.input("data", @wire.uint(8))
  let mask = builder.input("mask", @wire.bits(4))
  let domain = builder.rising_edge(clock)
  let memory = builder.synchronous_memory(
    "memory",
    @wire.uint(8),
    4,
    domain,
    read_write_policy=NoChange,
  )
  builder.memory_write_masked(memory, "write", address, data, mask, 2)
  let read = builder.memory_read(memory, "read", address)
  let low_data = builder.truncate(data, 4)
  let low_read = builder.truncate(read, 4)
  let low_mask = builder.slice(mask, 1, 0)
  let low_address = builder.truncate(address, 1)
  for
    (name, signal) in [
      ("data", low_data),
      ("read", low_read),
      ("mask", low_mask),
      ("address", low_address),
    ] {
    let output = builder.output(name, signal.signal_type())
    builder.connect(output, signal)
  }
  let ranges = module_partial_use_ranges(builder.finish())
  assert_eq(ranges[data.id().ordinal()], None)
  assert_eq(ranges[read.id().ordinal()], None)
  assert_eq(ranges[mask.id().ordinal()], None)
  assert_eq(ranges[address.id().ordinal()], None)
}

///|
test "asynchronous FIFO payload and private reads stay full" {
  let builder = @wire.ModuleBuilder::new("PartialFifo")
  let source_clock = builder.input("source_clock", @wire.clock())
  let destination_clock = builder.input("destination_clock", @wire.clock())
  let source_domain = builder.rising_edge(source_clock)
  let destination_domain = builder.rising_edge(destination_clock)
  let source_reset = builder.input("source_reset", @wire.reset())
  let destination_reset = builder.input("destination_reset", @wire.reset())
  let valid = builder.input("valid", @wire.bits(1))
  let data = builder.input("data", @wire.uint(8))
  let ready = builder.input("ready", @wire.bits(1))
  let fifo = builder.asynchronous_fifo(
    "fifo",
    source_domain,
    destination_domain,
    builder.ready_valid_forward(valid, @aggregate.Aggregate::leaf(data)),
    builder.ready_valid_backward(ready),
    builder.synchronous_reset(source_reset, 0UL),
    builder.synchronous_reset(destination_reset, 0UL),
    4,
  )
  let low = builder.truncate(data, 4)
  let output = builder.output("low", @wire.uint(4))
  builder.connect(output, low)
  let read = fifo.destination().payload().flatten()[0].value()
  let low_read = builder.truncate(read, 4)
  let read_output = builder.output("read", @wire.uint(4))
  builder.connect(read_output, low_read)
  for input in [source_reset, valid, data] {
    builder.input_timing(input, SampledIn(source_domain.id()))
  }
  for input in [destination_reset, ready] {
    builder.input_timing(input, SampledIn(destination_domain.id()))
  }
  builder.output_timing(output, ProducedIn(source_domain.id()))
  builder.output_timing(read_output, ProducedIn(destination_domain.id()))
  let hardware_module = builder.finish()
  let ranges = module_partial_use_ranges(hardware_module)
  assert_eq(ranges[data.id().ordinal()], None)
  let mut private_reads = 0
  for node in hardware_module.nodes() {
    if node.kind() is AsyncFifoRead(..) {
      private_reads += 1
      assert_eq(ranges[node.id().ordinal()], None)
    }
  }
  assert_eq(private_reads, 1)
  // The public payload view is a combinational masking mux, not SRAM state.
  assert_eq(ranges[read.id().ordinal()], Some((0, 3)))
}

///|
test "partial annotation does not allow an unused node" {
  let hardware_module = @ir.Module::checked(
    "PartialDead",
    [@ir.Node::new(partial_id(0), partial_u(8), Constant(0UL))],
    [],
  )
  assert_eq(module_partial_use_ranges(hardware_module)[0], None)
  try emit_design(@ir.Design::single("PartialDead", hardware_module)) catch {
    UnreachableNode(node=0, ..) => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("dead node must remain rejected")
  }
}
