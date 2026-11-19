///|
fn require_unsigned_port(
  port : String,
  signal : @wire.Signal,
  width : @ir.Width,
  bank : Bool,
) -> Unit raise MemoryComponentError {
  if signal.signal_type() != UInt(width) {
    if bank {
      raise ExpectedBankPort(port~, width=width.bits())
    }
    raise ExpectedRowPort(port~, width=width.bits())
  }
}

///|
fn bank_selector_valid(
  builder : @wire.ModuleBuilder,
  config : BankedMemoryConfig,
  selector : @wire.Signal,
) -> @wire.Signal raise {
  // For counts above one, a power-of-two bank count fills the exact selector
  // encoding space regardless of which public contract admitted the count.
  // Count one retains an explicit comparison because canonical widths are at
  // least one bit and therefore still have an invalid selector encoding.
  if config.bank_count() > 1 && is_power_of_two(config.bank_count()) {
    builder.constant(@wire.bits(1), 1UL)
  } else {
    let limit = builder.constant(
      UInt(config.bank_width()),
      config.bank_count().to_uint64(),
    )
    builder.less_than(selector, limit)
  }
}

///|
fn selected_bank_enable(
  builder : @wire.ModuleBuilder,
  selector : @wire.Signal,
  accepted : @wire.Signal,
  ordinal : Int32,
) -> @wire.Signal raise {
  let selected = builder.equal(
    selector,
    builder.constant(selector.signal_type(), ordinal.to_uint64()),
  )
  builder.bit_and(accepted, selected)
}

///|
fn select_read_data(
  builder : @wire.ModuleBuilder,
  selector : @wire.Signal,
  reads : ArrayView[@wire.Signal],
) -> @wire.Signal raise {
  let mut selected = reads[0]
  for ordinal in 1..<reads.length() {
    let is_bank = builder.equal(
      selector,
      builder.constant(selector.signal_type(), ordinal.to_uint64()),
    )
    selected = builder.mux(is_bank, reads[ordinal], selected)
  }
  selected
}

///|
fn require_banked_ports(
  config : BankedMemoryConfig,
  read_enable : @wire.Signal,
  read_bank : @wire.Signal,
  read_row : @wire.Signal,
  write_enable : @wire.Signal,
  write_bank : @wire.Signal,
  write_row : @wire.Signal,
  write_data : @wire.Signal,
  write_mask : @wire.Signal?,
) -> Unit raise MemoryComponentError {
  require_control_port("read_enable", read_enable)
  require_control_port("write_enable", write_enable)
  require_unsigned_port("read_bank", read_bank, config.bank_width(), true)
  require_unsigned_port("write_bank", write_bank, config.bank_width(), true)
  require_unsigned_port("read_row", read_row, config.row_width(), false)
  require_unsigned_port("write_row", write_row, config.row_width(), false)
  require_element_port("write_data", write_data, config.element_type())
  match (config.write_mask(), write_mask) {
    (WholeElement, None) => ()
    (WholeElement, Some(_)) => raise UnexpectedMaskSignal
    (Granular(_), None) => raise MissingMaskSignal
    (Granular(granularity), Some(mask)) => {
      let expected = config.element_type().width().bits() / granularity
      match mask.signal_type() {
        Bits(width) if width.bits() == expected => ()
        _ => raise ExpectedMaskPort(width=expected)
      }
    }
  }
}

