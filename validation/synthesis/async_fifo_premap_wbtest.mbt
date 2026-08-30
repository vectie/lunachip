///|
fn premap_genuine_schema_fixture(
  register_name : String,
  raw_read_bit : String,
) -> String {
  let template =
    #|{
    #|  "creator": "Yosys 0.68+1",
    #|  "modules": {
    #|    "fifo_top": {
    #|      "attributes": {},
    #|      "ports": {
    #|        "clock": { "direction": "input", "bits": [1] }
    #|      },
    #|      "cells": {
    #|        "REGISTER_NAME": {
    #|          "hide_name": 1,
    #|          "type": "$dff",
    #|          "parameters": { "CLK_POLARITY": "1", "WIDTH": "1" },
    #|          "attributes": {},
    #|          "port_directions": { "CLK": "input", "D": "input", "Q": "output" },
    #|          "connections": { "CLK": [1], "D": [2], "Q": [3] }
    #|        },
    #|        "$memory$generated": {
    #|          "hide_name": 1,
    #|          "type": "$mem_v2",
    #|          "parameters": { "WIDTH": "1", "SIZE": "100" },
    #|          "attributes": {},
    #|          "port_directions": { "RD_DATA": "output", "RD_ADDR": "input" },
    #|          "connections": { "RD_DATA": [RAW_READ_BIT], "RD_ADDR": [4] }
    #|        }
    #|      },
    #|      "netnames": {
    #|        "clock": { "hide_name": 0, "bits": [1], "attributes": {} },
    #|        "state": { "hide_name": 0, "bits": [3], "attributes": {} },
    #|        "raw": { "hide_name": 0, "bits": [RAW_READ_BIT], "attributes": {} },
    #|        "unknown": { "hide_name": 0, "bits": ["x"], "attributes": {} }
    #|      }
    #|    }
    #|  }
    #|}
  template
  .replace(old="REGISTER_NAME", new=register_name)
  .replace(old="RAW_READ_BIT", new=raw_read_bit)
  .replace(old="RAW_READ_BIT", new=raw_read_bit)
}

///|
fn premap_test_signal(wire : Int) -> PreMapSignal {
  { bits: [Wire(wire)] }
}

///|
fn premap_test_cell(
  name : String,
  cell_type : String,
  connections : Array[(String, PreMapSignal)],
  directions : Array[(String, String)],
  parameters? : Array[(String, String)] = [],
) -> PreMapCell {
  {
    name,
    cell_type,
    parameters: Map(parameters),
    connections: Map(connections),
    directions: Map(directions),
  }
}

///|
fn premap_register_fixture(
  register_name : String,
  q_wire : Int,
  clock_wire : Int,
  d_wire : Int,
  mux_next_wire : Int,
  mux_reset_wire : Int,
) -> PreMapModule {
  {
    name: "fifo_top",
    ports: Map([]),
    netnames: Map([]),
    cells: [
      premap_test_cell(
        register_name,
        "$dff",
        [
          ("CLK", premap_test_signal(clock_wire)),
          ("D", premap_test_signal(d_wire)),
          ("Q", premap_test_signal(q_wire)),
        ],
        [("CLK", "input"), ("D", "input"), ("Q", "output")],
        parameters=[("CLK_POLARITY", "1")],
      ),
      premap_test_cell(
        "$generated_mux_name",
        "$mux",
        [
          ("A", premap_test_signal(mux_next_wire)),
          ("B", { bits: [Zero] }),
          ("S", premap_test_signal(mux_reset_wire)),
          ("Y", premap_test_signal(d_wire)),
        ],
        [("A", "input"), ("B", "input"), ("S", "input"), ("Y", "output")],
      ),
    ],
  }
}

///|
fn premap_has_issue(
  issues : Array[AsyncFifoPreMapIssue],
  code : String,
) -> Bool {
  issues.any(issue => issue.code == code)
}

///|
test "strict parser accepts genuine Yosys 0.68 schema and typed bits" {
  let document = parse_yosys_pre_map_json(
    premap_genuine_schema_fixture("$auto$dff$17", "6"),
  )
  assert_eq(document.hardware_module.name, "fifo_top")
  assert_eq(document.hardware_module.cells.length(), 2)
  assert_eq(document.hardware_module.netnames["unknown"].bits, [Unknown])
  assert_eq(document.hardware_module.netnames["raw"].bits, [Wire(6)])
  let memory = premap_find_cells(
    document.hardware_module,
    "$mem_v2",
    "RD_DATA",
    premap_test_signal(6),
  )
  assert_eq(memory.length(), 1)
  assert_eq(memory[0].name, "$memory$generated")
}

///|
test "generated cell renaming cannot change bit-bound ownership" {
  for name in ["$auto$dff$17", "$auto$dff$999999"] {
    let document = parse_yosys_pre_map_json(
      premap_genuine_schema_fixture(name, "6"),
    )
    let owners = premap_find_cells(
      document.hardware_module,
      "$dff",
      "Q",
      premap_test_signal(3),
    )
    assert_eq(owners.length(), 1)
    assert_eq(owners[0].name, name)
  }
}

