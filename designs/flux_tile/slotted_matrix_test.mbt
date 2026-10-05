///|
test "slotted execute stores independent oracle matrices in two real C slots with mixed operands" {
  for (rows, columns, reduction) in [(1, 1, 1), (2, 3, 5), (8, 8, 3)] {
    let simulator = slotted_prepare(rows, columns, reduction)
    let left = Array::makei(rows * reduction, index => {
      (index * 47 + 13) % 256 - 128
    })
    let right = Array::makei(reduction * columns, index => {
      (index * 83 + 231) % 256 - 128
    })
    let other_left = left.map(value => -value - 1)
    let other_right = right.map(value => -value - 1)
    slotted_load_matrix(simulator, 0, 1, rows, columns, reduction, left, right)
    slotted_load_matrix(
      simulator, 1, 0, rows, columns, reduction, other_left, other_right,
    )
    slotted_accept(simulator, 0, 1, 0, rows, columns, reduction, 10)
    // All selector inputs may change after acceptance, without redirecting
    // bank reads, capture, or the identity of the eventual completion.
    slotted_select(simulator, 1, 0, 1)
    slotted_run(simulator, rows, columns, reduction, true)
    slotted_completion(simulator, 10, 0, 0UL)
    slotted_ack(simulator)
    slotted_accept(simulator, 1, 0, 1, rows, columns, reduction, 11)
    slotted_select(simulator, 0, 1, 0)
    slotted_run(simulator, rows, columns, reduction, false)
    slotted_completion(simulator, 11, 1, 0UL)
    slotted_matrix_reads(
      simulator,
      0,
      rows,
      columns,
      @flux_tile.matmul_int8_oracle(left, right, rows~, columns~, reduction~),
    )
    slotted_matrix_reads(
      simulator,
      1,
      rows,
      columns,
      @flux_tile.matmul_int8_oracle(
        other_left,
        other_right,
        rows~,
        columns~,
        reduction~,
      ),
    )
  }
}

///|
test "slotted execute preserves another result while replacing a smaller active shape" {
  let simulator = slotted_prepare(3, 3, 5)
  slotted_load_matrix(simulator, 0, 0, 2, 2, 3, [1, -2, 3, -4, 5, -6], [
    7, -8, 9, 10, -11, 12,
  ])
  slotted_accept(simulator, 0, 0, 0, 2, 2, 3, 20)
  slotted_run(simulator, 2, 2, 3, false)
  slotted_ack(simulator)
  slotted_load_matrix(simulator, 1, 1, 1, 3, 1, [-128], [-128, 0, 127])
  slotted_accept(simulator, 1, 1, 1, 1, 3, 1, 21)
  slotted_run(simulator, 1, 3, 1, false)
  slotted_ack(simulator)
  slotted_read(simulator, 1, 15, 0, 22, 1UL, 0)
  slotted_response_ack(simulator)
  slotted_read(simulator, 0, 2, 0, 23, 1UL, 0)
  slotted_response_ack(simulator)
  slotted_matrix_reads(simulator, 1, 1, 3, [16384, 0, -16256])
  slotted_load(simulator, "b", 1, 0, 0, 127, 1UL)
  slotted_accept(simulator, 1, 1, 1, 1, 1, 1, 24)
  slotted_run(simulator, 1, 1, 1, false)
  slotted_read(simulator, 1, 0, 1, 25, 1UL, 0)
  slotted_response_ack(simulator)
  slotted_matrix_reads(simulator, 1, 1, 1, [-16256])
  slotted_matrix_reads(
    simulator,
    0,
    2,
    2,
    @flux_tile.matmul_int8_oracle(
      [1, -2, 3, -4, 5, -6],
      [7, -8, 9, 10, -11, 12],
      rows=2,
      columns=2,
      reduction=3,
    ),
  )
}
