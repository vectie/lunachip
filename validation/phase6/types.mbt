///|
/// A relative UTF-8 artifact in the deterministic independent-tool bundle.
pub(all) struct BundleArtifact {
  path : String
  content : String
}

///|
/// Frozen input trace and post-edge observations for the first fetched-device
/// fixture. Generation checks the real host result against the matrix oracle;
/// it does not invoke Verilator or claim independent RTL agreement.
pub struct FixtureBundle {
  ports : ReadOnlyArray[@verilator.HarnessPort]
  expected : @differential.ObservationSet
  expected_tsv : String
  post_reset_cycles : Int
  artifacts : ReadOnlyArray[BundleArtifact]
}

///|
pub fn FixtureBundle::id(_self : FixtureBundle) -> String {
  "fetched-concurrent-1x1-k2"
}

///|
pub fn FixtureBundle::ports(
  self : FixtureBundle,
) -> ReadOnlyArray[@verilator.HarnessPort] {
  self.ports
}

///|
pub fn FixtureBundle::expected_tsv(self : FixtureBundle) -> String {
  self.expected_tsv
}

///|
pub fn FixtureBundle::post_reset_cycles(self : FixtureBundle) -> Int {
  self.post_reset_cycles
}

///|
pub fn FixtureBundle::artifacts(
  self : FixtureBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}

///|
/// Parse exact identity-bound result rows and compare every public output.
pub fn FixtureBundle::compare_actual_tsv(
  self : FixtureBundle,
  source : String,
) -> @differential.Comparison raise {
  @differential.compare(
    self.expected,
    @verilator.parse_actual_tsv(
      source,
      self.ports,
      self.post_reset_cycles,
      result_protocol(),
    ),
  )
}

///|
priv struct FixtureRun {
  stimulus : @differential.StimulusSequence
  expected : @differential.ObservationSet
  stimulus_tsv : String
  expected_tsv : String
  cycles : Int
  summary : String
}

///|
fn result_protocol() -> @verilator.ResultProtocol raise {
  @verilator.ResultProtocol::checked(
    "LUNACHIP-PHASE6-RESULT", "1", "lunachip.flux-tile/device-abi-1.0/descriptor-0.2/fixture-v1",
  )
}
