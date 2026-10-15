///|
fn fetched_dma_request_ok(r : FetchedUsefulNativeRequest) -> Bool {
  r.address <= 0xffffffffUL &&
  r.address + r.bytes <= 1024UL &&
  (if r.write {
    r.bytes == 4UL && r.mask == 15UL && (r.address & 3UL) == 0UL
  } else {
    r.bytes == 1UL && r.mask == 1UL && r.data == 0UL
  })
}

///|
fn fetched_dma_check_native(
  aliases : Array[QueueControlAlias],
  simulator : @sim.Simulator,
) -> Unit raise {
  for (client, bytes) in [("loader", 1UL), ("storer", 4UL)] {
    let read = field => {
      let binding = aliases.filter(item => {
          item.name == "composition_dma_" + client + "_" + field
        })[0]
      simulator.value(binding.node).to_uint64()
    }
    let state = read("state")
    if state >= 1UL && state <= 3UL {
      let rows = read("rows")
      let columns = read("columns")
      let row = read("row")
      let column = read("column")
      let base = read("base")
      let stride = read("stride")
      assert_true(rows >= 1UL && columns >= 1UL)
      assert_true(row < rows && column < columns)
      assert_true(base + (rows - 1UL) * stride + columns * bytes <= 1024UL)
      assert_true(stride >= columns * bytes)
      assert_eq(read("address_full"), base + row * stride + column * bytes)
      assert_true(read("address_full") + bytes <= 1024UL)
      if bytes == 4UL {
        assert_eq((base & 3UL, stride & 3UL), (0UL, 0UL))
      }
    }
  }
}

///|
test "fetched DMA native aperture edges reject full width overflow and preserve numeric Store under stalls" {
  let sequential = fetched_transport_sequential()
  let aliases = fetched_dma_roots(sequential)
  // Packet index, base, stride, expected fault, whether the Store is legal.
  for
    (changed, base, stride, fault, store_legal) in [
      (3, 1020UL, 0xfffffffcUL, 0UL, true),
      (3, 0xfffffffcUL, 4UL, 8UL, false),
      (3, 1024UL, 4UL, 8UL, false),
      (3, 1022UL, 4UL, 7UL, false),
      (3, 1020UL, 0UL, 6UL, false),
      (0, 0xffffffffUL, 2UL, 8UL, false),
      (0, 1023UL, 2UL, 8UL, false),
      (0, 256UL, 1UL, 6UL, false),
      (1, 512UL, 0xffffffffUL, 8UL, false),
    ] {
    let simulator = @sim.Simulator::prepare(sequential.probe.source)
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
    let packets = Array::makei(4, index => fetched_useful_packet(index))
    packets[changed][2] = base | (stride << 32)
    let mut configured = false
    let mut published = false
    let mut pending : FetchedUsefulNativeRequest? = None
    let mut held : FetchedUsefulNativeRequest? = None
    let mut retired = 0
    let mut writes = 0
    let mut request_stall_seen = false
    for edge in 0..<1200 {
      let ready = edge % 4 == 0
      let respond = pending is Some(_) && edge % 3 == 0
      let response_data = match pending {
        Some(r) if !r.write && r.address < 128UL => {
          let offset = (r.address % 32UL).to_int()
          (packets[(r.address / 32UL).to_int()][offset / 8] >> (offset % 8 * 8)) &
          255UL
        }
        Some(r) if !r.write => fetched_useful_native_data(r.address)
        _ => 0UL
      }
      for
        (name, width, value) in [
          ("reset", 1, if edge == 0 { 1UL } else { 0UL }),
          ("config_valid", 1, if edge > 0 && !configured { 1UL } else { 0UL }),
          ("publish_valid", 1, if configured && !published { 1UL } else { 0UL }),
          ("publish_producer", 32, 4UL),
          ("completion_ready", 1, 1UL),
          ("memory_request_ready", 1, if ready { 1UL } else { 0UL }),
          ("memory_response_valid", 1, if respond { 1UL } else { 0UL }),
          ("memory_response_tag", 32, pending.map(r => r.tag).unwrap_or(0UL)),
          ("memory_response_data", 32, response_data),
        ] {
        records_put(simulator, name, width, value)
      }
      simulator.settle()
      if edge > 0 {
        fetched_dma_check_native(aliases, simulator)
        if !configured && records_output(simulator, "config_ready") == 1UL {
          configured = true
        } else if configured &&
          !published &&
          records_output(simulator, "publish_ready") == 1UL {
          published = true
        }
        let offer = if records_output(simulator, "memory_request_valid") == 1UL {
          Some(FetchedUsefulNativeRequest::{
            tag: records_output(simulator, "memory_request_tag"),
            address: records_output(simulator, "memory_request_address"),
            write: records_output(simulator, "memory_request_write") == 1UL,
            bytes: records_output(simulator, "memory_request_bytes"),
            mask: records_output(simulator, "memory_request_mask"),
            data: records_output(simulator, "memory_request_data"),
          })
        } else {
          None
        }
        if held is Some(old) {
          guard offer is Some(current) else { fail("held DMA disappeared") }
          assert_eq(
            (
              current.tag,
              current.address,
              current.write,
              current.bytes,
              current.mask,
              current.data,
            ),
            (old.tag, old.address, old.write, old.bytes, old.mask, old.data),
          )
          request_stall_seen = true
        }
        held = if ready { None } else { offer }
        if offer is Some(r) {
          assert_true(fetched_dma_request_ok(r))
          if r.write {
            assert_eq((r.address, r.data), (base, 4294967267UL))
          }
          if ready {
            assert_true(pending is None)
            pending = Some(r)
            if r.write {
              writes += 1
            }
          }
        } else if respond &&
          records_output(simulator, "memory_response_ready") == 1UL {
          pending = None
        }
        if records_output(simulator, "completion_valid") == 1UL {
          if retired == changed {
            assert_eq(records_output(simulator, "completion_fault"), fault)
          }
          retired += 1
        }
        if retired == 4 {
          break
        }
      }
      simulator.rising_edge("clock")
      simulator.settle()
      fetched_dma_check_native(aliases, simulator)
    }
    assert_eq(retired, 4)
    assert_eq(writes, if store_legal { 1 } else { 0 })
    assert_true(request_stall_seen)
  }
}

///|
test "fetched DMA checker rejects wrapped address and corrupted payload controls" {
  let valid : FetchedUsefulNativeRequest = {
    tag: 0UL,
    address: 1020UL,
    write: true,
    bytes: 4UL,
    mask: 15UL,
    data: 0xffffffE3UL,
  }
  assert_true(fetched_dma_request_ok(valid))
  for
    bad in [
      { ..valid, address: 0xfffffffcUL, },
      { ..valid, address: 1024UL, },
      { ..valid, address: 1021UL, },
      { ..valid, bytes: 1UL, },
      { ..valid, mask: 1UL, },
      { ..valid, address: 0UL, write: false, bytes: 1UL, mask: 1UL, data: 1UL, },
    ] {
    assert_false(fetched_dma_request_ok(bad))
  }
}
