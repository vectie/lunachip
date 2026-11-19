///|
fn row(
  op : UInt32,
  dst : UInt32,
  a : UInt32,
  n : UInt32,
  k~ : UInt32 = 0U,
  ddr~ : UInt32 = 0U,
  immediate~ : UInt32 = 0U,
  flags~ : UInt32 = 0U,
) -> Array[UInt32] {
  [op, dst, a, 0U, n, k, 1U, 0U, ddr, immediate, flags, 0U, 0U, 0U, 0U, 0U]
}

///|
fn scalar_program() -> Array[UInt32] {
  [
    ..row(14U, 0U, 0U, 4U, ddr=0x7ffffff0U),
    ..row(2U, 16U, 0U, 4U, immediate=0x40000000U, flags=2U),
    ..row(15U, 0U, 16U, 4U, ddr=0x40000004U),
    ..row(0U, 0U, 0U, 0U),
  ]
}

///|
fn matrix_program() -> Array[UInt32] {
  [
    ..row(4U, 1024U, 0U, 16U, k=64U, ddr=0x7ffff800U, flags=1U),
    ..row(15U, 0U, 1024U, 16U, ddr=0x70000000U),
    ..row(0U, 0U, 0U, 0U),
  ]
}

///|
fn scalar_inputs() -> Array[UInt32] {
  [1.0F, -2.0F, 0.5F, 3.25F].map(x => x.reinterpret_as_uint())
}

///|
fn scalar_outputs() -> Array[UInt32] {
  scalar_inputs().map(x => {
    (Float::reinterpret_from_uint(x) + 2.0F).reinterpret_as_uint()
  })
}

///|
/// Deterministic board-arrival jobs matching the integrated simulation.
/// UInt32 arrays encode little-endian words; the host prepares binary files.
pub fn smoke_workloads() -> String {
  let jobs : Json = {
    "schema_version": "lunachip.pblaze3-smoke/v1",
    "jobs": [
      {
        "name": "scalar-high-memory",
        "program_words": @json.to_json(scalar_program()),
        "scratch_words": [],
        "assets": [
          {
            "name": "input",
            "address": @json.to_json(0x7ffffff0U),
            "words": @json.to_json(scalar_inputs()),
          },
        ],
        "outputs": [
          {
            "name": "output",
            "address": @json.to_json(0x40000004U),
            "words": @json.to_json(scalar_outputs()),
          },
        ],
      },
      {
        "name": "packed-matrix-upper-bound",
        "program_words": @json.to_json(matrix_program()),
        "assets": [
          {
            "name": "weights",
            "address": @json.to_json(0x7ffff800U),
            "words": @json.to_json(Array::make(512, 0x3f803f80U)),
          },
        ],
        "scratch_words": @json.to_json(Array::make(64, 0x3f800000U)),
        "outputs": [
          {
            "name": "matrix",
            "address": @json.to_json(0x70000000U),
            "words": @json.to_json(Array::make(16, 0x42800000U)),
          },
        ],
      },
    ],
  }
  jobs.stringify(indent=2) + "\n"
}

