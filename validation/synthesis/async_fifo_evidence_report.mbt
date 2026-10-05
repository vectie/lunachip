///|
fn async_fifo_evidence_binding(
  source : String,
) -> AsyncFifoEvidenceInputBinding {
  let bytes = @utf8.encode(source).length()
  { sha256: "sha256:\{sha256_hex(source)}", bytes, nonempty: bytes > 0, }
}

///|
fn async_fifo_issue_compare(
  left : AsyncFifoPreMapIssue,
  right : AsyncFifoPreMapIssue,
) -> Int {
  let code = left.code.compare(right.code)
  if code != 0 {
    return code
  }
  let role = left.role.compare(right.role)
  if role != 0 {
    return role
  }
  let expected = left.expected.compare(right.expected)
  if expected != 0 {
    return expected
  }
  left.observed.compare(right.observed)
}

///|
fn async_fifo_provenance_check(
  name : String,
  binding : AsyncFifoEvidenceInputBinding,
  issues : Array[AsyncFifoPreMapIssue],
) -> AsyncFifoEvidenceCheck {
  if !binding.nonempty {
    premap_issue(
      issues, "provenance.empty", name, "nonempty bound source", "0 bytes",
    )
  }
  {
    name: "provenance.\{name}",
    status: if binding.nonempty {
      EvidenceCheckPass
    } else {
      EvidenceCheckFail
    },
  }
}

///|
fn async_fifo_synthesis_evidence_from_audit(
  audit : AsyncFifoPreMapReport,
  inventory_source : String,
  pre_map_json_source : String,
  pre_map_rtlil_source : String,
  yosys_lock_source : String,
) -> AsyncFifoSynthesisEvidenceReport {
  let inputs : AsyncFifoEvidenceInputs = {
    inventory_json: async_fifo_evidence_binding(inventory_source),
    pre_map_json: async_fifo_evidence_binding(pre_map_json_source),
    pre_map_rtlil: async_fifo_evidence_binding(pre_map_rtlil_source),
    yosys_lock: async_fifo_evidence_binding(yosys_lock_source),
  }
  let issues = audit.issues.copy()
  let checks : Array[AsyncFifoEvidenceCheck] = []
  let audit_pass = audit.completed_checks_passed()
  for name in audit.checks {
    checks.push({
      name: "audit.\{name}",
      status: if audit_pass {
        EvidenceCheckPass
      } else {
        EvidenceCheckFail
      },
    })
  }
  checks.push(
    async_fifo_provenance_check("inventory_json", inputs.inventory_json, issues),
  )
  checks.push(
    async_fifo_provenance_check("pre_map_json", inputs.pre_map_json, issues),
  )
  checks.push(
    async_fifo_provenance_check("pre_map_rtlil", inputs.pre_map_rtlil, issues),
  )
  checks.push(
    async_fifo_provenance_check("yosys_lock", inputs.yosys_lock, issues),
  )
  issues.sort_by(async_fifo_issue_compare)
  let pass = audit_pass &&
    inputs.inventory_json.nonempty &&
    inputs.pre_map_json.nonempty &&
    inputs.pre_map_rtlil.nonempty &&
    inputs.yosys_lock.nonempty
  let checks_passed = checks
    .filter(check => check.status == EvidenceCheckPass)
    .length()
  let claims : AsyncFifoEvidenceClaims = {
    pre_map_typed_graph: pass,
    two_state_role_equivalence: pass,
    owned_state_exact: pass,
    memory_topology: pass,
    ram_mapping: false,
    timing: false,
    physical_cdc: false,
    metastability: false,
    four_state_equivalence: false,
  }
  {
    fixture: audit.fixture,
    top_module: audit.top_module,
    yosys_creator: audit.creator,
    inputs,
    checks,
    issues,
    counts: {
      checks_total: checks.length(),
      checks_passed,
      checks_failed: checks.length() - checks_passed,
      issues: issues.length(),
      sequential_bits: audit.sequential_bits,
      memory_bits: audit.memory_bits,
    },
    claims,
    pass,
  }
}

