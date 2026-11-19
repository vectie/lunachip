///|
/// Reset behavior supported by the first asynchronous-FIFO profile.
pub(all) enum AsyncFifoResetPolicy {
  CoordinatedIdle
} derive(Debug, Eq)

///|
/// Canonical declaration of one checked asynchronous FIFO.
///
/// Pointer, flag, and synchronizer logic remains ordinary IR. Only the
/// primitive-private storage read is represented by `AsyncFifoRead` nodes.
pub struct AsyncFifoPrimitive {
  id : CdcPrimitiveId
  name : String
  source_domain : ClockDomainId
  destination_domain : ClockDomainId
  depth : Int32
  pointer_width : Int32
  synchronizer_stages : Int32
  reset_policy : AsyncFifoResetPolicy
  source_reset : ResetSpec
  destination_reset : ResetSpec
  payload_shape : @aggregate.Aggregate[SignalType]
  source_valid : NodeId
  source_ready : NodeId
  source_transfer : NodeId
  source_payload : ReadOnlyArray[NodeId]
  destination_ready : NodeId
  destination_valid : NodeId
  destination_transfer : NodeId
  raw_reads : ReadOnlyArray[NodeId]
  destination_payload : ReadOnlyArray[NodeId]
  write_binary : NodeId
  write_binary_next : NodeId
  read_binary : NodeId
  read_binary_next : NodeId
  write_gray : NodeId
  write_gray_next : NodeId
  read_gray : NodeId
  read_gray_next : NodeId
  read_gray_stages : ReadOnlyArray[NodeId]
  write_gray_stages : ReadOnlyArray[NodeId]
  full : NodeId
  full_next : NodeId
  nonempty : NodeId
  nonempty_next : NodeId
  write_address : NodeId
  read_address : NodeId
} derive(Debug, Eq)

///|
fn async_fifo_log2(depth : Int32) -> Int32 {
  let mut value = depth
  let mut bits = 0
  while value > 1 {
    value = value >> 1
    bits += 1
  }
  bits
}

///|
fn add_unique_async_fifo_node(
  primitive : Int32,
  seen : Map[Int32, Unit],
  node : NodeId,
) -> Unit raise IrError {
  let ordinal = node.ordinal()
  if seen.contains(ordinal) {
    raise AsyncFifoDuplicateNode(primitive~, node=ordinal)
  }
  seen[ordinal] = ()
}

