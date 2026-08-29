///|
fn memory_types() -> (@ir.SignalType, @ir.SignalType, @ir.SignalType) raise @ir.IrError {
  (UInt(@ir.Width::new(2)), UInt(@ir.Width::new(8)), Bits(@ir.Width::new(1)))
}

///|
fn memory_nodes(
  memory? : @ir.MemoryId,
  port? : @ir.MemoryReadPortId,
) -> Array[@ir.Node] raise @ir.IrError {
  let (address_type, element_type, bit) = memory_types()
  let memory = memory.unwrap_or(@ir.MemoryId::new(0))
  let port = port.unwrap_or(@ir.MemoryReadPortId::new(0))
  [
    @ir.Node::new(@ir.NodeId::new(0), Clock, Input("clock")),
    @ir.Node::new(@ir.NodeId::new(1), address_type, Input("address")),
    @ir.Node::new(@ir.NodeId::new(2), bit, Input("enable")),
    @ir.Node::new(@ir.NodeId::new(3), element_type, Input("write_data")),
    @ir.Node::new(@ir.NodeId::new(4), Bits(@ir.Width::new(2)), Input("mask")),
    @ir.Node::new(@ir.NodeId::new(5), element_type, MemoryRead(memory~, port~)),
    @ir.Node::new(@ir.NodeId::new(6), address_type, Input("address_b")),
  ]
}

///|
fn write_only_nodes() -> Array[@ir.Node] raise @ir.IrError {
  let nodes = memory_nodes()
  nodes[5] = @ir.Node::new(
    @ir.NodeId::new(5),
    UInt(@ir.Width::new(8)),
    Constant(0UL),
  )
  nodes
}

///|
fn memory_read_port(
  id? : @ir.MemoryReadPortId,
  name? : String,
  domain? : @ir.ClockDomain,
  address? : @ir.NodeId,
  enable? : @ir.NodeId,
  result? : @ir.NodeId,
  behavior? : @ir.MemoryReadEnableBehavior,
) -> @ir.MemoryReadPort raise @ir.IrError {
  @ir.MemoryReadPort::new(
    id.unwrap_or(@ir.MemoryReadPortId::new(0)),
    name.unwrap_or("read"),
    domain.unwrap_or(@ir.ClockDomain::rising(@ir.NodeId::new(0))),
    address.unwrap_or(@ir.NodeId::new(1)),
    enable?,
    OneCycle,
    behavior.unwrap_or(HoldLast),
    result.unwrap_or(@ir.NodeId::new(5)),
  )
}

///|
fn memory_write_port(
  id? : @ir.MemoryWritePortId,
  name? : String,
  domain? : @ir.ClockDomain,
  address? : @ir.NodeId,
  data? : @ir.NodeId,
  enable? : @ir.NodeId,
  mask? : @ir.MemoryWriteMask,
) -> @ir.MemoryWritePort raise @ir.IrError {
  @ir.MemoryWritePort::new(
    id.unwrap_or(@ir.MemoryWritePortId::new(0)),
    name.unwrap_or("write"),
    domain.unwrap_or(@ir.ClockDomain::rising(@ir.NodeId::new(0))),
    address.unwrap_or(@ir.NodeId::new(1)),
    data.unwrap_or(@ir.NodeId::new(3)),
    enable?,
    mask.unwrap_or(All),
  )
}

///|
fn memory_spec(
  id? : @ir.MemoryId,
  element_type? : @ir.SignalType,
  domain? : @ir.ClockDomain,
  reads? : Array[@ir.MemoryReadPort],
  writes? : Array[@ir.MemoryWritePort],
  read_write_policy? : @ir.MemoryReadWritePolicy,
  multi_write_policy? : @ir.MemoryMultiWritePolicy,
) -> @ir.MemorySpec raise @ir.IrError {
  let (_, default_element, _) = memory_types()
  @ir.MemorySpec::new(
    id.unwrap_or(@ir.MemoryId::new(0)),
    "storage",
    element_type.unwrap_or(default_element),
    @ir.MemoryDepth::new(4),
    domain.unwrap_or(@ir.ClockDomain::rising(@ir.NodeId::new(0))),
    reads.unwrap_or([memory_read_port()]),
    writes.unwrap_or([]),
    read_write_policy.unwrap_or(ReadOld),
    multi_write_policy.unwrap_or(Reject),
    Fault,
  )
}

///|
fn checked_memory_module(
  nodes : Array[@ir.Node],
  memories : Array[@ir.MemorySpec],
) -> @ir.Module raise @ir.IrError {
  @ir.Module::checked_with_memories("Memory", nodes, memories, [])
}

