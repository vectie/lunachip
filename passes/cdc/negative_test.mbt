///|
fn register_control_module(role : Int) -> @ir.Module raise @ir.IrError {
  let u8 = cdc_uint(8)
  let bit = cdc_bits(1)
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let next = @ir.NodeId::new(2)
  let enable = @ir.NodeId::new(3)
  let reset = @ir.NodeId::new(4)
  let state = @ir.NodeId::new(5)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let next_timing : @ir.InputTiming = if role == 0 {
    SampledIn(domain_b.id())
  } else {
    SampledIn(domain_a.id())
  }
  let enable_timing : @ir.InputTiming = if role == 1 {
    Asynchronous
  } else {
    SampledIn(domain_a.id())
  }
  let reset_timing : @ir.InputTiming = if role == 2 {
    SampledIn(domain_b.id())
  } else {
    SampledIn(domain_a.id())
  }
  @ir.Module::checked_with_metadata(
    "RegisterControls",
    [domain_b, domain_a],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(next, u8, Input("next")),
      @ir.Node::new(enable, bit, Input("enable")),
      @ir.Node::new(reset, Reset, Input("reset")),
      @ir.Node::new(
        state,
        u8,
        Register(
          @ir.RegisterSpec::new(
            domain_a,
            next,
            reset=@ir.ResetSpec::new(reset, 0UL),
            enable~,
          ),
        ),
      ),
    ],
    [],
    [@ir.OutputPort::new("state", u8, state)],
    cdc_metadata(
      [
        cdc_input_timing(2, next_timing),
        cdc_input_timing(3, enable_timing),
        cdc_input_timing(4, reset_timing),
      ],
      [cdc_output_timing("state", ProducedIn(domain_a.id()))],
    ),
  )
}

///|
test "register next enable and synchronous reset reject unsafe provenance" {
  for role in 0..<3 {
    try @cdc.validate_module(register_control_module(role)) catch {
      @cdc.UnsafeDependency(sink~, destination~, actual~, witness~, ..) => {
        assert_eq(destination.ordinal(), 0)
        assert_eq(
          sink,
          match role {
            0 => RegisterNext(@ir.NodeId::new(5))
            1 => RegisterEnable(@ir.NodeId::new(5))
            _ => SynchronousReset(@ir.NodeId::new(5))
          },
        )
        assert_eq(cdc_path_ordinals(witness), [role + 2, 5])
        if role == 1 {
          assert_true(actual.has_asynchronous())
        } else {
          assert_eq(cdc_ordinals(actual.domains()), [1])
        }
      }
      error => fail("unexpected register CDC error: \{Repr(error)}")
    } noraise {
      _ => fail("expected register CDC rejection")
    }
  }
}

///|
fn mixed_mux_module() -> @ir.Module raise @ir.IrError {
  let u8 = cdc_uint(8)
  let bit = cdc_bits(1)
  let clock_a = @ir.NodeId::new(0)
  let domain_value = @ir.NodeId::new(1)
  let asynchronous = @ir.NodeId::new(2)
  let clock_b = @ir.NodeId::new(3)
  let foreign = @ir.NodeId::new(4)
  let select = @ir.NodeId::new(5)
  let mixed = @ir.NodeId::new(6)
  let state = @ir.NodeId::new(7)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  @ir.Module::checked_with_metadata(
    "MixedMux",
    [domain_b, domain_a],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(domain_value, u8, Input("domain_value")),
      @ir.Node::new(asynchronous, u8, Input("async")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(foreign, u8, Input("foreign")),
      @ir.Node::new(select, bit, Input("select")),
      @ir.Node::new(
        mixed,
        u8,
        Mux(select~, when_true=asynchronous, when_false=foreign),
      ),
      @ir.Node::new(state, u8, Register(@ir.RegisterSpec::new(domain_a, mixed))),
    ],
    [],
    [@ir.OutputPort::new("state", u8, state)],
    cdc_metadata(
      [
        cdc_input_timing(1, SampledIn(domain_a.id())),
        cdc_input_timing(2, Asynchronous),
        cdc_input_timing(4, SampledIn(domain_b.id())),
        cdc_input_timing(5, SampledIn(domain_a.id())),
      ],
      [cdc_output_timing("state", ProducedIn(domain_a.id()))],
    ),
  )
}

///|
test "mixed mux reports sorted sparse provenance and stable minimal path" {
  try @cdc.validate_module(mixed_mux_module()) catch {
    @cdc.UnsafeDependency(sink~, actual~, witness~, ..) => {
      assert_eq(sink, RegisterNext(@ir.NodeId::new(7)))
      assert_true(actual.has_asynchronous())
      assert_eq(cdc_ordinals(actual.domains()), [0, 3])
      assert_eq(cdc_path_ordinals(witness), [2, 6, 7])
      assert_eq(witness.origin(), AsynchronousInput(@ir.NodeId::new(2)))
    }
    error => fail("unexpected mixed provenance error: \{Repr(error)}")
  } noraise {
    _ => fail("expected mixed mux rejection")
  }
}

