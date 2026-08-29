///|
/// SplitMix64 with its algorithm and constants fixed for replayable fixtures.
pub struct DeterministicPrng {
  mut state : UInt64
}

///|
pub fn DeterministicPrng::new(seed : UInt64) -> DeterministicPrng {
  { state: seed }
}

///|
pub fn DeterministicPrng::next(self : DeterministicPrng) -> UInt64 {
  self.state = self.state + 0x9e3779b97f4a7c15UL
  let mut value = self.state
  value = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9UL
  value = (value ^ (value >> 27)) * 0x94d049bb133111ebUL
  value ^ (value >> 31)
}
