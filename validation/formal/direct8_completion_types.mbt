///|
// Private until the registry owns a published entry. This is a separate direct
// 8x8/K16 device, not a changed interpretation of any direct1 task identifier.
priv struct Direct8CompletionBundle {
  artifacts : ReadOnlyArray[FormalBundleArtifact]
}

///|
fn direct8_completion_id(fixture : DirectCompletionFixture) -> String {
  match fixture {
    Eventual => "phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718"
    UsefulStore => "phase6-flux-tile-direct8-q3-useful-store-r2-h2-c2-d11718"
    NegativeDeadline => "phase6-flux-tile-direct8-q3-negative-deadline1"
  }
}

///|
fn direct8_completion_from_id(id : String) -> DirectCompletionFixture? {
  match id {
    "phase6-flux-tile-direct8-q3-eventual-r2-h2-c2-d11718" => Some(Eventual)
    "phase6-flux-tile-direct8-q3-useful-store-r2-h2-c2-d11718" =>
      Some(UsefulStore)
    "phase6-flux-tile-direct8-q3-negative-deadline1" => Some(NegativeDeadline)
    _ => None
  }
}
