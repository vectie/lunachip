///|
fn same_data_kind(lhs : SignalType, rhs : SignalType) -> Bool {
  match (lhs, rhs) {
    (Bits(_), Bits(_)) | (UInt(_), UInt(_)) | (SInt(_), SInt(_)) => true
    _ => false
  }
}

///|
fn checked_width_sum(
  operation : String,
  lhs : Int32,
  rhs : Int32,
) -> Int32 raise IrError {
  if lhs > 2147483647 - rhs {
    raise WidthOverflow(operation~)
  }
  lhs + rhs
}

///|
fn require_bits_result(
  operation : String,
  result_type : SignalType,
  width : Int32,
) -> Unit raise IrError {
  match result_type {
    Bits(actual) =>
      if actual.bits() != width {
        raise WidthMismatch(operation~, expected=width, actual=actual.bits())
      }
    _ => raise TypeMismatch(operation~)
  }
}

///|
fn validate_numeric_binary(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  operation : String,
  lhs : NodeId,
  rhs : NodeId,
) -> Unit raise IrError {
  if !result_type.is_numeric() {
    raise TypeMismatch(operation~)
  }
  validate_binary(nodes, current, result_type, operation, lhs, rhs)
}

///|
fn validate_full_multiply(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  lhs : NodeId,
  rhs : NodeId,
) -> Unit raise IrError {
  let left = require_prior_node(nodes, current, lhs)
  let right = require_prior_node(nodes, current, rhs)
  require_type("mul_full", left.signal_type(), right.signal_type())
  if !left.signal_type().is_numeric() ||
    !same_data_kind(result_type, left.signal_type()) {
    raise TypeMismatch(operation="mul_full")
  }
  let expected = checked_width_sum(
    "mul_full",
    left.signal_type().width().bits(),
    right.signal_type().width().bits(),
  )
  let actual = result_type.width().bits()
  if actual != expected {
    raise WidthMismatch(operation="mul_full", expected~, actual~)
  }
}

///|
fn validate_comparison(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  operation : String,
  lhs : NodeId,
  rhs : NodeId,
  numeric : Bool,
) -> Unit raise IrError {
  let left = require_prior_node(nodes, current, lhs)
  let right = require_prior_node(nodes, current, rhs)
  require_type(operation, left.signal_type(), right.signal_type())
  if !left.signal_type().is_data() ||
    (numeric && !left.signal_type().is_numeric()) {
    raise TypeMismatch(operation~)
  }
  require_bits_result(operation, result_type, 1)
}

///|
fn validate_shift(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  operation : String,
  value : NodeId,
  amount : NodeId,
  signed_value : Bool,
) -> Unit raise IrError {
  let value_node = require_prior_node(nodes, current, value)
  let amount_node = require_prior_node(nodes, current, amount)
  if !value_node.signal_type().is_data() {
    raise TypeMismatch(operation~)
  }
  if signed_value && !(value_node.signal_type() is SInt(_)) {
    raise ExpectedSigned(operation~, node=value.ordinal())
  }
  if !(amount_node.signal_type() is UInt(_)) {
    raise ExpectedUnsigned(operation~, node=amount.ordinal())
  }
  require_type(operation, value_node.signal_type(), result_type)
}

///|
fn validate_slice(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  value : NodeId,
  msb : Int32,
  lsb : Int32,
) -> Unit raise IrError {
  let input = require_prior_node(nodes, current, value)
  if !input.signal_type().is_data() {
    raise TypeMismatch(operation="slice")
  }
  let input_width = input.signal_type().width().bits()
  if lsb < 0 || msb < lsb || msb >= input_width {
    raise InvalidSliceBounds(width=input_width, msb~, lsb~)
  }
  require_bits_result("slice", result_type, msb - lsb + 1)
}

///|
fn validate_concat(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  most_significant : NodeId,
  least_significant : NodeId,
) -> Unit raise IrError {
  let upper = require_prior_node(nodes, current, most_significant)
  let lower = require_prior_node(nodes, current, least_significant)
  if !upper.signal_type().is_data() || !lower.signal_type().is_data() {
    raise TypeMismatch(operation="concat")
  }
  let width = checked_width_sum(
    "concat",
    upper.signal_type().width().bits(),
    lower.signal_type().width().bits(),
  )
  require_bits_result("concat", result_type, width)
}

///|
fn validate_width_conversion(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  operation : String,
  value : NodeId,
  relation : (Int32, Int32) -> Bool,
) -> Unit raise IrError {
  let input = require_prior_node(nodes, current, value)
  if !input.signal_type().is_data() ||
    !result_type.is_data() ||
    !same_data_kind(input.signal_type(), result_type) {
    raise TypeMismatch(operation~)
  }
  let source_width = input.signal_type().width().bits()
  let result_width = result_type.width().bits()
  if !relation(source_width, result_width) {
    raise WidthMismatch(operation~, expected=source_width, actual=result_width)
  }
}

///|
fn validate_reinterpret(
  nodes : ArrayView[Node],
  current : Int32,
  result_type : SignalType,
  value : NodeId,
) -> Unit raise IrError {
  let input = require_prior_node(nodes, current, value)
  let reset_to_bits = input.signal_type() is Reset &&
    result_type is Bits(width) &&
    width.bits() == 1
  if !reset_to_bits &&
    (!input.signal_type().is_data() || !result_type.is_data()) {
    raise TypeMismatch(operation="reinterpret")
  }
  let expected = input.signal_type().width().bits()
  let actual = result_type.width().bits()
  if expected != actual {
    raise WidthMismatch(operation="reinterpret", expected~, actual~)
  }
}
