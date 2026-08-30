#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"
schema="$repo_dir/toolchain/yosys/toggle-synthesis-report.schema.json"

fail() {
  printf '%s\n' "yosys-toggle-synthesis-report-check: $*" >&2
  exit 1
}

[ "$#" -eq 6 ] || fail \
  "usage: $0 FIXTURE REPORT EXPECTED_CONTRACT PRE_MAP_JSON PRE_MAP_RTLIL YOSYS_LOCK"
fixture=$1
report=$2
expected=$3
pre_map_json=$4
pre_map_rtlil=$5
lock_file=$6

case "$fixture" in
  toggle-scalar-2-stage) stages=2; leaves=1; states=9 ;;
  toggle-record-3-stage) stages=3; leaves=2; states=13 ;;
  toggle-record-4-stage) stages=4; leaves=2; states=15 ;;
  *) fail "unknown fixed fixture: $fixture" ;;
esac
for input in "$report" "$expected" "$pre_map_json" "$pre_map_rtlil" \
  "$lock_file" "$schema"; do
  [ -s "$input" ] && [ -f "$input" ] && [ ! -L "$input" ] ||
    fail "input is absent, empty, symbolic, or special: $input"
done
command -v jq >/dev/null 2>&1 || fail "jq is required"
jq -e . "$schema" >/dev/null || fail "report schema is invalid JSON"

