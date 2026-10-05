///|
/// Construct a single-command FluxTile load/execute/completion core.
///
/// Each row of A and column of B has a synchronous INT8 memory bank. Loads
/// accept contiguous prefixes and overwrites while Idle. A command checks
/// dimensions and pre-edge loaded prefixes, then clears, prefetches, and
/// advances the systolic wavefront once per ready Run edge. Completion and
/// results remain stable until accepted. See PHASE6_EXECUTE.md for the
/// provisional signal contract; this is not the complete device ABI.
/// A load and command may both accept on one Idle edge. The command checks
/// prefixes before that edge; a simultaneous append cannot satisfy a missing
/// prefix. An overwrite of an initialized entry is visible to later reads.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @flux_tile.execute_tile(rows=1, columns=1, max_reduction=4)
///     .memories()
///     .length(),
///     2,
///   )
/// }
/// ```
pub fn execute_tile(
  rows~ : Int,
  columns~ : Int,
  max_reduction~ : Int,
) -> @ir.Module raise {
  let builder = execute_builder("FluxTileExecute", rows, columns, max_reduction)
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let reset_inactive = builder.bit_not(builder.reset_asserted(reset_signal))
  let inputs = execute_inputs(builder)
  let signals = build_execute_graph(
    builder,
    domain,
    reset,
    reset_inactive,
    inputs,
    rows,
    columns,
    max_reduction,
    (_, _, _, _) => inputs.completion_ready,
  )
  execute_accumulator_outputs(builder, signals, rows, columns)
  execute_status_outputs(builder, signals)
  builder.finish()
}
