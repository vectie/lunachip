///|
fn exercise_chain(b : Bench) -> Unit raise {
  b.reset()
  assert_eq(b.read(0x9cUL), 0x43484e31UL)
  b.write(0x98UL, 0UL, response=2UL)
  b.write(0x98UL, 65536UL, response=2UL)
  b.write(0x98UL, 2UL)
  b.write(0x10UL, 2UL, response=2UL)
  b.write(0x3cUL, 0x7fffffc0UL)
  b.write(0x10UL, 2UL, response=2UL)
  assert_eq(b.read(0x38UL), 0UL)
  let base = 0x70000000UL
  for i, word in scalar_program() {
    b.memory[base + i.to_uint64() * 4UL] = word.to_uint64()
  }
  for i, word in scalar_inputs() {
    b.memory[0x7ffffff0UL + i.to_uint64() * 4UL] = word.to_uint64()
  }
  for seq in 1..<=2 {
    b.write(0x3cUL, base)
    b.write(0x98UL, 4UL)
    b.write(0x10UL, 2UL)
    assert_eq(b.read(8UL), 3UL)
    b.write(0x10UL, 2UL, response=2UL)
    b.write(0x98UL, 2UL, response=2UL)
    b.complete()
    assert_eq(b.read(0x200UL), seq.to_uint64())
    assert_eq(b.read(0x234UL), seq.to_uint64())
    assert_eq(b.read(0x20cUL), 4UL)
    assert_eq(b.read(0x224UL), 3UL)
    assert_eq(b.read(0x238UL), 1UL)
    assert_eq(b.read(0x23cUL), b.read(0x21cUL) + b.read(0x230UL) + 1UL)
    for i, word in scalar_outputs() {
      assert_eq(b.word(0x40000004UL + i.to_uint64() * 4UL), word.to_uint64())
    }
  }
}
