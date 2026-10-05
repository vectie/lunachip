///|
/// Read-only facts from the authoritative physical C-slot publication state.
/// Gathering these references does not allocate another validity or shape bank.
priv struct SlottedResultFact {
  valid : @wire.Signal
  rows : @wire.Signal
  columns : @wire.Signal
}

///|
/// Private integration view of already constructed storage and capture signals.
/// Host engines can inspect publication and lease release without rebuilding
/// the compute controller or adding visibility nodes to existing constructors.
priv struct SlottedGraphSignals {
  stored : StoredSignals
  result_slots : Array[SlottedResultFact]
  final_capture : @wire.Signal
  ownership_active : @wire.Signal
}