///|
fn generic_two_flop_module() -> @ir.Module raise @ir.IrError {
  let bit = cdc_bits(1)
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let source = @ir.NodeId::new(2)
  let first = @ir.NodeId::new(3)
  let second = @ir.NodeId::new(4)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  @ir.Module::checked_with_metadata(
    "GenericTwoFlop",
    [domain_a, domain_b],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(source, bit, Input("source")),
      @ir.Node::new(
        first,
        bit,
        Register(@ir.RegisterSpec::new(domain_a, source)),
      ),
      @ir.Node::new(
        second,
        bit,
        Register(@ir.RegisterSpec::new(domain_a, first)),
      ),
    ],
    [],
    [@ir.OutputPort::new("value", bit, second)],
    cdc_metadata([cdc_input_timing(2, SampledIn(domain_b.id()))], [
      cdc_output_timing("value", ProducedIn(domain_a.id())),
    ]),
  )
}

///|
test "a generic two-flop pattern receives no structural exemption" {
  try @cdc.validate_module(generic_two_flop_module()) catch {
    @cdc.UnsafeDependency(sink~, witness~, ..) => {
      assert_eq(sink, RegisterNext(@ir.NodeId::new(3)))
      assert_eq(cdc_path_ordinals(witness), [2, 3])
    }
    error => fail("unexpected generic synchronizer error: \{Repr(error)}")
  } noraise {
    _ => fail("expected generic two-flop rejection")
  }
}

///|
fn memory_control_module(unsafe_role : Int) -> @ir.Module raise @ir.IrError {
  let clock_a = @ir.NodeId::new(0)
  let clock_b = @ir.NodeId::new(1)
  let read_address = @ir.NodeId::new(2)
  let read_enable = @ir.NodeId::new(3)
  let write_address = @ir.NodeId::new(4)
  let write_data = @ir.NodeId::new(5)
  let write_enable = @ir.NodeId::new(6)
  let write_mask = @ir.NodeId::new(7)
  let read_result = @ir.NodeId::new(8)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let memory_id = @ir.MemoryId::new(0)
  let read_id = @ir.MemoryReadPortId::new(0)
  let write_id = @ir.MemoryWritePortId::new(0)
  let read_enable_option : @ir.NodeId? = Some(read_enable)
  let write_enable_option : @ir.NodeId? = Some(write_enable)
  let read = @ir.MemoryReadPort::new(
    read_id,
    "read",
    domain_a,
    read_address,
    enable?=read_enable_option,
    OneCycle,
    HoldLast,
    read_result,
  )
  let write = @ir.MemoryWritePort::new(
    write_id,
    "write",
    domain_a,
    write_address,
    write_data,
    enable?=write_enable_option,
    Granular(signal=write_mask, granularity=@ir.Width::new(4)),
  )
  let memory = @ir.MemorySpec::new(
    memory_id,
    "storage",
    cdc_uint(8),
    @ir.MemoryDepth::new(4),
    domain_a,
    [read],
    [write],
    ReadOld,
    Reject,
    Fault,
  )
  @ir.Module::checked_with_metadata(
    "MemoryControls",
    [domain_b, domain_a],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(read_address, cdc_uint(2), Input("read_address")),
      @ir.Node::new(read_enable, cdc_bits(1), Input("read_enable")),
      @ir.Node::new(write_address, cdc_uint(2), Input("write_address")),
      @ir.Node::new(write_data, cdc_uint(8), Input("write_data")),
      @ir.Node::new(write_enable, cdc_bits(1), Input("write_enable")),
      @ir.Node::new(write_mask, cdc_bits(2), Input("write_mask")),
      @ir.Node::new(
        read_result,
        cdc_uint(8),
        MemoryRead(memory=memory_id, port=read_id),
      ),
    ],
    [memory],
    [@ir.OutputPort::new("result", cdc_uint(8), read_result)],
    cdc_metadata(
      [
        cdc_input_timing(
          2,
          if unsafe_role == 0 {
            SampledIn(domain_b.id())
          } else {
            SampledIn(domain_a.id())
          },
        ),
        cdc_input_timing(
          3,
          if unsafe_role == 1 {
            SampledIn(domain_b.id())
          } else {
            SampledIn(domain_a.id())
          },
        ),
        cdc_input_timing(
          4,
          if unsafe_role == 2 {
            SampledIn(domain_b.id())
          } else {
            SampledIn(domain_a.id())
          },
        ),
        cdc_input_timing(
          5,
          if unsafe_role == 3 {
            SampledIn(domain_b.id())
          } else {
            SampledIn(domain_a.id())
          },
        ),
        cdc_input_timing(
          6,
          if unsafe_role == 4 {
            SampledIn(domain_b.id())
          } else {
            SampledIn(domain_a.id())
          },
        ),
        cdc_input_timing(
          7,
          if unsafe_role == 5 {
            SampledIn(domain_b.id())
          } else {
            SampledIn(domain_a.id())
          },
        ),
      ],
      [cdc_output_timing("result", ProducedIn(domain_a.id()))],
    ),
  )
}

