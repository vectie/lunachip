///|
/// Verification component using the exact production word loader functions.
/// Command admission is Idle plus valid, with production rectangle preflight;
/// memory replies, poison and both bank-ready inputs are external cuts. This
/// contains no arbiter, queue or SRAM and makes no full-device proof claim.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.word_loader_verification_fixture().memories().length(),
///     0,
///   )
/// }
/// ```
pub fn word_loader_verification_fixture() -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("FluxTileWordLoaderVerification")
  let d = b.rising_edge(b.input("clock", @wire.clock()))
  let rs = b.input("reset", @wire.reset())
  let reset = b.synchronous_reset(rs, 0UL)
  let live = b.bit_not(b.reset_asserted(rs))
  let poison = b.input("poison", @wire.bits(1))
  let state = concurrent_loader_state(b, d, reset, word_reads=true)
  let view = concurrent_loader_view(b, state, live, poison)
  let ports = concurrent_transfer_inputs(b, "load", true)
  let route : ArbiterClientRoute = {
    request_ready: b.input("request_ready", @wire.bits(1)),
    response_valid: b.input("response_valid", @wire.bits(1)),
    response_tag: b.input("response_tag", @wire.uint(32)),
    response_fault: b.input("response_fault", @wire.uint(2)),
    response_data: b.input("response_data", @wire.bits(32)),
  }
  let a_ready = b.input("a_ready", @wire.bits(1))
  let b_ready = b.input("b_ready", @wire.bits(1))
  // Only the two bank-ready fields are consumed by the production loader.
  // Reuse existing signals for structurally required, unused result fields.
  let core : StoredSignals = {
    execute: {
      load_a_ready: a_ready,
      load_b_ready: b_ready,
      command_ready: a_ready,
      completion_valid: a_ready,
      completion_id: route.response_tag,
      completion_fault: route.response_fault,
      accepted_steps: route.response_tag,
      elapsed_cycles: route.response_tag,
      active_cycles: route.response_tag,
      stall_cycles: route.response_tag,
      accumulators: [],
      active_rows: route.response_tag,
      active_columns: route.response_tag,
      legal: a_ready,
    },
    capture_cycles: route.response_tag,
    read_ready: a_ready,
    response_valid: route.response_valid,
    response_id: route.response_tag,
    response_fault: route.response_fault,
    response_data: route.response_data,
  }
  let accept = execute_and(b, [view.states[0], ports.valid, b.bit_not(poison)])
  let preflight = concurrent_transfer_fault(
    b,
    ports,
    8,
    8,
    16,
    4096UL,
    false,
    b.constant(@wire.bits(1), 1UL),
  )
  let finish = concurrent_loader_connect(
    b, state, ports, view, route, core, accept, preflight, poison,
  )
  let request = view.request
  for
    (name, value) in [
      ("request_valid", request.valid),
      ("request_write", request.write),
      ("request_address", request.address),
      ("request_bytes", request.bytes),
      ("request_mask", request.mask),
      ("request_data", request.data),
      ("request_tag", request.tag),
      ("response_ready", view.response_ready),
      ("a_valid", view.a_valid),
      ("b_valid", view.b_valid),
      ("a_row", view.a_row),
      ("a_index", view.a_index),
      ("b_column", view.b_column),
      ("b_index", view.b_index),
      ("data", view.data),
      ("slot", view.slot),
      ("active", view.active),
      ("finish", finish),
      ("state", state.transfer.state.value()),
      ("word", state.byte.value()),
      ("remaining", state.remaining.unwrap().value()),
      ("row", state.transfer.row.value()),
      ("column", state.transfer.column.value()),
      ("columns", state.transfer.columns.value()),
      ("progress", state.transfer.progress.value()),
      ("fault", state.transfer.fault.value()),
      ("completion_id", state.transfer.id.value()),
      ("fault_address", state.transfer.fault_address.value()),
      ("expected_tag", state.transfer.expected_tag.value()),
    ] {
    execute_output(b, name, value)
  }
  b.finish()
}
