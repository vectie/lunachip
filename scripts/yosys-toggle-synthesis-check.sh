#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

fail() {
  echo "yosys-toggle-synthesis-check: $*" >&2
  exit 1
}

[ "$#" -eq 3 ] || fail "usage: $0 EXPECTED_SHAPE_JSON PRE_MAP_RTLIL REPORT_JSON"
expected=$1
rtlil=$2
report=$3
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
shape_schema="$repo_dir/toolchain/yosys/toggle-synthesis-shape.schema.json"
report_schema="$repo_dir/toolchain/yosys/toggle-synthesis-report.schema.json"

command -v jq >/dev/null 2>&1 || fail "jq is required"
[ -s "$expected" ] || fail "expected shape is missing or empty: $expected"
[ -s "$rtlil" ] || fail "pre-map RTLIL is missing or empty: $rtlil"
[ ! -e "$report" ] || fail "report path already exists: $report"
jq -e . "$shape_schema" >/dev/null || fail "shape schema is invalid JSON"
jq -e . "$report_schema" >/dev/null || fail "report schema is invalid JSON"
jq -e '
  def keys_are($allowed): ((keys - $allowed) | length) == 0;
  def ident: type == "string" and test("^[A-Za-z_][A-Za-z0-9_$]*$") and length <= 256;
  keys_are(["$schema", "schema_version", "fixture", "top_module",
    "synchronizer_stages", "payload_leaf_count", "state_count", "state",
    "edge", "reset_mode"]) and
  .["$schema"] == "https://lunachip.dev/schema/toggle-synthesis-shape-v1.json" and
  .schema_version == "lunachip.toggle-synthesis-shape/v1" and
  (.fixture as $fixture |
    if $fixture == "toggle-scalar-2-stage" then
      .synchronizer_stages == 2 and .payload_leaf_count == 1
    elif $fixture == "toggle-record-3-stage" then
      .synchronizer_stages == 3 and .payload_leaf_count == 2
    elif $fixture == "toggle-record-4-stage" then
      .synchronizer_stages == 4 and .payload_leaf_count == 2
    else false end) and
  (.top_module | ident) and
  (.state_count == 2 * .synchronizer_stages + 3 + 2 * .payload_leaf_count) and
  (.state | type == "array") and
  (.state | length == $document.state_count) and
  (.state | map(.signal) | length == (unique | length)) and
  (.state | all(.[];
    keys_are(["signal", "width", "clock", "reset", "enable"]) and
    (.signal | ident) and (.clock | ident) and (.reset | ident) and
    (.width | type == "number" and floor == . and . >= 1 and . <= 64) and
    (.enable | type == "boolean"))) and
  (.state | map(select(.enable)) | length == 2 * $document.payload_leaf_count) and
  (.state | map(.clock) | unique | length == 2) and
  (.state | map(.reset) | unique | length == 2) and
  ([.state[].signal, .state[].clock, .state[].reset] |
    length == (unique | length) + 2 * ($document.state_count - 2)) and
  .edge == "positive" and .reset_mode == "synchronous-active-high-zero"
' --argjson document "$(jq -c . "$expected")" "$expected" >/dev/null ||
  fail "expected shape violates the exact toggle synthesis contract"

fixture=$(jq -r '.fixture' "$expected")
top_module=$(jq -r '.top_module' "$expected")
state_count=$(jq -r '.state_count' "$expected")

