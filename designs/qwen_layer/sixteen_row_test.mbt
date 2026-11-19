///|
test "sixteen-row owners preserve signed ordered results and scalar fallback" {
  for (n, k) in [(32, 192), (16, 64), (8, 64), (3, 64)] {
    parallel_case(
      n,
      k,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
      sixteen_row=true,
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
    sixteen_row=true,
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
    sixteen_row=true,
  )
}

///|
test "sixteen-row owners drain faults health loss and delayed products" {
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
      sixteen_row=true,
    )
  }
}
