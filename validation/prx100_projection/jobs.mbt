///|
fn fixture(
  tiles : Int32,
  seed : Int32,
) -> (Array[Int32], Array[Int32], Array[Array[Int32]], Array[Int32]) {
  let a = Array::makei(tiles * 16, k => (k * 29 + seed * 7) % 256 - 128)
  let w = Array::makei(tiles * 128, i => (i * 19 + seed * 31) % 256 - 128)
  let partials = Array::makei(tiles, _ => Array::make(8, 0))
  let sums = Array::make(8, 0)
  for t in 0..<tiles {
    for j in 0..<8 {
      for k in 0..<16 {
        partials[t][j] += a[t * 16 + k] * w[t * 128 + k * 8 + j]
      }
      sums[j] += partials[t][j]
    }
  }
  (a, w, partials, sums)
}

///|
fn store_codes(b : Bench, base : UInt32, codes : Array[Int32]) -> Unit {
  for i in 0..<(codes.length() / 4) {
    let mut word = 0U
    for lane in 0..<4 {
      word = word |
        ((codes[i * 4 + lane].reinterpret_as_uint() & 255U) << (lane * 8))
    }
    b.memory[base + i.reinterpret_as_uint() * 4U] = word
  }
}

///|
fn Bench::configure(self : Bench, tiles : Int32) -> Unit raise {
  for
    (address, data) in [
      (20UL, 0x100000UL),
      (24UL, 0x200000UL),
      (28UL, 0x300000UL),
      (32UL, 0x400000UL),
      (36UL, tiles.to_uint64()),
    ] {
    assert_eq(self.write(address, data), 0UL)
  }
}

///|
fn Bench::finish_job(
  self : Bench,
  tiles : Int32,
  partials : Array[Array[Int32]],
  sums : Array[Int32],
) -> Unit raise {
  for _ in 0..<160 {
    let flags = self.read(8UL)
    if (flags & 8UL) != 0UL {
      fail(
        "job fault " +
        self.read(12UL).to_string() +
        " state=" +
        self.read(116UL).to_string(),
      )
    }
    if (flags & 4UL) != 0UL {
      break
    }
    for _ in 0..<64 {
      self.step()
    }
  }
  assert_eq(self.read(8UL), 5UL)
  for
    (address, expected) in [
      (44UL, tiles),
      (48UL, tiles * 4),
      (52UL, tiles * 8),
      (96UL, tiles * 36),
      (100UL, tiles * 2),
      (104UL, tiles * 2 + 2),
      (108UL, tiles * 4),
      (112UL, tiles * 4),
      (88UL, tiles * 24),
    ] {
    assert_eq(self.read(address), expected.to_uint64())
  }
  for t in 0..<tiles {
    for j in 0..<8 {
      assert_eq(
        self.memory[0x300000U + (t * 32 + j * 4).reinterpret_as_uint()].reinterpret_as_int(),
        partials[t][j],
      )
    }
  }
  for j in 0..<8 {
    assert_eq(
      self.memory[0x400000U + j.reinterpret_as_uint() * 4U].reinterpret_as_int(),
      sums[j],
    )
    assert_eq(
      self.read(128UL + j.to_uint64() * 4UL).to_uint().reinterpret_as_int(),
      sums[j],
    )
  }
  assert_true(self.read(56UL) > self.read(88UL))
}