scratch=$(mktemp -d /tmp/lunachip-toggle-synthesis-check.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
records="$scratch/records.tsv"
findings="$scratch/findings.tsv"
expected_state="$scratch/expected.tsv"
jq -r '.state[] | [.signal, (.width|tostring), .clock, .reset, (.enable|tostring)] | @tsv' \
  "$expected" >"$expected_state"

awk '
  function clean(value) { sub(/^\\/, "", value); return value }
  function emit_cell() {
    if (!inside_cell) return
    print "CELL", cell_name, cell_type, width, clock_polarity,
      clock, data, output, mux_a, mux_b, mux_select
    inside_cell = 0
  }
  BEGIN { OFS = "\t" }
  $1 == "module" { print "MODULE", clean($2); next }
  $1 == "cell" {
    emit_cell(); inside_cell = 1; cell_type = $2; cell_name = clean($3)
    width = ""; clock_polarity = ""; clock = ""; data = ""; output = ""
    mux_a = ""; mux_b = ""; mux_select = ""
    next
  }
  inside_cell && $1 == "parameter" {
    key = clean($2)
    if (key == "WIDTH") width = $3
    else if (key == "CLK_POLARITY") clock_polarity = $3
    next
  }
  inside_cell && $1 == "connect" {
    key = clean($2); value = clean($3)
    if (key == "CLK") clock = value
    else if (key == "D") data = value
    else if (key == "Q") output = value
    else if (key == "A") mux_a = value
    else if (key == "B") mux_b = value
    else if (key == "S") mux_select = value
    else if (key == "Y") output = value
    next
  }
  inside_cell && $1 == "end" { emit_cell(); next }
  !inside_cell && $1 == "connect" { print "ALIAS", clean($2), clean($3); next }
  !inside_cell && $1 == "memory" { print "MEMORY", "declaration" }
  END { emit_cell() }
' "$rtlil" >"$records"

awk -F '\t' -v expected_file="$expected_state" -v expected_top="$top_module" \
  -v expected_count="$state_count" '
  function root(value, cursor) {
    if (!(value in parent)) parent[value] = value
    cursor = value
    while (parent[cursor] != cursor) cursor = parent[cursor]
    return cursor
  }
  function unite(left, right, lroot, rroot) {
    lroot = root(left); rroot = root(right)
    if (lroot != rroot) parent[rroot] = lroot
  }
  function same(left, right) { return root(left) == root(right) }
  function one(value) { return value == "1" || value == "1'\''1" }
  function zero(value) { return value == "0" || value ~ /^[0-9]+'\''0+$/ }
  function bool(value) { return value ? "true" : "false" }
  BEGIN {
    OFS = "\t"
    while ((getline line < expected_file) > 0) {
      split(line, fields, "\t"); expected += 1
      expected_signal[expected] = fields[1]; expected_width[expected] = fields[2]
      expected_clock[expected] = fields[3]; expected_reset[expected] = fields[4]
      expected_enable[expected] = fields[5]
    }
    close(expected_file)
  }
  $1 == "MODULE" { module_count += 1; if ($2 == expected_top) top_matches += 1; next }
  $1 == "ALIAS" { unite($2, $3); next }
  $1 == "MEMORY" { memory_count += 1; next }
  $1 == "CELL" {
    cell_count += 1; type[cell_count] = $3; width[cell_count] = $4
    clock_polarity[cell_count] = $5; clock[cell_count] = $6
    data[cell_count] = $7; output[cell_count] = $8
    mux_a[cell_count] = $9; mux_b[cell_count] = $10
    mux_select[cell_count] = $11
    if ($3 ~ /^\$.*(dff|ff|latch|sr)/) stateful_count += 1
    if ($3 ~ /^\$mem/) memory_count += 1
  }
  END {
    single_module = module_count == 1 && top_matches == 1
    exact_count = expected == expected_count && stateful_count == expected_count
    exact_inventory = exact_count; exact_clock_reset = exact_count
    exact_width = exact_count; exact_control = exact_count
    for (item = 1; item <= expected; item += 1) {
      matches = 0; selected = 0
      for (cell = 1; cell <= cell_count; cell += 1) {
        if (type[cell] == "$dff" && same(output[cell], expected_signal[item])) {
          matches += 1; selected = cell
        }
      }
      if (matches != 1) {
        exact_inventory = 0; exact_clock_reset = 0; exact_width = 0; exact_control = 0
      } else {
        if (width[selected] != expected_width[item]) exact_width = 0
        if (!same(clock[selected], expected_clock[item])) exact_clock_reset = 0
        enabled = expected_enable[item] == "true"
        if (type[selected] != "$dff" || !one(clock_polarity[selected]))
          exact_control = 0
        reset_matches = 0; reset_mux = 0
        for (cell = 1; cell <= cell_count; cell += 1) {
          if (type[cell] == "$mux" && same(output[cell], data[selected])) {
            reset_matches += 1; reset_mux = cell
          }
        }
        if (reset_matches != 1) {
          exact_clock_reset = 0; exact_control = 0
        } else {
          if (width[reset_mux] != expected_width[item] ||
            !same(mux_select[reset_mux], expected_reset[item]) ||
            !zero(mux_b[reset_mux])) {
            exact_clock_reset = 0; exact_control = 0
          }
          if (enabled) {
            enable_matches = 0; enable_mux = 0
            for (cell = 1; cell <= cell_count; cell += 1) {
              if (type[cell] == "$mux" && same(output[cell], mux_a[reset_mux])) {
                enable_matches += 1; enable_mux = cell
              }
            }
            if (enable_matches != 1 ||
              width[enable_mux] != expected_width[item] ||
              !same(mux_a[enable_mux], expected_signal[item]) ||
              mux_select[enable_mux] == "" ||
              same(mux_b[enable_mux], expected_signal[item]))
              exact_control = 0
          }
        }
      }
    }
    no_extra_state = stateful_count == expected_count
    no_memory = memory_count == 0
    pass = single_module && exact_count && exact_inventory && exact_clock_reset &&
      exact_width && exact_control && no_extra_state && no_memory
    print "module_count", module_count + 0
    print "cell_count", cell_count + 0
    print "stateful_count", stateful_count + 0
    print "memory_count", memory_count + 0
    print "single_module", bool(single_module)
    print "exact_state_count", bool(exact_count)
    print "exact_state_inventory", bool(exact_inventory)
    print "exact_clock_reset_domains", bool(exact_clock_reset)
    print "exact_widths", bool(exact_width)
    print "exact_sync_reset_enable_shape", bool(exact_control)
    print "no_extra_state", bool(no_extra_state)
    print "no_memory", bool(no_memory)
    print "pass", bool(pass)
  }
' "$records" >"$findings"

field() {
  awk -F '\t' -v key="$1" '$1 == key { print $2; found = 1 }
    END { if (!found) exit 1 }' "$findings"
}

pass=$(field pass)
classification=toggle-state-shape-mismatch
[ "$pass" = false ] || classification=exact-toggle-state-shape
jq -n \
  --arg fixture "$fixture" \
  --argjson module_count "$(field module_count)" \
  --argjson cell_count "$(field cell_count)" \
  --argjson stateful_count "$(field stateful_count)" \
  --argjson memory_count "$(field memory_count)" \
  --argjson single_module "$(field single_module)" \
  --argjson exact_state_count "$(field exact_state_count)" \
  --argjson exact_state_inventory "$(field exact_state_inventory)" \
  --argjson exact_clock_reset_domains "$(field exact_clock_reset_domains)" \
  --argjson exact_widths "$(field exact_widths)" \
  --argjson exact_sync_reset_enable_shape "$(field exact_sync_reset_enable_shape)" \
  --argjson no_extra_state "$(field no_extra_state)" \
  --argjson no_memory "$(field no_memory)" \
  --arg classification "$classification" --argjson pass "$pass" '
  {
    schema_version: 1, fixture: $fixture,
    observed: { module_count: $module_count, cells: $cell_count,
      stateful_cells: $stateful_count, memory_cells: $memory_count },
    checks: { single_expected_module: $single_module,
      exact_state_count: $exact_state_count,
      exact_state_inventory: $exact_state_inventory,
      exact_clock_reset_domains: $exact_clock_reset_domains,
      exact_widths: $exact_widths,
      exact_sync_reset_enable_shape: $exact_sync_reset_enable_shape,
      no_extra_state: $no_extra_state, no_memory: $no_memory },
    classification: $classification,
    claim_boundary: { pre_map_state_shape: true,
      combinational_protocol_logic: false, physical_placement: false,
      metastability: false, mtbf: false, timing_closure: false },
    pass: $pass
  }' >"$report"

jq -e '
  def keys_are($allowed): ((keys - $allowed) | length) == 0;
  keys_are(["schema_version", "fixture", "observed", "checks",
    "classification", "claim_boundary", "pass"]) and
  .schema_version == 1 and
  (.observed | keys_are(["module_count", "cells", "stateful_cells",
    "memory_cells"])) and
  (.checks | keys_are(["single_expected_module", "exact_state_count",
    "exact_state_inventory", "exact_clock_reset_domains", "exact_widths",
    "exact_sync_reset_enable_shape", "no_extra_state", "no_memory"]) and
    all(.[]; type == "boolean")) and
  (.classification == "exact-toggle-state-shape" or
    .classification == "toggle-state-shape-mismatch") and
  .claim_boundary == { pre_map_state_shape: true,
    combinational_protocol_logic: false, physical_placement: false,
    metastability: false, mtbf: false, timing_closure: false } and
  (.pass | type == "boolean")
' "$report" >/dev/null || fail "report failed exact structural schema validation"
[ "$pass" = true ] || fail "$fixture does not match its exact pre-map state shape"
