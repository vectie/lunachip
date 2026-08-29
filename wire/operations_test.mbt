///|
test "builds the complete typed combinational operation subset" {
  let builder = @wire.ModuleBuilder::new("Combinational")
  let u8 = @wire.uint(8)
  let s8 = @wire.sint(8)
  let a = builder.input("a", u8)
  let b = builder.input("b", u8)
  let signed = builder.input("signed", s8)
  let amount = builder.input("amount", @wire.uint(3))
  let sub = builder.sub(a, b)
  let low = builder.mul_low(a, b)
  let full = builder.mul_full(a, b)
  let equal = builder.equal(a, b)
  let not_equal = builder.not_equal(a, b)
  let less = builder.less_than(a, b)
  let less_equal = builder.less_equal(a, b)
  let greater = builder.greater_than(a, b)
  let greater_equal = builder.greater_equal(a, b)
  let left = builder.shift_left(a, amount)
  let right = builder.logical_shift_right(a, amount)
  let arithmetic = builder.arithmetic_shift_right(signed, amount)
  let slice = builder.slice(a, 6, 2)
  let concat = builder.concat(slice, equal)
  let zero_extended = builder.zero_extend(a, 12)
  let sign_extended = builder.sign_extend(signed, 12)
  let truncated = builder.truncate(zero_extended, 4)
  let reinterpreted = builder.reinterpret(a, @wire.bits(8))
  assert_eq(sub.signal_type(), u8)
  assert_eq(low.signal_type(), u8)
  assert_eq(full.signal_type(), @wire.uint(16))
  for comparison in [equal, not_equal, less, less_equal, greater, greater_equal] {
    assert_eq(comparison.signal_type(), @wire.bits(1))
  }
  assert_eq(left.signal_type(), u8)
  assert_eq(right.signal_type(), u8)
  assert_eq(arithmetic.signal_type(), s8)
  assert_eq(slice.signal_type(), @wire.bits(5))
  assert_eq(concat.signal_type(), @wire.bits(6))
  assert_eq(zero_extended.signal_type(), @wire.uint(12))
  assert_eq(sign_extended.signal_type(), @wire.sint(12))
  assert_eq(truncated.signal_type(), @wire.uint(4))
  assert_eq(reinterpreted.signal_type(), @wire.bits(8))
  let canonical = builder.finish()
  assert_eq(canonical.nodes().length(), 23)
}

///|
test "reset assertion conversion is explicit and type checked" {
  let builder = @wire.ModuleBuilder::new("ResetControl")
  let reset = builder.input("reset", @wire.reset())
  let asserted = builder.reset_asserted(reset)
  assert_eq(asserted.signal_type(), @wire.bits(1))
  let output = builder.output("asserted", @wire.bits(1))
  builder.connect(output, asserted)
  let canonical = builder.finish()
  assert_eq(canonical.nodes()[1].kind(), Reinterpret(@ir.NodeId::new(0)))

  let invalid = @wire.ModuleBuilder::new("InvalidResetControl")
  let bit = invalid.input("bit", @wire.bits(1))
  try invalid.reset_asserted(bit) catch {
    @ir.IrError::TypeMismatch(operation~) =>
      assert_eq(operation, "reset_asserted")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reset control type rejection")
  }
}

///|
test "requires exact width and signedness for arithmetic and comparison" {
  let builder = @wire.ModuleBuilder::new("ExactTypes")
  let u8 = builder.input("u8", @wire.uint(8))
  let u16 = builder.input("u16", @wire.uint(16))
  let s8 = builder.input("s8", @wire.sint(8))
  let b8 = builder.input("b8", @wire.bits(8))
  try builder.sub(u8, u16) catch {
    @ir.IrError::WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "sub")
      assert_eq(expected, 8)
      assert_eq(actual, 16)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected subtraction width rejection")
  }
  try builder.mul_full(u8, s8) catch {
    @ir.IrError::TypeMismatch(operation~) => assert_eq(operation, "mul_full")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected multiply signedness rejection")
  }
  try builder.equal(u8, s8) catch {
    @ir.IrError::TypeMismatch(operation~) => assert_eq(operation, "equal")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected equality signedness rejection")
  }
  try builder.less_than(b8, b8) catch {
    @ir.IrError::TypeMismatch(operation~) => assert_eq(operation, "less_than")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-numeric ordering rejection")
  }
  assert_eq(builder.finish().nodes().length(), 4)
}

