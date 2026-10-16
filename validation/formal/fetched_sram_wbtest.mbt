///|
test "fetched SRAM binds exact memories raw accumulator and unchanged accepted packet inputs" {
  let sequential = fetched_transport_sequential()
  let fixture = fetched_sram_fixture(sequential.probe.source)
  assert_eq(fixture.observations().length(), 83)
  ignore(fetched_sram_producer(fixture))
  assert_eq(
    fetched_packet_order_artifacts().map(item => sha256_hex(item.content)),
    [
      "e368221a8a9f9b611907afff849a7cf5e20e8ee4d6222e795f9571e9122916dc", "31ad891bbab0560db30582b9d293a7e3fdf9f5548154f8bd0ef99fa56510eead",
      "3bbf46f47312c8c6e9be390a4684df22db5db78d88ee2a659fcb35fed8f6e229", "54104b0f41568399f219b46b86d8eb79e83dec53eb38860acfc6bc436b3af5ae",
      "6ec9d3ab71e9fcc7e8e69cf300d6a30f78e18658f7b7ddd9a313698a85b34d20",
    ],
  )
  let simulator = @sim.Simulator::prepare(fixture.hardware())
  for memory in fixture.hardware().memories() {
    for slot in 0..<memory.depth().elements() {
      assert_true(simulator.memory_cell(memory.name(), slot).is_fully_unknown())
    }
    for read in memory.read_ports() {
      assert_true(simulator.value(read.result()).is_fully_unknown())
    }
  }
}

///|
test "fetched SRAM composes original public premises without initializing memories" {
  let artifacts = fetched_sram_artifacts()
  let source = artifacts[0].content
  assert_eq(source.split(": assert (").count() - 1, 164)
  assert_eq(source.split(": assume (").count() - 1, 5)
  assert_eq(source.split("(* anyseq *)").count() - 1, 12)
  assert_eq(source.split(": cover (").count() - 1, 0)
  assert_eq(source.split("\nmodule ").count() - 1, 2)
  assert_true(source.contains("lc_checked_request_end <= 34'd1024"))
  assert_true(source.contains("lc_fs_origin_address <= lc_fs_address_full"))
  assert_true(
    source.contains(
      "if (lc_fs_store_snapshot) begin lc_fs_origin_word <= lc_fs_pending_word",
    ),
  )
  assert_false(source.contains("lc_fs_store_grant_reverse: assert"))
  assert_true(source.contains("lc_fs_held_request_owner: assert"))
  assert_true(source.contains("lc_fs_reserved_mat_intent: assert"))
  assert_true(
    source.contains("lc_fs_pending_ticket == lc_fs_store_basis_ticket"),
  )
  assert_true(source.contains("lc_fs_latest_generation_1: assert"))
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_SRAM_INPUTS_PRINT") == Some("1") {
    for artifact in artifacts {
      println(
        "FETCHED-SAFETY-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-FETCHED-SAFETY-ARTIFACT \{artifact.path}")
    }
  }
}
