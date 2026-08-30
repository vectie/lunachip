#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

fail() {
  echo "yosys-cdc-synthesis-check: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fail \
  "usage: $0 EXPECTED_CDC_SHAPE_JSON PRE_MAP_RTLIL REPORT_JSON"
expected=$1
rtlil=$2
report=$3
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
shape_schema="$repo_dir/toolchain/yosys/cdc-synthesis-shape.schema.json"
report_schema="$repo_dir/toolchain/yosys/cdc-synthesis-report.schema.json"

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -s "$expected" ] || fail "expected shape is missing or empty: $expected"
[ -s "$rtlil" ] || fail "pre-map RTLIL is missing or empty: $rtlil"
[ ! -e "$report" ] || fail "report path already exists: $report"
jq -e . "$shape_schema" >/dev/null || fail "shape schema is invalid JSON"
jq -e . "$report_schema" >/dev/null || fail "report schema is invalid JSON"
jq -e '
  def keys_are($allowed): ((keys - $allowed) | length) == 0;
  def ident: type == "string" and
    test("^[A-Za-z_][A-Za-z0-9_$]*$") and length <= 256;
  keys_are([
    "$schema", "schema_version", "fixture", "top_module", "stage_count",
    "clock_signal", "source_signal", "stage_signals", "output_signal",
    "edge", "width", "reset"
  ]) and
  .schema_version == "lunachip.cdc-synthesis-shape/v1" and
  (.fixture | test("^bit-synchronizer-[234]-stage$")) and
  (.top_module | ident) and
  (.stage_count | type == "number" and floor == . and . >= 2 and . <= 4) and
  (.clock_signal | ident) and (.source_signal | ident) and
  (.output_signal | ident) and
  (.stage_signals | type == "array" and length == $document.stage_count and
    length == (unique | length) and all(.[]; ident)) and
  ([.clock_signal, .source_signal, .output_signal] + .stage_signals |
    length == (unique | length)) and
  .edge == "positive" and .width == 1 and .reset == false
' --argjson document "$(jq -c . "$expected")" "$expected" >/dev/null ||
  fail "expected shape violates the exact CDC synthesis contract"

fixture=$(jq -r '.fixture' "$expected")
top_module=$(jq -r '.top_module' "$expected")
stage_count=$(jq -r '.stage_count' "$expected")
clock_signal=$(jq -r '.clock_signal' "$expected")
source_signal=$(jq -r '.source_signal' "$expected")
stage_signals=$(jq -r '.stage_signals | join(",")' "$expected")
output_signal=$(jq -r '.output_signal' "$expected")

