///|
priv struct ExecuteBanks {
  data : Array[@wire.Signal]
  valid : Array[@wire.Signal]
  prefixes : Array[@wire.Signal]
  load_ready : @wire.Signal
}

///|
fn execute_operand_banks(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  name : String,
  bank_count : Int,
  capacity : Int,
  idle : @wire.Signal,
  load_valid : @wire.Signal,
  load_bank : @wire.Signal,
  load_index : @wire.Signal,
  load_data : @wire.Signal,
  read_launch : @wire.Signal,
  read_step : @wire.Signal,
  active_banks : @wire.Signal,
  reduction : @wire.Signal,
) -> ExecuteBanks raise {
  let data : Array[@wire.Signal] = []
  let valid : Array[@wire.Signal] = []
  let prefixes : Array[@wire.Signal] = []
  let mut load_ready = builder.constant(@wire.bits(1), 0UL)
  let address_width = @ir.MemoryDepth::new(capacity).address_width().bits()
  let write_address = builder.truncate(load_index, address_width)
  for ordinal in 0..<bank_count {
    let prefix = builder.register_state_in(domain, @wire.uint(13), reset~)
    prefixes.push(prefix.value())
    let selected = builder.equal(
      load_bank,
      execute_constant(builder, 4, ordinal),
    )
    let ready = execute_and(builder, [
      idle,
      selected,
      builder.less_than(load_index, execute_constant(builder, 13, capacity)),
      builder.less_equal(load_index, prefix.value()),
    ])
    load_ready = builder.bit_or(load_ready, ready)
    let write = builder.bit_and(ready, load_valid)
    let extend_prefix = builder.bit_and(
      write,
      builder.equal(load_index, prefix.value()),
    )
    builder.connect_next(
      prefix,
      builder.mux(
        extend_prefix,
        builder.add(prefix.value(), execute_constant(builder, 13, 1)),
        prefix.value(),
      ),
    )
    let offset = execute_constant(builder, 13, ordinal)
    let index = builder.sub(read_step, offset)
    let in_window = execute_and(builder, [
      builder.less_than(execute_constant(builder, 4, ordinal), active_banks),
      builder.greater_equal(read_step, offset),
      builder.less_than(index, reduction),
    ])
    let read_enable = builder.bit_and(read_launch, in_window)
    let safe_index = builder.mux(
      in_window,
      index,
      execute_constant(builder, 13, 0),
    )
    let memory = builder.synchronous_memory(
      "\{name}_bank_\{ordinal}",
      @wire.sint(8),
      capacity,
      domain,
      read_write_policy=ReadOld,
      multi_write_policy=Reject,
      bounds_policy=Fault,
    )
    data.push(
      builder.memory_read(
        memory,
        "read",
        builder.truncate(safe_index, address_width),
        enable=read_enable,
        enable_behavior=HoldLast,
      ),
    )
    valid.push(
      builder.register_in(domain, in_window, reset~, enable=read_launch),
    )
    builder.memory_write(
      memory,
      "write",
      write_address,
      load_data,
      enable=write,
    )
  }
  { data, valid, prefixes, load_ready, }
}

///|
fn execute_banks_loaded(
  builder : @wire.ModuleBuilder,
  prefixes : Array[@wire.Signal],
  requested_banks : @wire.Signal,
  requested_reduction : @wire.Signal,
) -> @wire.Signal raise {
  let checks : Array[@wire.Signal] = []
  for ordinal in 0..<prefixes.length() {
    let inactive = builder.greater_equal(
      execute_constant(builder, 4, ordinal),
      requested_banks,
    )
    let initialized = builder.greater_equal(
      prefixes[ordinal],
      requested_reduction,
    )
    checks.push(builder.bit_or(inactive, initialized))
  }
  execute_and(builder, checks)
}