///|
/// Elaborate a one-read/one-write split-address banked memory.
///
/// General bank counts explicitly compare selectors against `bank_count`; an
/// invalid selector accepts neither read nor write. A successful read produces
/// `response_valid` and selected-bank data one cycle later. Row bounds retain
/// the canonical memory's explicit `Fault` behavior.
pub fn banked_memory(
  builder : @wire.ModuleBuilder,
  config : BankedMemoryConfig,
  domain : @wire.ClockDomain,
  reset_signal : @wire.Signal,
  read_enable : @wire.Signal,
  read_bank : @wire.Signal,
  read_row : @wire.Signal,
  write_enable : @wire.Signal,
  write_bank : @wire.Signal,
  write_row : @wire.Signal,
  write_data : @wire.Signal,
  write_mask? : @wire.Signal,
) -> BankedMemorySignals raise {
  require_banked_ports(
    config, read_enable, read_bank, read_row, write_enable, write_bank, write_row,
    write_data, write_mask,
  )
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let read_bank_valid = bank_selector_valid(builder, config, read_bank)
  let write_bank_valid = bank_selector_valid(builder, config, write_bank)
  let read_accepted = builder.bit_and(
    builder.bit_and(read_enable, read_bank_valid),
    reset_inactive,
  )
  let write_accepted = builder.bit_and(
    builder.bit_and(write_enable, write_bank_valid),
    reset_inactive,
  )
  let delayed_bank = builder.register_in(
    domain,
    read_bank,
    reset~,
    enable=read_accepted,
  )
  let response_valid = builder.register_in(domain, read_accepted, reset~)
  let reads : Array[@wire.Signal] = []
  for ordinal in 0..<config.bank_count() {
    let memory = builder.synchronous_memory(
      "\{config.name()}.bank.\{ordinal}",
      config.element_type(),
      config.rows_per_bank().elements(),
      domain,
      read_write_policy=config.read_write_policy(),
      multi_write_policy=Reject,
      bounds_policy=Fault,
    )
    let read_selected = selected_bank_enable(
      builder, read_bank, read_accepted, ordinal,
    )
    reads.push(
      builder.memory_read(
        memory,
        "read",
        read_row,
        enable=read_selected,
        enable_behavior=HoldLast,
      ),
    )
    let write_selected = selected_bank_enable(
      builder, write_bank, write_accepted, ordinal,
    )
    match config.write_mask() {
      WholeElement => {
        guard write_mask is None else { raise UnexpectedMaskSignal }
        builder.memory_write(
          memory,
          "write",
          write_row,
          write_data,
          enable=write_selected,
        )
      }
      Granular(granularity) => {
        guard write_mask is Some(mask) else { raise MissingMaskSignal }
        builder.memory_write_masked(
          memory,
          "write",
          write_row,
          write_data,
          mask,
          granularity,
          enable=write_selected,
        )
      }
    }
  }
  {
    read_data: select_read_data(builder, delayed_bank, reads),
    read_accepted,
    response_valid,
    read_bank_valid,
    write_bank_valid,
    write_accepted,
  }
}

///|
/// Build a standalone banked-memory module with deterministic split-address
/// ports and derived per-bank names.
pub fn banked_memory_module(config : BankedMemoryConfig) -> @ir.Module raise {
  let builder = @wire.ModuleBuilder::new(config.name())
  let clock = builder.input("clock", Clock)
  let reset = builder.input("reset", Reset)
  let read_enable = builder.input("read_enable", @wire.bits(1))
  let read_bank = builder.input("read_bank", UInt(config.bank_width()))
  let read_row = builder.input("read_row", UInt(config.row_width()))
  let write_enable = builder.input("write_enable", @wire.bits(1))
  let write_bank = builder.input("write_bank", UInt(config.bank_width()))
  let write_row = builder.input("write_row", UInt(config.row_width()))
  let write_data = builder.input("write_data", config.element_type())
  let write_mask = match config.write_mask() {
    WholeElement => None
    Granular(granularity) =>
      Some(
        builder.input(
          "write_mask",
          @wire.bits(config.element_type().width().bits() / granularity),
        ),
      )
  }
  let signals = banked_memory(
    builder,
    config,
    builder.rising_edge(clock),
    reset,
    read_enable,
    read_bank,
    read_row,
    write_enable,
    write_bank,
    write_row,
    write_data,
    write_mask?,
  )
  let read_data = builder.output("read_data", config.element_type())
  let read_accepted = builder.output("read_accepted", @wire.bits(1))
  let response_valid = builder.output("response_valid", @wire.bits(1))
  let read_bank_valid = builder.output("read_bank_valid", @wire.bits(1))
  let write_bank_valid = builder.output("write_bank_valid", @wire.bits(1))
  let write_accepted = builder.output("write_accepted", @wire.bits(1))
  builder.connect(read_data, signals.read_data())
  builder.connect(read_accepted, signals.read_accepted())
  builder.connect(response_valid, signals.response_valid())
  builder.connect(read_bank_valid, signals.read_bank_valid())
  builder.connect(write_bank_valid, signals.write_bank_valid())
  builder.connect(write_accepted, signals.write_accepted())
  builder.finish()
}
