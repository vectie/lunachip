///|
test "bit-level UART framing yields an independently decoded Identify response" {
  let bundle = @prx100_board.generate_uart_bundle()
  assert_true(bundle.any(a => a.path == "expected.tsv"))
}