///|
test "memory IDs, depths, and canonical address widths are checked" {
  for ordinal in [-1, -9] {
    try @ir.MemoryId::new(ordinal) catch {
      InvalidMemoryId(actual) => assert_eq(actual, ordinal)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected invalid memory id")
    }
  }
  try @ir.MemoryReadPortId::new(-1) catch {
    InvalidMemoryPortId(role~, ordinal~) => {
      assert_eq(role, ReadPort)
      assert_eq(ordinal, -1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid read port id")
  }
  try @ir.MemoryWritePortId::new(-1) catch {
    InvalidMemoryPortId(role~, ordinal~) => {
      assert_eq(role, WritePort)
      assert_eq(ordinal, -1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid write port id")
  }
  for elements in [0, -1] {
    try @ir.MemoryDepth::new(elements) catch {
      InvalidMemoryDepth(actual) => assert_eq(actual, elements)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected invalid memory depth")
    }
  }
  let widths = [1, 2, 3, 4, 5, 8, 9].map(elements => {
    @ir.MemoryDepth::new(elements).address_width().bits()
  })
  debug_inspect(widths, content="[1, 1, 2, 2, 3, 3, 4]")
}

///|
test "valid synchronous memory preserves every explicit policy and role" {
  let read = memory_read_port(enable=@ir.NodeId::new(2), behavior=Undefined)
  let write = memory_write_port(
    enable=@ir.NodeId::new(2),
    mask=Granular(signal=@ir.NodeId::new(4), granularity=@ir.Width::new(4)),
  )
  let memory = memory_spec(
    reads=[read],
    writes=[write],
    read_write_policy=ReadNew,
    multi_write_policy=LowerPortIdWins,
  )
  let hardware_module = checked_memory_module(memory_nodes(), [memory])
  assert_eq(hardware_module.memories().length(), 1)
  let frozen = hardware_module.memories()[0]
  assert_eq(frozen.element_type(), UInt(@ir.Width::new(8)))
  assert_eq(frozen.depth().elements(), 4)
  assert_eq(frozen.domain(), @ir.ClockDomain::rising(@ir.NodeId::new(0)))
  assert_eq(frozen.read_ports()[0].latency(), OneCycle)
  assert_eq(frozen.read_ports()[0].enable_behavior(), Undefined)
  assert_eq(frozen.read_write_policy(), ReadNew)
  assert_eq(frozen.multi_write_policy(), LowerPortIdWins)
  assert_eq(frozen.bounds_policy(), Fault)
}

///|
test "legacy module constructor creates no implicit memory state" {
  let hardware_module = @ir.Module::checked("Empty", [], [])
  assert_true(hardware_module.memories().is_empty())
}

///|
test "memory requires data elements and at least one explicit port" {
  for element_type in [@ir.SignalType::Clock, Reset] {
    try
      checked_memory_module(memory_nodes(), [
        memory_spec(element_type~, reads=[memory_read_port()]),
      ])
    catch {
      InvalidMemoryElementType(memory~) => assert_eq(memory, 0)
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected element-type rejection")
    }
  }
  try
    checked_memory_module(memory_nodes(), [memory_spec(reads=[], writes=[])])
  catch {
    MemoryHasNoPorts(memory~) => assert_eq(memory, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected portless-memory rejection")
  }
}

///|
test "memory and port identifiers are canonical sequential ordinals" {
  try
    checked_memory_module(memory_nodes(memory=@ir.MemoryId::new(1)), [
      memory_spec(id=@ir.MemoryId::new(1)),
    ])
  catch {
    NonSequentialMemoryId(expected~, actual~) => {
      assert_eq(expected, 0)
      assert_eq(actual, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected memory-id rejection")
  }
  try
    checked_memory_module(memory_nodes(port=@ir.MemoryReadPortId::new(1)), [
      memory_spec(reads=[memory_read_port(id=@ir.MemoryReadPortId::new(1))]),
    ])
  catch {
    NonSequentialMemoryPortId(role~, expected~, actual~, ..) => {
      assert_eq(role, ReadPort)
      assert_eq(expected, 0)
      assert_eq(actual, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected port-id rejection")
  }
  try
    checked_memory_module(write_only_nodes(), [
      memory_spec(reads=[], writes=[
        memory_write_port(id=@ir.MemoryWritePortId::new(1)),
      ]),
    ])
  catch {
    NonSequentialMemoryPortId(role~, expected~, actual~, ..) => {
      assert_eq(role, WritePort)
      assert_eq(expected, 0)
      assert_eq(actual, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected write-port-id rejection")
  }
}

///|
test "all ports must share the memory's exact clock domain" {
  let foreign = @ir.ClockDomain::rising(@ir.NodeId::new(1))
  try
    checked_memory_module(memory_nodes(), [
      memory_spec(reads=[memory_read_port(domain=foreign)]),
    ])
  catch {
    MemoryDomainMismatch(memory~, role~, port~) => {
      assert_eq(memory, 0)
      assert_eq(role, ReadPort)
      assert_eq(port, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected cross-domain rejection")
  }
  let address_domain = @ir.ClockDomain::rising(@ir.NodeId::new(1))
  try
    checked_memory_module(memory_nodes(), [
      memory_spec(domain=address_domain, reads=[
        memory_read_port(domain=address_domain),
      ]),
    ])
  catch {
    ExpectedClock(node~) => assert_eq(node, 1)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-clock domain rejection")
  }
}

///|
test "memory address is exact canonical-width UInt including depth one" {
  let bad_nodes = memory_nodes()
  bad_nodes[1] = @ir.Node::new(
    @ir.NodeId::new(1),
    Bits(@ir.Width::new(2)),
    Input("address"),
  )
  try checked_memory_module(bad_nodes, [memory_spec()]) catch {
    ExpectedMemoryAddress(role~, node~, ..) => {
      assert_eq(role, ReadPort)
      assert_eq(node, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected address-type rejection")
  }
  let wide_nodes = memory_nodes()
  wide_nodes[1] = @ir.Node::new(
    @ir.NodeId::new(1),
    UInt(@ir.Width::new(3)),
    Input("address"),
  )
  try checked_memory_module(wide_nodes, [memory_spec()]) catch {
    MemoryAddressWidth(expected~, actual~, ..) => {
      assert_eq(expected, 2)
      assert_eq(actual, 3)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected address-width rejection")
  }
}

///|
test "read and write enables must be one-bit data" {
  let nodes = memory_nodes()
  for role in [@ir.MemoryPortRole::ReadPort, WritePort] {
    let memory = if role == ReadPort {
      memory_spec(reads=[memory_read_port(enable=@ir.NodeId::new(3))])
    } else {
      memory_spec(reads=[], writes=[
        memory_write_port(enable=@ir.NodeId::new(3)),
      ])
    }
    let selected_nodes = if role == ReadPort {
      nodes
    } else {
      write_only_nodes()
    }
    try checked_memory_module(selected_nodes, [memory]) catch {
      ExpectedMemoryEnable(role=actual, node~, ..) => {
        assert_eq(actual, role)
        assert_eq(node, 3)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected enable rejection")
    }
  }
}

///|
test "write data and granular mask types widths and divisibility are exact" {
  let (_, element, _) = memory_types()
  let bad_data = memory_spec(element_type=element, reads=[], writes=[
    memory_write_port(data=@ir.NodeId::new(2)),
  ])
  try checked_memory_module(write_only_nodes(), [bad_data]) catch {
    MemoryDataTypeMismatch(memory~, port~) => {
      assert_eq(memory, 0)
      assert_eq(port, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected write-data rejection")
  }
  let wrong_kind = memory_spec(reads=[], writes=[
    memory_write_port(
      mask=Granular(signal=@ir.NodeId::new(1), granularity=@ir.Width::new(4)),
    ),
  ])
  try checked_memory_module(write_only_nodes(), [wrong_kind]) catch {
    ExpectedMemoryMask(node~, ..) => assert_eq(node, 1)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected mask-type rejection")
  }
  let wrong_width = memory_spec(reads=[], writes=[
    memory_write_port(
      mask=Granular(signal=@ir.NodeId::new(2), granularity=@ir.Width::new(2)),
    ),
  ])
  try checked_memory_module(write_only_nodes(), [wrong_width]) catch {
    MemoryMaskWidth(expected~, actual~, ..) => {
      assert_eq(expected, 4)
      assert_eq(actual, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected mask-width rejection")
  }
  let indivisible = memory_spec(
    element_type=UInt(@ir.Width::new(7)),
    reads=[],
    writes=[
      memory_write_port(
        mask=Granular(signal=@ir.NodeId::new(4), granularity=@ir.Width::new(4)),
      ),
    ],
  )
  let seven_bit_nodes = write_only_nodes()
  seven_bit_nodes[3] = @ir.Node::new(
    @ir.NodeId::new(3),
    UInt(@ir.Width::new(7)),
    Input("write_data"),
  )
  try checked_memory_module(seven_bit_nodes, [indivisible]) catch {
    MemoryMaskGranularity(element~, granule~, ..) => {
      assert_eq(element, 7)
      assert_eq(granule, 4)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected indivisible-mask rejection")
  }
}

///|
test "read result identity is typed bijective state and breaks cycles" {
  let address_type : @ir.SignalType = UInt(@ir.Width::new(2))
  let element_type : @ir.SignalType = UInt(@ir.Width::new(8))
  let memory_id = @ir.MemoryId::new(0)
  let read_id = @ir.MemoryReadPortId::new(0)
  let nodes = [
    @ir.Node::new(@ir.NodeId::new(0), Clock, Input("clock")),
    @ir.Node::new(@ir.NodeId::new(1), address_type, Input("address")),
    @ir.Node::new(
      @ir.NodeId::new(2),
      element_type,
      MemoryRead(memory=memory_id, port=read_id),
    ),
    @ir.Node::new(
      @ir.NodeId::new(3),
      element_type,
      Add(@ir.NodeId::new(2), @ir.NodeId::new(2)),
    ),
  ]
  let read = memory_read_port(result=@ir.NodeId::new(2))
  let memory = memory_spec(
    reads=[read],
    writes=[memory_write_port(data=@ir.NodeId::new(3))],
    read_write_policy=ReadOld,
  )
  ignore(checked_memory_module(nodes, [memory]))
  let wrong = memory_nodes()
  wrong[5] = @ir.Node::new(
    @ir.NodeId::new(5),
    Bits(@ir.Width::new(8)),
    MemoryRead(memory=@ir.MemoryId::new(0), port=@ir.MemoryReadPortId::new(0)),
  )
  try checked_memory_module(wrong, [memory_spec()]) catch {
    MemoryReadResultMismatch(node~, ..) => assert_eq(node, 5)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected result mismatch")
  }
}

///|
test "orphan and unknown memory-read identities are rejected" {
  let unknown = memory_nodes(memory=@ir.MemoryId::new(1))
  try checked_memory_module(unknown, []) catch {
    UnknownMemoryId(memory) => assert_eq(memory, 1)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown memory")
  }
  let orphan = memory_nodes()
  orphan.push(
    @ir.Node::new(
      @ir.NodeId::new(7),
      UInt(@ir.Width::new(8)),
      MemoryRead(memory=@ir.MemoryId::new(0), port=@ir.MemoryReadPortId::new(0)),
    ),
  )
  try checked_memory_module(orphan, [memory_spec()]) catch {
    OrphanMemoryReadNode(node~, memory~, port~) => {
      assert_eq(node, 7)
      assert_eq(memory, 0)
      assert_eq(port, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected orphan result")
  }
  let unknown_port = memory_nodes()
  unknown_port.push(
    @ir.Node::new(
      @ir.NodeId::new(7),
      UInt(@ir.Width::new(8)),
      MemoryRead(memory=@ir.MemoryId::new(0), port=@ir.MemoryReadPortId::new(1)),
    ),
  )
  try checked_memory_module(unknown_port, [memory_spec()]) catch {
    UnknownMemoryReadPort(memory~, port~) => {
      assert_eq(memory, 0)
      assert_eq(port, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unknown read port")
  }
  let duplicate = memory_spec(reads=[
    memory_read_port(),
    memory_read_port(
      id=@ir.MemoryReadPortId::new(1),
      name="read_b",
      result=@ir.NodeId::new(5),
    ),
  ])
  try checked_memory_module(memory_nodes(), [duplicate]) catch {
    DuplicateMemoryReadResult(node~) => assert_eq(node, 5)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected duplicate result rejection")
  }
}

///|
test "Reject policies fail closed while priority accepts distinct granules" {
  let read = memory_read_port()
  let write = memory_write_port()
  try
    checked_memory_module(memory_nodes(), [
      memory_spec(reads=[read], writes=[write], read_write_policy=Reject),
    ])
  catch {
    RejectedMemoryReadWriteCollision(memory~) => assert_eq(memory, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected read/write Reject failure")
  }
  let writes = [
    write,
    memory_write_port(id=@ir.MemoryWritePortId::new(1), name="write_b"),
  ]
  try
    checked_memory_module(write_only_nodes(), [
      memory_spec(reads=[], writes~, multi_write_policy=Reject),
    ])
  catch {
    RejectedStaticMultiWriteCollision(first~, second~, ..) => {
      assert_eq(first, 0)
      assert_eq(second, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected static multi-write rejection")
  }
  ignore(
    checked_memory_module(write_only_nodes(), [
      memory_spec(reads=[], writes~, multi_write_policy=LowerPortIdWins),
    ]),
  )
}
