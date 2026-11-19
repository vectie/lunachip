///|
fn invalid_request_address(
  b : @wire.ModuleBuilder,
  received : @wire.Signal,
  wide : Bool,
  batch : Bool,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  boundary_negative~ : Bool = false,
) -> @wire.Signal raise {
  let invalid_address = any(b, [
    b.bit_not(eq(b, b.slice(received, 33, 32), 0UL)),
    both(b, [
      b.slice(received, 61, 61),
      b.bit_not(eq(b, b.slice(received, 35, 32), 0UL)),
    ]),
    both(b, [
      b.slice(received, 62, 62),
      any(b, [
        b.bit_not(b.slice(received, 61, 61)),
        b.slice(received, 60, 60),
        b.bit_not(eq(b, b.slice(received, 38, 32), 0UL)),
      ]),
    ]),
  ])
  let invalid_address = if wide {
    b.bit_or(
      invalid_address,
      both(b, [
        b.slice(received, 63, 63),
        b.bit_not(
          both(b, [
            b.slice(received, 62, 62),
            b.slice(received, 61, 61),
            b.bit_not(b.slice(received, 60, 60)),
          ]),
        ),
      ]),
    )
  } else {
    invalid_address
  }
  let invalid_address = if batch {
    b.bit_or(
      invalid_address,
      invalid_batch_address(
        b,
        received,
        eight_row~,
        sixteen_row~,
        aligned_extent~,
        boundary_negative~,
      ),
    )
  } else {
    invalid_address
  }
  invalid_address
}

///|
/// Combinational evidence seam comparing complete header rejection over all
/// 64 input bits. The negative profile deliberately rejects the last valid line.
///
/// ```mbt check
/// test {
///   assert_eq(
///     @prx100_layer_ddr.address_validation_equivalence().outputs().length(),
///     2,
///   )
/// }
/// ```
pub fn address_validation_equivalence(
  negative~ : Bool = false,
  sixteen_row~ : Bool = false,
) -> @ir.Module raise {
  let b = @wire.ModuleBuilder::new("Prx100AddressValidationEquivalence")
  let header = b.input("header", @wire.uint(64))
  let legacy = invalid_request_address(
    b,
    header,
    true,
    true,
    eight_row=true,
    sixteen_row~,
  )
  let aligned = invalid_request_address(
    b,
    header,
    true,
    true,
    eight_row=true,
    sixteen_row~,
    aligned_extent=true,
    boundary_negative=negative,
  )
  b.connect(b.output("legacy", @wire.bits(1)), legacy)
  b.connect(b.output("aligned", @wire.bits(1)), aligned)
  b.finish()
}
