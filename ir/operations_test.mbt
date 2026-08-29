///|
test "low-level full multiply requires doubled matching numeric result" {
  let u8 = @ir.SignalType::UInt(@ir.Width::new(8))
  let u15 = @ir.SignalType::UInt(@ir.Width::new(15))
  let u16 = @ir.SignalType::UInt(@ir.Width::new(16))
  let lhs = @ir.NodeId::new(0)
  let rhs = @ir.NodeId::new(1)
  let product = @ir.NodeId::new(2)
  let good_nodes = [
    @ir.Node::new(lhs, u8, Input("lhs")),
    @ir.Node::new(rhs, u8, Input("rhs")),
    @ir.Node::new(product, u16, MulFull(lhs, rhs)),
  ]
  assert_eq(
    @ir.Module::checked("FullMultiply", good_nodes, []).nodes().length(),
    3,
  )
  let bad_nodes = [
    @ir.Node::new(lhs, u8, Input("lhs")),
    @ir.Node::new(rhs, u8, Input("rhs")),
    @ir.Node::new(product, u15, MulFull(lhs, rhs)),
  ]
  try @ir.Module::checked("BadFullMultiply", bad_nodes, []) catch {
    WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "mul_full")
      assert_eq(expected, 16)
      assert_eq(actual, 15)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected full multiply result-width rejection")
  }
}

///|
test "low-level comparison and slice result types are exact" {
  let u8 = @ir.SignalType::UInt(@ir.Width::new(8))
  let bit = @ir.SignalType::Bits(@ir.Width::new(1))
  let wrong_bit = @ir.SignalType::UInt(@ir.Width::new(1))
  let a = @ir.NodeId::new(0)
  let b = @ir.NodeId::new(1)
  let result = @ir.NodeId::new(2)
  let good = [
    @ir.Node::new(a, u8, Input("a")),
    @ir.Node::new(b, u8, Input("b")),
    @ir.Node::new(result, bit, Equal(a, b)),
  ]
  ignore(@ir.Module::checked("GoodEquality", good, []))
  let bad = [
    @ir.Node::new(a, u8, Input("a")),
    @ir.Node::new(b, u8, Input("b")),
    @ir.Node::new(result, wrong_bit, Equal(a, b)),
  ]
  try @ir.Module::checked("BadEquality", bad, []) catch {
    TypeMismatch(operation~) => assert_eq(operation, "equal")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected equality result-type rejection")
  }
  let bad_slice = [
    @ir.Node::new(a, u8, Input("a")),
    @ir.Node::new(b, Bits(@ir.Width::new(4)), Slice(value=a, msb=8, lsb=5)),
  ]
  try @ir.Module::checked("BadSlice", bad_slice, []) catch {
    InvalidSliceBounds(width~, msb~, lsb~) => {
      assert_eq(width, 8)
      assert_eq(msb, 8)
      assert_eq(lsb, 5)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected slice bounds rejection")
  }
}
