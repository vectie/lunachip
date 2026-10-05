///|
fn ModuleBuilder::require_reset_signal(
  self : ModuleBuilder,
  signal : Signal,
) -> Unit raise {
  self.require_open()
  self.require_signal(signal)
  if !(signal.signal_type is Reset) {
    raise @ir.IrError::ExpectedReset(node=signal.id.ordinal())
  }
}

///|
/// Construct a synchronous active-high reset control. Its raw value is checked
/// against each register type when attached.
pub fn ModuleBuilder::synchronous_reset(
  self : ModuleBuilder,
  signal : Signal,
  value : UInt64,
) -> SynchronousReset raise {
  self.require_reset_signal(signal)
  {
    owner: self.owner,
    signal,
    canonical: @ir.ResetSpec::new(signal.id, value),
  }
}

///|
/// Construct an active-low synchronous reset without changing the historical
/// active-high `synchronous_reset` API.
pub fn ModuleBuilder::synchronous_reset_active_low(
  self : ModuleBuilder,
  signal : Signal,
  value : UInt64,
) -> SynchronousReset raise {
  self.require_reset_signal(signal)
  {
    owner: self.owner,
    signal,
    canonical: @ir.ResetSpec::explicit(signal.id, value, Synchronous, ActiveLow),
  }
}

///|
/// Construct an active-high asynchronous reset control.
pub fn ModuleBuilder::asynchronous_reset(
  self : ModuleBuilder,
  signal : Signal,
  value : UInt64,
) -> AsynchronousReset raise {
  self.require_reset_signal(signal)
  {
    owner: self.owner,
    signal,
    canonical: @ir.ResetSpec::explicit(
      signal.id,
      value,
      Asynchronous,
      ActiveHigh,
    ),
  }
}

///|
/// Construct an active-low asynchronous reset control.
pub fn ModuleBuilder::asynchronous_reset_active_low(
  self : ModuleBuilder,
  signal : Signal,
  value : UInt64,
) -> AsynchronousReset raise {
  self.require_reset_signal(signal)
  {
    owner: self.owner,
    signal,
    canonical: @ir.ResetSpec::explicit(
      signal.id,
      value,
      Asynchronous,
      ActiveLow,
    ),
  }
}
