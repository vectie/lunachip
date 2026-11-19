///|
test "one-edge feedback preserves ordered matrix sums and stripe ownership" {
  for delivery in [false, true] {
    for (n, k) in [(16, 64), (32, 64), (32, 192), (48, 128)] {
      parallel_case(
        n,
        k,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        sixteen_row=true,
        packed_weights=true,
        feedback=true,
        delivery~,
      )
    }
    parallel_case(
      16,
      128,
      packed_flag=false,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
      sixteen_row=true,
      packed_weights=true,
      feedback=true,
      delivery~,
    )
  }
}

///|
test "one-edge feedback rejects faults and resets without stale accumulation" {
  for delivery in [false, true] {
    for fault in 1..<=5 {
      parallel_case(
        32,
        128,
        fault~,
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        sixteen_row=true,
        packed_weights=true,
        feedback=true,
        delivery~,
      )
    }
    parallel_case(
      32,
      64,
      reset_mid=true,
      overlap=true,
      wide=true,
      batch=true,
      throughput=true,
      eight_row=true,
      sixteen_row=true,
      packed_weights=true,
      feedback=true,
      delivery~,
    )
    for fault in [3, 4, 5] {
      parallel_case(
        32,
        64,
        fault~,
        fault_response=if delivery { 71 } else { 135 },
        overlap=true,
        wide=true,
        batch=true,
        throughput=true,
        eight_row=true,
        sixteen_row=true,
        packed_weights=true,
        feedback=true,
        delivery~,
      )
    }
  }
}
