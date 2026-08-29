///|
fn bit_possibilities(bit : @wave.LogicBit) -> Int {
  match bit {
    Zero => 1
    One => 2
    Unknown => 3
  }
}

///|
/// Compute the exact three-state result of a fixed-width modular addition.
///
/// `carry_possibilities` is a two-bit set: bit zero means carry zero is
/// possible and bit one means carry one is possible. Enumerating the eight
/// local full-adder assignments keeps the implementation small while retaining
/// every output bit that is determined despite unknown inputs.
fn add_values(
  left : @wave.LogicValue,
  right : @wave.LogicValue,
) -> @wave.LogicValue raise {
  if left.width() != right.width() {
    raise @wave.LogicValueError::WidthMismatch(
      left=left.width(),
      right=right.width(),
    )
  }
  let mut result_bits = 0UL
  let mut known_mask = 0UL
  let mut carry_possibilities = 1
  for bit_index in 0..<left.width() {
    let left_possibilities = bit_possibilities(left.bit_at(bit_index))
    let right_possibilities = bit_possibilities(right.bit_at(bit_index))
    let mut sum_possibilities = 0
    let mut next_carry_possibilities = 0
    for left_bit in 0..<2 {
      if (left_possibilities & (1 << left_bit)) != 0 {
        for right_bit in 0..<2 {
          if (right_possibilities & (1 << right_bit)) != 0 {
            for carry_bit in 0..<2 {
              if (carry_possibilities & (1 << carry_bit)) != 0 {
                let total = left_bit + right_bit + carry_bit
                sum_possibilities = sum_possibilities | (1 << (total & 1))
                next_carry_possibilities = next_carry_possibilities |
                  (1 << (total >> 1))
              }
            }
          }
        }
      }
    }
    let bit_mask = 1UL << bit_index
    if sum_possibilities == 1 {
      known_mask = known_mask | bit_mask
    } else if sum_possibilities == 2 {
      known_mask = known_mask | bit_mask
      result_bits = result_bits | bit_mask
    }
    carry_possibilities = next_carry_possibilities
  }
  @wave.LogicValue::from_masks(
    width=left.width(),
    value_bits=result_bits,
    known_mask~,
  )
}

///|
/// Merge mux branches when the select bit is unknown. A result bit remains
/// known only when both branches know and agree on that bit.
fn merge_mux_branches(
  when_true : @wave.LogicValue,
  when_false : @wave.LogicValue,
) -> @wave.LogicValue raise {
  if when_true.width() != when_false.width() {
    raise @wave.LogicValueError::WidthMismatch(
      left=when_true.width(),
      right=when_false.width(),
    )
  }
  let agreeing = when_true.known_mask() &
    when_false.known_mask() &
    (when_true.value_bits() ^ when_false.value_bits() ^ when_true.width_mask())
  @wave.LogicValue::from_masks(
    width=when_true.width(),
    value_bits=when_true.value_bits(),
    known_mask=agreeing,
  )
}
