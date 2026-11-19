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
/// One exact clock/reset domain named by the asynchronous-FIFO role inventory.
/// The fixed edge and reset semantics are rendered by the inventory codec;
/// callers cannot substitute an untyped map with missing fields.
priv struct AsyncFifoSynthesisDomainRole {
  clock : String
  reset : String
}

///|
/// One exact private storage lane and its three canonical data-path bindings.
priv struct AsyncFifoSynthesisLaneRole {
  index : Int32
  memory : String
  width : Int32
  source_payload : String
  raw_read : String
  visible_payload : String
}

///|
/// Claim boundary carried by the generated expected-contract artifact.
priv struct AsyncFifoSynthesisExpectedContract {
  kind : String
  pre_map_typed_graph : Bool
  ram_mapping : Bool
  timing : Bool
  physical_cdc : Bool
  metastability : Bool
  four_state_equivalence : Bool
}

///|
fn AsyncFifoSynthesisKind::depth(self : AsyncFifoSynthesisKind) -> Int32 {
  match self {
    ScalarDepth8Stages4 => 8
    _ => 4
  }
}

///|
fn AsyncFifoSynthesisKind::stages(self : AsyncFifoSynthesisKind) -> Int32 {
  match self {
    ScalarDepth4Stages2 => 2
    AggregateDepth4Stages3 => 3
    ScalarDepth8Stages4 => 4
  }
}

///|
fn AsyncFifoSynthesisKind::address_width(
  self : AsyncFifoSynthesisKind,
) -> Int32 {
  match self {
    ScalarDepth8Stages4 => 3
    _ => 2
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

///|
pub extend AsyncFifoSynthesisKind with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoSynthesisKind with Eq::{not_equal, equal}

///|
pub extend AsyncFifoSynthesisBundle with @moonbitlang/core/debug.Debug::{
  to_repr,
}

///|
pub extend AsyncFifoSynthesisBundle with Eq::{not_equal, equal}
