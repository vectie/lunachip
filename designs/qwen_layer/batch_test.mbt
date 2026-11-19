///|
test "batched DDR stripe requests preserve ordered FP32 and scalar fallback" {
  parallel_case(8, 192, overlap=true, wide=true, batch=true)
  parallel_case(4, 128, overlap=true, wide=true, batch=true, reset_mid=true)
  parallel_case(4, 64, overlap=true, wide=true, batch=true)
  parallel_case(3, 64, overlap=true, wide=true, batch=true)
  parallel_case(4, 64, dst=0, overlap=true, wide=true, batch=true)
}

///|
test "batched DDR early LAST late faults and health drain are terminal" {
  for fault in 1..<=5 {
    parallel_case(4, 128, overlap=true, wide=true, batch=true, fault~)
  }
}
