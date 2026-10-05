///|
// Fixed semantic keys, not guessed RTL names. Node aliases are intentional;
// each role has one distinct observation pin in the isolated formal copy.
fn queue_role_name(role : @flux_tile.QueueConservationRole) -> String {
  match role {
    FifoPushValid(lane) => "fifo_push_valid_\{lane}"
    FifoPushReady(lane) => "fifo_push_ready_\{lane}"
    FifoPopRequest(lane) => "fifo_pop_request_\{lane}"
    FifoPopReady(lane) => "fifo_pop_ready_\{lane}"
    FifoResponseValid(lane) => "fifo_response_valid_\{lane}"
    FifoResponseData(lane) => "fifo_response_data_\{lane}"
    FifoOccupancy(lane) => "fifo_occupancy_\{lane}"
    FifoFull(lane) => "fifo_full_\{lane}"
    FifoEmpty(lane) => "fifo_empty_\{lane}"
    HeadLane(lane) => "head_lane_\{lane}"
    HeadState => "head_state"
    HeadEntry => "head_entry"
    HeadTicket => "head_ticket"
    NextTicket => "next_ticket"
    HeadReserve => "head_reserve"
    HeadPop => "head_pop"
    HeadCapture => "head_capture"
    HeadIssue => "head_issue"
    HeadFinish => "head_finish"
    HeadReject => "head_reject"
    HeadFence => "head_fence"
    HeadLocalFault => "head_local_fault"
    RetirementReadPointer => "retirement_read_pointer"
    RetirementWritePointer => "retirement_write_pointer"
    RetirementOccupancy => "retirement_occupancy"
    RetirementFire => "retirement_fire"
    RetirementValid => "retirement_valid"
    RetirementId => "retirement_id"
    RetirementFault => "retirement_fault"
    RetirementProgress => "retirement_progress"
    RetirementAddress => "retirement_address"
    EntryValid(entry) => "entry_valid_\{entry}"
    EntryTerminal(entry) => "entry_terminal_\{entry}"
    EntryTicket(entry) => "entry_ticket_\{entry}"
    EntryId(entry) => "entry_id_\{entry}"
    EntryFault(entry) => "entry_fault_\{entry}"
    EntryProgress(entry) => "entry_progress_\{entry}"
    EntryAddress(entry) => "entry_address_\{entry}"
    EntryAllocate(entry) => "entry_allocate_\{entry}"
    EntryAcknowledge(entry) => "entry_acknowledge_\{entry}"
    EntryLocalTerminal(entry) => "entry_local_terminal_\{entry}"
    EntryCollector(entry, engine) => "entry_collector_\{entry}_\{engine}"
    EngineAccept(engine) => "engine_accept_\{engine}"
    EngineState(engine) => "engine_state_\{engine}"
    EngineTicket(engine) => "engine_ticket_\{engine}"
    EngineTerminal(engine) => "engine_terminal_\{engine}"
    EngineFault(engine) => "engine_fault_\{engine}"
  }
}

///|
fn queue_role_type(
  role : @flux_tile.QueueConservationRole,
) -> @ir.SignalType raise FormalGateError {
  let (width, unsigned) = match role {
    FifoResponseData(_) | HeadLane(_) => (64, false)
    FifoOccupancy(_) | HeadState => (2, true)
    HeadEntry
    | RetirementReadPointer
    | RetirementWritePointer
    | RetirementOccupancy => (5, true)
    HeadTicket
    | NextTicket
    | RetirementId
    | RetirementProgress
    | RetirementAddress
    | EntryTicket(_)
    | EntryId(_)
    | EntryProgress(_)
    | EntryAddress(_)
    | EngineTicket(_) => (32, true)
    HeadLocalFault | RetirementFault | EntryFault(_) | EngineFault(_) =>
      (4, true)
    EngineState(engine) => (if engine == 1 { 2 } else { 3 }, true)
    FifoPushValid(_)
    | FifoPushReady(_)
    | FifoPopRequest(_)
    | FifoPopReady(_)
    | FifoResponseValid(_)
    | FifoFull(_)
    | FifoEmpty(_)
    | HeadReserve
    | HeadPop
    | HeadCapture
    | HeadIssue
    | HeadFinish
    | HeadReject
    | HeadFence
    | RetirementFire
    | RetirementValid
    | EntryValid(_)
    | EntryTerminal(_)
    | EntryAllocate(_)
    | EntryAcknowledge(_)
    | EntryLocalTerminal(_)
    | EntryCollector(_, _)
    | EngineAccept(_)
    | EngineTerminal(_) => (1, false)
  }
  let width = @ir.Width::new(width) catch { error => raise IrContract(error) }
  if unsigned {
    UInt(width)
  } else {
    Bits(width)
  }
}

