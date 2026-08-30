#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"

fail() {
  printf '%s\n' "phase5-async-fifo-synthesis-report-check: $*" >&2
  exit 1
}

[ "$#" -eq 8 ] || fail \
  "usage: $0 FIXTURE REPORT INVENTORY PRE_MAP_JSON PRE_MAP_RTLIL LOCK SEQUENTIAL_BITS MEMORY_BITS"

fixture=$1
report=$2
inventory=$3
pre_map_json=$4
pre_map_rtlil=$5
lock_file=$6
sequential_bits=$7
memory_bits=$8

case "$sequential_bits:$memory_bits" in
  *[!0-9:]*|:*|*:|*:*:*) fail "state and memory counts must be decimal integers" ;;
esac
for source in "$report" "$inventory" "$pre_map_json" "$pre_map_rtlil" "$lock_file"; do
  [ -f "$source" ] && [ ! -L "$source" ] ||
    fail "input is absent, symbolic, or special: $source"
done
command -v jq >/dev/null 2>&1 || fail "jq is required"

inventory_sha="sha256:$(lc_evidence_sha256_file "$inventory")"
json_sha="sha256:$(lc_evidence_sha256_file "$pre_map_json")"
rtlil_sha="sha256:$(lc_evidence_sha256_file "$pre_map_rtlil")"
lock_sha="sha256:$(lc_evidence_sha256_file "$lock_file")"
inventory_bytes=$(wc -c <"$inventory" | tr -d ' ')
json_bytes=$(wc -c <"$pre_map_json" | tr -d ' ')
rtlil_bytes=$(wc -c <"$pre_map_rtlil" | tr -d ' ')
lock_bytes=$(wc -c <"$lock_file" | tr -d ' ')

jq -e \
  --arg fixture "$fixture" \
  --arg inventory_sha "$inventory_sha" \
  --arg json_sha "$json_sha" \
  --arg rtlil_sha "$rtlil_sha" \
  --arg lock_sha "$lock_sha" \
  --argjson inventory_bytes "$inventory_bytes" \
  --argjson json_bytes "$json_bytes" \
  --argjson rtlil_bytes "$rtlil_bytes" \
  --argjson lock_bytes "$lock_bytes" \
  --argjson sequential_bits "$sequential_bits" \
  --argjson memory_bits "$memory_bits" '
  def exact_keys($wanted): (keys | sort) == ($wanted | sort);
  def binding($sha; $bytes):
    exact_keys(["sha256", "bytes", "nonempty"]) and
    .sha256 == $sha and .bytes == $bytes and .nonempty == true;
  def expected_checks: [
    "audit.identity", "audit.roles", "audit.ports", "audit.owned_state",
    "audit.registers", "audit.pipelines", "audit.transfers",
    "audit.binary_next", "audit.gray_next", "audit.full",
    "audit.nonempty", "audit.addresses", "audit.memory_shape",
    "audit.memory_write", "audit.memory_read", "audit.visible_payload",
    "audit.dependency_cutsets", "audit.crossing_fanout",
    "audit.payload_barriers", "audit.lane_isolation", "audit.graph_closure",
    "provenance.inventory_json", "provenance.pre_map_json",
    "provenance.pre_map_rtlil", "provenance.yosys_lock"
  ];
  exact_keys([
    "schema_version", "artifact_kind", "fixture", "top_module",
    "yosys_creator", "inputs", "checks", "issues", "counts",
    "claim_boundary", "result", "pass"
  ]) and
  .schema_version == "lunachip.async-fifo-synthesis-evidence/v1" and
  .artifact_kind == "async-fifo-pre-map-final-evidence" and
  .fixture == $fixture and
  (.top_module | type == "string" and length > 0) and
  (.yosys_creator | type == "string" and startswith("Yosys 0.68 ")) and
  (.inputs |
    exact_keys(["inventory_json", "pre_map_json", "pre_map_rtlil", "yosys_lock"]) and
    (.inventory_json | binding($inventory_sha; $inventory_bytes)) and
    (.pre_map_json | binding($json_sha; $json_bytes)) and
    (.pre_map_rtlil | binding($rtlil_sha; $rtlil_bytes)) and
    (.yosys_lock | binding($lock_sha; $lock_bytes))) and
  (.checks | type == "array" and length == 25 and
    map(.name) == expected_checks and
    all(.[]; exact_keys(["name", "status"]) and .status == "pass")) and
  .issues == [] and
  (.counts | exact_keys([
      "checks_total", "checks_passed", "checks_failed", "issues",
      "sequential_bits", "memory_bits"
    ]) and . == {
      checks_total: 25, checks_passed: 25, checks_failed: 0, issues: 0,
      sequential_bits: $sequential_bits, memory_bits: $memory_bits
    }) and
  (.claim_boundary | exact_keys([
      "pre_map_typed_graph", "two_state_role_equivalence", "owned_state_exact",
      "memory_topology", "ram_mapping", "timing", "physical_cdc",
      "metastability", "four_state_equivalence"
    ]) and . == {
      pre_map_typed_graph: true, two_state_role_equivalence: true,
      owned_state_exact: true, memory_topology: true, ram_mapping: false,
      timing: false, physical_cdc: false, metastability: false,
      four_state_equivalence: false
    }) and
  .result == "pass" and .pass == true
' "$report" >/dev/null || fail "report is not the exact passing fixture evidence"

printf '%s\n' "Strict asynchronous-FIFO synthesis report passes: $fixture"
