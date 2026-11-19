///|
fn toggle_primitive(
  request_stages? : Array[@ir.NodeId],
  acknowledge_stages? : Array[@ir.NodeId],
  held_payload? : Array[@ir.NodeId],
) -> @ir.ToggleHandshakePrimitive raise @ir.IrError {
  let request_stages = match request_stages {
    Some(value) => value
    None => [@ir.NodeId::new(12), @ir.NodeId::new(13)]
  }
  let acknowledge_stages = match acknowledge_stages {
    Some(value) => value
    None => [@ir.NodeId::new(22), @ir.NodeId::new(23)]
  }
  let held_payload = match held_payload {
    Some(value) => value
    None => [@ir.NodeId::new(11)]
  }
  @ir.ToggleHandshakePrimitive::checked(
    @ir.CdcPrimitiveId::new(0),
    "toggle🔥",
    @ir.ClockDomainId::new(0),
    @ir.ClockDomainId::new(1),
    @ir.ResetSpec::new(@ir.NodeId::new(2), 0UL),
    @ir.ResetSpec::new(@ir.NodeId::new(3), 0UL),
    @aggregate.Aggregate::leaf(UInt(@ir.Width::new(8))),
    @ir.NodeId::new(4),
    @ir.NodeId::new(5),
    @ir.NodeId::new(6),
    [@ir.NodeId::new(10)],
    held_payload,
    @ir.NodeId::new(7),
    request_stages,
    @ir.NodeId::new(14),
    @ir.NodeId::new(15),
    @ir.NodeId::new(16),
    @ir.NodeId::new(17),
    @ir.NodeId::new(18),
    @ir.NodeId::new(19),
    [@ir.NodeId::new(20)],
    @ir.NodeId::new(21),
    acknowledge_stages,
  )
}

///|
test "toggle handshake IR retains complete canonical roles" {
  let spec = toggle_primitive()
  assert_eq(spec.id().ordinal(), 0)
  assert_eq(spec.name(), "toggle🔥")
  assert_eq(spec.source_domain().ordinal(), 0)
  assert_eq(spec.destination_domain().ordinal(), 1)
  assert_eq(spec.source_payload().map(node => node.ordinal()), [10])
  assert_eq(spec.held_payload().map(node => node.ordinal()), [11])
  assert_eq(spec.request_stages().map(node => node.ordinal()), [12, 13])
  assert_eq(spec.destination_payload().map(node => node.ordinal()), [20])
  assert_eq(spec.acknowledge_stages().map(node => node.ordinal()), [22, 23])
  assert_eq(spec.source_ready().ordinal(), 5)
  assert_eq(spec.destination_valid().ordinal(), 16)
}

///|
test "toggle handshake IR rejects stage payload and role aliasing" {
  try toggle_primitive(request_stages=[@ir.NodeId::new(12)]) catch {
    InvalidToggleHandshakeStageCount(primitive~, actual~) => {
      assert_eq(primitive, 0)
      assert_eq(actual, 1)
    }
    error => fail("unexpected request-stage error: \{Repr(error)}")
  } noraise {
    _ => fail("expected request-stage rejection")
  }
  try
    toggle_primitive(acknowledge_stages=[
      @ir.NodeId::new(22),
      @ir.NodeId::new(23),
      @ir.NodeId::new(24),
    ])
  catch {
    InvalidToggleHandshakeStageCount(primitive~, actual~) => {
      assert_eq(primitive, 0)
      assert_eq(actual, 3)
    }
    error => fail("unexpected acknowledge-stage error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unequal synchronizer-stage rejection")
  }
  try toggle_primitive(held_payload=[]) catch {
    ToggleHandshakePayloadCountMismatch(primitive~, expected~, held~, ..) => {
      assert_eq(primitive, 0)
      assert_eq(expected, 1)
      assert_eq(held, 0)
    }
    error => fail("unexpected payload-count error: \{Repr(error)}")
  } noraise {
    _ => fail("expected payload-count rejection")
  }
  try toggle_primitive(held_payload=[@ir.NodeId::new(7)]) catch {
    ToggleHandshakeDuplicateNode(primitive~, node~) => {
      assert_eq(primitive, 0)
      assert_eq(node, 7)
    }
    error => fail("unexpected role-alias error: \{Repr(error)}")
  } noraise {
    _ => fail("expected role-alias rejection")
  }
}