///|
test "strict parser isolates unknown-key and invalid-bit mutants" {
  try
    parse_yosys_pre_map_json(
      "{\"creator\":\"Yosys 0.68+1\",\"modules\":{},\"extra\":0}",
    )
  catch {
    UnknownKey(path~, key~) => {
      assert_eq(path, "$")
      assert_eq(key, "extra")
    }
    error => fail("unexpected strict-schema error: \{Repr(error)}")
  } noraise {
    _ => fail("unknown root key must be rejected")
  }
  try
    parse_yosys_pre_map_json(
      premap_genuine_schema_fixture("$auto$dff$17", "\"X\""),
    )
  catch {
    InvalidValue(path~, value~) => {
      assert_true(path.contains("RD_DATA"))
      assert_eq(value, "X")
    }
    error => fail("unexpected bit error: \{Repr(error)}")
  } noraise {
    _ => fail("uppercase X must be rejected")
  }
}

///|
test "inventory v2 parser consumes generated bundles and rejects key drift" {
  let source = async_fifo_inventory_text(ScalarDepth4Stages2)
  let inventory = parse_async_fifo_role_inventory_v2(source)
  assert_eq(inventory.depth, 4)
  assert_eq(inventory.pointer_width, 3)
  assert_eq(inventory.address_width, 2)
  assert_eq(inventory.synchronizer_stages, 2)
  assert_eq(inventory.lanes.length(), 1)
  try
    parse_async_fifo_role_inventory_v2(
      source.replace(old="schema_version", new="schema_drift"),
    )
  catch {
    UnknownKey(path~, key~) => {
      assert_eq(path, "$")
      assert_eq(key, "schema_drift")
    }
    error => fail("unexpected inventory error: \{Repr(error)}")
  } noraise {
    _ => fail("inventory key drift must be rejected")
  }
}

///|
test "register checker binds Q D clock and synchronous reset by bits" {
  for register_name in ["$auto$dff$1", "$auto$dff$54321"] {
    let issues : Array[AsyncFifoPreMapIssue] = []
    let hardware_module = premap_register_fixture(
      register_name, 10, 1, 20, 11, 2,
    )
    premap_check_register(
      hardware_module,
      issues,
      "write_binary",
      premap_test_signal(10),
      premap_test_signal(11),
      premap_test_signal(1),
      premap_test_signal(2),
    )
    assert_eq(issues, [])
  }
}

///|
test "register graph mutants fail independently" {
  let q_issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_register(
    premap_register_fixture("renamed", 99, 1, 20, 11, 2),
    q_issues,
    "stage",
    premap_test_signal(10),
    premap_test_signal(11),
    premap_test_signal(1),
    premap_test_signal(2),
  )
  assert_true(premap_has_issue(q_issues, "state.owner"))

  let clock_issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_register(
    premap_register_fixture("renamed", 10, 7, 20, 11, 2),
    clock_issues,
    "stage",
    premap_test_signal(10),
    premap_test_signal(11),
    premap_test_signal(1),
    premap_test_signal(2),
  )
  assert_true(premap_has_issue(clock_issues, "state.clock"))

  let bypass_issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_register(
    premap_register_fixture("renamed", 10, 1, 20, 12, 2),
    bypass_issues,
    "stage",
    premap_test_signal(10),
    premap_test_signal(11),
    premap_test_signal(1),
    premap_test_signal(2),
  )
  assert_true(premap_has_issue(bypass_issues, "state.reset_d"))

  let reset_issues : Array[AsyncFifoPreMapIssue] = []
  premap_check_register(
    premap_register_fixture("renamed", 10, 1, 20, 11, 8),
    reset_issues,
    "stage",
    premap_test_signal(10),
    premap_test_signal(11),
    premap_test_signal(1),
    premap_test_signal(2),
  )
  assert_true(premap_has_issue(reset_issues, "state.reset_d"))
}

///|
test "report JSON is deterministic and keeps deferred claims false" {
  let report : AsyncFifoPreMapReport = {
    fixture: "fixture",
    top_module: "top",
    creator: "Yosys 0.68+1",
    checks: ["identity"],
    issues: [],
    sequential_bits: 26,
    memory_bits: 16,
  }
  let first = report.to_canonical_json()
  assert_eq(first, report.to_canonical_json())
  assert_true(
    first.contains(
      "\"schema_version\": \"lunachip.async-fifo-pre-map-audit/v1\"",
    ),
  )
  assert_true(first.contains("\"result\": \"incomplete\""))
  assert_true(first.contains("\"evidence_ready\": false"))
  assert_true(first.contains("\"pre_map_typed_graph\": false"))
  assert_true(first.contains("\"memory_topology\": false"))
  assert_true(first.contains("\"two_state_role_equivalence\": false"))
  assert_true(first.contains("\"owned_state_exact\": false"))
}
