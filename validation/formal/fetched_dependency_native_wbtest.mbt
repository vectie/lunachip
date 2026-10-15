///|
test "fetched generations follow public packets failed writers syntax rejection recovery and reset" {
  let sequential = fetched_transport_sequential()
  let aliases = fetched_dependency_aliases(sequential.probe.source)
  let simulator = @sim.Simulator::prepare(sequential.probe.source)
  let packet_order = FetchedPacketNative::new(sequential.probe.source)
  assert_true(
    sequential.probe.source
    .nodes()
    .any(node => {
      node.kind() is MemoryRead(..) &&
      !simulator.value(node.id()).is_fully_known()
    }),
  )
  for node in sequential.probe.source.nodes() {
    if node.kind() is Input(name) && name != "clock" {
      records_put(simulator, name, node.signal_type().width().bits(), 0UL)
    }
  }
  let useful = Array::makei(4, index => fetched_useful_packet(index))
  let bad_address = useful[0].copy()
  bad_address[2] = 0xffffffffUL | (2UL << 32)
  let bad_version = useful[0].copy()
  bad_version[0] = bad_version[0] ^ 1UL
  let bad_dimension = useful[0].copy()
  bad_dimension[1] = 8192UL | (2UL << 16)
  let bad_unused = useful[0].copy()
  bad_unused[3] = 1UL << 8
  let bad_opcode = useful[0].copy()
  bad_opcode[0] = (73UL << 32) | (8UL << 16) | 0x200UL
  // (packet, independent raw local fault, syntax valid, expected completion).
  let batches : Array[Array[(Array[UInt64], UInt64, Bool, UInt64)]] = [
    [
      (useful[0], 0UL, true, 0UL),
      (useful[1], 0UL, true, 0UL),
      (useful[2], 0UL, true, 0UL),
      (useful[3], 0UL, true, 0UL),
    ],
    [
      (bad_address, 0UL, true, 8UL),
      (useful[2], 0UL, true, 4UL),
      (useful[3], 0UL, true, 5UL),
      (bad_version, 12UL, false, 12UL),
    ],
    [
      (useful[0], 0UL, true, 0UL),
      (useful[2], 0UL, true, 0UL),
      (useful[3], 0UL, true, 0UL),
      (bad_dimension, 14UL, false, 14UL),
    ],
    [
      (bad_unused, 2UL, true, 2UL),
      (useful[2], 0UL, true, 4UL),
      (useful[3], 0UL, true, 5UL),
      (bad_opcode, 1UL, false, 1UL),
    ],
    [
      (useful[2], 0UL, true, 4UL),
      (useful[0], 0UL, true, 0UL),
      (useful[1], 0UL, true, 0UL),
      (useful[2], 0UL, true, 0UL),
    ],
  ]
  let mut model = FetchedGenerationNative::new()
  let read = role => fetched_dependency_native_read(aliases, simulator, role)
  let mut total_reserved = 0
  let mut total_retired = 0
  let mut writes = 0
  let mut inner_accepts = 0
  let mut negative_seen = false
  for batch in 0..<5 {
    let reset_batch = batch == 0 || batch == 4
    if reset_batch {
      model = FetchedGenerationNative::new()
    }
    let base_count = if batch == 4 { 0 } else { batch * 4 }
    let mut configured = !reset_batch
    let mut published = false
    let mut reserved = 0
    let mut retired = 0
    let mut pending : FetchedUsefulNativeRequest? = None
    for edge in 0..<1600 {
      let reset = reset_batch && edge == 0
      let ready = edge % 4 == 0
      let respond = pending is Some(_) && edge % 3 == 0
      let response_data = match pending {
        Some(r) if !r.write && r.address < 128UL => {
          let offset = (r.address % 32UL).to_int()
          (
            batches[batch][(r.address / 32UL).to_int()].0[offset / 8] >>
            (offset % 8 * 8)
          ) &
          255UL
        }
        Some(r) if !r.write => fetched_useful_native_data(r.address)
        _ => 0UL
      }
      for
        (name, width, value) in [
          ("reset", 1, if reset { 1UL } else { 0UL }),
          ("config_valid", 1, if !reset && !configured { 1UL } else { 0UL }),
          (
            "publish_valid",
            1,
            if !reset && configured && !published {
              1UL
            } else {
              0UL
            },
          ),
          ("publish_producer", 32, (base_count + 4).to_uint64()),
          ("completion_ready", 1, if edge % 5 != 0 { 1UL } else { 0UL }),
          ("memory_request_ready", 1, if ready { 1UL } else { 0UL }),
          ("memory_response_valid", 1, if respond { 1UL } else { 0UL }),
          ("memory_response_tag", 32, pending.map(r => r.tag).unwrap_or(0UL)),
          ("memory_response_data", 32, response_data),
        ] {
        records_put(simulator, name, width, value)
      }
      simulator.settle()
      if !reset {
        if !configured && records_output(simulator, "config_ready") == 1UL {
          configured = true
        } else if configured &&
          !published &&
          records_output(simulator, "publish_ready") == 1UL {
          published = true
        }
        let lanes = Array::makei(4, lane => read(HeadLane(lane)))
        let known = batches
          .iter()
          .flat_map(items => items.iter())
          .filter(item => item.0 == lanes)
          .to_array()
          .get(0)
        let (raw_fault, syntax_ok) = known
          .map(item => (item.1, item.2))
          .unwrap_or((12UL, false))
        if read(HeadReserve) == 1UL {
          assert_true(reserved < 4)
          assert_eq(lanes, batches[batch][reserved].0)
          reserved += 1
          total_reserved += 1
        }
        if read(InnerCommandValid) == 1UL && read(InnerCommandReady) == 1UL {
          inner_accepts += 1
        }
        model.step(
          read,
          raw_fault,
          syntax_ok,
          records_output(simulator, "halted") == 1UL,
        )
        if respond {
          assert_eq(records_output(simulator, "memory_response_ready"), 1UL)
        }
        if ready && records_output(simulator, "memory_request_valid") == 1UL {
          assert_true(pending is None)
          let r : FetchedUsefulNativeRequest = {
            tag: records_output(simulator, "memory_request_tag"),
            address: records_output(simulator, "memory_request_address"),
            write: records_output(simulator, "memory_request_write") == 1UL,
            bytes: records_output(simulator, "memory_request_bytes"),
            mask: records_output(simulator, "memory_request_mask"),
            data: records_output(simulator, "memory_request_data"),
          }
          assert_true(fetched_dma_request_ok(r))
          if r.write {
            assert_eq((r.address, r.data), (768UL, 4294967267UL))
            writes += 1
          }
          pending = Some(r)
        } else if respond &&
          records_output(simulator, "memory_response_ready") == 1UL {
          pending = None
        }
        if records_output(simulator, "completion_valid") == 1UL && edge % 5 != 0 {
          assert_true(retired < 4)
          assert_eq(records_output(simulator, "completion_id"), 73UL)
          assert_eq(
            records_output(simulator, "completion_fault"),
            batches[batch][retired].3,
          )
          retired += 1
          total_retired += 1
        }
      }
      packet_order.step(simulator, reset)
      simulator.rising_edge("clock")
      simulator.settle()
      packet_order.check(simulator)
      model.check(read)
      if !negative_seen && model.next != 0U {
        model.ticket[0] = model.ticket[0] ^ 0x80000000U
        try model.check(read) catch {
          _ => negative_seen = true
        } noraise {
          _ => fail("wrong high ticket accepted")
        }
        model.ticket[0] = model.ticket[0] ^ 0x80000000U
      }
      if retired == 4 {
        assert_true(pending is None)
        break
      }
    }
    assert_eq((reserved, retired), (4, 4))
  }
  assert_eq(
    (total_reserved, total_retired, writes, inner_accepts),
    (20, 20, 2, 3),
  )
  assert_true(negative_seen)
}
