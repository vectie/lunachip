///|
priv struct ExecuteInputs {
  load_a_valid : @wire.Signal
  load_a_row : @wire.Signal
  load_a_index : @wire.Signal
  load_a_data : @wire.Signal
  load_b_valid : @wire.Signal
  load_b_column : @wire.Signal
  load_b_index : @wire.Signal
  load_b_data : @wire.Signal
  command_valid : @wire.Signal
  command_rows : @wire.Signal
  command_columns : @wire.Signal
  command_reduction : @wire.Signal
  command_id : @wire.Signal
  step_ready : @wire.Signal
  completion_ready : @wire.Signal
}

///|
priv struct ExecuteSignals {
  load_a_ready : @wire.Signal
  load_b_ready : @wire.Signal
  command_ready : @wire.Signal
  completion_valid : @wire.Signal
  completion_id : @wire.Signal
  completion_fault : @wire.Signal
  accepted_steps : @wire.Signal
  elapsed_cycles : @wire.Signal
  active_cycles : @wire.Signal
  stall_cycles : @wire.Signal
  accumulators : Array[@wire.Signal]
  active_rows : @wire.Signal
  active_columns : @wire.Signal
  legal : @wire.Signal
}

///|
fn execute_builder(
  name : String,
  rows : Int,
  columns : Int,
  max_reduction : Int,
) -> @wire.ModuleBuilder raise {
  for
    (name, value, maximum) in [
      ("rows", rows, 8),
      ("columns", columns, 8),
      ("max_reduction", max_reduction, 4096),
    ] {
    if value < 1 || value > maximum {
      raise ExecuteTileError::InvalidParameter(name~, value~, maximum~)
    }
  }
  let builder = @wire.ModuleBuilder::new(name)
  builder.parameter("rows", Signed(rows.to_int64()))
  builder.parameter("columns", Signed(columns.to_int64()))
  builder.parameter("max_reduction", Signed(max_reduction.to_int64()))
  builder
}

///|
fn execute_inputs(builder : @wire.ModuleBuilder) -> ExecuteInputs raise {
  let bit_type = @wire.bits(1)
  let operand_type = @wire.sint(8)
  let load_a_valid = builder.input("load_a_valid", bit_type)
  let load_a_row = builder.input("load_a_row", @wire.uint(4))
  let load_a_index = builder.input("load_a_index", @wire.uint(13))
  let load_a_data = builder.input("load_a_data", operand_type)
  let load_b_valid = builder.input("load_b_valid", bit_type)
  let load_b_column = builder.input("load_b_column", @wire.uint(4))
  let load_b_index = builder.input("load_b_index", @wire.uint(13))
  let load_b_data = builder.input("load_b_data", operand_type)
  let command_valid = builder.input("command_valid", bit_type)
  let command_rows = builder.input("command_rows", @wire.uint(4))
  let command_columns = builder.input("command_columns", @wire.uint(4))
  let command_reduction = builder.input("command_reduction", @wire.uint(13))
  let command_id = builder.input("command_id", @wire.uint(32))
  let step_ready = builder.input("step_ready", bit_type)
  let completion_ready = builder.input("completion_ready", bit_type)
  {
    load_a_valid,
    load_a_row,
    load_a_index,
    load_a_data,
    load_b_valid,
    load_b_column,
    load_b_index,
    load_b_data,
    command_valid,
    command_rows,
    command_columns,
    command_reduction,
    command_id,
    step_ready,
    completion_ready,
  }
}

///|
fn execute_accumulator_outputs(
  builder : @wire.ModuleBuilder,
  signals : ExecuteSignals,
  rows : Int,
  columns : Int,
) -> Unit raise {
  for row in 0..<rows {
    for column in 0..<columns {
      execute_output(
        builder,
        "accumulator_\{row}_\{column}",
        signals.accumulators[row * columns + column],
      )
    }
  }
}

///|
fn execute_status_outputs(
  builder : @wire.ModuleBuilder,
  signals : ExecuteSignals,
) -> Unit raise {
  execute_output(builder, "load_a_ready", signals.load_a_ready)
  execute_output(builder, "load_b_ready", signals.load_b_ready)
  execute_output(builder, "command_ready", signals.command_ready)
  execute_output(builder, "completion_valid", signals.completion_valid)
  execute_output(builder, "completion_id", signals.completion_id)
  execute_output(builder, "completion_fault", signals.completion_fault)
  execute_output(builder, "accepted_steps", signals.accepted_steps)
  execute_output(builder, "elapsed_cycles", signals.elapsed_cycles)
  execute_output(builder, "active_cycles", signals.active_cycles)
  execute_output(builder, "stall_cycles", signals.stall_cycles)
}
