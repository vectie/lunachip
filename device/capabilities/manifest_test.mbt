///|
test "capability manifest is deterministic fixed-order JSON with exact profile semantics" {
  let config = capability_test_config()
  assert_eq(config.manifest(), capability_test_config().manifest())
  assert_true(config.manifest().has_suffix("\n"))
  inspect(
    config.manifest(),
    content=(
      #|{
      #|  "schema": "lunachip.flux-tile-capabilities/v1",
      #|  "profile": "flux-tile-0/fetched-concurrent",
      #|  "module": "FluxTileHostConcurrent",
      #|  "device_abi": {"major": 1, "minor": 0},
      #|  "descriptor_encoding": {"major": 0, "minor": 2},
      #|  "rows": 2,
      #|  "columns": 3,
      #|  "max_reduction": 5,
      #|  "host_bytes": 4096,
      #|  "ring_depth": 4,
      #|  "queue_depth": 3,
      #|  "retirement_depth": 3,
      #|  "descriptor_bytes": 32,
      #|  "ring_alignment_bytes": 32,
      #|  "operand_slots": 2,
      #|  "result_slots": 2,
      #|  "arrays": 1,
      #|  "operand_bits": 8,
      #|  "operand_signed": true,
      #|  "accumulator_bits": 32,
      #|  "accumulator_signed": true,
      #|  "memory_address_bits": 32,
      #|  "memory_tag_bits": 32,
      #|  "memory_outstanding": 1,
      #|  "read_bytes": 1,
      #|  "write_bytes": 4,
      #|  "command_id_bits": 32,
      #|  "duplicate_command_ids": true,
      #|  "dispatch_heads": 1,
      #|  "reader_packets": 1,
      #|  "encoding": "little-endian",
      #|  "opcodes": ["LoadA", "LoadB", "MatMul", "StoreC", "Fence"],
      #|  "dispatch": "strict-in-order",
      #|  "retirement": "ordered-held",
      #|  "dependencies": "latest-writer",
      #|  "leases": "whole-slot",
      #|  "consumer_advancement": "atomic-queue-admission",
      #|  "ring_slot_reuse": "descriptor-slot-only-after-consumer-advancement",
      #|  "fifo_occupancy_scope": "fifo-only",
      #|  "accepted_command_owners": "retirement-and-dispatch-head-in-addition-to-fifo",
      #|  "reader_packet_ownership": "unadmitted-packet-owns-host-ring-slot",
      #|  "host_aliasing": "host-managed",
      #|  "host_coherency": "host-managed",
      #|  "mmio_register_map": false,
      #|  "completion_payload": "valid-only",
      #|  "counters": {
      #|    "accepted_steps_bits": 13,
      #|    "elapsed_cycles_bits": 64,
      #|    "active_cycles_bits": 64,
      #|    "stall_cycles_bits": 64,
      #|    "capture_cycles_bits": 7,
      #|    "scope": "latest-inner-issued-matmul",
      #|    "reset": "successful-inner-core-issue",
      #|    "invalid_preflight": "retain",
      #|    "overflow": "fixed-width-wrap",
      #|    "atomic_snapshot": false
      #|  },
      #|  "reset": {
      #|    "scope": "joint-device-and-transport",
      #|    "handshakes": "suppressed-while-asserted",
      #|    "registered_payloads": "clear-on-reset-clock-edge",
      #|    "host_transactions": "flush-before-release",
      #|    "physical_sram": "not-erased",
      #|    "host_writes": "not-rolled-back",
      #|    "interrupted_completions": "not-manufactured"
      #|  }
      #|}
      #|
    ),
  )
}

///|
test "manifest emits full-width aperture and binds retirement to configured queue" {
  let manifest = capability_test_config(
    rows=8,
    columns=8,
    max_reduction=4096,
    host_bytes=4294967296UL,
    ring_depth=16,
    queue_depth=16,
  ).manifest()
  for
    fragment in [
      "\"rows\": 8", "\"columns\": 8", "\"max_reduction\": 4096", "\"host_bytes\": 4294967296",
      "\"ring_depth\": 16", "\"queue_depth\": 16", "\"retirement_depth\": 16",
    ] {
    assert_true(manifest.contains(fragment))
  }
}