scratch=$(mktemp -d /tmp/lunachip-cdc-synthesis-check.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
records="$scratch/records.tsv"
findings="$scratch/findings.tsv"

awk '
  function clean(value) { sub(/^\\/, "", value); return value }
  function emit_cell() {
    if (!inside_cell) return
    print "CELL", cell_name, cell_type, width, polarity, clock, data, output
    inside_cell = 0
  }
  BEGIN { OFS = "\t" }
  $1 == "module" { print "MODULE", clean($2); next }
  $1 == "cell" {
    emit_cell()
    inside_cell = 1
    cell_type = $2
    cell_name = clean($3)
    width = ""; polarity = ""; clock = ""; data = ""; output = ""
    next
  }
  inside_cell && $1 == "parameter" {
    key = clean($2)
    if (key == "WIDTH") width = $3
    else if (key == "CLK_POLARITY") polarity = $3
    next
  }
  inside_cell && $1 == "connect" {
    key = clean($2); value = clean($3)
    if (key == "CLK") clock = value
    else if (key == "D") data = value
    else if (key == "Q") output = value
    next
  }
  inside_cell && $1 == "end" { emit_cell(); next }
  !inside_cell && $1 == "connect" {
    print "ALIAS", clean($2), clean($3)
    next
  }
  !inside_cell && $1 == "memory" { print "MEMORY", "declaration" }
  END { emit_cell() }
' "$rtlil" >"$records"

awk -F '\t' \
  -v expected_top="$top_module" \
  -v expected_stages="$stage_signals" \
  -v expected_count="$stage_count" \
  -v expected_clock="$clock_signal" \
  -v expected_source="$source_signal" \
  -v expected_output="$output_signal" '
  function find_root(value, cursor) {
    if (!(value in parent)) parent[value] = value
    cursor = value
    while (parent[cursor] != cursor) cursor = parent[cursor]
    return cursor
  }
  function unite(left, right, left_root, right_root) {
    left_root = find_root(left); right_root = find_root(right)
    if (left_root != right_root) parent[right_root] = left_root
  }
  function same(left, right) { return find_root(left) == find_root(right) }
  function bool(value) { return value ? "true" : "false" }
  BEGIN { OFS = "\t"; split(expected_stages, stages, ",") }
  $1 == "MODULE" {
    module_count += 1
    if ($2 == expected_top) top_matches += 1
    next
  }
  $1 == "ALIAS" { unite($2, $3); next }
  $1 == "MEMORY" { memory_count += 1; next }
  $1 == "CELL" {
    cell_count += 1
    cell_type[cell_count] = $3
    cell_width[cell_count] = $4
    cell_polarity[cell_count] = $5
    cell_clock[cell_count] = $6
    cell_data[cell_count] = $7
    cell_output[cell_count] = $8
    if ($3 == "$dff") dff_count += 1
    if ($3 ~ /^\$.*(dff|ff|latch|sr)/) stateful_count += 1
    if ($3 ~ /^\$mem/) memory_count += 1
  }
  END {
    single_module = module_count == 1 && top_matches == 1
    exact_count = dff_count == expected_count
    dff_shape = exact_count
    same_clock = exact_count
    exact_chain = exact_count
    for (stage = 1; stage <= expected_count; stage += 1) {
      matches = 0; selected = 0
      for (cell = 1; cell <= cell_count; cell += 1) {
        if (cell_type[cell] == "$dff" &&
          same(cell_output[cell], stages[stage])) {
          matches += 1; selected = cell
        }
      }
      if (matches != 1) {
        dff_shape = 0; same_clock = 0; exact_chain = 0
      } else {
        if (cell_width[selected] != "1" ||
          (cell_polarity[selected] != "1" &&
           cell_polarity[selected] != "1'\''1")) dff_shape = 0
        if (!same(cell_clock[selected], expected_clock)) same_clock = 0
        predecessor = stage == 1 ? expected_source : stages[stage - 1]
        if (!same(cell_data[selected], predecessor)) exact_chain = 0
      }
    }
    final_output = same(expected_output, stages[expected_count])
    no_bypass = !same(expected_output, expected_source)
    for (stage = 1; stage < expected_count; stage += 1)
      if (same(expected_output, stages[stage])) no_bypass = 0
    no_extra_state = stateful_count == expected_count &&
      stateful_count == dff_count
    no_memory = memory_count == 0
    pass = single_module && exact_count && dff_shape && same_clock &&
      exact_chain && final_output && no_bypass && no_extra_state && no_memory
    print "module_count", module_count + 0
    print "dff_count", dff_count + 0
    print "stateful_count", stateful_count + 0
    print "memory_count", memory_count + 0
    print "single_module", bool(single_module)
    print "exact_count", bool(exact_count)
    print "dff_shape", bool(dff_shape)
    print "same_clock", bool(same_clock)
    print "exact_chain", bool(exact_chain)
    print "final_output", bool(final_output)
    print "no_bypass", bool(no_bypass)
    print "no_extra_state", bool(no_extra_state)
    print "no_memory", bool(no_memory)
    print "pass", bool(pass)
  }
' "$records" >"$findings"

field() {
  awk -F '\t' -v key="$1" '$1 == key { print $2; found = 1 }
    END { if (!found) exit 1 }' "$findings"
}

cells_json=$(jq -Rn '
  [inputs | split("\t") | select(.[0] == "CELL") | {
    name: .[1], type: .[2], width: .[3], clock_polarity: .[4],
    clock: .[5], data: .[6], output: .[7]
  }]
' "$records")
pass=$(field pass)
classification=bit-synchronizer-shape-mismatch
[ "$pass" = false ] || classification=exact-bit-synchronizer-shape

jq -n \
  --arg fixture "$fixture" \
  --argjson stage_count "$stage_count" \
  --argjson module_count "$(field module_count)" \
  --argjson dff_count "$(field dff_count)" \
  --argjson stateful_count "$(field stateful_count)" \
  --argjson memory_count "$(field memory_count)" \
  --argjson cells "$cells_json" \
  --argjson single_module "$(field single_module)" \
  --argjson exact_count "$(field exact_count)" \
  --argjson dff_shape "$(field dff_shape)" \
  --argjson same_clock "$(field same_clock)" \
  --argjson exact_chain "$(field exact_chain)" \
  --argjson final_output "$(field final_output)" \
  --argjson no_bypass "$(field no_bypass)" \
  --argjson no_extra_state "$(field no_extra_state)" \
  --argjson no_memory "$(field no_memory)" \
  --arg classification "$classification" \
  --argjson pass "$pass" \
  '{
    schema_version: 1, fixture: $fixture, stage_count: $stage_count,
    observed: {
      module_count: $module_count, dff_cells: $dff_count,
      stateful_cells: $stateful_count, memory_cells: $memory_count,
      cells: $cells
    },
    checks: {
      single_expected_module: $single_module,
      exact_stage_count: $exact_count,
      positive_edge_one_bit_dff_only: $dff_shape,
      same_destination_clock: $same_clock,
      exact_source_to_stage_chain: $exact_chain,
      final_stage_to_output: $final_output,
      no_bypass: $no_bypass, no_extra_state: $no_extra_state,
      no_memory: $no_memory
    },
    classification: $classification,
    claim_boundary: {
      pre_map_structural_shape: true, physical_placement: false,
      metastability: false, mtbf: false, timing_closure: false
    },
    pass: $pass
  }' >"$report"

jq -e '
  def keys_are($allowed): ((keys - $allowed) | length) == 0;
  keys_are([
    "schema_version", "fixture", "stage_count", "observed", "checks",
    "classification", "claim_boundary", "pass"
  ]) and
  .schema_version == 1 and (.stage_count >= 2 and .stage_count <= 4) and
  (.observed | keys_are([
    "module_count", "dff_cells", "stateful_cells", "memory_cells", "cells"
  ])) and
  (.checks | keys_are([
    "single_expected_module", "exact_stage_count",
    "positive_edge_one_bit_dff_only", "same_destination_clock",
    "exact_source_to_stage_chain", "final_stage_to_output", "no_bypass",
    "no_extra_state", "no_memory"
  ])) and
  .claim_boundary == {
    pre_map_structural_shape: true, physical_placement: false,
    metastability: false, mtbf: false, timing_closure: false
  }
' "$report" >/dev/null || fail "report failed exact structural schema validation"

[ "$pass" = true ] ||
  fail "$fixture does not match its exact pre-map synchronizer shape"
