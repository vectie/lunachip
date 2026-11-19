///|
/// Existing-node references for validation; collecting them adds no hardware.
pub(all) struct Observation {
  name : String
  node : @ir.NodeId
} derive(Eq, @debug.Debug)

///|
pub extend Observation with Eq::{equal, not_equal}

///|
pub extend Observation with @debug.Debug::{to_repr}

///|
pub fn controller_evidence() -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let observations : Array[Observation] = []
  let hw = build_controller(50000000UL, observations)
  (hw, ReadOnlyArray::from_array(observations))
}

///|
pub fn bridge_evidence() -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let observations : Array[Observation] = []
  let hw = build_bridge(observations)
  (hw, ReadOnlyArray::from_array(observations))
}
