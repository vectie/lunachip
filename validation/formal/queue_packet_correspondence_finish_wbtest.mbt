///|
// All witnesses count actual source PRE events, not a projection prediction.
fn queue_packet_correspondence_metrics(
  observer : QueuePacketCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let reset = source.value(observer.sequential.probe.reset)
  assert_true(reset.is_fully_known())
  if reset.to_uint64() == 1UL {
    observer.reset_edges += 1
    return
  }
  let read = role => records_observe(observer.fixture, source, role)
  let admit = read(FifoPushValid(0)) == 1UL && read(FifoPushReady(0)) == 1UL
  if admit {
    observer.admissions += 1
    let descriptor = observer.sequential.probe.source
      .nodes()
      .filter(node => node.kind() is Input("descriptor_lane_0"))
    guard descriptor is [lane] else {
      fail("missing original public descriptor lane")
    }
    let data = source.value(lane.id())
    assert_true(data.is_fully_known())
    if data.to_uint64() >> 32 == 73UL {
      observer.id73_admissions += 1
    }
  }
  observer.reservations += read(HeadReserve).to_int()
  observer.captures += read(HeadCapture).to_int()
  observer.retirements += read(RetirementFire).to_int()
  for engine in 0..<3 {
    observer.accepts[engine] += read(EngineAccept(engine)).to_int()
    for entry in 0..<3 {
      observer.collections[engine] += read(EntryCollector(entry, engine)).to_int()
    }
  }
  for entry in 0..<3 {
    observer.local_terminals += read(EntryLocalTerminal(entry)).to_int()
  }
  if read(RetirementValid) == 1UL && read(RetirementFire) == 0UL {
    observer.held_edges += 1
  }
  let mut full_refill = true
  for lane in 0..<4 {
    full_refill = full_refill &&
      read(FifoOccupancy(lane)) == 3UL &&
      read(FifoPushValid(lane)) == 1UL &&
      read(FifoPushReady(lane)) == 1UL &&
      read(FifoPopRequest(lane)) == 1UL &&
      read(FifoPopReady(lane)) == 1UL
  }
  if full_refill {
    observer.full_refills += 1
  }
  if observer.reset_edges > 1 {
    if admit {
      observer.fresh_admissions += 1
    }
    observer.fresh_reservations += read(HeadReserve).to_int()
    observer.fresh_retirements += read(RetirementFire).to_int()
  }
}

///|
fn queue_packet_correspondence_finish(
  observer : QueuePacketCorrespondence,
) -> Unit raise {
  assert_false(observer.pre_pending)
  assert_eq(observer.pre_samples, observer.post_samples)
  assert_true(observer.pre_samples > 16)
  assert_true(observer.unknown_roots > 0)
  assert_true(observer.unknown_cuts > 0)
  assert_true(observer.unknown_reads > 0)
  assert_true(observer.unknown_cells > 0)
  assert_eq(observer.reset_edges, 2)
  assert_eq(observer.fresh_admissions, 1)
  assert_eq(observer.fresh_reservations, 1)
  assert_eq(observer.fresh_retirements, 1)
  println(
    "QUEUE-PACKET-NATIVE-CORRESPONDENCE PRE \{observer.pre_samples} POST \{observer.post_samples} admissions \{observer.admissions} captures \{observer.captures} reservations \{observer.reservations} accepts \{Repr(observer.accepts)} collectors \{Repr(observer.collections)} local \{observer.local_terminals} retirements \{observer.retirements} held \{observer.held_edges} full-refills \{observer.full_refills} reset-edges \{observer.reset_edges} unknown-roots \{observer.unknown_roots} unknown-cuts \{observer.unknown_cuts} unknown-reads \{observer.unknown_reads} unknown-cells \{observer.unknown_cells}",
  )
}

///|
fn queue_packet_correspondence_finish_records(
  observer : QueuePacketCorrespondence,
) -> Unit raise {
  queue_packet_correspondence_finish(observer)
  assert_eq(observer.accepts, [2, 1, 1])
  assert_eq(observer.collections, [2, 1, 1])
  assert_eq(observer.local_terminals, 4)
  assert_eq(observer.retirements, 7)
  assert_eq(observer.id73_admissions, 8)
  assert_true(observer.held_edges >= 16)
}

///|
fn queue_packet_correspondence_finish_storage(
  observer : QueuePacketCorrespondence,
) -> Unit raise {
  queue_packet_correspondence_finish(observer)
  assert_eq(observer.accepts, [0, 0, 0])
  assert_eq(observer.collections, [0, 0, 0])
  assert_eq(observer.retirements, 19)
  assert_true(observer.full_refills > 0)
}

///|
test "packet correspondence acceptance rejects same-count boundary drift and unchanged-report source drift" {
  let probe = queue_packet_composition_probe(
    @flux_tile.queued_concurrent_queue_formal_fixture(),
  )
  queue_packet_composition_require_inventory(probe)
  let candidates = probe.candidates.iter().to_array()
  guard candidates is [first, ..] else { fail("no original foreign boundary") }
  candidates[0] = { ..first, provenance: [], }
  let changed_source = @ir.Module::checked_with_memories(
    "DifferentOriginalSource",
    probe.source.nodes(),
    probe.source.memories(),
    probe.source.outputs(),
  )
  let changed : Array[QueuePacketCompositionProbe] = [
    { ..probe, candidates: ReadOnlyArray::from_array(candidates), },
    { ..probe, source: changed_source, },
  ]
  assert_eq(
    queue_packet_composition_report(changed[1]),
    queue_packet_composition_report(probe),
  )
  for drift in changed {
    assert_eq(drift.roots.length(), probe.roots.length())
    assert_eq(drift.candidates.length(), probe.candidates.length())
    try queue_packet_composition_require_inventory(drift) catch {
      InvalidFormalBundleIdentity(_) => ()
      _ => fail("unexpected inventory rejection")
    } noraise {
      _ => fail("count-only or unchanged-report acceptance bypass")
    }
  }
}
