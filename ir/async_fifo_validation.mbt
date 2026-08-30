///|
fn validate_async_fifo(
  spec : AsyncFifoPrimitive,
  domains : ArrayView[ClockDomain],
  nodes : ArrayView[Node],
  memories : ArrayView[MemorySpec],
  outputs : ArrayView[OutputPort],
) -> Unit raise IrError {
  let primitive = spec.id().ordinal()
  require_fifo_domain(primitive, "source_domain", spec.source_domain(), domains)
  require_fifo_domain(
    primitive,
    "destination_domain",
    spec.destination_domain(),
    domains,
  )
  require_fifo_reset(primitive, "source_reset", spec.source_reset(), nodes)
  require_fifo_reset(
    primitive,
    "destination_reset",
    spec.destination_reset(),
    nodes,
  )
  let bit_type = Bits(Width::new(1))
  let pointer_type = UInt(Width::new(spec.pointer_width()))
  for
    item in [
      ("source_valid", spec.source_valid()),
      ("source_ready", spec.source_ready()),
      ("source_transfer", spec.source_transfer()),
      ("destination_ready", spec.destination_ready()),
      ("destination_valid", spec.destination_valid()),
      ("destination_transfer", spec.destination_transfer()),
      ("full", spec.full()),
      ("full_next", spec.full_next()),
      ("nonempty", spec.nonempty()),
      ("nonempty_next", spec.nonempty_next()),
    ] {
    ignore(require_fifo_type(primitive, item.0, item.1, bit_type, nodes))
  }
  if spec.destination_valid() != spec.nonempty() {
    raise AsyncFifoStructureMismatch(primitive~, role="destination_valid_alias")
  }
  require_fifo_not(
    primitive,
    "source_ready",
    spec.source_ready(),
    spec.full(),
    nodes,
  )
  require_fifo_and(
    primitive,
    "source_transfer",
    spec.source_transfer(),
    spec.source_valid(),
    spec.source_ready(),
    nodes,
  )
  require_fifo_and(
    primitive,
    "destination_transfer",
    spec.destination_transfer(),
    spec.destination_valid(),
    spec.destination_ready(),
    nodes,
  )
  let (write_advance, write_one) = require_fifo_binary_next(
    primitive,
    "write_binary_next",
    spec.write_binary_next(),
    spec.write_binary(),
    spec.source_transfer(),
    pointer_type,
    nodes,
  )
  let (read_advance, read_one) = require_fifo_binary_next(
    primitive,
    "read_binary_next",
    spec.read_binary_next(),
    spec.read_binary(),
    spec.destination_transfer(),
    pointer_type,
    nodes,
  )
  let (write_shift, write_shift_one) = require_fifo_gray_next(
    primitive,
    "write_gray_next",
    spec.write_gray_next(),
    spec.write_binary_next(),
    pointer_type,
    nodes,
  )
  let (read_shift, read_shift_one) = require_fifo_gray_next(
    primitive,
    "read_gray_next",
    spec.read_gray_next(),
    spec.read_binary_next(),
    pointer_type,
    nodes,
  )
  require_fifo_register(
    primitive,
    "write_binary",
    spec.write_binary(),
    pointer_type,
    spec.source_domain(),
    spec.write_binary_next(),
    spec.source_reset(),
    nodes,
  )
  require_fifo_register(
    primitive,
    "write_gray",
    spec.write_gray(),
    pointer_type,
    spec.source_domain(),
    spec.write_gray_next(),
    spec.source_reset(),
    nodes,
  )
  require_fifo_register(
    primitive,
    "full",
    spec.full(),
    bit_type,
    spec.source_domain(),
    spec.full_next(),
    spec.source_reset(),
    nodes,
  )
  require_fifo_register(
    primitive,
    "read_binary",
    spec.read_binary(),
    pointer_type,
    spec.destination_domain(),
    spec.read_binary_next(),
    spec.destination_reset(),
    nodes,
  )
  require_fifo_register(
    primitive,
    "read_gray",
    spec.read_gray(),
    pointer_type,
    spec.destination_domain(),
    spec.read_gray_next(),
    spec.destination_reset(),
    nodes,
  )
  require_fifo_register(
    primitive,
    "nonempty",
    spec.nonempty(),
    bit_type,
    spec.destination_domain(),
    spec.nonempty_next(),
    spec.destination_reset(),
    nodes,
  )
  require_fifo_synchronizer(
    primitive,
    "read_gray_stage",
    spec.read_gray(),
    spec.read_gray_stages(),
    pointer_type,
    spec.source_domain(),
    spec.source_reset(),
    nodes,
  )
  require_fifo_synchronizer(
    primitive,
    "write_gray_stage",
    spec.write_gray(),
    spec.write_gray_stages(),
    pointer_type,
    spec.destination_domain(),
    spec.destination_reset(),
    nodes,
  )
  let full_node = require_fifo_type(
    primitive,
    "full_next",
    spec.full_next(),
    bit_type,
    nodes,
  )
  guard full_node.kind() is Equal(left, right) else {
    raise AsyncFifoStructureMismatch(primitive~, role="full_next")
  }
  let adjusted = if left == spec.write_gray_next() {
    right
  } else if right == spec.write_gray_next() {
    left
  } else {
    raise AsyncFifoStructureMismatch(primitive~, role="full_next")
  }
  let adjusted_node = require_fifo_type(
    primitive, "full_next_remote", adjusted, pointer_type, nodes,
  )
  guard adjusted_node.kind() is BitXor(remote, mask) &&
    remote == spec.read_gray_stages()[spec.synchronizer_stages() - 1] else {
    raise AsyncFifoStructureMismatch(primitive~, role="full_next")
  }
  let mask_node = require_fifo_type(
    primitive, "full_next_mask", mask, pointer_type, nodes,
  )
  let expected_mask = 3UL << (spec.pointer_width() - 2)
  if !(mask_node.kind() is Constant(value) && value == expected_mask) {
    raise AsyncFifoStructureMismatch(primitive~, role="full_next")
  }
  let nonempty_node = require_fifo_type(
    primitive,
    "nonempty_next",
    spec.nonempty_next(),
    bit_type,
    nodes,
  )
  guard nonempty_node.kind() is BitNot(equal_id) else {
    raise AsyncFifoStructureMismatch(primitive~, role="nonempty_next")
  }
  let equal_node = require_fifo_type(
    primitive, "nonempty_next_equal", equal_id, bit_type, nodes,
  )
  guard equal_node.kind() is Equal(read_next, synchronized_write) &&
    fifo_pair_matches(
      read_next,
      synchronized_write,
      spec.read_gray_next(),
      spec.write_gray_stages()[spec.synchronizer_stages() - 1],
    ) else {
    raise AsyncFifoStructureMismatch(primitive~, role="nonempty_next")
  }
  for index, stage in spec.read_gray_stages() {
    validate_fifo_hidden_fanout(
      primitive,
      "read_gray_stage_\{index}",
      stage,
      if index + 1 < spec.read_gray_stages().length() {
        [spec.read_gray_stages()[index + 1]]
      } else {
        [adjusted]
      },
      nodes,
      memories,
      outputs,
    )
  }
  for index, stage in spec.write_gray_stages() {
    validate_fifo_hidden_fanout(
      primitive,
      "write_gray_stage_\{index}",
      stage,
      if index + 1 < spec.write_gray_stages().length() {
        [spec.write_gray_stages()[index + 1]]
      } else {
        [equal_id]
      },
      nodes,
      memories,
      outputs,
    )
  }
  validate_fifo_hidden_fanout(
    primitive,
    "write_gray_crossing",
    spec.write_gray(),
    [spec.write_gray_stages()[0]],
    nodes,
    memories,
    outputs,
  )
  validate_fifo_hidden_fanout(
    primitive,
    "read_gray_crossing",
    spec.read_gray(),
    [spec.read_gray_stages()[0]],
    nodes,
    memories,
    outputs,
  )
  let address_width = spec.pointer_width() - 1
  let write_address_slice = require_fifo_address(
    primitive,
    "write_address",
    spec.write_address(),
    spec.write_binary(),
    address_width,
    nodes,
  )
  let read_address_slice = require_fifo_address(
    primitive,
    "read_address",
    spec.read_address(),
    spec.read_binary(),
    address_width,
    nodes,
  )
  if write_one != read_one ||
    write_one != write_shift_one ||
    write_one != read_shift_one {
    raise AsyncFifoStructureMismatch(primitive~, role="pointer_increment_one")
  }
  for
    item in [
      ("write_advance", write_advance, [spec.write_binary_next()]),
      ("read_advance", read_advance, [spec.read_binary_next()]),
      ("write_gray_shift", write_shift, [spec.write_gray_next()]),
      ("read_gray_shift", read_shift, [spec.read_gray_next()]),
      ("full_remote_adjust", adjusted, [spec.full_next()]),
      ("nonempty_equal", equal_id, [spec.nonempty_next()]),
      ("full_mask", mask, [adjusted]),
      (
        "pointer_increment_one",
        write_one,
        [write_advance, read_advance, write_shift, read_shift],
      ),
      ("source_transfer", spec.source_transfer(), [spec.write_binary_next()]),
      (
        "destination_transfer",
        spec.destination_transfer(),
        [spec.read_binary_next()],
      ),
      (
        "write_binary",
        spec.write_binary(),
        [write_advance, spec.write_binary_next(), write_address_slice],
      ),
      (
        "write_binary_next",
        spec.write_binary_next(),
        [spec.write_binary(), write_shift, spec.write_gray_next()],
      ),
      (
        "write_gray_next",
        spec.write_gray_next(),
        [spec.write_gray(), spec.full_next()],
      ),
      (
        "read_binary",
        spec.read_binary(),
        [read_advance, spec.read_binary_next(), read_address_slice],
      ),
      (
        "read_binary_next",
        spec.read_binary_next(),
        [spec.read_binary(), read_shift, spec.read_gray_next()],
      ),
      ("read_gray_next", spec.read_gray_next(), [spec.read_gray(), equal_id]),
      ("full", spec.full(), [spec.source_ready()]),
      ("full_next", spec.full_next(), [spec.full()]),
      ("nonempty_next", spec.nonempty_next(), [spec.nonempty()]),
      ("write_address_slice", write_address_slice, [spec.write_address()]),
      ("read_address_slice", read_address_slice, [spec.read_address()]),
    ] {
    validate_fifo_hidden_fanout(
      primitive,
      item.0,
      item.1,
      item.2,
      nodes,
      memories,
      outputs,
    )
  }
  let shape_leaves = spec.payload_shape().flatten()
  for index in 0..<shape_leaves.length() {
    let expected_type = shape_leaves[index].value()
    ignore(
      require_fifo_type(
        primitive,
        "source_payload_\{index}",
        spec.source_payload()[index],
        expected_type,
        nodes,
      ),
    )
    let raw = require_fifo_type(
      primitive,
      "raw_read_\{index}",
      spec.raw_reads()[index],
      expected_type,
      nodes,
    )
    if !(raw.kind() is AsyncFifoRead(primitive=owner, leaf~) &&
      owner == spec.id() &&
      leaf == index) {
      raise AsyncFifoStructureMismatch(primitive~, role="raw_read_\{index}")
    }
    let visible = require_fifo_type(
      primitive,
      "destination_payload_\{index}",
      spec.destination_payload()[index],
      expected_type,
      nodes,
    )
    guard visible.kind() is Mux(select~, when_true~, when_false~) &&
      select == spec.destination_valid() &&
      when_true == spec.raw_reads()[index] else {
      raise AsyncFifoStructureMismatch(
        primitive~,
        role="destination_payload_\{index}",
      )
    }
    let zero = require_fifo_type(
      primitive,
      "destination_payload_zero_\{index}",
      when_false,
      expected_type,
      nodes,
    )
    if !(zero.kind() is Constant(0UL)) {
      raise AsyncFifoStructureMismatch(
        primitive~,
        role="destination_payload_\{index}",
      )
    }
    validate_fifo_hidden_fanout(
      primitive,
      "destination_payload_zero_\{index}",
      when_false,
      [spec.destination_payload()[index]],
      nodes,
      memories,
      outputs,
    )
    validate_fifo_hidden_fanout(
      primitive,
      "raw_read_\{index}",
      spec.raw_reads()[index],
      [spec.destination_payload()[index]],
      nodes,
      memories,
      outputs,
    )
  }
  validate_fifo_hidden_fanout(
    primitive,
    "write_address",
    spec.write_address(),
    [],
    nodes,
    memories,
    outputs,
  )
  validate_fifo_hidden_fanout(
    primitive,
    "read_address",
    spec.read_address(),
    [],
    nodes,
    memories,
    outputs,
  )
}
