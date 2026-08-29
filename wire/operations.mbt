///|
fn data_type_with_width(
  signal_type : @ir.SignalType,
  width : Int,
) -> @ir.SignalType raise @ir.IrError {
  let checked = @ir.Width::new(width)
  match signal_type {
    Bits(_) => Bits(checked)
    UInt(_) => UInt(checked)
    SInt(_) => SInt(checked)
    Clock | Reset => raise TypeMismatch(operation="cast")
  }
}

///|
fn one_bit_result() -> @ir.SignalType raise @ir.IrError {
  Bits(@ir.Width::new(1))
}

///|
fn checked_result_width(
  operation : String,
  lhs : Int,
  rhs : Int,
) -> Int raise @ir.IrError {
  if lhs > 2147483647 - rhs {
    raise WidthOverflow(operation~)
  }
  lhs + rhs
}

///|
fn ModuleBuilder::numeric_binary(
  self : ModuleBuilder,
  operation : String,
  lhs : Signal,
  rhs : Signal,
  make_kind : (@ir.NodeId, @ir.NodeId) -> @ir.NodeKind,
) -> Signal raise {
  self.require_same_type(operation, lhs, rhs)
  if !lhs.signal_type.is_numeric() {
    raise @ir.IrError::TypeMismatch(operation~)
  }
  self.append(lhs.signal_type, make_kind(lhs.id, rhs.id))
}

///|
/// Fixed-width modular subtraction. Operands must have one exact numeric type.
pub fn ModuleBuilder::sub(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.numeric_binary("sub", lhs, rhs, (a, b) => Sub(a, b))
}

///|
/// Return the low half of a same-width multiplication.
pub fn ModuleBuilder::mul_low(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.numeric_binary("mul_low", lhs, rhs, (a, b) => MulLow(a, b))
}

///|
/// Return a multiplication result twice the operand width.
pub fn ModuleBuilder::mul_full(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.require_same_type("mul_full", lhs, rhs)
  if !lhs.signal_type.is_numeric() {
    raise @ir.IrError::TypeMismatch(operation="mul_full")
  }
  let result_type = data_type_with_width(
    lhs.signal_type,
    checked_result_width(
      "mul_full",
      lhs.signal_type.width().bits(),
      rhs.signal_type.width().bits(),
    ),
  )
  self.append(result_type, MulFull(lhs.id, rhs.id))
}

///|
fn ModuleBuilder::comparison(
  self : ModuleBuilder,
  operation : String,
  lhs : Signal,
  rhs : Signal,
  numeric : Bool,
  make_kind : (@ir.NodeId, @ir.NodeId) -> @ir.NodeKind,
) -> Signal raise {
  self.require_same_type(operation, lhs, rhs)
  if !lhs.signal_type.is_data() || (numeric && !lhs.signal_type.is_numeric()) {
    raise @ir.IrError::TypeMismatch(operation~)
  }
  self.append(one_bit_result(), make_kind(lhs.id, rhs.id))
}

///|
/// Compare all semantic bits. The result is `Bits(1)`.
pub fn ModuleBuilder::equal(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.comparison("equal", lhs, rhs, false, (a, b) => Equal(a, b))
}

///|
/// Return the logical negation of exact semantic equality.
pub fn ModuleBuilder::not_equal(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.bit_not(self.equal(lhs, rhs))
}

///|
/// Ordered numeric less-than comparison. The result is `Bits(1)`.
pub fn ModuleBuilder::less_than(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.comparison("less_than", lhs, rhs, true, (a, b) => LessThan(a, b))
}

///|
/// Ordered numeric less-than-or-equal comparison. The result is `Bits(1)`.
pub fn ModuleBuilder::less_equal(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.comparison("less_equal", lhs, rhs, true, (a, b) => LessEqual(a, b))
}

///|
/// Ordered numeric greater-than comparison, canonicalized as reversed `<`.
pub fn ModuleBuilder::greater_than(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.less_than(rhs, lhs)
}

///|
/// Ordered numeric greater-than-or-equal comparison, canonicalized as
/// reversed `<=`.
pub fn ModuleBuilder::greater_equal(
  self : ModuleBuilder,
  lhs : Signal,
  rhs : Signal,
) -> Signal raise {
  self.less_equal(rhs, lhs)
}

///|
fn ModuleBuilder::shift(
  self : ModuleBuilder,
  operation : String,
  value : Signal,
  amount : Signal,
  arithmetic : Bool,
  make_kind : (@ir.NodeId, @ir.NodeId) -> @ir.NodeKind,
) -> Signal raise {
  self.require_signal(value)
  self.require_signal(amount)
  if !value.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation~)
  }
  if arithmetic && !(value.signal_type is SInt(_)) {
    raise @ir.IrError::ExpectedSigned(operation~, node=value.id.ordinal())
  }
  if !(amount.signal_type is UInt(_)) {
    raise @ir.IrError::ExpectedUnsigned(operation~, node=amount.id.ordinal())
  }
  self.append(value.signal_type, make_kind(value.id, amount.id))
}

