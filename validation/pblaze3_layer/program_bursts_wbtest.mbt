///|
test "rejected response during grouped program staging cannot launch a partial program" {
  let b = bench(
    streaming=true,
    profile=true,
    vectors=true,
    wide512=true,
    rows64=true,
    banked64=true,
    prefetch256=true,
    scalar_lines=true,
    store_bursts=true,
    chain=true,
    program_bursts=true,
  )
  b.reset()
  let addr = 0x70000e00UL
  b.write(0x20000UL, 0xface1234UL)
  b.write(0x20000UL + 2047UL * 4UL, 0x87654321UL)
  b.write(0x3cUL, addr)
  b.write(0x98UL, 128UL)
  b.write(0x10UL, 2UL)
  for _ in 0..<300 {
    b.step()
    if b.control.get("program_write") == 1UL {
      break
    }
  }
  assert_eq(b.control.get("program_write"), 1UL)
  // Lose health part-way through unpacking a held beat. The committed prefix
  // is allowed; no other staged word or core launch is allowed after poison.
  b.step()
  b.drive("memory_healthy", 0UL)
  for _ in 0..<100 {
    b.step()
    assert_eq(b.control.get("program_write"), 0UL)
    assert_eq(b.control.get("start"), 0UL)
  }
  assert_eq(b.control.get("observe_loader_state"), 4UL)
  assert_eq(b.core.get("busy"), 0UL)
  b.reset()
  assert_eq(b.read(0x20000UL), b.word(addr))
  assert_eq(b.read(0x20000UL + 2047UL * 4UL), 0x87654321UL)
}
