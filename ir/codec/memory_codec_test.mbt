///|
const MEMORY_GOLDEN : String =
  #|LUNACHIP-IR 3
  #|DESIGN 6d656d6f72792d66697874757265
  #|TOP 4d656d6f7279
  #|MODULES 1
  #|MODULE 4d656d6f7279
  #|NODES 6
  #|NODE 0 clock input 636c6f636b
  #|NODE 1 uint:2 input 61646472657373
  #|NODE 2 bits:1 input 656e61626c65
  #|NODE 3 uint:8 input 64617461
  #|NODE 4 bits:2 input 6d61736b
  #|NODE 5 uint:8 memread 0 0
  #|MEMORIES 1
  #|MEMORY 0 73746f72616765 uint:8 4 0 rising read_new lower_port_id_wins fault
  #|READS 1
  #|READ 0 72656164 0 rising 1 2 one hold_last 5
  #|WRITES 1
  #|WRITE 0 7772697465 0 rising 1 3 2 granular 4 4
  #|ENDMEMORY
  #|OUTPUTS 1
  #|OUTPUT 71 uint:8 5
  #|ENDMODULE
  #|END
  #|

///|
fn memory_design(
  read_write_policy? : @ir.MemoryReadWritePolicy,
  multi_write_policy? : @ir.MemoryMultiWritePolicy,
  bounds_policy? : @ir.MemoryBoundsPolicy,
  enable_behavior? : @ir.MemoryReadEnableBehavior,
  include_write? : Bool,
  granular? : Bool,
) -> @ir.Design raise @ir.IrError {
  let clock = @ir.NodeId::new(0)
  let address = @ir.NodeId::new(1)
  let enable = @ir.NodeId::new(2)
  let data = @ir.NodeId::new(3)
  let mask = @ir.NodeId::new(4)
  let result = @ir.NodeId::new(5)
  let memory = @ir.MemoryId::new(0)
  let read_port = @ir.MemoryReadPortId::new(0)
  let address_type : @ir.SignalType = UInt(@ir.Width::new(2))
  let element_type : @ir.SignalType = UInt(@ir.Width::new(8))
  let nodes = [
    @ir.Node::new(clock, Clock, Input("clock")),
    @ir.Node::new(address, address_type, Input("address")),
    @ir.Node::new(enable, Bits(@ir.Width::new(1)), Input("enable")),
    @ir.Node::new(data, element_type, Input("data")),
    @ir.Node::new(mask, Bits(@ir.Width::new(2)), Input("mask")),
    @ir.Node::new(result, element_type, MemoryRead(memory~, port=read_port)),
  ]
  let domain = @ir.ClockDomain::rising(clock)
  let reads = [
    @ir.MemoryReadPort::new(
      read_port,
      "read",
      domain,
      address,
      enable~,
      OneCycle,
      enable_behavior.unwrap_or(HoldLast),
      result,
    ),
  ]
  let write_mask = if granular.unwrap_or(true) {
    @ir.MemoryWriteMask::Granular(signal=mask, granularity=@ir.Width::new(4))
  } else {
    All
  }
  let writes = if include_write.unwrap_or(true) {
    [
      @ir.MemoryWritePort::new(
        @ir.MemoryWritePortId::new(0),
        "write",
        domain,
        address,
        data,
        enable~,
        write_mask,
      ),
    ]
  } else {
    []
  }
  let spec = @ir.MemorySpec::new(
    memory,
    "storage",
    element_type,
    @ir.MemoryDepth::new(4),
    domain,
    reads,
    writes,
    read_write_policy.unwrap_or(ReadNew),
    multi_write_policy.unwrap_or(LowerPortIdWins),
    bounds_policy.unwrap_or(Fault),
  )
  let hardware_module = @ir.Module::checked_with_memories(
    "Memory",
    nodes,
    [spec],
    [@ir.OutputPort::new("q", element_type, result)],
  )
  @ir.Design::single("memory-fixture", hardware_module)
}

///|
test "schema three memory golden and round trip are byte stable" {
  let design = memory_design()
  let canonical = @codec.serialize(design)
  assert_eq(canonical, MEMORY_GOLDEN)
  assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
  inspect(@codec.content_digest(design).to_hex(), content="204129064adb6a89")
}

///|
test "schema four memory records use canonical domain references" {
  let base = memory_design().top_module().unwrap()
  let nodes = base.nodes().iter().to_array()
  let second_clock = @ir.NodeId::new(nodes.length())
  let next = @ir.NodeId::new(nodes.length() + 1)
  let state = @ir.NodeId::new(nodes.length() + 2)
  let ty : @ir.SignalType = UInt(@ir.Width::new(8))
  nodes.push(@ir.Node::new(second_clock, Clock, Input("second_clock")))
  nodes.push(@ir.Node::new(next, ty, Input("next")))
  nodes.push(
    @ir.Node::new(
      state,
      ty,
      Register(
        @ir.RegisterSpec::new(@ir.ClockDomain::rising(second_clock), next),
      ),
    ),
  )
  let hardware_module = @ir.Module::checked_with_memories(
    "Memory",
    nodes,
    base.memories().iter().to_array(),
    [
      @ir.OutputPort::new("q", ty, @ir.NodeId::new(5)),
      @ir.OutputPort::new("state", ty, state),
    ],
  )
  let design = @ir.Design::single("multi-domain-memory", hardware_module)
  let canonical = @codec.serialize(design)
  assert_true(canonical.has_prefix("LUNACHIP-IR 4\n"))
  assert_true(canonical.contains("DOMAINS 2\n"))
  assert_true(
    canonical.contains(
      "MEMORY 0 73746f72616765 uint:8 4 0 read_new lower_port_id_wins fault",
    ),
  )
  assert_true(canonical.contains("READ 0 72656164 0 1 2 one hold_last 5"))
  assert_true(canonical.contains("WRITE 0 7772697465 0 1 3 2 granular 4 4"))
  assert_eq(@codec.serialize(@codec.parse(canonical)), canonical)
}