///|
test "every synchronous memory control and granular mask is a CDC sink" {
  let memory = @ir.MemoryId::new(0)
  let read = @ir.MemoryReadPortId::new(0)
  let write = @ir.MemoryWritePortId::new(0)
  let expected : Array[@cdc.CdcSink] = [
    MemoryReadAddress(memory~, port=read),
    MemoryReadEnable(memory~, port=read),
    MemoryWriteAddress(memory~, port=write),
    MemoryWriteData(memory~, port=write),
    MemoryWriteEnable(memory~, port=write),
    MemoryWriteMask(memory~, port=write),
  ]
  for role in 0..<expected.length() {
    try @cdc.validate_module(memory_control_module(role)) catch {
      @cdc.UnsafeDependency(sink~, destination~, actual~, ..) => {
        assert_eq(sink, expected[role])
        assert_eq(destination.ordinal(), 0)
        assert_eq(cdc_ordinals(actual.domains()), [1])
      }
      error => fail("unexpected memory CDC error: \{Repr(error)}")
    } noraise {
      _ => fail("expected memory control rejection")
    }
  }
}

///|
fn output_matrix_module(
  actual_kind : Int,
  declared : @ir.OutputTiming,
) -> @ir.Module raise @ir.IrError {
  let u8 = cdc_uint(8)
  let clock_a = @ir.NodeId::new(0)
  let domain_value = @ir.NodeId::new(1)
  let asynchronous = @ir.NodeId::new(2)
  let clock_b = @ir.NodeId::new(3)
  let foreign = @ir.NodeId::new(4)
  let neutral = @ir.NodeId::new(5)
  let async_mixed = @ir.NodeId::new(6)
  let domain_mixed = @ir.NodeId::new(7)
  let domain_a = @ir.ClockDomain::rising(clock_a)
  let domain_b = @ir.ClockDomain::rising(clock_b)
  let driver = [
      neutral, asynchronous, domain_value, foreign, async_mixed, domain_mixed,
    ][actual_kind]
  @ir.Module::checked_with_metadata(
    "OutputMatrix",
    [domain_b, domain_a],
    [
      @ir.Node::new(clock_a, Clock, Input("clock_a")),
      @ir.Node::new(domain_value, u8, Input("domain_value")),
      @ir.Node::new(asynchronous, u8, Input("async")),
      @ir.Node::new(clock_b, Clock, Input("clock_b")),
      @ir.Node::new(foreign, u8, Input("foreign")),
      @ir.Node::new(neutral, u8, Constant(0UL)),
      @ir.Node::new(async_mixed, u8, BitXor(domain_value, asynchronous)),
      @ir.Node::new(domain_mixed, u8, BitXor(domain_value, foreign)),
    ],
    [],
    [@ir.OutputPort::new("result", u8, driver)],
    cdc_metadata(
      [
        cdc_input_timing(1, SampledIn(domain_a.id())),
        cdc_input_timing(2, Asynchronous),
        cdc_input_timing(4, SampledIn(domain_b.id())),
      ],
      [cdc_output_timing("result", declared)],
    ),
  )
}

///|
test "output timing agreement is exact for neutral async same foreign and mixed" {
  let domain_a = @ir.ClockDomainId::new(0)
  let declarations : Array[@ir.OutputTiming] = [
    Static,
    Asynchronous,
    ProducedIn(domain_a),
  ]
  for actual_kind in 0..<6 {
    for declaration_index, declared in declarations {
      let should_pass = (actual_kind == 0 && declaration_index == 0) ||
        (actual_kind == 1 && declaration_index == 1) ||
        (actual_kind == 2 && declaration_index == 2)
      if should_pass {
        @cdc.validate_module(output_matrix_module(actual_kind, declared))
      } else {
        try
          @cdc.validate_module(output_matrix_module(actual_kind, declared))
        catch {
          @cdc.OutputTimingMismatch(
            output~,
            declared=found,
            actual~,
            witness~,
            ..
          ) => {
            assert_eq(output, "result")
            assert_eq(found, declared)
            assert_eq(witness is None, actual.is_neutral())
          }
          error => fail("unexpected output timing error: \{Repr(error)}")
        } noraise {
          _ => fail("expected exact output timing rejection")
        }
      }
    }
  }
}
