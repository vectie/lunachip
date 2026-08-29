///|
/// A benchmark-only prepared combinational workload.
///
/// This type deliberately lives below `benchmarks/`; it is not part of the
/// stable LunaWire or LunaWave API. The workload combines arithmetic, logic,
/// comparison, shifts, slices, concatenation, and mux nodes in one long data
/// dependency chain so dead-code elimination cannot remove a stage.
pub struct PreparedWorkload {
  hardware_module : @ir.Module
  lhs : @wave.LogicValue
  rhs : @wave.LogicValue
  expected : UInt64
  stages : Int
  nodes : Int
}

///|
pub fn PreparedWorkload::hardware_module(self : PreparedWorkload) -> @ir.Module {
  self.hardware_module
}

///|
pub fn PreparedWorkload::lhs(self : PreparedWorkload) -> @wave.LogicValue {
  self.lhs
}

///|
pub fn PreparedWorkload::rhs(self : PreparedWorkload) -> @wave.LogicValue {
  self.rhs
}

///|
pub fn PreparedWorkload::expected(self : PreparedWorkload) -> UInt64 {
  self.expected
}

///|
pub fn PreparedWorkload::stages(self : PreparedWorkload) -> Int {
  self.stages
}

///|
pub fn PreparedWorkload::nodes(self : PreparedWorkload) -> Int {
  self.nodes
}

///|
fn oracle_stage(value : UInt64, lhs : UInt64, rhs : UInt64) -> UInt64 {
  let mask = 0xffffUL
  let salt = 0x9e37UL
  let added = (value + rhs) & mask
  let xored = added ^ salt
  let product = (xored * lhs) & mask
  let subtracted = (product - rhs) & mask
  let anded = subtracted & xored
  let ored = subtracted | xored
  let shifted_left = (ored << 3) & mask
  let shifted_right = anded >> 3
  let mixed = shifted_left ^ shifted_right
  let swapped = ((mixed & 0xffUL) << 8) | ((mixed >> 8) & 0xffUL)
  if subtracted < xored {
    swapped
  } else {
    ored
  }
}

///|
fn oracle(lhs : UInt64, rhs : UInt64, stages : Int) -> UInt64 {
  let mut value = lhs
  for _ in 0..<stages {
    value = oracle_stage(value, lhs, rhs)
  }
  value
}

///|
/// Build the representative fixed-width combinational graph used by the
/// steady-state allocation and throughput harness.
pub fn representative_workload(stages : Int) -> PreparedWorkload raise {
  if stages < 1 {
    fail("benchmark stages must be positive")
  }
  let builder = @wire.ModuleBuilder::new("PreparedCombinationalBenchmark")
  let word_type = @wire.uint(16)
  let amount_type = @wire.uint(4)
  let lhs = builder.input("lhs", word_type)
  let rhs = builder.input("rhs", word_type)
  let salt = builder.constant(word_type, 0x9e37UL)
  let shift_amount = builder.constant(amount_type, 3UL)
  let output = builder.output("result", word_type)
  let mut value = lhs
  for _ in 0..<stages {
    let added = builder.add(value, rhs)
    let xored = builder.bit_xor(added, salt)
    let product = builder.mul_low(xored, lhs)
    let subtracted = builder.sub(product, rhs)
    let anded = builder.bit_and(subtracted, xored)
    let ored = builder.bit_or(subtracted, xored)
    let shifted_left = builder.shift_left(ored, shift_amount)
    let shifted_right = builder.logical_shift_right(anded, shift_amount)
    let mixed = builder.bit_xor(shifted_left, shifted_right)
    let low = builder.slice(mixed, 7, 0)
    let high = builder.slice(mixed, 15, 8)
    let swapped = builder.concat(low, high)
    let swapped_numeric = builder.reinterpret(swapped, word_type)
    let select = builder.less_than(subtracted, xored)
    value = builder.mux(select, swapped_numeric, ored)
  }
  builder.connect(output, value)
  let hardware_module = builder.finish()
  let lhs_value = @wave.LogicValue::from_uint64(width=16, value=0x1357UL)
  let rhs_value = @wave.LogicValue::from_uint64(width=16, value=0x2468UL)
  {
    hardware_module,
    lhs: lhs_value,
    rhs: rhs_value,
    expected: oracle(0x1357UL, 0x2468UL, stages),
    stages,
    nodes: hardware_module.nodes().length(),
  }
}
