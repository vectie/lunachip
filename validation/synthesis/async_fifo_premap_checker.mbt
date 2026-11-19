///|
fn premap_issue(
  issues : Array[AsyncFifoPreMapIssue],
  code : String,
  role : String,
  expected : String,
  observed : String,
) -> Unit {
  issues.push({ code, role, expected, observed, })
}

///|
fn premap_role_signal(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
  role : String,
  name : String,
  width : Int32,
) -> PreMapSignal? {
  match hardware_module.netnames.get(name) {
    None => {
      premap_issue(issues, "role.missing", role, name, "missing")
      None
    }
    Some(signal) => {
      if signal.width() != width {
        premap_issue(
          issues,
          "role.width",
          role,
          width.to_string(),
          signal.width().to_string(),
        )
      }
      Some(signal)
    }
  }
}

///|
fn premap_bits_are(signal : PreMapSignal, bit : PreMapBit) -> Bool {
  signal.bits.all(value => value == bit)
}

///|
fn premap_find_cells(
  hardware_module : PreMapModule,
  cell_type : String,
  output : String,
  signal : PreMapSignal,
) -> Array[PreMapCell] {
  hardware_module.cells.filter(cell => {
    cell.cell_type == cell_type && cell.connections.get(output) == Some(signal)
  })
}

///|
fn premap_check_register(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
  role : String,
  state : PreMapSignal,
  next : PreMapSignal,
  clock : PreMapSignal,
  reset : PreMapSignal,
) -> Unit {
  let owners = premap_find_cells(hardware_module, "$dff", "Q", state)
  if owners.length() != 1 {
    premap_issue(
      issues,
      "state.owner",
      role,
      "one $dff bound by Q bits",
      owners.length().to_string(),
    )
    return
  }
  let owner = owners[0]
  if owner.connections.get("CLK") != Some(clock) ||
    premap_parameter_int(owner, "CLK_POLARITY") != Some(1) {
    premap_issue(
      issues, "state.clock", role, "positive expected clock", "mismatch",
    )
  }
  guard owner.connections.get("D") is Some(d) else {
    premap_issue(issues, "state.d", role, "D connection", "missing")
    return
  }
  let muxes = premap_find_cells(hardware_module, "$mux", "Y", d)
  let valid = muxes.any(mux => {
    mux.connections.get("A") == Some(next) &&
    mux.connections.get("B") is Some(zero) &&
    premap_bits_are(zero, Zero) &&
    mux.connections.get("S") == Some(reset)
  })
  if !valid {
    premap_issue(
      issues, "state.reset_d", role, "reset ? zero : next", "mismatch",
    )
  }
}

///|
fn premap_check_port_alias(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
  role : String,
  signal : PreMapSignal,
  direction : String,
) -> Unit {
  let count = hardware_module.ports
    .values()
    .filter(port => port.direction == direction && port.signal == signal)
    .count()
  if count != 1 {
    premap_issue(
      issues,
      "port.binding",
      role,
      "one \{direction} port alias",
      count.to_string(),
    )
  }
}

///|
fn premap_check_relation(
  hardware_module : PreMapModule,
  issues : Array[AsyncFifoPreMapIssue],
  role : String,
  target : PreMapSignal,
  roots : Array[PreMapSignal],
  expected : (Int32) -> Array[Bool],
) -> Unit {
  if !premap_relation_matches(hardware_module, target, roots, expected) {
    premap_issue(
      issues, "equation.mismatch", role, "exact two-state equation", "counterexample",
    )
  }
}

///|
fn premap_json_quote(value : String) -> String {
  Json::string(value).stringify()
}

///|
pub fn AsyncFifoPreMapReport::to_canonical_json(
  self : AsyncFifoPreMapReport,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\n  \"schema_version\": \"lunachip.async-fifo-pre-map-audit/v1\",\n",
  )
  out.write_string("  \"fixture\": \{premap_json_quote(self.fixture)},\n")
  out.write_string("  \"top_module\": \{premap_json_quote(self.top_module)},\n")
  out.write_string("  \"creator\": \{premap_json_quote(self.creator)},\n")
  out.write_string(
    "  \"result\": \"\{if self.completed_checks_passed() { "incomplete" } else { "fail" }}\",\n",
  )
  out.write_string(
    "  \"sequential_bits\": \{self.sequential_bits},\n  \"memory_bits\": \{self.memory_bits},\n",
  )
  out.write_string(
    "  \"checks\": [\{self.checks.map(premap_json_quote).join(", ")}],\n  \"issues\": [",
  )
  for index, issue in self.issues {
    if index > 0 {
      out.write_string(", ")
    }
    out.write_string(
      "{\"code\":\{premap_json_quote(issue.code)},\"role\":\{premap_json_quote(issue.role)},\"expected\":\{premap_json_quote(issue.expected)},\"observed\":\{premap_json_quote(issue.observed)}}",
    )
  }
  out.write_string(
    "],\n  \"evidence_ready\": false,\n  \"claim_boundary\": { \"pre_map_typed_graph\": false, \"two_state_role_equivalence\": false, \"owned_state_exact\": false, \"memory_topology\": false, \"ram_mapping\": false, \"timing\": false, \"physical_cdc\": false, \"metastability\": false, \"four_state_equivalence\": false }\n}\n",
  )
  out.to_string()
}
