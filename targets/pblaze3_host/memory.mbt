///|
/// Every host operation uses at most 1MiB of staging memory.
pub fn check_chunk(length : Int32) -> Unit raise HostError {
  if length < 0 || length > 1048576 {
    raise InvalidChunk(length~)
  }
}

///|
pub fn read_exact(
  manifest : Manifest,
  transport : Transport,
  address : UInt64,
  length : Int32,
) -> Bytes raise HostError {
  check_chunk(length)
  manifest.check_range(address, length.to_uint64())
  let result : Array[Byte] = []
  while result.length() < length {
    let position = address + result.length().to_uint64()
    let requested = length - result.length()
    let bytes = (transport.read)(position, requested)
    let actual = bytes.length()
    if actual == 0 {
      raise ShortIo(operation="read", address=position)
    }
    if actual > requested {
      raise InvalidIoCount(operation="read", actual~, requested~)
    }
    for byte in bytes {
      result.push(byte)
    }
  }
  Bytes::from_array(result)
}

///|
pub fn write_exact(
  manifest : Manifest,
  transport : Transport,
  address : UInt64,
  bytes : Bytes,
) -> Unit raise HostError {
  check_chunk(bytes.length())
  manifest.check_range(address, bytes.length().to_uint64())
  for offset = 0; offset < bytes.length(); {
    let position = address + offset.to_uint64()
    let remaining = bytes[offset:].to_owned()
    let requested = remaining.length()
    let actual = (transport.write)(position, remaining)
    if actual == 0 {
      raise ShortIo(operation="write", address=position)
    }
    if actual < 0 || actual > requested {
      raise InvalidIoCount(operation="write", actual~, requested~)
    }
    continue offset + actual
  }
}

///|
/// Address-dependent SplitMix64 pattern catches high-address aliases. The seed
/// selects independent deterministic passes; hardware time is not involved.
pub fn pattern(
  address : UInt64,
  length : Int32,
  seed : UInt64,
) -> Bytes raise HostError {
  check_chunk(length)
  default_manifest().check_range(address, length.to_uint64())
  Bytes::makei(length, i => {
    let byte_address = address + i.to_uint64()
    let word_address = byte_address / 8
    let z0 = (word_address ^ seed) + 0x9e3779b97f4a7c15UL
    let z1 = (z0 ^ (z0 >> 30)) * 0xbf58476d1ce4e5b9UL
    let z2 = (z1 ^ (z1 >> 27)) * 0x94d049bb133111ebUL
    let word = z2 ^ (z2 >> 31)
    (word >> ((byte_address % 8).to_int() * 8)).to_byte()
  })
}

///|
pub fn compare(
  address : UInt64,
  expected : Bytes,
  actual : Bytes,
) -> Unit raise HostError {
  if actual.length() != expected.length() {
    raise InvalidIoCount(
      operation="compare",
      actual=actual.length(),
      requested=expected.length(),
    )
  }
  for i in 0..<expected.length() {
    if expected[i] != actual[i] {
      raise DataMismatch(
        address=address + i.to_uint64(),
        expected=expected[i],
        actual=actual[i],
      )
    }
  }
}

///|
/// A two-phase test is required: write ALL regions, THEN verify ALL regions.
/// Immediate write/read of each region alone cannot detect mirrored banks.
pub fn smoke_addresses() -> Array[UInt64] {
  [
    0, 4096, 0x0ffff000, 0x10000000, 0x1ffff000, 0x20000000, 0x3ffff000, 0x40000000,
    0x60000000, 0x7ffff000,
  ]
}

///|
pub fn memory_smoke(
  manifest : Manifest,
  transport : Transport,
  seed : UInt64,
) -> Unit raise HostError {
  for address in smoke_addresses() {
    write_exact(manifest, transport, address, pattern(address, 4096, seed))
  }
  for address in smoke_addresses() {
    compare(
      address,
      pattern(address, 4096, seed),
      read_exact(manifest, transport, address, 4096),
    )
  }
}
