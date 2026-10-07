///|
// Host-side collection only: this helper never calls a hardware builder.
fn store_preservation_reference(
  observations : Array[StorePreservationObservation],
  role : StorePreservationRole,
  signal : @wire.Signal,
) -> Unit {
  observations.push({
    role,
    node: signal.id(),
    signal_type: signal.signal_type(),
  })
}

///|
fn store_preservation_store_references(
  observations : Array[StorePreservationObservation],
  state : ConcurrentTransferState,
) -> Unit {
  let fields : Array[(StorePreservationStoreField, @wire.RegisterHandle)] = [
    (State, state.state),
    (Slot, state.slot),
    (Id, state.id),
    (Rows, state.rows),
    (Columns, state.columns),
    (Base, state.base),
    (Stride, state.stride),
    (Row, state.row),
    (Column, state.column),
    (Tag, state.tag),
    (ExpectedTag, state.expected_tag),
    (Progress, state.progress),
    (Fault, state.fault),
    (FaultAddress, state.fault_address),
  ]
  for (field, handle) in fields {
    store_preservation_reference(
      observations,
      StoreRegister(field),
      handle.value(),
    )
  }
}

///|
fn store_preservation_compute_references(
  observations : Array[StorePreservationObservation],
  state : ConcurrentComputeState,
) -> Unit {
  let fields : Array[(StorePreservationComputeField, @wire.RegisterHandle)] = [
    (State, state.state),
    (Leased, state.leased),
    (Id, state.id),
    (A, state.a),
    (B, state.b),
    (C, state.c),
    (Rows, state.rows),
    (Columns, state.columns),
    (Reduction, state.reduction),
    (Fault, state.fault),
  ]
  for (field, handle) in fields {
    store_preservation_reference(
      observations,
      ComputeRegister(field),
      handle.value(),
    )
  }
}

///|
fn store_preservation_slotted_references(
  observations : Array[StorePreservationObservation],
  state : SlottedState,
) -> Unit {
  let fields : Array[(StorePreservationSlottedField, @wire.RegisterHandle)] = [
    (State, state.state),
    (CaptureRow, state.capture_row),
    (CaptureColumn, state.capture_column),
    (Pending, state.pending),
    (ActiveA, state.active_a),
    (ActiveB, state.active_b),
    (ActiveC, state.active_c),
    (ResponseSlot, state.response_slot),
  ]
  for (field, handle) in fields {
    store_preservation_reference(
      observations,
      SlottedRegister(field),
      handle.value(),
    )
  }
}

///|
fn store_preservation_events(
  observations : Array[StorePreservationObservation],
  events : ArrayView[(StorePreservationEvent, @wire.Signal)],
) -> Unit {
  for (event, signal) in events {
    store_preservation_reference(observations, Event(event), signal)
  }
}
