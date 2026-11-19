///|
// Deliberately malformed public packets give distinct words in every SRAM
// lane while retiring locally. No engine root or queue state is forced.
fn queue_storage_correspondence_packet(index : Int32) -> Array[UInt64] {
  let value = index.to_uint64()
  [
    ((100UL + value) << 32) | (4UL << 16) | 0x300UL,
    0x1000UL + value,
    0x2000UL + value,
    0x3000UL + value,
  ]
}

///|
test "original queue storage prefix matches saved PRE cuts through full ReadOld refill wraps and later reset" {
  let fixture = @flux_tile.queued_concurrent_queue_formal_fixture()
  let source = @sim.Simulator::prepare(fixture.hardware())
  let observer = queue_storage_correspondence_prepare(fixture)
  let packet_correspondence = queue_packet_correspondence_prepare(fixture)
  for node in fixture.hardware().nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(source, name, node.signal_type().width().bits(), 0UL)
    }
  }
  records_put(source, "reset", 1, 1UL)
  queue_packet_correspondence_pre(packet_correspondence, source)
  queue_storage_correspondence_tick(observer, source)
  queue_packet_correspondence_post(packet_correspondence, source)
  records_put(source, "reset", 1, 0UL)
  records_put(source, "memory_request_ready", 1, 1UL)
  let packets = Array::makei(18, queue_storage_correspondence_packet)
  let mut admitted = 0
  let mut captured = 0
  let mut retired = 0
  let mut full_held = 0
  let mut release = false
  for _ in 0..<1024 {
    records_present(
      source,
      if admitted < packets.length() {
        Some(packets[admitted])
      } else {
        None
      },
    )
    records_put(source, "completion_ready", 1, if release { 1UL } else { 0UL })
    source.settle()
    assert_eq(records_output(source, "memory_request_valid"), 0UL)
    let accept = admitted < packets.length() &&
      records_output(source, "descriptor_ready") == 1UL
    let capture = records_observe(fixture, source, HeadCapture) == 1UL
    let retire = records_output(source, "completion_valid") == 1UL && release
    if !release &&
      records_observe(fixture, source, FifoOccupancy(0)) == 3UL &&
      records_observe(fixture, source, RetirementOccupancy) == 3UL {
      full_held += 1
    }
    if capture {
      assert_true(captured < admitted)
      for lane in 0..<4 {
        assert_eq(
          records_observe(fixture, source, FifoResponseValid(lane)),
          1UL,
        )
        assert_eq(
          records_observe(fixture, source, FifoResponseData(lane)),
          packets[captured][lane],
        )
      }
    }
    if retire {
      assert_eq(
        records_output(source, "completion_id"),
        100UL + retired.to_uint64(),
      )
    }
    queue_packet_correspondence_pre(packet_correspondence, source)
    queue_storage_correspondence_tick(observer, source)
    queue_packet_correspondence_post(packet_correspondence, source)
    if accept {
      admitted += 1
    }
    if capture {
      captured += 1
    }
    if retire {
      retired += 1
    }
    if full_held >= 4 {
      release = true
    }
    if retired == packets.length() {
      break
    }
  }
  assert_true(release)
  assert_true(full_held >= 4)
  assert_eq(admitted, 18)
  assert_eq(captured, 18)
  assert_eq(retired, 18)
  assert_true(observer.full_refills > 0)
  assert_true(observer.changed_full_refills > 0)
  for lane in 0..<4 {
    assert_true(observer.read_wraps[lane] >= 6)
    assert_true(observer.write_wraps[lane] >= 6)
  }
  // Refill a real live prefix with completion backpressure before resetting.
  // Previously written SRAM and held response words must survive that reset.
  records_put(source, "completion_ready", 1, 0UL)
  let mut second_admitted = 0
  let mut second_captured = 0
  let mut held_before_reset = false
  for _ in 0..<256 {
    let packet = queue_storage_correspondence_packet(100 + second_admitted)
    records_present(source, Some(packet))
    source.settle()
    let accept = records_output(source, "descriptor_ready") == 1UL
    let capture = records_observe(fixture, source, HeadCapture) == 1UL
    if capture {
      for lane in 0..<4 {
        assert_eq(
          records_observe(fixture, source, FifoResponseData(lane)),
          queue_storage_correspondence_packet(100 + second_captured)[lane],
        )
      }
    }
    if records_observe(fixture, source, FifoOccupancy(0)) == 3UL &&
      records_observe(fixture, source, RetirementOccupancy) == 3UL &&
      records_observe(fixture, source, HeadState) == 2UL {
      held_before_reset = true
      break
    }
    queue_packet_correspondence_pre(packet_correspondence, source)
    queue_storage_correspondence_tick(observer, source)
    queue_packet_correspondence_post(packet_correspondence, source)
    if accept {
      second_admitted += 1
    }
    if capture {
      second_captured += 1
    }
  }
  assert_true(held_before_reset)
  assert_true(second_admitted >= 6)
  records_present(source, None)
  records_put(source, "reset", 1, 1UL)
  queue_packet_correspondence_pre(packet_correspondence, source)
  queue_storage_correspondence_tick(observer, source)
  queue_packet_correspondence_post(packet_correspondence, source)
  for root in observer.sequential.probe.roots {
    assert_eq(
      source.value(root.node),
      @wave.LogicValue::zero(width=root.signal_type.width().bits()),
    )
  }
  assert_eq(observer.later_reset_held_cells, 12)
  records_put(source, "reset", 1, 0UL)
  // An idle edge keeps old SRAM/read state but cannot expose a stale packet.
  queue_packet_correspondence_pre(packet_correspondence, source)
  queue_storage_correspondence_tick(observer, source)
  queue_packet_correspondence_post(packet_correspondence, source)
  assert_eq(records_observe(fixture, source, FifoOccupancy(0)), 0UL)
  assert_eq(records_output(source, "completion_valid"), 0UL)
  let fresh = queue_storage_correspondence_packet(500)
  let mut fresh_admitted = false
  let mut fresh_captured = false
  let mut fresh_retired = false
  records_put(source, "completion_ready", 1, 1UL)
  for _ in 0..<64 {
    records_present(source, if fresh_admitted { None } else { Some(fresh) })
    source.settle()
    let accept = !fresh_admitted &&
      records_output(source, "descriptor_ready") == 1UL
    let capture = records_observe(fixture, source, HeadCapture) == 1UL
    let retire = records_output(source, "completion_valid") == 1UL
    if capture {
      assert_false(fresh_captured)
      for lane in 0..<4 {
        assert_eq(
          records_observe(fixture, source, FifoResponseData(lane)),
          fresh[lane],
        )
      }
    }
    if retire {
      assert_eq(records_output(source, "completion_id"), 600UL)
    }
    queue_packet_correspondence_pre(packet_correspondence, source)
    queue_storage_correspondence_tick(observer, source)
    queue_packet_correspondence_post(packet_correspondence, source)
    if accept {
      fresh_admitted = true
    }
    if capture {
      fresh_captured = true
    }
    if retire {
      fresh_retired = true
      break
    }
  }
  assert_true(fresh_admitted && fresh_captured && fresh_retired)
  assert_eq(observer.reset_edges, 2)
  assert_eq(observer.pre_samples, observer.post_samples)
  assert_true(observer.pre_samples > 64)
  assert_true(observer.unknown_roots > 0)
  assert_true(observer.unknown_cuts > 0)
  assert_true(observer.unknown_reads > 0)
  assert_true(observer.unknown_cells > 0)
  assert_eq(observer.captures, 18 + second_captured + 1)
  queue_packet_correspondence_finish_storage(packet_correspondence)
  println(
    "QUEUE-STORAGE-NATIVE-CORRESPONDENCE PRE \{observer.pre_samples} POST \{observer.post_samples} captures \{observer.captures} full-refills \{observer.full_refills} changed-full-refills \{observer.changed_full_refills} read-wraps \{Repr(observer.read_wraps)} write-wraps \{Repr(observer.write_wraps)} reset-edges \{observer.reset_edges} retained-reset-cells \{observer.later_reset_held_cells}",
  )
}
