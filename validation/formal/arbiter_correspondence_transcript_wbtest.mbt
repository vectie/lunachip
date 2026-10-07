///|
// Fixed named response bytes for one public-device transcript. This is not a
// host-memory model: every accepted address, field, owner and tag is checked.
fn arbiter_transcript_request(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
  ordinal : Int,
) -> Unit raise {
  assert_true(ordinal >= 0 && ordinal < 7)
  let addresses = [32UL, 33UL, 64UL, 65UL, 128UL, 256UL, 129UL]
  let store = ordinal == 5
  assert_eq(records_output(source, "memory_request_tag"), ordinal.to_uint64())
  assert_eq(
    records_output(source, "memory_request_address"),
    addresses[ordinal],
  )
  assert_eq(
    records_output(source, "memory_request_write"),
    if store {
      1UL
    } else {
      0UL
    },
  )
  assert_eq(
    records_output(source, "memory_request_bytes"),
    if store {
      4UL
    } else {
      1UL
    },
  )
  assert_eq(
    records_output(source, "memory_request_mask"),
    if store {
      15UL
    } else {
      1UL
    },
  )
  assert_eq(
    records_output(source, "memory_request_data"),
    if store {
      31UL
    } else {
      0UL
    },
  )
  assert_eq(
    arbiter_correspondence_root(observer, source, "owner"),
    if store {
      1UL
    } else {
      0UL
    },
  )
  assert_eq(
    arbiter_correspondence_root(observer, source, "local_tag"),
    [0UL, 1UL, 2UL, 3UL, 4UL, 0UL, 5UL][ordinal],
  )
}

///|
fn arbiter_transcript_response(
  source : @sim.Simulator,
  ordinal : Int,
) -> Unit raise {
  assert_true(ordinal >= 0 && ordinal < 7)
  // A0=[2,3], B0=[5,7], A1=[-2,4], StoreC0 acknowledgement has no data.
  let named_response_bytes = [2UL, 3UL, 5UL, 7UL, 254UL, 0UL, 4UL]
  records_put(source, "memory_response_valid", 1, 1UL)
  records_put(source, "memory_response_tag", 32, ordinal.to_uint64())
  records_put(source, "memory_response_fault", 2, 0UL)
  records_put(source, "memory_response_data", 32, named_response_bytes[ordinal])
}

///|
fn arbiter_transcript_setup(
  observer : ArbiterCorrespondence,
  source : @sim.Simulator,
) -> Unit raise {
  let packets = [
    records_packet(0UL, 1UL, 2UL, 0UL, 32UL, 2UL),
    records_packet(1UL, 2UL, 1UL, 0UL, 64UL, 1UL),
    records_packet(2UL, 1UL, 1UL, 2UL, 0UL, 0UL),
  ]
  let mut requests = 0
  let mut pending : Int? = None
  for packet_index, packet in packets {
    let mut admitted = false
    let mut completed = false
    for _ in 0..<256 {
      records_present(source, if admitted { None } else { Some(packet) })
      records_put(source, "memory_response_valid", 1, 0UL)
      if pending is Some(ordinal) {
        arbiter_transcript_response(source, ordinal)
      }
      source.settle()
      let push = !admitted && records_output(source, "descriptor_ready") == 1UL
      let request = records_output(source, "memory_request_valid") == 1UL
      let response = pending is Some(_) &&
        records_output(source, "memory_response_ready") == 1UL
      let retire = records_output(source, "completion_valid") == 1UL
      if request {
        assert_eq(pending, None)
        assert_true(requests < 4)
        arbiter_transcript_request(observer, source, requests)
      }
      if retire {
        assert_eq(records_output(source, "completion_id"), 73UL)
        assert_eq(records_output(source, "completion_fault"), 0UL)
        assert_eq(
          records_output(source, "completion_bytes_completed"),
          if packet_index == 2 {
            0UL
          } else {
            2UL
          },
        )
        assert_eq(records_output(source, "completion_fault_address"), 0UL)
      }
      arbiter_correspondence_tick(observer, source)
      if push {
        admitted = true
      }
      if response {
        pending = None
      }
      if request {
        pending = Some(requests)
        requests += 1
      }
      if retire {
        completed = true
        break
      }
    }
    assert_true(admitted && completed)
  }
  assert_eq(requests, 4)
  assert_eq(pending, None)
  records_present(source, None)
  records_put(source, "memory_response_valid", 1, 0UL)
}