///|
pub fn AsyncFifoPrimitive::checked(
  id : CdcPrimitiveId,
  name : String,
  source_domain : ClockDomainId,
  destination_domain : ClockDomainId,
  depth : Int32,
  pointer_width : Int32,
  synchronizer_stages : Int32,
  reset_policy : AsyncFifoResetPolicy,
  source_reset : ResetSpec,
  destination_reset : ResetSpec,
  payload_shape : @aggregate.Aggregate[SignalType],
  source_valid : NodeId,
  source_ready : NodeId,
  source_transfer : NodeId,
  source_payload : ArrayView[NodeId],
  destination_ready : NodeId,
  destination_valid : NodeId,
  destination_transfer : NodeId,
  raw_reads : ArrayView[NodeId],
  destination_payload : ArrayView[NodeId],
  write_binary : NodeId,
  write_binary_next : NodeId,
  read_binary : NodeId,
  read_binary_next : NodeId,
  write_gray : NodeId,
  write_gray_next : NodeId,
  read_gray : NodeId,
  read_gray_next : NodeId,
  read_gray_stages : ArrayView[NodeId],
  write_gray_stages : ArrayView[NodeId],
  full : NodeId,
  full_next : NodeId,
  nonempty : NodeId,
  nonempty_next : NodeId,
  write_address : NodeId,
  read_address : NodeId,
) -> AsyncFifoPrimitive raise IrError {
  require_name(name, "CDC primitive")
  let primitive = id.ordinal()
  if source_domain == destination_domain {
    raise EqualAsyncFifoDomains(primitive~, domain=source_domain.ordinal())
  }
  if depth < 4 || depth > 1048576 || (depth & (depth - 1)) != 0 {
    raise InvalidAsyncFifoDepth(primitive~, actual=depth)
  }
  if pointer_width != async_fifo_log2(depth) + 1 {
    raise AsyncFifoStructureMismatch(primitive~, role="pointer_width")
  }
  if synchronizer_stages < 2 || synchronizer_stages > 4 {
    raise InvalidAsyncFifoStageCount(primitive~, actual=synchronizer_stages)
  }
  if read_gray_stages.length() != synchronizer_stages {
    raise InvalidAsyncFifoStageCount(
      primitive~,
      actual=read_gray_stages.length(),
    )
  }
  if write_gray_stages.length() != synchronizer_stages {
    raise InvalidAsyncFifoStageCount(
      primitive~,
      actual=write_gray_stages.length(),
    )
  }
  let expected = validate_aggregate_shape(primitive, payload_shape, 0)
  let leaves = payload_shape.flatten()
  let mut total_width = 0
  for leaf in leaves {
    if !leaf.value().is_data() {
      raise AsyncFifoNodeTypeMismatch(
        primitive~,
        role="payload_shape",
        node=leaf.ordinal(),
      )
    }
    let leaf_width = leaf.value().width().bits()
    if leaf_width > 64 - total_width {
      raise AsyncFifoPayloadWidth(primitive~, actual=65)
    }
    total_width += leaf_width
  }
  if expected == 0 || total_width < 1 || total_width > 64 {
    raise AsyncFifoPayloadWidth(primitive~, actual=total_width)
  }
  if source_payload.length() != expected ||
    raw_reads.length() != expected ||
    destination_payload.length() != expected {
    raise AsyncFifoPayloadCountMismatch(
      primitive~,
      expected~,
      source=source_payload.length(),
      raw=raw_reads.length(),
      visible=destination_payload.length(),
    )
  }
  let seen : Map[Int32, Unit] = Map([])
  for
    node in [
      source_ready, source_transfer, destination_transfer, write_binary, write_binary_next,
      read_binary, read_binary_next, write_gray, write_gray_next, read_gray, read_gray_next,
      full, full_next, nonempty, nonempty_next, write_address, read_address,
    ] {
    add_unique_async_fifo_node(primitive, seen, node)
  }
  for
    group in [
      raw_reads.to_owned(),
      destination_payload.to_owned(),
      read_gray_stages.to_owned(),
      write_gray_stages.to_owned(),
    ] {
    for node in group {
      add_unique_async_fifo_node(primitive, seen, node)
    }
  }
  {
    id,
    name,
    source_domain,
    destination_domain,
    depth,
    pointer_width,
    synchronizer_stages,
    reset_policy,
    source_reset,
    destination_reset,
    payload_shape,
    source_valid,
    source_ready,
    source_transfer,
    source_payload: ReadOnlyArray::from_array(source_payload.to_owned()),
    destination_ready,
    destination_valid,
    destination_transfer,
    raw_reads: ReadOnlyArray::from_array(raw_reads.to_owned()),
    destination_payload: ReadOnlyArray::from_array(
      destination_payload.to_owned(),
    ),
    write_binary,
    write_binary_next,
    read_binary,
    read_binary_next,
    write_gray,
    write_gray_next,
    read_gray,
    read_gray_next,
    read_gray_stages: ReadOnlyArray::from_array(read_gray_stages.to_owned()),
    write_gray_stages: ReadOnlyArray::from_array(write_gray_stages.to_owned()),
    full,
    full_next,
    nonempty,
    nonempty_next,
    write_address,
    read_address,
  }
}

///|
pub fn AsyncFifoPrimitive::id(self : AsyncFifoPrimitive) -> CdcPrimitiveId {
  self.id
}

///|
pub fn AsyncFifoPrimitive::name(self : AsyncFifoPrimitive) -> String {
  self.name
}

///|
pub fn AsyncFifoPrimitive::source_domain(
  self : AsyncFifoPrimitive,
) -> ClockDomainId {
  self.source_domain
}

///|
pub fn AsyncFifoPrimitive::destination_domain(
  self : AsyncFifoPrimitive,
) -> ClockDomainId {
  self.destination_domain
}

///|
pub fn AsyncFifoPrimitive::depth(self : AsyncFifoPrimitive) -> Int32 {
  self.depth
}

///|
pub fn AsyncFifoPrimitive::pointer_width(self : AsyncFifoPrimitive) -> Int32 {
  self.pointer_width
}

///|
pub fn AsyncFifoPrimitive::synchronizer_stages(
  self : AsyncFifoPrimitive,
) -> Int32 {
  self.synchronizer_stages
}

///|
pub fn AsyncFifoPrimitive::reset_policy(
  self : AsyncFifoPrimitive,
) -> AsyncFifoResetPolicy {
  self.reset_policy
}

///|
pub fn AsyncFifoPrimitive::source_reset(self : AsyncFifoPrimitive) -> ResetSpec {
  self.source_reset
}

///|
pub fn AsyncFifoPrimitive::destination_reset(
  self : AsyncFifoPrimitive,
) -> ResetSpec {
  self.destination_reset
}

///|
pub fn AsyncFifoPrimitive::payload_shape(
  self : AsyncFifoPrimitive,
) -> @aggregate.Aggregate[SignalType] {
  self.payload_shape
}

///|
pub fn AsyncFifoPrimitive::source_valid(self : AsyncFifoPrimitive) -> NodeId {
  self.source_valid
}

