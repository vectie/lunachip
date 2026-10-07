///|
fn arbiter_faults_nonrising(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  assert_false(observer.pre_pending)
  let saved : Array[@wave.LogicValue] = []
  for root in observer.sequential.probe.roots {
    saved.push(source.value(root.node))
  }
  assert_eq(saved.length(), 11)
  let mut changed_events = 0
  for level in [0UL, 1UL] {
    let before : Array[@wave.LogicValue] = []
    for candidate in observer.sequential.probe.candidates {
      before.push(source.value(candidate.original.id()))
    }
    let data = if level == 0UL {
      @wave.LogicValue::unknown(width=32)
    } else {
      @wave.LogicValue::from_uint64(width=32, value=5UL)
    }
    let drives = [
      @sim.InputDrive::checked(
        "clock",
        @wave.LogicValue::from_uint64(width=1, value=level),
      ),
      @sim.InputDrive::checked(
        "reset",
        @wave.LogicValue::from_uint64(width=1, value=1UL - level),
      ),
      @sim.InputDrive::checked(
        "memory_response_valid",
        @wave.LogicValue::one(width=1),
      ),
      @sim.InputDrive::checked(
        "memory_response_tag",
        @wave.LogicValue::from_uint64(width=32, value=55UL + level),
      ),
      @sim.InputDrive::checked(
        "memory_response_fault",
        @wave.LogicValue::from_uint64(width=2, value=3UL - level),
      ),
      @sim.InputDrive::checked("memory_response_data", data),
    ]
    let event = @sim.TimestampEvent::drives_only(source.time().next(), drives)
    assert_eq(event.active_domains().length(), 0)
    source.apply_event(event)
    // No active domain on either graph. Clock level changes do not infer edges.
    let projection_event = @sim.TimestampEvent::drives_only(
      observer.projection.time().next(),
      [
        @sim.InputDrive::checked(
          "clock",
          @wave.LogicValue::from_uint64(width=1, value=level),
        ),
      ],
    )
    assert_eq(projection_event.active_domains().length(), 0)
    observer.projection.apply_event(projection_event)
    arbiter_correspondence_compare(observer, source)
    for index, root in observer.sequential.probe.roots {
      assert_eq(source.value(root.node), saved[index])
    }
    let mut changed = 0
    for index, candidate in observer.sequential.probe.candidates {
      if source.value(candidate.original.id()) != before[index] {
        changed += 1
      }
    }
    assert_true(changed >= 4)
    changed_events += 1
    assert_eq(source.value(observer.sequential.probe.clock).to_uint64(), level)
  }
  assert_eq(changed_events, 2)
  assert_false(observer.pre_pending)
}

///|
test "actual arbiter Offer and Wait hold on changed nonrising peers then joint reset and recover" {
  for target_state in [1UL, 2UL] {
    let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
    let source = @sim.Simulator::prepare(fixture.hardware())
    let observer = arbiter_correspondence_prepare(fixture)
    arbiter_correspondence_startup(observer, source)
    arbiter_faults_offer(observer, source)
    if target_state == 2UL {
      arbiter_faults_accept_offer(observer, source)
    }
    assert_eq(
      arbiter_correspondence_root(observer, source, "state"),
      target_state,
    )
    arbiter_faults_nonrising(observer, source)
    assert_eq(
      arbiter_correspondence_root(observer, source, "state"),
      target_state,
    )
    assert_eq(
      observer.requests,
      if target_state == 2UL {
        [1, 0]
      } else {
        [0, 0]
      },
    )
    assert_eq(observer.responses, [0, 0])
    assert_eq(observer.reset_edges, 1)
    assert_eq(observer.malformed_responses, 0)
    assert_eq(observer.poisoned_edges, 0)
    arbiter_faults_joint_reset(observer, source)
    arbiter_faults_matching_recovery(observer, source, 0UL)
    assert_eq(
      observer.requests,
      if target_state == 2UL {
        [3, 0]
      } else {
        [2, 0]
      },
    )
    assert_eq(observer.responses, [2, 0])
    assert_eq(observer.reset_edges, 2)
    assert_eq(observer.malformed_responses, 0)
    assert_eq(observer.poisoned_edges, 0)
    arbiter_correspondence_finish(observer)
  }
}
