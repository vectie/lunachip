#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"
schema="$repo_dir/toolchain/yosys/cdc-synthesis-report.schema.json"

fail() {
  printf '%s\n' "yosys-cdc-synthesis-report-check: $*" >&2
  exit 1
}

[ "$#" -eq 6 ] || fail \
  "usage: $0 FIXTURE REPORT EXPECTED_SHAPE PRE_MAP_JSON PRE_MAP_RTLIL YOSYS_LOCK"
fixture=$1
report=$2
expected=$3
pre_map_json=$4
pre_map_rtlil=$5
lock_file=$6

case "$fixture" in
  bit-synchronizer-2-stage) stages=2 ;;
  bit-synchronizer-3-stage) stages=3 ;;
  bit-synchronizer-4-stage) stages=4 ;;
  *) fail "unknown fixed fixture: $fixture" ;;
esac
for input in "$report" "$expected" "$pre_map_json" "$pre_map_rtlil" \
  "$lock_file" "$schema"; do
  [ -s "$input" ] && [ -f "$input" ] && [ ! -L "$input" ] ||
    fail "input is absent, empty, symbolic, or special: $input"
done
command -v jq >/dev/null 2>&1 || fail "jq is required"
jq -e . "$schema" >/dev/null || fail "report schema is invalid JSON"

top_module=$(jq -er --arg fixture "$fixture" --argjson stages "$stages" '
  def exact_keys($wanted): (keys | sort) == ($wanted | sort);
  def ident: type == "string" and
    test("^[A-Za-z_][A-Za-z0-9_$]*$") and length <= 256;
  select(exact_keys([
      "$schema", "schema_version", "fixture", "top_module", "stage_count",
      "clock_signal", "source_signal", "stage_signals", "output_signal",
      "edge", "width", "reset"
    ]) and
    ."$schema" == "https://lunachip.dev/schema/cdc-synthesis-shape-v1.json" and
    .fixture == $fixture and .stage_count == $stages and
    .schema_version == "lunachip.cdc-synthesis-shape/v1" and
    (.top_module | ident) and (.clock_signal | ident) and
    (.source_signal | ident) and (.output_signal | ident) and
    (.stage_signals | type == "array" and length == $stages and
      length == (unique | length) and all(.[]; ident)) and
    ([.clock_signal, .source_signal, .output_signal] + .stage_signals |
      length == (unique | length)) and
    .edge == "positive" and .width == 1 and .reset == false) |
  .top_module | select(type == "string" and length > 0)
' "$expected") || fail "expected shape identity or topology drifted"
yosys_creator=$(jq -er --arg top "$top_module" --argjson stages "$stages" '
  select(type == "object" and
    (.creator | type == "string" and test("^Yosys 0\\.68( |$)")) and
    (.modules | type == "object" and keys == [$top] and
      (.[$top] | type == "object" and
        (.cells | type == "object" and length == $stages and
          all(.[]; type == "object" and .type == "$dff"))))) |
  .creator
' "$pre_map_json") ||
  fail "pre-map JSON does not contain the exact expected Yosys module identity"
jq -e '.provider.kind == "oci" and .tools.yosys.version == "0.68"' \
  "$lock_file" >/dev/null || fail "Yosys lock identity is invalid"

expected_sha="sha256:$(lc_evidence_sha256_file "$expected")"
pre_map_json_sha="sha256:$(lc_evidence_sha256_file "$pre_map_json")"
pre_map_rtlil_sha="sha256:$(lc_evidence_sha256_file "$pre_map_rtlil")"
lock_sha="sha256:$(lc_evidence_sha256_file "$lock_file")"
expected_bytes=$(wc -c <"$expected" | tr -d ' ')
pre_map_json_bytes=$(wc -c <"$pre_map_json" | tr -d ' ')
pre_map_rtlil_bytes=$(wc -c <"$pre_map_rtlil" | tr -d ' ')
lock_bytes=$(wc -c <"$lock_file" | tr -d ' ')

jq -e --arg fixture "$fixture" --arg top "$top_module" \
  --arg creator "$yosys_creator" --argjson stages "$stages" \
  --arg expected_sha "$expected_sha" \
  --arg pre_map_json_sha "$pre_map_json_sha" \
  --arg pre_map_rtlil_sha "$pre_map_rtlil_sha" \
  --arg lock_sha "$lock_sha" --argjson expected_bytes "$expected_bytes" \
  --argjson pre_map_json_bytes "$pre_map_json_bytes" \
  --argjson pre_map_rtlil_bytes "$pre_map_rtlil_bytes" \
  --argjson lock_bytes "$lock_bytes" '
  def exact_keys($wanted): (keys | sort) == ($wanted | sort);
  def binding($sha; $bytes):
    exact_keys(["sha256", "bytes", "nonempty"]) and
    .sha256 == $sha and .bytes == $bytes and .nonempty == true;
  exact_keys([
    "schema_version", "artifact_kind", "fixture", "top_module",
    "stage_count", "yosys_creator", "inputs", "observed", "checks",
    "issues", "counts", "classification", "claim_boundary", "result", "pass"
  ]) and
  .schema_version == "lunachip.cdc-synthesis-report/v2" and
  .artifact_kind == "bit-synchronizer-pre-map-structural-evidence" and
  .fixture == $fixture and .top_module == $top and
  .stage_count == $stages and .yosys_creator == $creator and
  (.inputs | exact_keys([
    "expected_shape_json", "pre_map_json", "pre_map_rtlil", "yosys_lock"
  ]) and
    (.expected_shape_json | binding($expected_sha; $expected_bytes)) and
    (.pre_map_json | binding($pre_map_json_sha; $pre_map_json_bytes)) and
    (.pre_map_rtlil | binding($pre_map_rtlil_sha; $pre_map_rtlil_bytes)) and
    (.yosys_lock | binding($lock_sha; $lock_bytes))) and
  (.observed | exact_keys([
    "module_count", "dff_cells", "stateful_cells", "memory_cells", "cells"
  ]) and .module_count == 1 and .dff_cells == $stages and
    .stateful_cells == $stages and .memory_cells == 0 and
    (.cells | type == "array" and length == $stages and all(.[];
      exact_keys(["name", "type", "width", "clock_polarity", "clock",
        "data", "output"]) and .type == "$dff" and .width == "1" and
      (.clock_polarity == "1" or .clock_polarity == "1'\''1") and
      all([.name, .clock, .data, .output][];
        type == "string" and length > 0)))) and
  (.checks | exact_keys([
    "single_expected_module", "exact_stage_count",
    "positive_edge_one_bit_dff_only", "same_destination_clock",
    "exact_source_to_stage_chain", "final_stage_to_output", "no_bypass",
    "no_extra_state", "no_memory"
  ]) and all(.[]; . == true)) and
  .issues == [] and
  .counts == {checks_total: 9, checks_passed: 9, checks_failed: 0, issues: 0} and
  .classification == "exact-bit-synchronizer-shape" and
  .claim_boundary == {pre_map_structural_shape: true,
    physical_placement: false, metastability: false, mtbf: false,
    timing_closure: false} and
  .result == "pass" and .pass == true
' "$report" >/dev/null || fail "report or provenance binding is not exact"

printf '%s\n' "Strict CDC synthesis report passes: $fixture"
