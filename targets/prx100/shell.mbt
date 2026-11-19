///|
/// Elaborate UART/control and the independent 4KiB memory aperture.
/// `divisor` is434 for the physical50MHz target; smaller test divisors have
/// distinct IR identities and are never exported as board bitstream inputs.
pub fn shell(profile : Profile, divisor~ : Int32 = 434) -> @ir.Module raise {
  build_shell(profile, divisor, false)
}

///|
/// Expose the exact control graph at its UART byte handshake for fast digital
/// integration tests. This separate module is never the physical board input.
pub fn byte_shell(profile : Profile) -> @ir.Module raise {
  build_shell(profile, 434, true)
}

///|
fn build_shell(
  profile : Profile,
  divisor : Int32,
  raw_bytes : Bool,
) -> @ir.Module raise {
  guard divisor >= 8 && divisor <= 65535 else { raise InvalidDivisor(divisor) }
  let b = @wire.ModuleBuilder::new(
    if raw_bytes {
      "Prx100ByteBramShell"
    } else {
      "Prx100UartBramShell"
    },
  )
  b.parameter("uart_divisor", Signed(divisor.to_int64()))
  let clock = b.input("clock", @wire.clock())
  let domain = b.rising_edge(clock)
  let reset_signal = b.input("reset", @wire.reset())
  b.input_timing(reset_signal, SampledIn(domain.id()))
  let reset = b.synchronous_reset(reset_signal, 0UL)
  let active = b.bit_not(b.reset_asserted(reset_signal))
  let ports : Map[String, @wire.Signal] = Map([])
  for port in core(profile).outputs() {
    let input = b.input("c_" + port.name(), port.signal_type())
    b.input_timing(input, SampledIn(domain.id()))
    ports[port.name()] = input
  }
  let state = b.register_state_in(domain, @wire.uint(3), reset~)
  let receiving = same(b, state.value(), 0UL)
  let executing = same(b, state.value(), 1UL)
  let read_wait = same(b, state.value(), 2UL)
  let resetting = same(b, state.value(), 3UL)
  let sending = same(b, state.value(), 4UL)
  let draining = same(b, state.value(), 5UL)
  let rx = if raw_bytes {
    Receiver::{
      valid: sampled_input(b, domain, "rx_valid", @wire.bits(1)),
      data: sampled_input(b, domain, "rx_data", @wire.uint(8)),
      error: sampled_input(b, domain, "rx_error", @wire.bits(1)),
    }
  } else {
    let pin = b.input("uart_rx", @wire.bits(1))
    b.input_timing(pin, Asynchronous)
    uart_receiver(b, domain, reset_signal, reset, pin, divisor)
  }
  let packet = packet_receiver(
    b,
    domain,
    reset,
    b.bit_and(active, receiving),
    rx,
    divisor,
  )
  let tx = if raw_bytes { None } else { Some(transmitter(b, domain, reset)) }
  let tx_ready = match tx {
    Some(tx) => tx.ready
    None => sampled_input(b, domain, "tx_ready", @wire.bits(1))
  }
  let bus = aperture_registers(b, domain, reset)
  let retired = b.register_state_in(domain, @wire.uint(32), reset~)
  let idle = all(b, [
    b.equal(ports["producer_count"], retired.value()),
    b.bit_not(ports["completion_valid"]),
    b.bit_not(bus.pending.value()),
  ])
  let op = packet.opcode
  let argument = packet.argument
  let data = packet.data
  let ops : Array[@wire.Signal] = []
  for ordinal in 0..<10 {
    ops.push(same(b, op, ordinal.to_uint64()))
  }
  let no_args = all(b, [same(b, argument, 0UL), same(b, data, 0UL)])
  let syntax = b.mux(
    either(b, [ops[1], ops[3]]),
    b.constant(@wire.bits(1), 1UL),
    b.mux(either(b, [ops[2], ops[4]]), same(b, data, 0UL), no_args),
  )
  let known_op = b.less_equal(op, number(b, 8, 9UL))
  let valid_command = all(b, [executing, syntax, known_op, active])
  let memory_op = either(b, [ops[1], ops[2]])
  let bounded = word_address_valid(b, argument)
  let memory_access = all(b, [valid_command, memory_op, idle, bounded])
  let host_read = b.bit_and(memory_access, ops[2])
  let host_write = b.bit_and(memory_access, ops[1])
  let configure = all(b, [valid_command, ops[3], idle, ports["config_ready"]])
  let publish = all(b, [valid_command, ops[4], idle, ports["publish_ready"]])
  let complete = all(b, [valid_command, ops[5], ports["completion_valid"]])
  let do_reset = b.bit_and(valid_command, ops[8])
  let word = finish_aperture(
    b, domain, ports, bus, active, resetting, host_read, host_write, argument, data,
  )
  b.connect_next(
    retired,
    b.mux(
      resetting,
      number(b, 32, 0UL),
      b.mux(
        configure,
        data,
        b.mux(
          complete,
          b.add(retired.value(), number(b, 32, 1UL)),
          retired.value(),
        ),
      ),
    ),
  )
  output(
    b,
    "core_reset",
    either(b, [b.reset_asserted(reset_signal), resetting]),
  )
  output(b, "config_valid", configure)
  output(b, "config_base", argument)
  output(b, "config_origin", data)
  output(b, "publish_valid", publish)
  output(b, "publish_producer", argument)
  output(b, "completion_ready", complete)
  let status = b.register_state_in(domain, @wire.uint(8), reset~)
  let reply_op = b.register_state_in(domain, @wire.uint(8), reset~)
  let sequence = b.register_state_in(domain, @wire.uint(16), reset~)
  b.connect_next(
    reply_op,
    b.mux(packet.complete, b.bit_or(op, number(b, 8, 128UL)), reply_op.value()),
  )
  b.connect_next(
    sequence,
    b.mux(packet.complete, packet.sequence, sequence.value()),
  )
  let busy = either(b, [
    all(b, [memory_op, b.bit_not(idle)]),
    all(b, [ops[3], b.bit_not(configure)]),
    all(b, [ops[4], b.bit_not(publish)]),
  ])
  let result_status = b.mux(
    b.bit_not(b.bit_and(syntax, known_op)),
    number(b, 8, 2UL),
    b.mux(
      busy,
      number(b, 8, 4UL),
      b.mux(
        all(b, [memory_op, b.bit_not(bounded)]),
        number(b, 8, 3UL),
        b.mux(
          all(b, [ops[5], b.bit_not(ports["completion_valid"])]),
          number(b, 8, 5UL),
          number(b, 8, 0UL),
        ),
      ),
    ),
  )
  b.connect_next(
    status,
    b.mux(
      packet.complete,
      number(b, 8, 1UL),
      b.mux(executing, result_status, status.value()),
    ),
  )
  let words : Array[@wire.Signal] = []
  let flags = little_flags(b, [
    ports["configured"],
    ports["ring_fault_valid"],
    ports["halted"],
    ports["transport_halted"],
    ports["completion_valid"],
    idle,
  ])
  let counts = as_uint(
    b,
    b.concat(
      b.zero_extend(ports["capture_cycles"], 16),
      b.zero_extend(ports["accepted_steps"], 16),
    ),
  )
  let groups : Array[Array[@wire.Signal]] = [
    [
      number(b, 32, 0x50525831UL),
      number(b, 32, 1UL),
      number(b, 32, 4096UL),
      number(b, 32, (profile.rows() * 256 + profile.rows()).to_uint64()),
      number(b, 32, profile.reduction().to_uint64()),
    ],
    [
      ports["completion_id"],
      b.zero_extend(ports["completion_fault"], 32),
      ports["completion_bytes_completed"],
      ports["completion_fault_address"],
      number(b, 32, 0UL),
    ],
    [
      flags,
      ports["producer_count"],
      ports["consumer_count"],
      retired.value(),
      b.zero_extend(ports["queue_occupancy"], 32),
    ],
    [
      as_uint(b, b.slice(ports["elapsed_cycles"], 31, 0)),
      as_uint(b, b.slice(ports["elapsed_cycles"], 63, 32)),
      as_uint(b, b.slice(ports["active_cycles"], 31, 0)),
      as_uint(b, b.slice(ports["active_cycles"], 63, 32)),
      counts,
    ],
    [
      b.zero_extend(ports["ring_fault_code"], 32),
      ports["ring_fault_address"],
      ports["transport_fault_address"],
      as_uint(b, b.slice(ports["stall_cycles"], 31, 0)),
      as_uint(b, b.slice(ports["stall_cycles"], 63, 32)),
    ],
  ]
  for index in 0..<5 {
    let register = b.register_state_in(domain, @wire.uint(32), reset~)
    let selected = b.mux(
      ops[0],
      groups[0][index],
      b.mux(
        ops[5],
        groups[1][index],
        b.mux(
          ops[6],
          groups[2][index],
          b.mux(
            ops[7],
            groups[3][index],
            b.mux(ops[9], groups[4][index], number(b, 32, 0UL)),
          ),
        ),
      ),
    )
    let value = b.mux(same(b, result_status, 0UL), selected, number(b, 32, 0UL))
    b.connect_next(
      register,
      b.mux(
        packet.complete,
        number(b, 32, 0UL),
        b.mux(
          executing,
          value,
          if index == 0 {
            b.mux(read_wait, word, register.value())
          } else {
            register.value()
          },
        ),
      ),
    )
    words.push(register.value())
  }
  let reply_index = b.register_state_in(domain, @wire.uint(5), reset~)
  let reply_crc = b.register_state_in(domain, @wire.uint(8), reset~)
  let byte = reply_byte(
    b,
    reply_index.value(),
    reply_op.value(),
    sequence.value(),
    status.value(),
    words,
    reply_crc.value(),
  )
  let tx_accept = all(b, [sending, tx_ready, active])
  let last = same(b, reply_index.value(), 31UL)
  let begin_reply = either(b, [
    all(b, [packet.complete, b.bit_not(packet.valid)]),
    all(b, [executing, b.bit_not(either(b, [host_read, do_reset]))]),
    read_wait,
    resetting,
  ])
  b.connect_next(
    reply_index,
    b.mux(
      begin_reply,
      number(b, 5, 0UL),
      b.mux(
        tx_accept,
        b.add(reply_index.value(), number(b, 5, 1UL)),
        reply_index.value(),
      ),
    ),
  )
  let crc_byte = all(b, [
    tx_accept,
    b.greater_equal(reply_index.value(), number(b, 5, 2UL)),
    b.less_equal(reply_index.value(), number(b, 5, 29UL)),
  ])
  b.connect_next(
    reply_crc,
    b.mux(
      begin_reply,
      number(b, 8, 0UL),
      b.mux(crc_byte, crc_step(b, reply_crc.value(), byte), reply_crc.value()),
    ),
  )
  b.connect_next(
    state,
    b.mux(
      packet.valid,
      number(b, 3, 1UL),
      b.mux(
        begin_reply,
        number(b, 3, 4UL),
        b.mux(
          host_read,
          number(b, 3, 2UL),
          b.mux(
            do_reset,
            number(b, 3, 3UL),
            b.mux(
              all(b, [tx_accept, last]),
              number(b, 3, 5UL),
              b.mux(
                all(b, [draining, tx_ready]),
                number(b, 3, 0UL),
                state.value(),
              ),
            ),
          ),
        ),
      ),
    ),
  )
  match tx {
    Some(tx) =>
      output(
        b,
        "uart_tx",
        finish_transmitter(b, tx, b.bit_and(sending, active), byte, divisor),
      )
    None => {
      output(b, "tx_valid", b.bit_and(sending, active))
      output(b, "tx_data", byte)
    }
  }
  b.finish()
}