///|
/// Runs the complete typed pre-map audit and binds its result to the exact
/// inventory JSON, pre-map JSON, pre-map RTLIL, and Yosys lock text.
pub fn finalize_async_fifo_synthesis_evidence(
  inventory_source : String,
  pre_map_json_source : String,
  pre_map_rtlil_source : String,
  yosys_lock_source : String,
) -> AsyncFifoSynthesisEvidenceReport raise {
  let audit = audit_async_fifo_pre_map_json(
    inventory_source, pre_map_json_source,
  )
  async_fifo_synthesis_evidence_from_audit(
    audit, inventory_source, pre_map_json_source, pre_map_rtlil_source, yosys_lock_source,
  )
}

///|
fn async_fifo_evidence_binding_json(
  binding : AsyncFifoEvidenceInputBinding,
) -> String {
  "{\"sha256\":\{premap_json_quote(binding.sha256)},\"bytes\":\{binding.bytes},\"nonempty\":\{binding.nonempty}}"
}

///|
fn AsyncFifoEvidenceCheckStatus::to_json(
  self : AsyncFifoEvidenceCheckStatus,
) -> String {
  match self {
    EvidenceCheckPass => "\"pass\""
    EvidenceCheckFail => "\"fail\""
  }
}

///|
pub fn AsyncFifoSynthesisEvidenceReport::to_canonical_json(
  self : AsyncFifoSynthesisEvidenceReport,
) -> String {
  let out = StringBuilder()
  out.write_string(
    "{\n  \"schema_version\": \"lunachip.async-fifo-synthesis-evidence/v1\",\n  \"artifact_kind\": \"async-fifo-pre-map-final-evidence\",\n",
  )
  out.write_string("  \"fixture\": \{premap_json_quote(self.fixture)},\n")
  out.write_string("  \"top_module\": \{premap_json_quote(self.top_module)},\n")
  out.write_string(
    "  \"yosys_creator\": \{premap_json_quote(self.yosys_creator)},\n",
  )
  out.write_string("  \"inputs\": {\n")
  out.write_string(
    "    \"inventory_json\": \{async_fifo_evidence_binding_json(self.inputs.inventory_json)},\n",
  )
  out.write_string(
    "    \"pre_map_json\": \{async_fifo_evidence_binding_json(self.inputs.pre_map_json)},\n",
  )
  out.write_string(
    "    \"pre_map_rtlil\": \{async_fifo_evidence_binding_json(self.inputs.pre_map_rtlil)},\n",
  )
  out.write_string(
    "    \"yosys_lock\": \{async_fifo_evidence_binding_json(self.inputs.yosys_lock)}\n  },\n",
  )
  out.write_string("  \"checks\": [")
  for index, check in self.checks {
    if index > 0 {
      out.write_string(",")
    }
    out.write_string(
      "{\"name\":\{premap_json_quote(check.name)},\"status\":\{check.status.to_json()}}",
    )
  }
  out.write_string("],\n  \"issues\": [")
  for index, issue in self.issues {
    if index > 0 {
      out.write_string(",")
    }
    out.write_string(
      "{\"code\":\{premap_json_quote(issue.code)},\"role\":\{premap_json_quote(issue.role)},\"expected\":\{premap_json_quote(issue.expected)},\"observed\":\{premap_json_quote(issue.observed)}}",
    )
  }
  out.write_string("],\n")
  out.write_string(
    "  \"counts\": {\"checks_total\":\{self.counts.checks_total},\"checks_passed\":\{self.counts.checks_passed},\"checks_failed\":\{self.counts.checks_failed},\"issues\":\{self.counts.issues},\"sequential_bits\":\{self.counts.sequential_bits},\"memory_bits\":\{self.counts.memory_bits}},\n",
  )
  out.write_string(
    "  \"claim_boundary\": {\"pre_map_typed_graph\":\{self.claims.pre_map_typed_graph},\"two_state_role_equivalence\":\{self.claims.two_state_role_equivalence},\"owned_state_exact\":\{self.claims.owned_state_exact},\"memory_topology\":\{self.claims.memory_topology},\"ram_mapping\":false,\"timing\":false,\"physical_cdc\":false,\"metastability\":false,\"four_state_equivalence\":false},\n",
  )
  out.write_string(
    "  \"result\": \"\{if self.pass { "pass" } else { "fail" }}\",\n  \"pass\": \{self.pass}\n}\n",
  )
  out.to_string()
}
