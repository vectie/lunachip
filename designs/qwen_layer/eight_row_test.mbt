///|
test "eight-row DDR groups retain ordered signed results scalar fallback and reset" {
  for (n, k) in [(32, 192), (16, 64), (8, 64), (3, 64)] {
    parallel_case(
      n,
      k,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
    )
  }
  parallel_case(
    16,
    64,
    dst=0,
    cycle_limit=60000,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
  )
  parallel_case(
    16,
    128,
    reset_mid=true,
    overlap=true,
    wide=true,
    batch=true,
    throughput=true,
    eight_row=true,
  )
}

///|
test "eight-row DDR groups retain terminal fault and health drainage" {
  for fault in 1..<=5 {
    parallel_case(
      16,
      128,
      fault~,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
    )
  }
}
