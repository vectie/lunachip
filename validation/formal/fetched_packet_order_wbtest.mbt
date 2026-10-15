///|
test "fetched packet observer preserves original graph memories and accepted dependency inputs" {
  let sequential = fetched_transport_sequential()
  let original = sequential.probe.source
  let view = fetched_dependency_view(sequential)
  assert_eq(
    (view.nodes(), view.memories(), view.domains(), view.metadata()),
    (
      original.nodes(),
      original.memories(),
      original.domains(),
      original.metadata(),
    ),
  )
  assert_eq(
    fetched_dependency_artifacts().map(item => sha256_hex(item.content)),
    [
      "b4e7819f39ddb76b6b14504797c487a201798943a868fee17f8c01026bb39bd3", "3c834364a2891f3ae8eca0ed855a9ff3370643b9bb9a073e7e3eb9070cb2703f",
      "7fc7d56ea8162b0b4143d90c3b3134ba4d426f263291f62d9462edd13ceb4e75", "54104b0f41568399f219b46b86d8eb79e83dec53eb38860acfc6bc436b3af5ae",
      "4230c33067109d08dfbc63f8ae4bf4cad954fe5231a5262b1b279eba85a875d0",
    ],
  )
  let emitted = @rtl.emit_design(
    @ir.Design::single("FetchedPacketOrderView", view),
  )
  let (binary, _) = dependency_boolean_helpers(
    view,
    top_emitted_module(emitted).source(),
  )
  let observer = fetched_packet_order_observer(original, emitted)
  let inserted = fetched_packet_order_insert(binary, observer)
  assert_eq(
    inserted.replace(old=observer + "endmodule\n", new="endmodule\n"),
    binary,
  )
  assert_false(observer.contains("anyseq"))
  assert_false(observer.contains(": assume ("))
  assert_eq(observer.split(": assert (").count() - 1, 15)
  let simulator = @sim.Simulator::prepare(original)
  for memory in original.memories() {
    for slot in 0..<memory.depth().elements() {
      assert_true(simulator.memory_cell(memory.name(), slot).is_fully_unknown())
    }
    for read in memory.read_ports() {
      assert_true(simulator.value(read.result()).is_fully_unknown())
    }
  }
}

///|
test "fetched packet order composes all prior conclusions under five public premises" {
  let artifacts = fetched_packet_order_artifacts()
  let source = artifacts[0].content
  assert_eq(source.split(": assert (").count() - 1, 119)
  assert_eq(source.split(": assume (").count() - 1, 5)
  assert_eq(source.split("(* anyseq *)").count() - 1, 12)
  assert_eq(source.split(": cover (").count() - 1, 0)
  assert_eq(source.split("\nmodule ").count() - 1, 2)
  assert_true(source.contains("lc_checked_request_end <= 34'd1024"))
  assert_true(source.contains(fetched_dependency_support()))
  if @env.get_env_var("LUNACHIP_PHASE6_FETCHED_PACKET_ORDER_INPUTS_PRINT") ==
    Some("1") {
    for artifact in artifacts {
      println(
        "FETCHED-SAFETY-ARTIFACT \{artifact.path} sha256 \{sha256_hex(artifact.content)}",
      )
      println(artifact.content)
      println("END-FETCHED-SAFETY-ARTIFACT \{artifact.path}")
    }
  }
}
