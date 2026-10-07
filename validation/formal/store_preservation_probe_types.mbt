///|
// Candidate inspection only: no leaf below is authorization to cut storage,
// progress, admission, ownership or a derived controller event.
priv enum StorePreservationProbeOrigin {
  RootNext(@flux_tile.StorePreservationRole)
  RootReset(@flux_tile.StorePreservationRole)
  RootEnable(@flux_tile.StorePreservationRole)
  Event(@flux_tile.StorePreservationEvent)
  ReadResult(Int)
  ReadAddress(Int, @ir.MemoryReadPortId)
  ReadEnable(Int, @ir.MemoryReadPortId)
  WriteAddress(Int, @ir.MemoryWritePortId)
  WriteData(Int, @ir.MemoryWritePortId)
  WriteEnable(Int, @ir.MemoryWritePortId)
  WriteMask(Int, @ir.MemoryWritePortId)
} derive(Debug, Eq)

///|
fn store_preservation_probe_role_type(
  role : @flux_tile.StorePreservationRole,
) -> @ir.SignalType raise {
  match role {
    StoreRegister(field) =>
      @wire.uint(
        match field {
          State => 3
          Slot => 1
          Rows | Columns | Row | Column => 13
          Fault => 4
          Id | Base | Stride | Tag | ExpectedTag | Progress | FaultAddress => 32
        },
      )
    ComputeRegister(Leased) | SlottedRegister(Pending) => @wire.bits(1)
    ComputeRegister(field) =>
      @wire.uint(
        match field {
          State => 2
          Leased =>
            raise InvalidFormalBundleIdentity(
              "Store probe: lease type dispatch",
            )
          A | B | C => 1
          Rows | Columns | Reduction => 13
          Id => 32
          Fault => 4
        },
      )
    SlottedRegister(field) =>
      @wire.uint(
        match field {
          State => 2
          CaptureRow | CaptureColumn => 4
          ActiveA | ActiveB | ActiveC | ResponseSlot => 1
          Pending =>
            raise InvalidFormalBundleIdentity(
              "Store probe: pending type dispatch",
            )
        },
      )
    CoreRegister(field) =>
      @wire.uint(
        match field {
          State | Fault => 2
          Rows | Columns => 4
          Reduction | TotalSteps | AcceptedSteps => 13
          Id => 32
        },
      )
    ResultValid(slot)
    | ResultRows(slot)
    | ResultColumns(slot)
    | CReadData(slot) => {
      if slot < 0 || slot > 1 {
        raise InvalidFormalBundleIdentity("Store probe: result slot")
      }
      match role {
        ResultValid(_) => @wire.bits(1)
        CReadData(_) => @wire.sint(32)
        _ => @wire.uint(4)
      }
    }
    ResponseId => @wire.uint(32)
    ResponseFault => @wire.uint(2)
    Event(ComputePreflight) => @wire.uint(4)
    Event(ResponseData) => @wire.sint(32)
    Event(_) => @wire.bits(1)
  }
}

///|
fn store_preservation_probe_event_roles() -> Array[
  @flux_tile.StorePreservationEvent,
] {
  [
    StoreAccept,
    StoreActive,
    StoreReadValid,
    StoreRequestValid,
    StoreRequestAccept,
    StoreResponseGood,
    StoreResponseRemote,
    StoreResponseProtocol,
    StoreInternalFault,
    StoreCancelled,
    StoreTerminal,
    ComputeAccept,
    ComputePreflight,
    ComputeLegalAccept,
    ComputeTerminal,
    ComputeRelease,
    CoreAccept,
    CoreReady,
    CoreLegal,
    CoreClearing,
    CoreRunning,
    CoreDone,
    CoreAdvance,
    CoreFinalStep,
    SlottedAccept,
    SlottedLegalAccept,
    OwnershipActive,
    Capture,
    FinalCapture,
    ReadReady,
    ReadAccept,
    ResponseValid,
    ResponseData,
  ]
}

///|
priv struct StorePreservationProbeSeed {
  origin : StorePreservationProbeOrigin
  node : @ir.NodeId
} derive(Debug, Eq)

///|
priv struct StorePreservationProbeRoot {
  binding : @flux_tile.StorePreservationObservation
  original : @ir.Node
  spec : @ir.RegisterSpec
} derive(Debug, Eq)

///|
priv struct StorePreservationProbeCandidate {
  original : @ir.Node
  memory : @ir.MemorySpec?
  // Exact seed indices, in seed order, not guessed semantic classifications.
  provenance : ReadOnlyArray[Int]
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv struct StorePreservationProbe {
  source : @ir.Module
  source_digest : String
  clock : @ir.NodeId
  reset : @ir.NodeId
  domain : @ir.ClockDomain
  roots : ReadOnlyArray[StorePreservationProbeRoot]
  events : ReadOnlyArray[@flux_tile.StorePreservationObservation]
  memories : ReadOnlyArray[@flux_tile.StorePreservationMemory]
  seeds : ReadOnlyArray[StorePreservationProbeSeed]
  candidates : ReadOnlyArray[StorePreservationProbeCandidate]
  cone : ReadOnlyArray[@ir.Node]
} derive(Debug, Eq)
