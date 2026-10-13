///|
fn store_clock_reset_groups() -> ReadOnlyArray[String] {
  [
    "reset-ports", "reset-registers", "reset-memory", "clock-registers", "clock-memory",
  ]
}

///|
// Every group uses the same original module, free inputs/arithmetic cuts and
// startup-only reset. Later reset remains arbitrary and checks are not disabled
// during it. Observation state never feeds the original graph.
fn store_clock_reset_source(
  inputs : StorePreservationProofInputs,
  group : String,
) -> String raise {
  if !store_clock_reset_groups().contains(group) {
    raise InvalidFormalBundleIdentity("Store clock/reset: unknown lemma group")
  }
  let inventory = store_clock_reset_inventory(inputs.projection, inputs.emitted)
  let reset = port_identifier(inputs.emitted, InputPort, "reset")
  let out = StringBuilder()
  out.write_string(
    "  wire lc_reset = \{reset};\n" +
    "  logic lc_seen_edge = 1'b0;\n" +
    "  logic lc_previous_reset;\n" +
    "  always @(posedge lc_clock) begin\n" +
    "    lc_store_clock_reset_startup: assume ((lc_seen_edge || lc_reset) === 1'b1);\n" +
    "    lc_seen_edge <= 1'b1;\n" +
    "    lc_previous_reset <= lc_reset;\n" +
    "  end\n",
  )
  if group == "reset-ports" {
    out.write_string(
      "  always @(posedge lc_clock) begin\n" +
      "    lc_store_reset_ports: assert ((!lc_reset || !(\{inventory.memory_enables.join(" || ")})) === 1'b1);\n" +
      "  end\n",
    )
  } else if group == "reset-registers" {
    out.write_string(
      "  always @(posedge lc_clock) begin\n" +
      "    lc_store_reset_registers: assert ((!lc_seen_edge || !lc_previous_reset || (\{inventory.reset_checks.join(" && ")})) === 1'b1);\n" +
      "  end\n",
    )
  } else {
    let (terms, width) = if group == "clock-registers" {
      (inventory.registers, inventory.register_bits)
    } else {
      (inventory.memory, inventory.memory_bits)
    }
    out.write_string(
      "  wire [\{width - 1}:0] lc_observed_pair = {\{terms.join(", ")}};\n",
    )
    if group == "reset-memory" {
      out.write_string(
        "  logic [\{width - 1}:0] lc_pre_memory_pair;\n" +
        "  always @(posedge lc_clock) begin\n" +
        "    lc_pre_memory_pair <= lc_observed_pair;\n" +
        "    lc_store_reset_memory: assert ((!lc_seen_edge || !lc_previous_reset || (lc_observed_pair === lc_pre_memory_pair)) === 1'b1);\n" +
        "  end\n",
      )
    } else {
      let label = if group == "clock-registers" {
        "lc_store_clock_registers"
      } else {
        "lc_store_clock_memory"
      }
      out.write_string(
        "  logic lc_seen_global = 1'b0;\n" +
        "  logic lc_previous_clock = 1'b0;\n" +
        "  logic [\{width - 1}:0] lc_previous_pair;\n" +
        "  always @($global_clock) begin\n" +
        "    lc_seen_global <= 1'b1;\n" +
        "    lc_previous_clock <= lc_clock;\n" +
        "    lc_previous_pair <= lc_observed_pair;\n" +
        "    \{label}: assert ((!lc_seen_global || (!lc_previous_clock && lc_clock) || (lc_observed_pair === lc_previous_pair)) === 1'b1);\n" +
        "  end\n",
      )
    }
  }
  let standalone = store_preservation_adapter(
    inputs.projection,
    inputs.emitted,
    "",
  )
  let original = store_clock_reset_without_bounds(
    standalone,
    inputs.memory_bounds,
  )
  let observer = out.to_string()
  if original.split("endmodule\n").count() != 2 ||
    observer.contains("endmodule") {
    raise InvalidFormalBundleIdentity(
      "Store clock/reset: exact standalone observer splice",
    )
  }
  let inserted = observer + "endmodule\n"
  let selected = original.replace(old="endmodule\n", new=inserted)
  if selected.replace(old=inserted, new="endmodule\n") != original ||
    selected.split(": assert (").count() != 2 ||
    selected.split(": assume (").count() != 2 ||
    selected.contains(": cover (") {
    raise InvalidFormalBundleIdentity(
      "Store clock/reset: one conclusion, unchanged body, one startup premise",
    )
  }
  selected
}

///|
#warnings("-unused_value")
fn store_clock_reset_artifacts() -> ReadOnlyArray[FormalBundleArtifact] raise {
  let inputs = store_preservation_proof_inputs(
    @flux_tile.queued_concurrent_store_preservation_fixture(),
  )
  let artifacts : Array[FormalBundleArtifact] = []
  for group in store_clock_reset_groups() {
    let file = group + ".sv"
    let config =
      $|[options]
      $|mode prove
      $|depth 20
      $|timeout 600
      $|multiclock on
      $|expect pass
      $|[engines]
      $|smtbmc bitwuzla
      $|[script]
      $|logger -werror .*
      $|read_verilog -formal -sv -noautowire \{file}
      $|prep -top \{inputs.top_identifier}
      $|write_rtlil /out/\{group}-prepared.rtlil
      $|[files]
      $|\{file} /work/\{file}
      $|
    artifacts.push({
      path: file,
      content: store_clock_reset_source(inputs, group),
    })
    artifacts.push({ path: group + ".sby", content: config, })
  }
  ReadOnlyArray::from_array(artifacts)
}
