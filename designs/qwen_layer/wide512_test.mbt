///|
test "512-bit response feeds 32 ordered rows and retains packed-16 semantics" {
  for
    (n, k, packed) in [
      (64, 128, false),
      (48, 128, false),
      (32, 128, true),
      (16, 64, true),
      (3, 64, false),
    ] {
    parallel_case(
      n,
      k,
      wide512=true,
      feedback=true,
      delivery=true,
      throughput=true,
      overlap=true,
      wide=true,
      batch=true,
      sixteen_row=true,
      packed_weights=true,
      packed_flag=packed,
      memory=GiB2,
    )
  }
}

///|
test "64 row-major lanes use four checked requests and preserve smaller groups" {
  for (n, packed) in [(128, false), (96, false), (48, false), (64, true)] {
    parallel_case(
      n,
      128,
      wide512=true,
      rows64=true,
      feedback=true,
      delivery=true,
      throughput=true,
      overlap=true,
      wide=true,
      batch=true,
      sixteen_row=true,
      packed_weights=true,
      packed_flag=packed,
      memory=GiB2,
    )
  }
}

///|
test "diagonal RAM banking preserves all 64 rows and packed-16 layout" {
  for (n, packed) in [(128, false), (96, false), (48, false), (64, true)] {
    parallel_case(
      n,
      128,
      wide512=true,
      rows64=true,
      banked64=true,
      feedback=true,
      delivery=true,
      throughput=true,
      overlap=true,
      wide=true,
      batch=true,
      sixteen_row=true,
      packed_weights=true,
      packed_flag=packed,
      memory=GiB2,
    )
  }
}

///|
test "64-row long prefetch handles multiple stripes, following groups and short fallbacks" {
  for
    (n, k, packed, base) in [
      (128, 512, false, 0x10000U),
      (32, 256, false, 0x10200U),
      (64, 256, false, 0x10080U),
      (32, 256, true, 0x10000U),
      (48, 128, false, 0x10000U),
    ] {
    parallel_case(
      n,
      k,
      wide512=true,
      rows64=true,
      banked64=true,
      prefetch256=true,
      feedback=true,
      delivery=true,
      throughput=true,
      overlap=true,
      wide=true,
      batch=true,
      sixteen_row=true,
      packed_weights=true,
      packed_flag=packed,
      memory=GiB2,
      ddr_base=base,
    )
  }
}