///|
test "every supported memory policy and mask shape round trips" {
  let read_write = [
    @ir.MemoryReadWritePolicy::ReadOld,
    ReadNew,
    NoChange,
    Undefined,
  ]
  for policy in read_write {
    let encoded = @codec.serialize(memory_design(read_write_policy=policy))
    assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
  }
  let reject = @codec.serialize(
    memory_design(read_write_policy=Reject, include_write=false),
  )
  assert_true(reject.contains(" reject "))
  assert_eq(@codec.serialize(@codec.parse(reject)), reject)
  for bounds in [@ir.MemoryBoundsPolicy::Fault, Undefined] {
    let encoded = @codec.serialize(memory_design(bounds_policy=bounds))
    assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
  }
  for behavior in [@ir.MemoryReadEnableBehavior::HoldLast, Undefined] {
    let encoded = @codec.serialize(memory_design(enable_behavior=behavior))
    assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
  }
  let all_mask = @codec.serialize(memory_design(granular=false))
  assert_true(all_mask.contains(" all\n"))
  assert_eq(@codec.serialize(@codec.parse(all_mask)), all_mask)
  let rejected_multiwrite = @codec.serialize(
    memory_design(multi_write_policy=Reject),
  )
  assert_eq(
    @codec.serialize(@codec.parse(rejected_multiwrite)),
    rejected_multiwrite,
  )
}

///|
test "schema three is used only when memory state is present" {
  let noncanonical =
    #|LUNACHIP-IR 3
    #|DESIGN 656d707479
    #|TOP 456d707479
    #|MODULES 1
    #|MODULE 456d707479
    #|NODES 0
    #|MEMORIES 0
    #|OUTPUTS 0
    #|ENDMODULE
    #|END
    #|
  try @codec.parse(noncanonical) catch {
    NonCanonical => ()
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unnecessary schema-three rejection")
  }
}

///|
test "schema three represents memoryless sibling modules explicitly" {
  let memory = memory_design().top_module().unwrap()
  let auxiliary = @ir.Module::checked("Auxiliary", [], [])
  let design = @ir.Design::checked(
    "mixed-memory-design",
    [memory, auxiliary],
    "Memory",
  )
  let encoded = @codec.serialize(design)
  assert_true(encoded.has_prefix("LUNACHIP-IR 3\n"))
  assert_eq(encoded.split("MEMORIES 0").count(), 2)
  assert_eq(@codec.serialize(@codec.parse(encoded)), encoded)
}

///|
test "schema three rejects malformed latency edge and memory semantics" {
  let malformed_latency = MEMORY_GOLDEN.replace(
    old=" one hold_last ",
    new=" zero hold_last ",
  )
  try @codec.parse(malformed_latency) catch {
    UnexpectedLine(expected~, ..) =>
      assert_eq(expected, "one-cycle memory read latency")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected latency rejection")
  }
  let malformed_edge = MEMORY_GOLDEN.replace(
    old=" 0 rising read_new ",
    new=" 0 falling read_new ",
  )
  try @codec.parse(malformed_edge) catch {
    UnexpectedLine(expected~, ..) => assert_eq(expected, "rising clock edge")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected edge rejection")
  }
  let invalid_depth = MEMORY_GOLDEN.replace(
    old=" uint:8 4 0 rising ",
    new=" uint:8 0 0 rising ",
  )
  try @codec.parse(invalid_depth) catch {
    IrRejected(reason~) => assert_true(reason.contains("InvalidMemoryDepth"))
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected invalid depth rejection")
  }
}

///|
test "schema three rejects noncanonical memory and port ordinals" {
  let memory_id = MEMORY_GOLDEN
    .replace(old="MEMORY 0 73746f72616765", new="MEMORY 1 73746f72616765")
    .replace(old="memread 0 0", new="memread 1 0")
  try @codec.parse(memory_id) catch {
    IrRejected(reason~) => assert_true(reason.contains("NonSequentialMemoryId"))
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected memory ordinal rejection")
  }
  let port_id = MEMORY_GOLDEN
    .replace(old="READ 0 72656164", new="READ 1 72656164")
    .replace(old="memread 0 0", new="memread 0 1")
  try @codec.parse(port_id) catch {
    IrRejected(reason~) =>
      assert_true(reason.contains("NonSequentialMemoryPortId"))
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected port ordinal rejection")
  }
}
