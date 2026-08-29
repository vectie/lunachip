///|
/// SplitMix64 with its algorithm and constants fixed in source. The generator
/// never consults host entropy or a standard-library random implementation.
priv struct SplitMix64 {
  mut state : UInt64
}

///|
fn SplitMix64::new(seed : UInt64) -> SplitMix64 {
  { state: seed }
}

///|
fn SplitMix64::next(self : SplitMix64) -> UInt64 {
  self.state = self.state + 0x9e3779b97f4a7c15UL
  let mut value = self.state
  value = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9UL
  value = (value ^ (value >> 27)) * 0x94d049bb133111ebUL
  value ^ (value >> 31)
}

///|
fn width_mask(width : Int) -> UInt64 {
  if width == 64 {
    0xffffffffffffffffUL
  } else {
    (1UL << width) - 1UL
  }
}
