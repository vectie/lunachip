///|
test "Store bounds support binds all original descriptor pointers without premises" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let source = store_bounds_support_source(inputs)
  assert_eq(source, store_bounds_support_source(inputs))
  assert_eq(source.split(": assert (").count(), 9)
  assert_eq(source.split("wire [1:0] lc_bounds_lane_").count(), 9)
  assert_false(source.contains(": assume"))
  assert_false(source.contains(": cover"))
  assert_false(source.contains("anyseq"))
  assert_false(source.contains("logic "))
  for lane in 0..<4 {
    for access in ["read", "write"] {
      assert_true(
        source.contains(
          "lc_bounds_lane_\{lane}_\{access}_range: assert ((!lc_seen_edge || lc_bounds_lane_\{lane}_\{access}_pointer < 2'd3) === 1'b1);",
        ),
      )
    }
  }
  // Source-facing original bound statements are not selected away or replaced
  // by this fragment. Root's composed top must keep all twelve original labels.
  assert_eq(inputs.memory_bounds.length(), 12)
  for label in inputs.memory_bounds {
    assert_eq(inputs.positive.split(label + ": assert (").count(), 2)
  }
}

///|
test "Store bounds pointer discovery rejects unrelated fire and C-address substitution" {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  guard inputs.projection.plan.memories.filter(memory => {
      memory.name() == "descriptor_lane_0.storage"
    })
    is [fifo] &&
    fifo.read_ports() is [read] &&
    fifo.write_ports() is [write] &&
    read.enable() is Some(read_fire) &&
    write.enable() is Some(write_fire) else {
    fail("expected original descriptor lane ports")
  }
  ignore(store_bounds_pointer_identifier(inputs, read.address(), read_fire))
  try
    store_bounds_pointer_identifier(inputs, read.address(), write_fire)
  catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("expected source identity error")
  } noraise {
    _ => fail("unrelated write fire must not bind read-pointer recurrence")
  }
  guard inputs.projection.plan.memories.filter(memory => {
      memory.name() == "c_result_slot_0"
    })
    is [c] &&
    c.read_ports() is [c_read] &&
    c_read.enable() is Some(c_fire) else {
    fail("expected original C read port")
  }
  try store_bounds_pointer_identifier(inputs, c_read.address(), c_fire) catch {
    InvalidFormalBundleIdentity(_) => ()
    _ => fail("expected source identity error")
  } noraise {
    _ => fail("C arithmetic address must not substitute for FIFO pointer")
  }
}
