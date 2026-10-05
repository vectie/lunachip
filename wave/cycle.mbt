///|
/// Stable failures raised by deterministic simulation time.
pub(all) suberror SimulationTimeError {
  CycleOverflow
} derive(Debug, Eq)

///|
/// Immutable, deterministic simulation-cycle counter.
///
/// The counter is simulation state only. It never observes wall-clock time.
pub struct CycleCounter {
  priv value : UInt64
} derive(Debug, Eq)

///|
pub fn CycleCounter::zero() -> CycleCounter {
  { value: 0UL, }
}

///|
pub fn CycleCounter::from_uint64(value : UInt64) -> CycleCounter {
  { value, }
}

///|
pub fn CycleCounter::value(self : CycleCounter) -> UInt64 {
  self.value
}

///|
/// Returns the following cycle or raises rather than wrapping simulation time.
pub fn CycleCounter::next(
  self : CycleCounter,
) -> CycleCounter raise SimulationTimeError {
  if self.value == 0xffffffffffffffffUL {
    raise CycleOverflow
  }
  { value: self.value + 1UL, }
}

///|
/// Advances by a deterministic number of cycles or raises on overflow.
pub fn CycleCounter::advance(
  self : CycleCounter,
  amount : UInt64,
) -> CycleCounter raise SimulationTimeError {
  if amount > 0xffffffffffffffffUL - self.value {
    raise CycleOverflow
  }
  { value: self.value + amount, }
}

///|
pub extend SimulationTimeError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend SimulationTimeError with Eq::{not_equal, equal}

///|
pub extend CycleCounter with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CycleCounter with Eq::{not_equal, equal}
