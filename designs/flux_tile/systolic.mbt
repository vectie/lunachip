///|
pub(all) suberror SystolicArrayError {
  InvalidRows(Int)
  InvalidColumns(Int)
} derive(Eq, @debug.Debug)

///|
fn systolic_forward_register(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  signal : @wire.Signal,
  clear : @wire.Signal,
  enabled : @wire.Signal,
  reset : @wire.SynchronousReset,
) -> @wire.Signal raise {
  let zero = builder.constant(signal.signal_type(), 0UL)
  builder.register_in(
    domain,
    builder.mux(clear, zero, signal),
    reset~,
    enable=enabled,
  )
}

///|
/// Construct the output-stationary FluxTile-0 compute array.
///
/// Shapes contain 1..8 rows and columns. Ports `a_i` and `b_j` are signed
/// INT8 values, with one-bit `a_valid_i` and `b_valid_j` qualifiers. Each cell
/// exposes its signed INT32 state as `accumulator_i_j`; arithmetic wraps at
/// 32 bits. A cell accumulates only when both arriving qualifiers are one.
///
/// On each `advance` edge, A moves one column right and B one row down.
/// For A(rows,K) times B(K,columns), inject A[i,k] at accepted edge k+i and
/// B[k,j] at accepted edge k+j, starting at zero. Inject invalid bubbles outside
/// those windows. Cell (i,j) consumes term k at edge k+i+j, so every result is
/// ready after K+rows+columns-2 accepted edges. The caller owns this schedule.
/// `advance=0` freezes every pipeline and accumulator; input changes while
/// paused are ignored. Synchronous active-high `reset` and one-bit `clear`
/// both zero every state element even when paused; reset has priority.
pub fn systolic_array(rows~ : Int, columns~ : Int) -> @ir.Module raise {
  if rows < 1 || rows > 8 {
    raise SystolicArrayError::InvalidRows(rows)
  }
  if columns < 1 || columns > 8 {
    raise SystolicArrayError::InvalidColumns(columns)
  }
  let builder = @wire.ModuleBuilder::new("FluxTileSystolicArray")
  builder.parameter("rows", Signed(rows.to_int64()))
  builder.parameter("columns", Signed(columns.to_int64()))
  let clock = builder.input("clock", @wire.clock())
  let domain = builder.rising_edge(clock)
  let reset_signal = builder.input("reset", @wire.reset())
  let reset = builder.synchronous_reset(reset_signal, 0UL)
  let bit_type = @wire.bits(1)
  let operand_type = @wire.sint(8)
  let accumulator_type = @wire.sint(32)
  let clear = builder.input("clear", bit_type)
  let advance = builder.input("advance", bit_type)
  let enabled = builder.bit_or(clear, advance)
  let zero_accumulator = builder.constant(accumulator_type, 0UL)
  let a_inputs : Array[@wire.Signal] = []
  let a_valid_inputs : Array[@wire.Signal] = []
  let b_inputs : Array[@wire.Signal] = []
  let b_valid_inputs : Array[@wire.Signal] = []
  for row in 0..<rows {
    a_inputs.push(builder.input("a_\{row}", operand_type))
    a_valid_inputs.push(builder.input("a_valid_\{row}", bit_type))
  }
  for column in 0..<columns {
    b_inputs.push(builder.input("b_\{column}", operand_type))
    b_valid_inputs.push(builder.input("b_valid_\{column}", bit_type))
  }
  // Preserve standalone node order while sharing the cell generator with
  // the banked execute controller.
  let accumulators = build_systolic_array(
    builder,
    domain,
    reset,
    clear,
    advance,
    a_inputs,
    b_inputs,
    a_valid_inputs,
    b_valid_inputs,
    enabled~,
    zero=zero_accumulator,
  )
  for row in 0..<rows {
    for column in 0..<columns {
      let output = builder.output(
        "accumulator_\{row}_\{column}",
        accumulator_type,
      )
      builder.connect(output, accumulators[row * columns + column])
    }
  }
  builder.finish()
}

