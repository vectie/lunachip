///|
/// Bounded instruction machine for a complete mixed BF16-weight/FP32 layer.
/// Program/scratch memories are loaded only while idle; all runtime tensor
/// arithmetic, instruction sequencing and DDR requests execute in this module.
pub fn layer_machine(memory~ : MemoryAperture = MiB256) -> @ir.Module raise {
  make_layer_machine(false, memory~)
}

///|
/// Four output-row lanes with three-stage FP32 multipliers and independently
/// ordered FP32 accumulator feedback. The descriptor/host ABI is unchanged.
pub fn parallel_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(true, memory~)
}

///|
/// Four ordered lanes with ping-pong weight stripes. DDR fills the inactive
/// bank while the active bank feeds the arithmetic pipeline.
/// Example: `let design = @qwen_layer.overlapped_layer_machine()`.
pub fn overlapped_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(true, overlap=true, memory~)
}

///|
/// Four-word DDR responses fill banked weight stripes without changing the
/// ordered BF16/FP32 arithmetic or the legacy generators.
pub fn wide_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(true, overlap=true, wide=true, memory~)
}

///|
/// One strided DDR request fills all four lanes of a ping-pong stripe.
pub fn batched_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(true, overlap=true, wide=true, batch=true, memory~)
}

///|
/// Sixteen ordered output-row lanes,four legacy batches per stripe,and
/// registered FP32 arithmetic with two-cycle ordered accumulation.
pub fn throughput_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    memory~,
  )
}

///|
/// Sixteen ordered rows with two eight-row DDR owners per weight stripe.
/// Requires the matching eight-row target controller and bridge.
pub fn eight_row_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    memory~,
  )
}

///|
/// Eight-row DDR transport with two-edge sums and four-edge products in the
/// nonlinear engine. Uses the same FP32 operations and ordered microprogram.
pub fn short_unary_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    short_unary=true,
    memory~,
  )
}

///|
/// Sixteen-row DDR ownership with the existing sixteen ordered arithmetic
/// lanes and short nonlinear schedule. Requires the matched target transport.
/// Example: `let design = @qwen_layer.sixteen_row_layer_machine()`.
pub fn sixteen_row_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    short_unary=true,
    sixteen_row=true,
    memory~,
  )
}

///|
/// Thirty-two ordered FP32 row accumulators with exact BF16-weight multipliers.
/// Example: `let hardware = @qwen_layer.compute_layer_machine()`.
pub fn compute_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    compute=true,
    memory~,
  )
}

///|
/// Sixteen-row ordered BF16/FP32 execution with optional contiguous K64 stripes.
/// External matrix flags 1 selects packed weights; flags 0 remains row-major.
/// Example: `let design = @qwen_layer.contiguous_layer_machine()`.
pub fn contiguous_layer_machine(
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    short_unary=true,
    sixteen_row=true,
    packed_weights=true,
    memory~,
  )
}

///|
/// Packed-stripe machine with exact single-edge ordered FP32 matrix feedback.
/// The existing sixteen-row DDR transport and scalar arithmetic are retained.
/// Example: `let design = @qwen_layer.feedback_layer_machine()`.
pub fn feedback_layer_machine(
  delivery~ : Bool = false,
  memory~ : MemoryAperture = MiB256,
) -> @ir.Module raise {
  make_layer_machine(
    true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
    short_unary=true,
    sixteen_row=true,
    packed_weights=true,
    feedback=true,
    delivery~,
    memory~,
  )
}
