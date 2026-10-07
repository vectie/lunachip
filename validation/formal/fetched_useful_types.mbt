///|
priv struct FetchedUsefulBundle {
  artifacts : ReadOnlyArray[FormalBundleArtifact]
}

///|
fn fetched_useful_id() -> String {
  "phase6-flux-tile-fetched-useful-store-r1-h1-c1"
}

///|
// Four canonical descriptor0.2 packets. Repeated caller IDs are deliberate;
// completion identity below is public retirement ordinal, never caller ID.
fn fetched_useful_packet(index : Int) -> Array[UInt64] raise FormalGateError {
  let (opcode, rows, columns, reduction, base, stride) : (
    UInt64,
    UInt64,
    UInt64,
    UInt64,
    UInt64,
    UInt64,
  ) = match index {
    0 => (0UL, 1UL, 2UL, 0UL, 256UL, 2UL)
    1 => (1UL, 2UL, 1UL, 0UL, 512UL, 1UL)
    2 => (2UL, 1UL, 1UL, 2UL, 0UL, 0UL)
    3 => (3UL, 1UL, 1UL, 0UL, 768UL, 4UL)
    _ => raise InvalidFormalBundleIdentity("fetched useful packet index")
  }
  [
    (73UL << 32) | (opcode << 16) | 0x200UL,
    rows | (columns << 16) | (reduction << 32),
    base | (stride << 32),
    0UL,
  ]
}

///|
fn fetched_useful_packet_literal(index : Int) -> String raise FormalGateError {
  let lanes = fetched_useful_packet(index)
  "{64'd\{lanes[3]}, 64'd\{lanes[2]}, 64'd\{lanes[1]}, 64'd\{lanes[0]}}"
}

///|
/// Optional input-artifact selector for the exact directed fetched Store ID.
/// Unknown IDs return None. Generation is not proof evidence or Phase 6 closure.
///
/// ```mbt check
/// test {
///   assert_eq(@formal.fetched_useful_artifacts_from_id("unknown"), None)
/// }
/// ```
pub fn fetched_useful_artifacts_from_id(
  id : String,
) -> ReadOnlyArray[FormalBundleArtifact]? raise {
  if id == fetched_useful_id() {
    Some(generate_fetched_useful_bundle().artifacts)
  } else {
    None
  }
}