///|
fn queue_expected_observations() -> Array[
  (@flux_tile.QueueConservationRole, @ir.SignalType),
] raise FormalGateError {
  let roles : Array[@flux_tile.QueueConservationRole] = []
  for engine in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EngineAccept(engine),
        EngineState(engine),
        EngineTicket(engine),
        EngineTerminal(engine),
        EngineFault(engine),
      ] {
      roles.push(role)
    }
  }
  for lane in 0..<4 {
    for
      role in [
        @flux_tile.QueueConservationRole::FifoPushValid(lane),
        FifoPushReady(lane),
        FifoPopRequest(lane),
        FifoPopReady(lane),
        FifoResponseValid(lane),
        FifoResponseData(lane),
        FifoOccupancy(lane),
        FifoFull(lane),
        FifoEmpty(lane),
      ] {
      roles.push(role)
    }
  }
  for lane in 0..<4 {
    roles.push(HeadLane(lane))
  }
  for
    role in [
      @flux_tile.QueueConservationRole::HeadState,
      HeadEntry,
      HeadTicket,
      NextTicket,
      HeadReserve,
      HeadPop,
      HeadCapture,
      HeadIssue,
      HeadFinish,
      HeadReject,
      HeadFence,
      HeadLocalFault,
    ] {
    roles.push(role)
  }
  for entry in 0..<3 {
    for
      role in [
        @flux_tile.QueueConservationRole::EntryValid(entry),
        EntryTerminal(entry),
        EntryTicket(entry),
        EntryId(entry),
        EntryFault(entry),
        EntryProgress(entry),
        EntryAddress(entry),
        EntryAllocate(entry),
        EntryAcknowledge(entry),
        EntryLocalTerminal(entry),
      ] {
      roles.push(role)
    }
    for engine in 0..<3 {
      roles.push(EntryCollector(entry, engine))
    }
  }
  for
    role in [
      @flux_tile.QueueConservationRole::RetirementReadPointer,
      RetirementWritePointer,
      RetirementOccupancy,
      RetirementFire,
      RetirementValid,
      RetirementId,
      RetirementFault,
      RetirementProgress,
      RetirementAddress,
    ] {
    roles.push(role)
  }
  let expected : Array[(@flux_tile.QueueConservationRole, @ir.SignalType)] = []
  for role in roles {
    expected.push((role, queue_role_type(role)))
  }
  expected
}

///|
// Reuse the existing direct-device public roster, checking the exact ground
// type too. Dedicated Clock/Reset and uninterpreted payloads are not UInt.
fn queue_public_port_type(
  role : String,
  width : Int,
) -> @ir.SignalType raise FormalGateError {
  match role {
    "clock" => return Clock
    "reset" => return Reset
    _ => ()
  }
  let width = @ir.Width::new(width) catch { error => raise IrContract(error) }
  if width.bits() == 1 ||
    role == "descriptor_lane_0" ||
    role == "descriptor_lane_1" ||
    role == "descriptor_lane_2" ||
    role == "descriptor_lane_3" ||
    role == "memory_response_data" ||
    role == "memory_request_data" ||
    role == "memory_request_mask" {
    Bits(width)
  } else {
    UInt(width)
  }
}
