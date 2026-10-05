///|
fn synchronizer_test_observations() -> Array[SynchronizerFormalObservation] {
  [
    { port: "observe_stage0", node: "node0", },
    { port: "observe_stage1", node: "node1", },
    { port: "observe_stage2", node: "node2", },
    { port: "observe_source", node: "node3", },
  ]
}

///|
fn synchronizer_test_source() -> String {
  "`default_nettype none\n" +
  "module dut (\n" +
  "  input logic source\n" +
  ");\n\n" +
  "  logic node0;\n" +
  "  logic node1;\n" +
  "  logic node2;\n" +
  "  logic node3;\n" +
  "endmodule\n\n" +
  "`default_nettype wire\n"
}

///|
fn expect_synchronizer_adapter_failure(
  source : String,
  observations : Array[SynchronizerFormalObservation],
) -> Unit raise {
  try synchronizer_add_formal_observation_ports(source, observations) catch {
    InvalidSynchronizerBundle(_) => ()
    _ => fail("unexpected synchronizer adapter error")
  } noraise {
    _ => fail("malformed synchronizer observation boundary was accepted")
  }
}

///|
test "synchronizer formal adapter exposes four exact observation ports" {
  let source = synchronizer_add_formal_observation_ports(
    synchronizer_test_source(),
    synchronizer_test_observations(),
  )
  for observation in synchronizer_test_observations() {
    assert_eq(source.split("output logic \{observation.port}").length() - 1, 1)
    assert_eq(
      source.split("assign \{observation.port} = \{observation.node};").length() -
      1,
      1,
    )
  }
}

///|
test "synchronizer formal adapter rejects incomplete and duplicate inventories" {
  let source = synchronizer_test_source()
  let incomplete = synchronizer_test_observations()
  ignore(incomplete.pop())
  expect_synchronizer_adapter_failure(source, incomplete)
  let duplicate_port = synchronizer_test_observations()
  duplicate_port[3] = { port: "observe_stage0", node: "node3", }
  expect_synchronizer_adapter_failure(source, duplicate_port)
  let duplicate_node = synchronizer_test_observations()
  duplicate_node[3] = { port: "observe_source", node: "node0", }
  expect_synchronizer_adapter_failure(source, duplicate_node)
}

///|
test "synchronizer formal adapter rejects missing and repeated splice markers" {
  let observations = synchronizer_test_observations()
  let source = synchronizer_test_source()
  expect_synchronizer_adapter_failure(
    source.replace(old="\n);\n\n", new="\n);\n"),
    observations,
  )
  expect_synchronizer_adapter_failure(
    source.replace(old="endmodule\n\n`default_nettype wire", new="endmodule"),
    observations,
  )
  expect_synchronizer_adapter_failure(source + source, observations)
}
