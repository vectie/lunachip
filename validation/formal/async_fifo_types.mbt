///|
pub(all) enum AsyncFifoFormalFixture {
  ValidAsyncFifo
  BrokenAsyncFifoGray
  BrokenAsyncFifoFull
  BrokenAsyncFifoAddress
  BrokenAsyncFifoStorageOrder
  BrokenAsyncFifoReadPipeline
  BrokenAsyncFifoWritePipeline
  BrokenAsyncFifoWriteAddressBounds
  BrokenAsyncFifoReadAddressBounds
} derive(Debug, Eq)

///|
pub fn AsyncFifoFormalFixture::id(self : AsyncFifoFormalFixture) -> String {
  match self {
    ValidAsyncFifo => "valid-async-fifo"
    BrokenAsyncFifoGray => "broken-async-fifo-gray"
    BrokenAsyncFifoFull => "broken-async-fifo-full"
    BrokenAsyncFifoAddress => "broken-async-fifo-address"
    BrokenAsyncFifoStorageOrder => "broken-async-fifo-storage-order"
    BrokenAsyncFifoReadPipeline => "broken-async-fifo-read-pipeline"
    BrokenAsyncFifoWritePipeline => "broken-async-fifo-write-pipeline"
    BrokenAsyncFifoWriteAddressBounds =>
      "broken-async-fifo-write-address-bounds"
    BrokenAsyncFifoReadAddressBounds => "broken-async-fifo-read-address-bounds"
  }
}

///|
pub fn AsyncFifoFormalFixture::from_id(id : String) -> AsyncFifoFormalFixture? {
  match id {
    "valid-async-fifo" => Some(ValidAsyncFifo)
    "broken-async-fifo-gray" => Some(BrokenAsyncFifoGray)
    "broken-async-fifo-full" => Some(BrokenAsyncFifoFull)
    "broken-async-fifo-address" => Some(BrokenAsyncFifoAddress)
    "broken-async-fifo-storage-order" => Some(BrokenAsyncFifoStorageOrder)
    "broken-async-fifo-read-pipeline" => Some(BrokenAsyncFifoReadPipeline)
    "broken-async-fifo-write-pipeline" => Some(BrokenAsyncFifoWritePipeline)
    "broken-async-fifo-write-address-bounds" =>
      Some(BrokenAsyncFifoWriteAddressBounds)
    "broken-async-fifo-read-address-bounds" =>
      Some(BrokenAsyncFifoReadAddressBounds)
    _ => None
  }
}

///|
pub struct AsyncFifoFormalBundle {
  fixture : AsyncFifoFormalFixture
  artifacts : ReadOnlyArray[FormalBundleArtifact]
  tasks : ReadOnlyArray[GateTask]
  job_json : String
  expected_failure : String
  completion_bound : Int
} derive(Debug, Eq)

///|
pub fn AsyncFifoFormalBundle::fixture(
  self : AsyncFifoFormalBundle,
) -> AsyncFifoFormalFixture {
  self.fixture
}

///|
pub fn AsyncFifoFormalBundle::artifacts(
  self : AsyncFifoFormalBundle,
) -> ReadOnlyArray[FormalBundleArtifact] {
  self.artifacts
}

///|
pub fn AsyncFifoFormalBundle::tasks(
  self : AsyncFifoFormalBundle,
) -> ReadOnlyArray[GateTask] {
  self.tasks
}

///|
pub fn AsyncFifoFormalBundle::job_json(self : AsyncFifoFormalBundle) -> String {
  self.job_json
}

///|
pub fn AsyncFifoFormalBundle::expected_failure(
  self : AsyncFifoFormalBundle,
) -> String {
  self.expected_failure
}

///|
pub fn AsyncFifoFormalBundle::completion_bound(
  self : AsyncFifoFormalBundle,
) -> Int {
  self.completion_bound
}

///|
pub extend AsyncFifoFormalFixture with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoFormalFixture with Eq::{not_equal, equal}

///|
pub extend AsyncFifoFormalBundle with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoFormalBundle with Eq::{not_equal, equal}
