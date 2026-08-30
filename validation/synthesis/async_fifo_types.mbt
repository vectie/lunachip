///|
/// Phase 5 asynchronous-FIFO pre-map synthesis fixtures.
pub(all) enum AsyncFifoSynthesisKind {
  ScalarDepth4Stages2
  AggregateDepth4Stages3
  ScalarDepth8Stages4
} derive(Debug, Eq)

///|
pub fn AsyncFifoSynthesisKind::id(self : AsyncFifoSynthesisKind) -> String {
  match self {
    ScalarDepth4Stages2 => "async-fifo-scalar-depth4-stages2"
    AggregateDepth4Stages3 => "async-fifo-aggregate-depth4-stages3"
    ScalarDepth8Stages4 => "async-fifo-scalar-depth8-stages4"
  }
}

///|
fn AsyncFifoSynthesisKind::depth(self : AsyncFifoSynthesisKind) -> Int {
  match self {
    ScalarDepth8Stages4 => 8
    _ => 4
  }
}

///|
fn AsyncFifoSynthesisKind::stages(self : AsyncFifoSynthesisKind) -> Int {
  match self {
    ScalarDepth4Stages2 => 2
    AggregateDepth4Stages3 => 3
    ScalarDepth8Stages4 => 4
  }
}

///|
fn AsyncFifoSynthesisKind::widths(self : AsyncFifoSynthesisKind) -> Array[Int] {
  match self {
    AggregateDepth4Stages3 => [13, 3]
    _ => [13]
  }
}

///|
pub fn async_fifo_synthesis_matrix() -> ReadOnlyArray[AsyncFifoSynthesisKind] {
  ReadOnlyArray::from_array([
    ScalarDepth4Stages2,
    AggregateDepth4Stages3,
    ScalarDepth8Stages4,
  ])
}

///|
pub struct AsyncFifoSynthesisBundle {
  artifacts : ReadOnlyArray[BundleArtifact]
} derive(Debug, Eq)

///|
pub fn AsyncFifoSynthesisBundle::artifacts(
  self : AsyncFifoSynthesisBundle,
) -> ReadOnlyArray[BundleArtifact] {
  self.artifacts
}
