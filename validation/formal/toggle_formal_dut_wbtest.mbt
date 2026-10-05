///|
fn toggle_test_source() -> String {
  "`default_nettype none\n" +
  "module dut (\n" +
  "  input logic source\n" +
  ");\n\n" +
  "  logic node0;\n" +
  "  logic node1;\n" +
  "  logic node2;\n" +
  "  logic node3;\n" +
  "  logic [7:0] node4;\n" +
  "  logic [2:0] node5;\n" +
  "endmodule\n\n" +
  "`default_nettype wire\n"
}

///|
fn toggle_test_observations(record : Bool) -> Array[ToggleFormalObservation] {
  let observations : Array[ToggleFormalObservation] = [
    {
      role: "source_accept",
      width: 1,
      port: "lc_formal_observe_source_accept",
      node: "node0",
    },
    {
      role: "destination_capture",
      width: 1,
      port: "lc_formal_observe_destination_capture",
      node: "node1",
    },
    {
      role: "destination_consume",
      width: 1,
      port: "lc_formal_observe_destination_consume",
      node: "node2",
    },
    {
      role: "acknowledge_toggle",
      width: 1,
      port: "lc_formal_observe_acknowledge_toggle",
      node: "node3",
    },
    {
      role: "held_word",
      width: 8,
      port: "lc_formal_observe_held_word",
      node: "node4",
    },
  ]
  if record {
    observations.push({
      role: "held_tag",
      width: 3,
      port: "lc_formal_observe_held_tag",
      node: "node5",
    })
  }
  observations
}

///|
fn expect_toggle_adapter_failure(
  fixture : ToggleFormalFixture,
  source : String,
  observations : Array[ToggleFormalObservation],
) -> Unit raise {
  try toggle_add_formal_observation_ports(fixture, source, observations) catch {
    InvalidToggleHandshakeBundle(_) => ()
    _ => fail("unexpected toggle adapter error")
  } noraise {
    _ => fail("malformed toggle observation boundary was accepted")
  }
}

///|
test "toggle formal DUT preserves production emission and exact typed roles" {
  for fixture in [ValidToggleScalar2, ValidToggleRecord3, ValidToggleRecord4] {
    let built = toggle_formal_design(fixture)
    let emitted = @rtl.emit_design(built.design)
    let production = top_emitted_module(emitted)
    let formal = toggle_formal_dut(fixture, built.design, emitted, production)
    guard built.design.top_module() is Some(hardware_module) else {
      fail("toggle formal test design omitted its top module")
    }
    guard hardware_module.cdc_primitives() is [ToggleHandshake(spec)] else {
      fail("toggle formal test design omitted its primitive")
    }
    let expected_nodes = [
      ("source_accept", spec.source_accept()),
      ("destination_capture", spec.destination_capture()),
      ("destination_consume", spec.destination_consume()),
      ("acknowledge_toggle", spec.acknowledge_toggle()),
      ("held_word", spec.held_payload()[0]),
    ]
    if fixture.has_record_payload() {
      expected_nodes.push(("held_tag", spec.held_payload()[1]))
    }
    assert_false(production.source().contains("lc_formal_observe_"))
    assert_eq(
      formal.observations.map(observation => {
        (observation.role, observation.width)
      }),
      toggle_formal_expected_roles(fixture),
    )
    assert_eq(
      formal.observations.map(observation => {
        (observation.role, observation.node)
      }),
      expected_nodes.map(role_node => {
        let (role, node) = role_node
        (role, emitted_node_identifier(emitted, node.ordinal()))
      }),
    )
    assert_eq(formal.identifier(), production.identifier())
    assert_eq(formal.filename(), production.filename())
    assert_false(formal.source() == production.source())
  }
}

///|
test "toggle formal adapter exposes exact scalar and record observations" {
  for fixture in [ValidToggleScalar2, ValidToggleRecord3] {
    let record = fixture.has_record_payload()
    let observations = toggle_test_observations(record)
    let source = toggle_add_formal_observation_ports(
      fixture,
      toggle_test_source(),
      observations,
    )
    assert_eq(observations.length(), if record { 6 } else { 5 })
    for observation in observations {
      let range = toggle_formal_width_range(observation.width)
      assert_eq(
        source.split("output logic \{range}\{observation.port}").length() - 1,
        1,
      )
      assert_eq(
        source
        .split("assign \{observation.port} = \{observation.node};")
        .length() -
        1,
        1,
      )
    }
    assert_eq(source.split("\n);\n\n").length(), 2)
    assert_eq(source.split("endmodule\n\n`default_nettype wire").length(), 2)
  }
}

///|
test "toggle formal adapter rejects incomplete duplicate and invalid inventories" {
  let source = toggle_test_source()
  let incomplete = toggle_test_observations(true)
  ignore(incomplete.pop())
  expect_toggle_adapter_failure(ValidToggleRecord3, source, incomplete)
  let duplicate_role = toggle_test_observations(true)
  duplicate_role[1] = {
    role: "source_accept",
    width: 1,
    port: "lc_formal_observe_source_accept",
    node: "node1",
  }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, duplicate_role)
  let duplicate_port = toggle_test_observations(true)
  duplicate_port[5] = {
    role: "held_tag",
    width: 3,
    port: "lc_formal_observe_held_word",
    node: "node5",
  }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, duplicate_port)
  let duplicate_node = toggle_test_observations(true)
  duplicate_node[5] = {
    role: "held_tag",
    width: 3,
    port: "lc_formal_observe_held_tag",
    node: "node4",
  }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, duplicate_node)
  let wrong_width = toggle_test_observations(true)
  wrong_width[4] = {
    role: "held_word",
    width: 0,
    port: "lc_formal_observe_held_word",
    node: "node4",
  }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, wrong_width)
  let empty_role = toggle_test_observations(true)
  empty_role[5] = {
    role: "",
    width: 3,
    port: "lc_formal_observe_held_tag",
    node: "node5",
  }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, empty_role)
  let empty_port = toggle_test_observations(true)
  empty_port[5] = { role: "held_tag", width: 3, port: "", node: "node5", }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, empty_port)
  let empty_node = toggle_test_observations(true)
  empty_node[5] = {
    role: "held_tag",
    width: 3,
    port: "lc_formal_observe_held_tag",
    node: "",
  }
  expect_toggle_adapter_failure(ValidToggleRecord3, source, empty_node)
}

///|
test "toggle formal adapter rejects missing and repeated splice markers" {
  let source = toggle_test_source()
  let observations = toggle_test_observations(true)
  expect_toggle_adapter_failure(
    ValidToggleRecord3,
    source.replace(old="\n);\n\n", new="\n);\n"),
    observations,
  )
  expect_toggle_adapter_failure(
    ValidToggleRecord3,
    source.replace(old="endmodule\n\n`default_nettype wire", new="endmodule"),
    observations,
  )
  expect_toggle_adapter_failure(
    ValidToggleRecord3,
    source + source,
    observations,
  )
}