///|
fn little_flags(
  b : @wire.ModuleBuilder,
  flags : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut result = number(b, 32, 0UL)
  for index, flag in flags {
    result = b.bit_or(
      result,
      b.shift_left(
        b.zero_extend(as_uint(b, flag), 32),
        number(b, 5, index.to_uint64()),
      ),
    )
  }
  result
}

///|
fn reply_byte(
  b : @wire.ModuleBuilder,
  index : @wire.Signal,
  op : @wire.Signal,
  sequence : @wire.Signal,
  status : @wire.Signal,
  words : ArrayView[@wire.Signal],
  crc : @wire.Signal,
) -> @wire.Signal raise {
  let bytes : Array[@wire.Signal] = [
    number(b, 8, 0xa5UL),
    number(b, 8, 0x5aUL),
    number(b, 8, 1UL),
    op,
    byte_at(b, sequence, 0),
    byte_at(b, sequence, 1),
    status,
    number(b, 8, 0UL),
  ]
  for word in words {
    for offset in 0..<4 {
      bytes.push(byte_at(b, word, offset))
    }
  }
  bytes.push(number(b, 8, 0UL))
  bytes.push(number(b, 8, 0UL))
  bytes.push(crc)
  bytes.push(number(b, 8, 0x0dUL))
  let mut result = bytes[31]
  for offset in 0..<31 {
    result = b.mux(same(b, index, offset.to_uint64()), bytes[offset], result)
  }
  result
}
