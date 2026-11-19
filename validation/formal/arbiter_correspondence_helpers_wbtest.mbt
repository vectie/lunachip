///|
// Finite original-graph correspondence, not a transport model or proof.
priv struct ArbiterCorrespondence {
  fixture : @flux_tile.QueueConservationFixture
  sequential : TwoClientArbiterSequential
  projection : @sim.Simulator
  requests : Array[Int32]
  responses : Array[Int32]
  mut pre_pending : Bool
  mut pre_samples : Int32
  mut post_samples : Int32
  mut unknown_roots : Int32
  mut reset_edges : Int32
  mut stalled_offers : Int32
  mut stalled_competitors : Int32
  mut tied_grants : Int32
  mut malformed_responses : Int32
  mut poisoned_edges : Int32
  mut held_offer : Array[@wave.LogicValue]?
}

///|
fn arbiter_correspondence_prepare(
  fixture : @flux_tile.QueueConservationFixture,
) -> ArbiterCorrespondence raise {
  let sequential = two_client_arbiter_sequential(fixture)
  {
    fixture,
    sequential,
    projection: @sim.Simulator::prepare(sequential.hardware),
    requests: [0, 0],
    responses: [0, 0],
    pre_pending: false,
    pre_samples: 0,
    post_samples: 0,
    unknown_roots: 0,
    reset_edges: 0,
    stalled_offers: 0,
    stalled_competitors: 0,
    tied_grants: 0,
    malformed_responses: 0,
    poisoned_edges: 0,
    held_offer: None,
  }
}

///|
fn arbiter_correspondence_root(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  guard observer.sequential.probe.roots.filter(root => root.name == name)
    is [root] else {
    fail("missing arbiter root " + name)
  }
  source.value(root.node).to_uint64()
}

///|
fn arbiter_correspondence_event(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
  name : String,
) -> UInt64 raise {
  guard observer.sequential.probe.events.filter(event => event.name == name)
    is [event] else {
    fail("missing arbiter event " + name)
  }
  source.value(event.node).to_uint64()
}

///|
fn arbiter_correspondence_boundary(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
  role : String,
) -> UInt64 raise {
  guard observer.sequential.probe.boundaries.filter(boundary => {
      boundary.roles.contains(role)
    })
    is [boundary] else {
    fail("missing raw arbiter interface " + role)
  }
  source.value(boundary.original.id()).to_uint64()
}

///|
fn arbiter_correspondence_compare(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  for candidate in observer.sequential.probe.candidates {
    let original = candidate.original.id()
    let actual = source.value(original)
    observer.projection.set_input("cut_n\{original.ordinal()}", actual)
    assert_eq(
      observer.projection.value(
        dependency_generation_mapped(
          observer.sequential.original_to_local,
          original,
        ),
      ),
      actual,
    )
  }
  observer.projection.settle()
  for root in observer.sequential.probe.roots {
    let actual = source.value(root.node)
    assert_eq(
      observer.projection.value(
        dependency_generation_mapped(
          observer.sequential.original_to_local,
          root.node,
        ),
      ),
      actual,
    )
    if !actual.is_fully_known() {
      observer.unknown_roots += 1
    }
  }
  for event in observer.sequential.probe.events {
    assert_eq(
      observer.projection.value(
        dependency_generation_mapped(
          observer.sequential.original_to_local,
          event.node,
        ),
      ),
      source.value(event.node),
    )
  }
}

///|
fn arbiter_correspondence_pre(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_false(observer.pre_pending)
  source.settle()
  arbiter_correspondence_compare(observer, source)
  observer.pre_pending = true
  observer.pre_samples += 1
  if source.value(observer.sequential.probe.reset).to_uint64() == 1UL {
    observer.reset_edges += 1
    observer.held_offer = None
    for name in ["offer", "grant", "request_accept", "response_accept"] {
      assert_eq(arbiter_correspondence_event(observer, source, name), 0UL)
    }
    return
  }
  let event = name => arbiter_correspondence_event(observer, source, name)
  let boundary = role => arbiter_correspondence_boundary(observer, source, role)
  let payload : Array[@wave.LogicValue] = []
  for root in observer.sequential.probe.roots {
    if [
        "owner", "local_tag", "write", "address", "bytes", "mask", "data", "next_tag",
      ].contains(root.name) {
      payload.push(source.value(root.node))
    }
  }
  if observer.held_offer is Some(previous) {
    assert_eq(event("offer"), 1UL)
    assert_eq(payload, previous)
  }
  if event("offer") == 1UL && boundary("request_ready") == 0UL {
    observer.stalled_offers += 1
    if boundary("reader_valid") == 1UL && boundary("engine_valid") == 1UL {
      observer.stalled_competitors += 1
    }
    observer.held_offer = Some(payload)
  } else {
    observer.held_offer = None
  }
  if event("grant") == 1UL &&
    boundary("reader_valid") == 1UL &&
    boundary("engine_valid") == 1UL {
    observer.tied_grants += 1
  }
  let owner = arbiter_correspondence_root(observer, source, "owner").to_int()
  if event("request_accept") == 1UL {
    observer.requests[owner] += 1
  }
  if event("response_accept") == 1UL {
    observer.responses[owner] += 1
    observer.malformed_responses += event("malformed_controller").to_int()
  }
  observer.poisoned_edges += event("poisoned").to_int()
}

///|
fn arbiter_correspondence_tick(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  arbiter_correspondence_pre(observer, source)
  source.rising_edge("clock")
  // Commit the projection from saved PRE boundaries before POST is mirrored.
  observer.projection.rising_edge("clock")
  arbiter_correspondence_compare(observer, source)
  if source.value(observer.sequential.probe.reset).to_uint64() == 1UL {
    for root in observer.sequential.probe.roots {
      assert_eq(source.value(root.node).to_uint64(), 0UL)
    }
  }
  observer.pre_pending = false
  observer.post_samples += 1
}

///|
fn arbiter_correspondence_startup(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  for node in observer.fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  records_put(source, "reset", 1, 1UL)
  arbiter_correspondence_tick(observer, source)
  records_put(source, "reset", 1, 0UL)
  records_put(source, "completion_ready", 1, 1UL)
  records_put(source, "memory_request_ready", 1, 1UL)
}

///|
fn arbiter_correspondence_finish(
  observer : ArbiterCorrespondence,
) -> Unit raise {
  assert_false(observer.pre_pending)
  assert_eq(observer.pre_samples, observer.post_samples)
  assert_true(observer.pre_samples > 16)
  assert_true(observer.unknown_roots >= 11)
}