///|
test "shift validation distinguishes unsigned amounts and signed data" {
  let builder = @wire.ModuleBuilder::new("ShiftTypes")
  let unsigned = builder.input("unsigned", @wire.uint(8))
  let amount_bits = builder.input("amount_bits", @wire.bits(3))
  let amount = builder.input("amount", @wire.uint(3))
  try builder.shift_left(unsigned, amount_bits) catch {
    @ir.IrError::ExpectedUnsigned(operation~, node~) => {
      assert_eq(operation, "shift_left")
      assert_eq(node, 1)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsigned shift amount rejection")
  }
  try builder.arithmetic_shift_right(unsigned, amount) catch {
    @ir.IrError::ExpectedSigned(operation~, node~) => {
      assert_eq(operation, "arithmetic_shift_right")
      assert_eq(node, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected signed shift value rejection")
  }
  ignore(builder.finish())
}

///|
test "slice rejects reversed negative and out-of-range inclusive bounds" {
  let builder = @wire.ModuleBuilder::new("SliceBounds")
  let value = builder.input("value", @wire.uint(8))
  for bounds in [(2, 3), (3, -1), (8, 0)] {
    let (msb, lsb) = bounds
    try builder.slice(value, msb, lsb) catch {
      @ir.IrError::InvalidSliceBounds(width~, msb=actual_msb, lsb=actual_lsb) => {
        assert_eq(width, 8)
        assert_eq(actual_msb, msb)
        assert_eq(actual_lsb, lsb)
      }
      error => fail("unexpected error: \{Repr(error)}")
    } noraise {
      _ => fail("expected invalid slice bounds")
    }
  }
  ignore(builder.finish())
}

///|
test "casts require explicit direction and exact reinterpret width" {
  let builder = @wire.ModuleBuilder::new("CastRules")
  let unsigned = builder.input("unsigned", @wire.uint(8))
  try builder.zero_extend(unsigned, 8) catch {
    @ir.IrError::WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "zero_extend")
      assert_eq(expected, 8)
      assert_eq(actual, 8)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-extending width rejection")
  }
  try builder.truncate(unsigned, 9) catch {
    @ir.IrError::WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "truncate")
      assert_eq(expected, 8)
      assert_eq(actual, 9)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-truncating width rejection")
  }
  try builder.sign_extend(unsigned, 16) catch {
    @ir.IrError::ExpectedSigned(operation~, node~) => {
      assert_eq(operation, "sign_extend")
      assert_eq(node, 0)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected unsigned sign-extension rejection")
  }
  try builder.reinterpret(unsigned, @wire.bits(7)) catch {
    @ir.IrError::WidthMismatch(operation~, expected~, actual~) => {
      assert_eq(operation, "reinterpret")
      assert_eq(expected, 8)
      assert_eq(actual, 7)
    }
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected reinterpret width rejection")
  }
  ignore(builder.finish())
}

///|
test "derived widths reject overflow and non-positive targets" {
  let builder = @wire.ModuleBuilder::new("DerivedWidths")
  let huge_type = @wire.uint(1073741824)
  let huge = builder.input("huge", huge_type)
  try builder.mul_full(huge, huge) catch {
    @ir.IrError::WidthOverflow(operation~) => assert_eq(operation, "mul_full")
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected derived-width overflow")
  }
  let small = builder.input("small", @wire.uint(8))
  try builder.truncate(small, 0) catch {
    @ir.IrError::InvalidWidth(width) => assert_eq(width, 0)
    error => fail("unexpected error: \{Repr(error)}")
  } noraise {
    _ => fail("expected non-positive width rejection")
  }
  ignore(builder.finish())
}