///|
pub fn ModuleBuilder::shift_left(
  self : ModuleBuilder,
  value : Signal,
  amount : Signal,
) -> Signal raise {
  self.shift("shift_left", value, amount, false, (value, amount) => {
    ShiftLeft(value~, amount~)
  })
}

///|
pub fn ModuleBuilder::logical_shift_right(
  self : ModuleBuilder,
  value : Signal,
  amount : Signal,
) -> Signal raise {
  self.shift("logical_shift_right", value, amount, false, (value, amount) => {
    LogicalShiftRight(value~, amount~)
  })
}

///|
pub fn ModuleBuilder::arithmetic_shift_right(
  self : ModuleBuilder,
  value : Signal,
  amount : Signal,
) -> Signal raise {
  self.shift("arithmetic_shift_right", value, amount, true, (value, amount) => {
    ArithmeticShiftRight(value~, amount~)
  })
}

///|
/// Extract inclusive constant bounds. The result is uninterpreted `Bits`.
pub fn ModuleBuilder::slice(
  self : ModuleBuilder,
  value : Signal,
  msb : Int,
  lsb : Int,
) -> Signal raise {
  self.require_signal(value)
  if !value.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="slice")
  }
  let input_width = value.signal_type.width().bits()
  if lsb < 0 || msb < lsb || msb >= input_width {
    raise @ir.IrError::InvalidSliceBounds(width=input_width, msb~, lsb~)
  }
  self.append(
    Bits(@ir.Width::new(msb - lsb + 1)),
    Slice(value=value.id, msb~, lsb~),
  )
}

///|
/// Concatenate with `most_significant` above `least_significant`.
pub fn ModuleBuilder::concat(
  self : ModuleBuilder,
  most_significant : Signal,
  least_significant : Signal,
) -> Signal raise {
  self.require_signal(most_significant)
  self.require_signal(least_significant)
  if !most_significant.signal_type.is_data() ||
    !least_significant.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation="concat")
  }
  let width = checked_result_width(
    "concat",
    most_significant.signal_type.width().bits(),
    least_significant.signal_type.width().bits(),
  )
  self.append(
    Bits(@ir.Width::new(width)),
    Concat(
      most_significant=most_significant.id,
      least_significant=least_significant.id,
    ),
  )
}

///|
fn ModuleBuilder::width_conversion(
  self : ModuleBuilder,
  operation : String,
  value : Signal,
  new_width : Int,
  extending : Bool,
  make_kind : (@ir.NodeId) -> @ir.NodeKind,
) -> Signal raise {
  self.require_signal(value)
  if !value.signal_type.is_data() {
    raise @ir.IrError::TypeMismatch(operation~)
  }
  ignore(@ir.Width::new(new_width))
  let old_width = value.signal_type.width().bits()
  let width_is_valid = if extending {
    new_width > old_width
  } else {
    new_width < old_width
  }
  if !width_is_valid {
    raise @ir.IrError::WidthMismatch(
      operation~,
      expected=old_width,
      actual=new_width,
    )
  }
  self.append(
    data_type_with_width(value.signal_type, new_width),
    make_kind(value.id),
  )
}

///|
/// Extend with zeros while preserving the source signal kind.
pub fn ModuleBuilder::zero_extend(
  self : ModuleBuilder,
  value : Signal,
  new_width : Int,
) -> Signal raise {
  self.width_conversion("zero_extend", value, new_width, true, id => {
    ZeroExtend(id)
  })
}

///|
/// Extend a signed value with copies of its sign bit.
pub fn ModuleBuilder::sign_extend(
  self : ModuleBuilder,
  value : Signal,
  new_width : Int,
) -> Signal raise {
  self.require_signal(value)
  if !(value.signal_type is SInt(_)) {
    raise @ir.IrError::ExpectedSigned(
      operation="sign_extend",
      node=value.id.ordinal(),
    )
  }
  self.width_conversion("sign_extend", value, new_width, true, id => {
    SignExtend(id)
  })
}

///|
/// Drop the most-significant bits while preserving the source signal kind.
pub fn ModuleBuilder::truncate(
  self : ModuleBuilder,
  value : Signal,
  new_width : Int,
) -> Signal raise {
  self.width_conversion("truncate", value, new_width, false, id => Truncate(id))
}

///|
/// Preserve bits while explicitly changing signedness or interpretation.
pub fn ModuleBuilder::reinterpret(
  self : ModuleBuilder,
  value : Signal,
  target : @ir.SignalType,
) -> Signal raise {
  self.require_signal(value)
  if !value.signal_type.is_data() || !target.is_data() {
    raise @ir.IrError::TypeMismatch(operation="reinterpret")
  }
  let expected = value.signal_type.width().bits()
  let actual = target.width().bits()
  if expected != actual {
    raise @ir.IrError::WidthMismatch(
      operation="reinterpret",
      expected~,
      actual~,
    )
  }
  self.append(target, Reinterpret(value.id))
}
