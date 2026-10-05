///|
fn build_ring_graph(
  builder : @wire.ModuleBuilder,
  registers : RingRegisters,
  reset_inactive : @wire.Signal,
  ports : RingInputs,
  host_bytes : UInt64,
  ring_depth : Int,
  transport_poison? : @wire.Signal,
) -> RingSignals raise {
  let {
    state,
    base,
    origin,
    producer,
    consumer,
    configured,
    cursor,
    tag,
    expected_tag,
    fault,
    fault_address,
    lanes,
  } = registers
  // Unconfigured, ValidateConfig, Ready, Request, WaitResponse, Packet, Fault.
  // A shared-bus poison freezes this client without fabricating a response.
  // Standalone construction adds no nodes; an owned terminal fault remains
  // visible even when the shared transport has poisoned further activity.
  let active_gate = match transport_poison {
    None => reset_inactive
    Some(poison) => builder.bit_and(reset_inactive, builder.bit_not(poison))
  }
  let states : Array[@wire.Signal] = []
  for index in 0..<7 {
    states.push(
      execute_and(builder, [
        if index == 6 {
          reset_inactive
        } else {
          active_gate
        },
        builder.equal(state.value(), execute_constant(builder, 3, index)),
      ]),
    )
  }
  let config_accept = builder.bit_and(states[0], ports.config_valid)
  portable_hold(builder, base, config_accept, ports.config_base)
  portable_hold(builder, origin, config_accept, ports.config_origin)
  let aligned = builder.equal(
    builder.bit_and(base.value(), execute_constant(builder, 32, 31)),
    execute_constant(builder, 32, 0),
  )
  let end_exclusive = builder.add(
    builder.zero_extend(base.value(), 64),
    execute_constant(builder, 64, ring_depth * 32),
  )
  let in_aperture = builder.less_equal(
    end_exclusive,
    builder.constant(@wire.uint(64), host_bytes),
  )
  let config_ok = execute_and(builder, [states[1], aligned, in_aperture])
  let config_bad = builder.bit_and(
    states[1],
    builder.bit_not(builder.bit_and(aligned, in_aperture)),
  )
  builder.connect_next(
    configured,
    builder.bit_or(configured.value(), config_ok),
  )
  let packet_accept = builder.bit_and(states[5], ports.descriptor_ready)
  // Publication cannot retract a stalled request or packet. A delivered
  // packet still owns its slot during publication capacity validation.
  let publish_ready = builder.bit_or(states[2], packet_accept)
  let publish_accept = builder.bit_and(publish_ready, ports.publish_valid)
  let occupancy = builder.sub(producer.value(), consumer.value())
  let free = builder.sub(execute_constant(builder, 32, ring_depth), occupancy)
  let advance = builder.sub(ports.publish_producer, producer.value())
  let publication_ok = builder.less_equal(advance, free)
  let publication_bad = builder.bit_and(
    publish_accept,
    builder.bit_not(publication_ok),
  )
  builder.connect_next(
    producer,
    builder.mux(
      config_ok,
      origin.value(),
      builder.mux(
        builder.bit_and(publish_accept, publication_ok),
        ports.publish_producer,
        producer.value(),
      ),
    ),
  )
  builder.connect_next(
    consumer,
    builder.mux(
      config_ok,
      origin.value(),
      builder.mux(
        packet_accept,
        builder.add(consumer.value(), execute_constant(builder, 32, 1)),
        consumer.value(),
      ),
    ),
  )
  let nonempty = builder.bit_not(
    builder.equal(producer.value(), consumer.value()),
  )
  let start = execute_and(builder, [
    states[2],
    nonempty,
    builder.bit_not(publication_bad),
  ])
  // UInt64 address arithmetic precedes explicit truncation. Configuration
  // bounds cover every fixed-size slot; cursor remains in 0..31.
  let slot = builder.bit_and(
    consumer.value(),
    execute_constant(builder, 32, ring_depth - 1),
  )
  let offset = builder.mul_low(
    builder.zero_extend(slot, 64),
    execute_constant(builder, 64, 32),
  )
  let wide_address = builder.add(
    builder.add(builder.zero_extend(base.value(), 64), offset),
    builder.zero_extend(cursor.value(), 64),
  )
  let address = builder.truncate(wide_address, 32)
  let request_accept = builder.bit_and(states[3], ports.request_ready)
  portable_hold(
    builder,
    tag,
    request_accept,
    builder.add(tag.value(), execute_constant(builder, 32, 1)),
  )
  portable_hold(builder, expected_tag, request_accept, tag.value())
  let response_accept = builder.bit_and(states[4], ports.response_valid)
  let malformed = builder.bit_or(
    builder.bit_not(builder.equal(ports.response_tag, expected_tag.value())),
    builder.greater_equal(ports.response_fault, execute_constant(builder, 2, 2)),
  )
  let protocol_fault = builder.bit_and(response_accept, malformed)
  let matched = builder.bit_and(response_accept, builder.bit_not(malformed))
  let remote_fault = builder.bit_and(
    matched,
    builder.equal(ports.response_fault, execute_constant(builder, 2, 1)),
  )
  let response_good = builder.bit_and(
    matched,
    builder.equal(ports.response_fault, execute_constant(builder, 2, 0)),
  )
  let response_bad = builder.bit_or(protocol_fault, remote_fault)
  let last = builder.equal(cursor.value(), execute_constant(builder, 5, 31))
  builder.connect_next(
    cursor,
    builder.mux(
      start,
      execute_constant(builder, 5, 0),
      builder.mux(
        response_good,
        builder.add(cursor.value(), execute_constant(builder, 5, 1)),
        cursor.value(),
      ),
    ),
  )
  let byte_index = builder.reinterpret(
    builder.slice(cursor.value(), 2, 0),
    @wire.uint(3),
  )
  let shift = builder.mul_low(
    builder.zero_extend(byte_index, 6),
    execute_constant(builder, 6, 8),
  )
  let byte = builder.zero_extend(builder.slice(ports.response_data, 7, 0), 64)
  let shifted_byte = builder.shift_left(byte, shift)
  let lane_index = builder.reinterpret(
    builder.slice(cursor.value(), 4, 3),
    @wire.uint(2),
  )
  for index in 0..<4 {
    let update = builder.bit_and(
      response_good,
      builder.equal(lane_index, execute_constant(builder, 2, index)),
    )
    builder.connect_next(
      lanes[index],
      builder.mux(
        start,
        builder.constant(@wire.bits(64), 0UL),
        builder.mux(
          update,
          builder.bit_or(lanes[index].value(), shifted_byte),
          lanes[index].value(),
        ),
      ),
    )
  }
  let terminal = builder.bit_or(
    config_bad,
    builder.bit_or(publication_bad, response_bad),
  )
  let config_fault = builder.mux(
    aligned,
    execute_constant(builder, 3, 2),
    execute_constant(builder, 3, 1),
  )
  let response_fault = builder.mux(
    protocol_fault,
    execute_constant(builder, 3, 5),
    execute_constant(builder, 3, 4),
  )
  let fault_code = builder.mux(
    config_bad,
    config_fault,
    builder.mux(
      publication_bad,
      execute_constant(builder, 3, 3),
      response_fault,
    ),
  )
  portable_hold(builder, fault, terminal, fault_code)
  portable_hold(
    builder,
    fault_address,
    terminal,
    builder.mux(
      config_bad,
      base.value(),
      builder.mux(publication_bad, execute_constant(builder, 32, 0), address),
    ),
  )
  let hold = state.value()
  let transitions = [
    builder.mux(config_accept, execute_constant(builder, 3, 1), hold),
    builder.mux(
      config_ok,
      execute_constant(builder, 3, 2),
      execute_constant(builder, 3, 6),
    ),
    builder.mux(
      publication_bad,
      execute_constant(builder, 3, 6),
      builder.mux(start, execute_constant(builder, 3, 3), hold),
    ),
    builder.mux(request_accept, execute_constant(builder, 3, 4), hold),
    builder.mux(
      response_bad,
      execute_constant(builder, 3, 6),
      builder.mux(
        response_good,
        builder.mux(
          last,
          execute_constant(builder, 3, 5),
          execute_constant(builder, 3, 3),
        ),
        hold,
      ),
    ),
    builder.mux(
      publication_bad,
      execute_constant(builder, 3, 6),
      builder.mux(packet_accept, execute_constant(builder, 3, 2), hold),
    ),
    hold,
  ]
  let mut next = hold
  for index in 0..<7 {
    next = builder.mux(states[index], transitions[index], next)
  }
  builder.connect_next(state, next)
  {
    config_ready: states[0],
    publish_ready,
    configured: builder.bit_and(configured.value(), reset_inactive),
    producer_count: producer.value(),
    consumer_count: consumer.value(),
    descriptor_valid: states[5],
    descriptor_lanes: lanes.map(lane => lane.value()),
    fault_valid: states[6],
    fault_code: fault.value(),
    fault_address: fault_address.value(),
    request_valid: states[3],
    request_write: builder.constant(@wire.bits(1), 0UL),
    address,
    request_bytes: execute_constant(builder, 3, 1),
    request_mask: builder.constant(@wire.bits(4), 1UL),
    request_data: builder.constant(@wire.bits(32), 0UL),
    request_tag: tag.value(),
    response_ready: states[4],
  }
}
