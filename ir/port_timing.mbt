///|
/// The declared relationship between one external input and module time.
///
/// `SampledIn` means the module contract guarantees that the input is stable
/// for sampling in exactly that domain. `Asynchronous` carries no such promise.
pub(all) enum InputTiming {
  Asynchronous
  SampledIn(ClockDomainId)
} derive(Debug, Eq)

///|
/// The declared timing class of one externally visible output.
///
/// This is interface metadata, not a CDC waiver. The provenance pass separately
/// verifies that the output driver satisfies the declaration.
pub(all) enum OutputTiming {
  Static
  Asynchronous
  ProducedIn(ClockDomainId)
} derive(Debug, Eq)

///|
/// One input timing declaration keyed by canonical module-local node identity.
pub struct InputTimingBinding {
  input : NodeId
  timing : InputTiming
} derive(Debug, Eq)

///|
pub fn InputTimingBinding::new(
  input : NodeId,
  timing : InputTiming,
) -> InputTimingBinding {
  { input, timing, }
}

///|
pub fn InputTimingBinding::input(self : InputTimingBinding) -> NodeId {
  self.input
}

///|
pub fn InputTimingBinding::timing(self : InputTimingBinding) -> InputTiming {
  self.timing
}

///|
/// One output timing declaration keyed by the exact public output name.
pub struct OutputTimingBinding {
  output : String
  timing : OutputTiming
} derive(Debug, Eq)

///|
pub fn OutputTimingBinding::checked(
  output : String,
  timing : OutputTiming,
) -> OutputTimingBinding raise IrError {
  require_name(output, "timed output")
  { output, timing, }
}

///|
pub fn OutputTimingBinding::output(self : OutputTimingBinding) -> String {
  self.output
}

///|
pub fn OutputTimingBinding::timing(self : OutputTimingBinding) -> OutputTiming {
  self.timing
}

///|
pub fn Module::input_timings(
  self : Module,
) -> ReadOnlyArray[InputTimingBinding] {
  self.metadata().input_timings()
}

///|
pub fn Module::output_timings(
  self : Module,
) -> ReadOnlyArray[OutputTimingBinding] {
  self.metadata().output_timings()
}

///|
pub extend InputTiming with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend InputTiming with Eq::{not_equal, equal}

///|
pub extend OutputTiming with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OutputTiming with Eq::{not_equal, equal}

///|
pub extend InputTimingBinding with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend InputTimingBinding with Eq::{not_equal, equal}

///|
pub extend OutputTimingBinding with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend OutputTimingBinding with Eq::{not_equal, equal}