///|
fn exercise(b : Bench, program_bursts~ : Bool = false) -> Unit raise {
  assert_eq(b.read(0UL), 0x50423330UL)
  assert_eq(b.read(4UL), 0x10001UL)
  assert_eq(b.read(0x80UL), 0x80000000UL)
  assert_eq(b.read(0x38UL), 0UL)
  for i, data in scalar_inputs() {
    b.memory[0x7ffffff0UL + i.to_uint64() * 4UL] = data.to_uint64()
  }
  let before = b.word(0x40000000UL)
  let after = b.word(0x40000014UL)
  b.upload(scalar_program())
  assert_eq(b.read(0x38UL), 0UL)
  b.write(0x10UL, 1UL)
  // Accepted START is counted once despite held AXI-Lite BVALID. A posted
  // host write can use this receipt to distinguish a fresh job from old DONE.
  assert_eq(b.read(0x38UL), 1UL)
  b.write(0x10UL, 1UL, response=2UL)
  assert_eq(b.read(0x38UL), 1UL)
  b.write(0x20000UL, 0xdeadbeefUL, response=2UL)
  b.complete()
  assert_eq(b.read(0x38UL), 1UL)
  for _ in 0..<8 {
    b.step()
  }
  assert_eq(b.read(8UL), 5UL)
  assert_eq(b.read(0x38UL), 1UL)
  b.write(0x10UL, 2UL, response=2UL)
  assert_eq(b.read(8UL), 5UL)
  assert_eq(b.read(0x38UL), 1UL)
  for i, expected in scalar_outputs() {
    assert_eq(b.word(0x40000004UL + i.to_uint64() * 4UL), expected.to_uint64())
    assert_eq(b.read(0x40040UL + i.to_uint64() * 4UL), expected.to_uint64())
  }
  assert_eq(b.word(0x40000000UL), before)
  assert_eq(b.word(0x40000014UL), after)
  assert_eq(b.reads, 4)
  assert_eq(b.writes, 4)
  assert_eq(b.read(0x20000UL), 14UL)
  for i in 0..<512 {
    b.memory[0x7ffff800UL + i.to_uint64() * 4UL] = 0x3f803f80UL
  }
  for i in 0..<64 {
    b.write(0x40000UL + i.to_uint64() * 4UL, 0x3f800000UL)
  }
  b.upload(matrix_program())
  b.write(0x10UL, 1UL)
  assert_eq(b.read(0x38UL), 2UL)
  b.complete()
  assert_eq(b.read(0x38UL), 2UL)
  for i in 0..<16 {
    assert_eq(b.word(0x70000000UL + i.to_uint64() * 4UL), 0x42800000UL)
    assert_eq(b.read(0x41000UL + i.to_uint64() * 4UL), 0x42800000UL)
  }
  assert_eq(b.read(0x30UL), 1024UL)
  assert_eq(b.read(0x34UL), 528UL)
  assert_eq(b.reads, if b.lanes >= 8 { 20 } else { 132 })
  assert_eq(b.writes, 20)
  // Poison the first half of a wide response. The core must fault and the
  // controller must drain all owned beats without accepting a new job.
  b.read_fault = 2UL
  b.write(0x10UL, 1UL)
  assert_eq(b.read(0x38UL), 3UL)
  for _ in 0..<300 {
    b.step()
  }
  assert_eq(b.read(8UL) & 8UL, 8UL)
  assert_eq(b.control.get("observe_owner"), 0UL)
  assert_eq(b.control.get("observe_protocol"), 0UL)
  assert_eq(b.core.get("products"), 0UL)
  b.write(0x10UL, 1UL, response=2UL)
  assert_eq(b.read(0x38UL), 3UL)
  b.reset()
  assert_eq(b.read(0x38UL), 0UL)
  // Program/scratch contents survive reset. Interrupt a newly accepted read,
  // resetting the mock interconnect together with all three digital blocks.
  b.write(0x14UL, 3UL)
  b.write(0x10UL, 1UL)
  assert_eq(b.read(0x38UL), 1UL)
  for _ in 0..<100 {
    b.step()
    if !b.rd.is_empty() {
      break
    }
  }
  assert_true(!b.rd.is_empty())
  assert_eq(b.core.get("busy"), 1UL)
  b.reset()
  assert_eq(b.read(0x38UL), 0UL)
  assert_eq(b.read(8UL), 1UL)
  b.write(0x14UL, 3UL)
  b.write(0x10UL, 1UL)
  assert_eq(b.read(0x38UL), 1UL)
  b.complete()
  assert_eq(b.read(0x38UL), 1UL)
  for i in 0..<16 {
    assert_eq(b.word(0x70000000UL + i.to_uint64() * 4UL), 0x42800000UL)
  }
  assert_eq(b.read(0x30UL), 1024UL)
  assert_eq(b.read(0x34UL), 528UL)
  exercise_resident(b, program_bursts~)
}

///|
fn exercise_resident(b : Bench, program_bursts~ : Bool = false) -> Unit raise {
  let program = scalar_program()
  for i, word in scalar_inputs() {
    b.memory[0x7ffffff0UL + i.to_uint64() * 4UL] = word.to_uint64()
  }
  let base = 0x60000fc0UL // includes a 4 KiB boundary
  for i, word in program {
    b.memory[base + i.to_uint64() * 4UL] = word.to_uint64()
  }
  assert_eq(b.read(0x90UL), 1UL)
  b.write(0x3cUL, base)
  b.write(0x14UL, (program.length() / 16).to_uint64())
  for trial in 0..<2 {
    b.write(0x44UL, 4UL)
    b.write(0x48UL, 0x40000004UL)
    assert_eq(b.read(0x4cUL), 0xffffffffUL)
    let sequence = b.read(0x38UL)
    let reads = b.reads
    b.write(0x10UL, 1UL)
    assert_eq(b.read(0x38UL), sequence + 1UL)
    assert_eq(b.read(8UL), 3UL)
    b.write(0x14UL, 1UL, response=2UL)
    b.complete(polls=2000)
    assert_true(b.read(0x40UL) > 64UL)
    assert_true(b.read(0x24UL) > 0UL)
    assert_eq(
      b.reads - reads,
      (if program_bursts { 16 + 1 + 16 } else { program.length() }) + 4,
    )
    assert_eq(b.read(0x4cUL), 3UL)
    assert_eq(b.read(0xa0UL), sequence + 1UL)
    assert_eq(b.read(0xd4UL), sequence + 1UL)
    for i, expected in scalar_outputs() {
      assert_eq(
        b.word(0x40000004UL + i.to_uint64() * 4UL),
        expected.to_uint64(),
      )
    }
    // A cached local-program corruption must be repaired from resident DDR.
    if trial == 0 {
      b.write(0x20000UL, 0UL)
    }
  }
  b.read_fault = 2UL
  b.write(0x10UL, 1UL)
  for _ in 0..<100 {
    b.step()
  }
  assert_eq(b.read(12UL), 256UL)
  assert_eq(b.core.get("busy"), 0UL)
  assert_eq(b.read(8UL) & 12UL, 8UL)
  b.write(0x10UL, 1UL, response=2UL)
}
