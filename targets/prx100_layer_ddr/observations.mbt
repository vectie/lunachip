///|
/// Exact-node evidence seam; it adds no hardware ports or logic.
pub struct Observation {
  name : String
  node : @ir.NodeId
}

///|
/// Return the ordinary bridge and references to its actual control nodes.
pub fn bridge_evidence() -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let nodes = []
  let hw = build_bridge(nodes)
  (hw, ReadOnlyArray::from_array(nodes))
}

///|
/// Exact-node evidence seam for the native-width bridge profile.
pub fn wide_bridge_evidence() -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let nodes = []
  let hw = build_bridge(nodes, wide=true)
  (hw, ReadOnlyArray::from_array(nodes))
}

///|
/// Observation-only references for the batched bridge.
pub fn batched_bridge_evidence() -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let nodes = []
  let hw = build_bridge(nodes, wide=true, batch=true)
  (hw, ReadOnlyArray::from_array(nodes))
}

///|
/// Observation-only references for the interleaved streaming bridge.
/// `staggered=true` deliberately alternates two/three synchronizer stages
/// for digital tests of unequal flag arrival; production uses two throughout.
pub fn streaming_bridge_evidence(
  staggered~ : Bool = false,
) -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let nodes = []
  let hw = build_bridge(
    nodes,
    wide=true,
    batch=true,
    streaming=true,
    staggered~,
  )
  (hw, ReadOnlyArray::from_array(nodes))
}

///|
/// Observation-only references for bounded four-row read-ahead.
pub fn read_ahead_bridge_evidence(
  staggered~ : Bool = false,
  eight_row~ : Bool = false,
  sixteen_row~ : Bool = false,
  aligned_extent~ : Bool = false,
  delivery~ : Bool = false,
) -> (@ir.Module, ReadOnlyArray[Observation]) raise {
  let nodes = []
  let hw = build_bridge(
    nodes,
    wide=true,
    batch=true,
    streaming=true,
    read_ahead=true,
    eight_row~,
    sixteen_row~,
    staggered~,
    aligned_extent~,
    delivery~,
  )
  (hw, ReadOnlyArray::from_array(nodes))
}