top_module=$(jq -er --arg fixture "$fixture" --argjson stages "$stages" \
  --argjson leaves "$leaves" --argjson states "$states" '
  def exact_keys($wanted): (keys | sort) == ($wanted | sort);
  def ident: type == "string" and
    test("^[A-Za-z_][A-Za-z0-9_$]*$") and length <= 256;
  select(exact_keys(["$schema", "schema_version", "fixture", "top_module",
      "synchronizer_stages", "payload_leaf_count", "state_count", "state",
      "edge", "reset_mode"]) and
    ."$schema" == "https://lunachip.dev/schema/toggle-synthesis-shape-v1.json" and
    .schema_version == "lunachip.toggle-synthesis-shape/v1" and
    .fixture == $fixture and .synchronizer_stages == $stages and
    .payload_leaf_count == $leaves and .state_count == $states and
    .state_count == 2 * .synchronizer_stages + 3 + 2 * .payload_leaf_count and
    (.top_module | ident) and
    (.state | type == "array" and length == $states and
      (map(.signal) | length == (unique | length)) and all(.[];
        exact_keys(["signal", "width", "clock", "reset", "enable"]) and
        (.signal | ident) and (.clock | ident) and (.reset | ident) and
        (.width | type == "number" and floor == . and . >= 1 and . <= 64) and
        (.enable | type == "boolean"))) and
    (.state | map(select(.enable)) | length == 2 * $leaves) and
    (.state | map(.clock) | unique | length == 2) and
    (.state | map(.reset) | unique | length == 2) and
    ([.state[].signal, .state[].clock, .state[].reset] |
      length == (unique | length) + 2 * ($states - 2)) and
    .edge == "positive" and
    .reset_mode == "synchronous-active-high-zero") |
  .top_module
' "$expected") || fail "expected toggle contract identity or topology drifted"
yosys_creator=$(jq -er '
  .creator | select(type == "string" and test("^Yosys 0\\.68( |$)"))
' "$pre_map_json") || fail "pre-map JSON creator is not locked Yosys 0.68"
jq -e --arg top "$top_module" --argjson states "$states" '
  def stateful: test("^\\$.*(dff|ff|latch|sr)");
  def memory: test("^\\$mem");
  (.modules | type == "object" and keys == [$top]) and
  (.modules[$top].cells | type == "object") and
  ([.modules[$top].cells[].type] as $types |
    ($types | map(select(. == "$dff")) | length) == $states and
    ($types | map(select(stateful and . != "$dff")) | length) == 0 and
    ($types | map(select(memory)) | length) == 0) and
  ((.modules[$top].memories? // {}) |
    type == "object" and length == 0)
' "$pre_map_json" >/dev/null || fail "pre-map JSON state inventory drifted"
jq -e '.provider.kind == "oci" and .tools.yosys.version == "0.68"' \
  "$lock_file" >/dev/null || fail "Yosys lock identity is invalid"

expected_sha="sha256:$(lc_evidence_sha256_file "$expected")"
json_sha="sha256:$(lc_evidence_sha256_file "$pre_map_json")"
rtlil_sha="sha256:$(lc_evidence_sha256_file "$pre_map_rtlil")"
lock_sha="sha256:$(lc_evidence_sha256_file "$lock_file")"
expected_bytes=$(wc -c <"$expected" | tr -d ' ')
json_bytes=$(wc -c <"$pre_map_json" | tr -d ' ')
rtlil_bytes=$(wc -c <"$pre_map_rtlil" | tr -d ' ')
lock_bytes=$(wc -c <"$lock_file" | tr -d ' ')

jq -e --arg fixture "$fixture" --arg top "$top_module" \
  --arg creator "$yosys_creator" --argjson stages "$stages" \
  --argjson leaves "$leaves" --argjson states "$states" \
  --arg expected_sha "$expected_sha" --arg json_sha "$json_sha" \
  --arg rtlil_sha "$rtlil_sha" --arg lock_sha "$lock_sha" \
  --argjson expected_bytes "$expected_bytes" --argjson json_bytes "$json_bytes" \
  --argjson rtlil_bytes "$rtlil_bytes" --argjson lock_bytes "$lock_bytes" '
  def exact_keys($wanted): (keys | sort) == ($wanted | sort);
  def binding($sha; $bytes):
    exact_keys(["sha256", "bytes", "nonempty"]) and
    .sha256 == $sha and .bytes == $bytes and .nonempty == true;
  exact_keys(["schema_version", "artifact_kind", "fixture", "top_module",
    "synchronizer_stages", "payload_leaf_count", "expected_state_count",
    "yosys_creator", "inputs", "observed", "checks", "issues", "counts",
    "classification", "claim_boundary", "result", "pass"]) and
  .schema_version == "lunachip.toggle-synthesis-report/v2" and
  .artifact_kind == "toggle-handshake-pre-map-state-structural-evidence" and
  .fixture == $fixture and .top_module == $top and
  .synchronizer_stages == $stages and .payload_leaf_count == $leaves and
  .expected_state_count == $states and .yosys_creator == $creator and
  (.inputs | exact_keys(["expected_contract_json", "pre_map_json",
    "pre_map_rtlil", "yosys_lock"]) and
    (.expected_contract_json | binding($expected_sha; $expected_bytes)) and
    (.pre_map_json | binding($json_sha; $json_bytes)) and
    (.pre_map_rtlil | binding($rtlil_sha; $rtlil_bytes)) and
    (.yosys_lock | binding($lock_sha; $lock_bytes))) and
  (.observed | exact_keys(["module_count", "cells", "stateful_cells",
    "memory_cells"]) and .module_count == 1 and .cells >= $states and
    .stateful_cells == $states and .memory_cells == 0) and
  (.checks | exact_keys(["single_expected_module", "exact_state_count",
    "exact_state_inventory", "exact_clock_reset_domains", "exact_widths",
    "exact_sync_reset_enable_shape", "no_extra_state", "no_memory"]) and
    all(.[]; . == true)) and
  .issues == [] and
  .counts == {checks_total: 8, checks_passed: 8, checks_failed: 0, issues: 0} and
  .classification == "exact-toggle-state-shape" and
  .claim_boundary == {pre_map_state_shape: true,
    combinational_protocol_logic: false, physical_placement: false,
    metastability: false, mtbf: false, timing_closure: false} and
  .result == "pass" and .pass == true
' "$report" >/dev/null || fail "report or provenance binding is not exact"

printf '%s\n' "Strict toggle synthesis report passes: $fixture"
