///|
test "PBlaze3 integrated AXIL core and AXI run high DDR scalar and packed matrix jobs" {
  exercise(bench())
}

///|
test "256-bit streaming target runs the same matrix, poisoned transfer and resident program" {
  exercise(bench(streaming=true))
}

///|
test "PBlaze3 vector pipeline retires in order across dependent descriptors" {
  exercise_vector_pipeline(bench(streaming=true, profile=true, vectors=true))
}

///|
test "scalar vector LOAD consumes one AXI beat per aligned 32-word block" {
  exercise_load_lines(
    bench(
      streaming=true,
      profile=true,
      vectors=true,
      wide512=true,
      rows64=true,
      banked64=true,
      prefetch256=true,
      scalar_lines=true,
    ),
  )
}

///|
test "faulted wide LOAD leaves scratch intact and refetches the line after reset" {
  let b = bench(
    streaming=true,
    profile=true,
    vectors=true,
    wide512=true,
    rows64=true,
    banked64=true,
    prefetch256=true,
    scalar_lines=true,
  )
  b.reset()
  let base = 0x40004000UL
  for i in 0..<32 {
    b.write(0x40000UL + 4UL * i.to_uint64(), 0x12345678UL)
    b.memory[base + 4UL * i.to_uint64()] = 0x89ab0010UL + i.to_uint64()
  }
  b.upload([..row(14U, 0U, 0U, 32U, ddr=base.to_uint()), ..row(0U, 0U, 0U, 0U)])
  b.read_fault = 2UL
  b.write(0x10UL, 1UL)
  for _ in 0..<200 {
    b.step()
  }
  assert_eq(b.read(8UL) & 8UL, 8UL)
  assert_eq(b.control.get("observe_owner"), 0UL)
  b.reset()
  for i in 0..<32 {
    assert_eq(b.read(0x40000UL + 4UL * i.to_uint64()), 0x12345678UL)
  }
  b.read_fault = 0UL
  b.write(0x14UL, 2UL)
  b.write(0x10UL, 1UL)
  b.complete()
  b.memory[base + 4UL] = 0x13572468UL
  b.write(0x10UL, 1UL)
  b.complete()
  assert_eq(b.read(0x40004UL), 0x13572468UL)
}
