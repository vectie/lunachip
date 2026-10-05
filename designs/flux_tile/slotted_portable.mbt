///|
priv struct SlottedPortableSelections {
  a : @wire.RegisterHandle
  b : @wire.RegisterHandle
  c : @wire.RegisterHandle
}

///|
/// Construct a serial acknowledged host-memory engine with two A/B/C slots.
/// Command UInt1 slot selections latch on acceptance; successful host loads
/// publish exact selected shapes. Failed reloads invalidate only their slot.
/// This reuses one transfer controller and one compute/capture engine, not
/// concurrent dispatch or a frozen slot-bearing descriptor ABI.
/// See PHASE6_SLOTTED_PORTABLE.md.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.slotted_portable_tile(
///       rows=1,
///       columns=1,
///       max_reduction=4,
///       host_bytes=256UL,
///     )
///     .memories()
///     .length(),
///     6,
///   )
/// }
/// ```
pub fn slotted_portable_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
  host_bytes~ : UInt64,
) -> @ir.Module raise {
  let builder = portable_builder(
    "FluxTileSlottedPortable", rows, columns, max_reduction, host_bytes,
  )
  builder.parameter("slot_count", Signed(2))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let ports = portable_inputs(builder)
  let a = builder.input("command_a_slot", @wire.uint(1))
  let b = builder.input("command_b_slot", @wire.uint(1))
  let c = builder.input("command_c_slot", @wire.uint(1))
  let selections : SlottedPortableSelections = {
    a: builder.register_state_in(domain, @wire.uint(1), reset~),
    b: builder.register_state_in(domain, @wire.uint(1), reset~),
    c: builder.register_state_in(domain, @wire.uint(1), reset~),
  }
  let signals = build_portable_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    ports,
    rows,
    columns,
    max_reduction,
    host_bytes,
    storage_control=(registers, command, op, accept) => {
      portable_hold(builder, selections.a, accept, a)
      portable_hold(builder, selections.b, accept, b)
      portable_hold(builder, selections.c, accept, c)
      slotted_portable_storage(
        builder, domain, reset, registers, command, op, selections,
      )
    },
    core_control=inputs => {
      // One physical slotted core, allocated exactly once at the shared
      // portable graph's existing core-construction position.
      let registers = slotted_state(builder, domain, reset)
      let slotted_inputs : SlottedInputs = {
        stored: inputs,
        load_a_slot: selections.a.value(),
        load_b_slot: selections.b.value(),
        command_a_slot: selections.a.value(),
        command_b_slot: selections.b.value(),
        command_c_slot: selections.c.value(),
        read_slot: selections.c.value(),
      }
      let graph = build_slotted_graph(
        builder, domain, reset, reset_inactive, slotted_inputs, registers, rows,
        columns, max_reduction,
      )
      graph.stored
    },
  )
  execute_output(builder, "command_ready", signals.command_ready)
  execute_output(builder, "completion_valid", signals.completion_valid)
  execute_output(builder, "completion_id", signals.completion_id)
  execute_output(builder, "completion_fault", signals.completion_fault)
  execute_output(builder, "completion_bytes_completed", signals.bytes_completed)
  execute_output(builder, "completion_fault_address", signals.fault_address)
  portable_memory_outputs(builder, signals)
  builder.finish()
}