///|
fn build_systolic_array(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  clear : @wire.Signal,
  advance : @wire.Signal,
  a_inputs : Array[@wire.Signal],
  b_inputs : Array[@wire.Signal],
  a_valid_inputs : Array[@wire.Signal],
  b_valid_inputs : Array[@wire.Signal],
  enabled? : @wire.Signal,
  zero? : @wire.Signal,
) -> Array[@wire.Signal] raise {
  let enabled = match enabled {
    Some(signal) => signal
    None => builder.bit_or(clear, advance)
  }
  let zero = match zero {
    Some(signal) => signal
    None => builder.constant(@wire.sint(32), 0UL)
  }
  build_systolic_cells(
    builder, domain, reset, clear, enabled, zero, a_inputs, b_inputs, a_valid_inputs,
    b_valid_inputs,
  )
}

///|
fn build_systolic_cells(
  builder : @wire.ModuleBuilder,
  domain : @wire.ClockDomain,
  reset : @wire.SynchronousReset,
  clear : @wire.Signal,
  enabled : @wire.Signal,
  zero_accumulator : @wire.Signal,
  a_inputs : Array[@wire.Signal],
  b_inputs : Array[@wire.Signal],
  a_valid_inputs : Array[@wire.Signal],
  b_valid_inputs : Array[@wire.Signal],
) -> Array[@wire.Signal] raise {
  let rows = a_inputs.length()
  let columns = b_inputs.length()
  let accumulator_type = @wire.sint(32)
  let accumulators : Array[@wire.Signal] = []
  let a_forward : Array[@wire.Signal] = []
  let a_valid_forward : Array[@wire.Signal] = []
  let b_forward : Array[@wire.Signal] = []
  let b_valid_forward : Array[@wire.Signal] = []
  for row in 0..<rows {
    for column in 0..<columns {
      let a = if column == 0 {
        a_inputs[row]
      } else {
        a_forward[row * columns + column - 1]
      }
      let a_valid = if column == 0 {
        a_valid_inputs[row]
      } else {
        a_valid_forward[row * columns + column - 1]
      }
      let b = if row == 0 {
        b_inputs[column]
      } else {
        b_forward[(row - 1) * columns + column]
      }
      let b_valid = if row == 0 {
        b_valid_inputs[column]
      } else {
        b_valid_forward[(row - 1) * columns + column]
      }
      a_forward.push(
        if column + 1 < columns {
          systolic_forward_register(builder, domain, a, clear, enabled, reset)
        } else {
          a
        },
      )
      a_valid_forward.push(
        if column + 1 < columns {
          systolic_forward_register(
            builder, domain, a_valid, clear, enabled, reset,
          )
        } else {
          a_valid
        },
      )
      b_forward.push(
        if row + 1 < rows {
          systolic_forward_register(builder, domain, b, clear, enabled, reset)
        } else {
          b
        },
      )
      b_valid_forward.push(
        if row + 1 < rows {
          systolic_forward_register(
            builder, domain, b_valid, clear, enabled, reset,
          )
        } else {
          b_valid
        },
      )
      let accumulator = builder.register_state_in(
        domain,
        accumulator_type,
        reset~,
        enable=enabled,
      )
      let product = builder.sign_extend(builder.mul_full(a, b), 32)
      let valid = builder.bit_and(a_valid, b_valid)
      let updated = builder.mux(
        valid,
        builder.add(accumulator.value(), product),
        accumulator.value(),
      )
      builder.connect_next(
        accumulator,
        builder.mux(clear, zero_accumulator, updated),
      )
      accumulators.push(accumulator.value())
    }
  }
  accumulators
}

///|
pub extend SystolicArrayError with Eq::{not_equal, equal}

///|
pub extend SystolicArrayError with @moonbitlang/core/debug.Debug::{to_repr}
