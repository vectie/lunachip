///|
// Exact original component with reviewed raw interfaces made symbolic.
// No observer state, property, assumption or proof result is added here.
#warnings("-unused_field")
priv struct TwoClientArbiterSequential {
  hardware : @ir.Module
  probe : TwoClientArbiterProbe
  original_to_local : ReadOnlyArray[@ir.NodeId?]
}
