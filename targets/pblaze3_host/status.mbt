///|
/// Ordered BAR-relative offsets used by the read-only status command.
pub fn status_offsets() -> Array[UInt64] {
  [
    0, 4, 8, 12, 0x14, 0x18, 0x1c, 0x20, 0x24, 0x28, 0x2c, 0x30, 0x34, 0x80, 0x84,
    0x88, 0x8c, 0x38,
  ]
}

///|
/// Decoded immutable snapshot; individual register reads are not atomic.
pub(all) struct Status {
  healthy : Bool
  busy : Bool
  done : Bool
  fault : Bool
  error : UInt32
  program_count : UInt32
  pc : UInt32
  state : UInt32
  opcode : UInt32
  cycles_low : UInt32
  cycles_high : UInt32
  instructions : UInt32
  products : UInt32
  ddr_beats : UInt32
  provisional_board : Bool
  launch_sequence : UInt32
} derive(Debug, ToJson)

///|
pub extend Status with @debug.Debug::{to_repr}

///|
pub extend Status with ToJson::{to_json}

///|
pub fn decode_status(words : Array[UInt32]) -> Status raise HostError {
  if words.length() != status_offsets().length() {
    raise InvalidIoCount(
      operation="status",
      actual=words.length(),
      requested=status_offsets().length(),
    )
  }
  if words[0] != 0x50423330 {
    raise InvalidManifest(field="device_id")
  }
  if words[1] != 0x00010001 {
    raise InvalidManifest(field="abi_version")
  }
  if words[13] != 0x80000000 || words[14] != 0 {
    raise InvalidManifest(field="capacity_bytes")
  }
  if words[15] != 31 {
    raise InvalidManifest(field="address_bits")
  }
  if (words[16] & 0xfffffffe) != 0 {
    raise InvalidManifest(field="profile_flags")
  }
  {
    healthy: (words[2] & 1) != 0,
    busy: (words[2] & 2) != 0,
    done: (words[2] & 4) != 0,
    fault: (words[2] & 8) != 0,
    error: words[3],
    program_count: words[4],
    pc: words[5],
    state: words[6],
    opcode: words[7],
    cycles_low: words[8],
    cycles_high: words[9],
    instructions: words[10],
    products: words[11],
    ddr_beats: words[12],
    provisional_board: (words[16] & 1) != 0,
    launch_sequence: words[17],
  }
}

///|
/// Completion belongs to exactly the next accepted launch, including wrap.
/// A stale DONE from the previous sequence remains pending.
pub fn check_launch(
  previous : UInt32,
  count : UInt32,
  status : Status,
) -> Bool raise HostError {
  if !status.healthy || status.fault {
    raise TransportFailure(
      message="accelerator lost health or reported a fault",
    )
  }
  if status.launch_sequence == previous {
    return false
  }
  if status.launch_sequence != previous + 1 {
    raise InvalidManifest(field="unexpected_launch_sequence")
  }
  if status.program_count != count {
    raise InvalidManifest(field="completion_program_count")
  }
  status.done && !status.busy
}