///|
pub fn AsyncFifoPrimitive::source_ready(self : AsyncFifoPrimitive) -> NodeId {
  self.source_ready
}

///|
pub fn AsyncFifoPrimitive::source_transfer(self : AsyncFifoPrimitive) -> NodeId {
  self.source_transfer
}

///|
pub fn AsyncFifoPrimitive::source_payload(
  self : AsyncFifoPrimitive,
) -> ReadOnlyArray[NodeId] {
  self.source_payload
}

///|
pub fn AsyncFifoPrimitive::destination_ready(
  self : AsyncFifoPrimitive,
) -> NodeId {
  self.destination_ready
}

///|
pub fn AsyncFifoPrimitive::destination_valid(
  self : AsyncFifoPrimitive,
) -> NodeId {
  self.destination_valid
}

///|
pub fn AsyncFifoPrimitive::destination_transfer(
  self : AsyncFifoPrimitive,
) -> NodeId {
  self.destination_transfer
}

///|
pub fn AsyncFifoPrimitive::raw_reads(
  self : AsyncFifoPrimitive,
) -> ReadOnlyArray[NodeId] {
  self.raw_reads
}

///|
pub fn AsyncFifoPrimitive::destination_payload(
  self : AsyncFifoPrimitive,
) -> ReadOnlyArray[NodeId] {
  self.destination_payload
}

///|
pub fn AsyncFifoPrimitive::write_binary(self : AsyncFifoPrimitive) -> NodeId {
  self.write_binary
}

///|
pub fn AsyncFifoPrimitive::write_binary_next(
  self : AsyncFifoPrimitive,
) -> NodeId {
  self.write_binary_next
}

///|
pub fn AsyncFifoPrimitive::read_binary(self : AsyncFifoPrimitive) -> NodeId {
  self.read_binary
}

///|
pub fn AsyncFifoPrimitive::read_binary_next(
  self : AsyncFifoPrimitive,
) -> NodeId {
  self.read_binary_next
}

///|
pub fn AsyncFifoPrimitive::write_gray(self : AsyncFifoPrimitive) -> NodeId {
  self.write_gray
}

///|
pub fn AsyncFifoPrimitive::write_gray_next(self : AsyncFifoPrimitive) -> NodeId {
  self.write_gray_next
}

///|
pub fn AsyncFifoPrimitive::read_gray(self : AsyncFifoPrimitive) -> NodeId {
  self.read_gray
}

///|
pub fn AsyncFifoPrimitive::read_gray_next(self : AsyncFifoPrimitive) -> NodeId {
  self.read_gray_next
}

///|
pub fn AsyncFifoPrimitive::read_gray_stages(
  self : AsyncFifoPrimitive,
) -> ReadOnlyArray[NodeId] {
  self.read_gray_stages
}

///|
pub fn AsyncFifoPrimitive::write_gray_stages(
  self : AsyncFifoPrimitive,
) -> ReadOnlyArray[NodeId] {
  self.write_gray_stages
}

///|
pub fn AsyncFifoPrimitive::full(self : AsyncFifoPrimitive) -> NodeId {
  self.full
}

///|
pub fn AsyncFifoPrimitive::full_next(self : AsyncFifoPrimitive) -> NodeId {
  self.full_next
}

///|
pub fn AsyncFifoPrimitive::nonempty(self : AsyncFifoPrimitive) -> NodeId {
  self.nonempty
}

///|
pub fn AsyncFifoPrimitive::nonempty_next(self : AsyncFifoPrimitive) -> NodeId {
  self.nonempty_next
}

///|
pub fn AsyncFifoPrimitive::write_address(self : AsyncFifoPrimitive) -> NodeId {
  self.write_address
}

///|
pub fn AsyncFifoPrimitive::read_address(self : AsyncFifoPrimitive) -> NodeId {
  self.read_address
}

///|
fn AsyncFifoPrimitive::implementation_nodes(
  self : AsyncFifoPrimitive,
) -> Array[NodeId] {
  let nodes = [
    self.source_ready,
    self.source_transfer,
    self.destination_transfer,
    self.write_binary,
    self.write_binary_next,
    self.read_binary,
    self.read_binary_next,
    self.write_gray,
    self.write_gray_next,
    self.read_gray,
    self.read_gray_next,
    self.full,
    self.full_next,
    self.nonempty,
    self.nonempty_next,
    self.write_address,
    self.read_address,
  ]
  for
    group in [
      self.raw_reads,
      self.destination_payload,
      self.read_gray_stages,
      self.write_gray_stages,
    ] {
    for node in group {
      nodes.push(node)
    }
  }
  nodes
}

///|
pub extend AsyncFifoResetPolicy with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoResetPolicy with Eq::{not_equal, equal}

///|
pub extend AsyncFifoPrimitive with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend AsyncFifoPrimitive with Eq::{not_equal, equal}
