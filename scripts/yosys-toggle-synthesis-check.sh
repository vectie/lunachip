#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

fail() {
  echo "yosys-toggle-synthesis-check: $*" >&2
  exit 1
}

[ "$#" -eq 5 ] || fail \
  "usage: $0 EXPECTED_CONTRACT_JSON PRE_MAP_JSON PRE_MAP_RTLIL YOSYS_LOCK REPORT_JSON"
expected=$1
pre_map_json=$2
rtlil=$3
lock_file=$4
report=$5
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"
shape_schema="$repo_dir/toolchain/yosys/toggle-synthesis-shape.schema.json"
report_schema="$repo_dir/toolchain/yosys/toggle-synthesis-report.schema.json"

command -v jq >/dev/null 2>&1 || fail "jq is required"
for input in "$expected" "$pre_map_json" "$rtlil" "$lock_file"; do
  [ -s "$input" ] && [ -f "$input" ] && [ ! -L "$input" ] ||
    fail "input is absent, empty, symbolic, or special: $input"
done
[ -d "$(dirname -- "$report")" ] && [ ! -L "$(dirname -- "$report")" ] ||
  fail "report parent is absent, symbolic, or not a directory"
[ ! -e "$report" ] && [ ! -L "$report" ] ||
  fail "report path already exists or is symbolic: $report"
jq -e . "$shape_schema" >/dev/null || fail "shape schema is invalid JSON"
jq -e . "$report_schema" >/dev/null || fail "report schema is invalid JSON"
jq -e '.creator | type == "string" and test("^Yosys 0\\.68( |$)")' \
  "$pre_map_json" >/dev/null || fail "pre-map JSON creator is not locked Yosys 0.68"
jq -e '.provider.kind == "oci" and .tools.yosys.version == "0.68"' \
  "$lock_file" >/dev/null || fail "Yosys lock identity is invalid"
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
stages=$(jq -r '.synchronizer_stages' "$expected")
payload_leaf_count=$(jq -r '.payload_leaf_count' "$expected")
state_count=$(jq -r '.state_count' "$expected")
yosys_creator=$(jq -r '.creator' "$pre_map_json")
expected_sha="sha256:$(lc_evidence_sha256_file "$expected")"
pre_map_json_sha="sha256:$(lc_evidence_sha256_file "$pre_map_json")"
rtlil_sha="sha256:$(lc_evidence_sha256_file "$rtlil")"
lock_sha="sha256:$(lc_evidence_sha256_file "$lock_file")"
expected_bytes=$(wc -c <"$expected" | tr -d ' ')
pre_map_json_bytes=$(wc -c <"$pre_map_json" | tr -d ' ')
rtlil_bytes=$(wc -c <"$rtlil" | tr -d ' ')
lock_bytes=$(wc -c <"$lock_file" | tr -d ' ')
jq -e --arg top "$top_module" --argjson states "$state_count" '
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
' "$pre_map_json" >/dev/null ||
  fail "pre-map JSON top or exact state/memory inventory drifted"

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
  --arg fixture "$fixture" --arg top_module "$top_module" \
  --argjson stages "$stages" --argjson payload_leaf_count "$payload_leaf_count" \
  --argjson expected_state_count "$state_count" \
  --arg yosys_creator "$yosys_creator" --arg expected_sha "$expected_sha" \
  --arg pre_map_json_sha "$pre_map_json_sha" --arg rtlil_sha "$rtlil_sha" \
  --arg lock_sha "$lock_sha" --argjson expected_bytes "$expected_bytes" \
  --argjson pre_map_json_bytes "$pre_map_json_bytes" \
  --argjson rtlil_bytes "$rtlil_bytes" --argjson lock_bytes "$lock_bytes" \
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
  def binding($sha; $bytes):
    {sha256: $sha, bytes: $bytes, nonempty: true};
  {
    single_expected_module: $single_module,
    exact_state_count: $exact_state_count,
    exact_state_inventory: $exact_state_inventory,
    exact_clock_reset_domains: $exact_clock_reset_domains,
    exact_widths: $exact_widths,
    exact_sync_reset_enable_shape: $exact_sync_reset_enable_shape,
    no_extra_state: $no_extra_state,
    no_memory: $no_memory
  } as $checks |
  ($checks | to_entries | map(select(.value == false) | .key)) as $issues |
  {
    schema_version: "lunachip.toggle-synthesis-report/v2",
    artifact_kind: "toggle-handshake-pre-map-state-structural-evidence",
    fixture: $fixture, top_module: $top_module,
    synchronizer_stages: $stages, payload_leaf_count: $payload_leaf_count,
    expected_state_count: $expected_state_count,
    yosys_creator: $yosys_creator,
    inputs: {
      expected_contract_json: binding($expected_sha; $expected_bytes),
      pre_map_json: binding($pre_map_json_sha; $pre_map_json_bytes),
      pre_map_rtlil: binding($rtlil_sha; $rtlil_bytes),
      yosys_lock: binding($lock_sha; $lock_bytes)
    },
    observed: { module_count: $module_count, cells: $cell_count,
      stateful_cells: $stateful_count, memory_cells: $memory_count },
    checks: $checks,
    issues: $issues,
    counts: {checks_total: 8, checks_passed: (8 - ($issues | length)),
      checks_failed: ($issues | length), issues: ($issues | length)},
    classification: $classification,
    claim_boundary: { pre_map_state_shape: $pass,
      combinational_protocol_logic: false, physical_placement: false,
      metastability: false, mtbf: false, timing_closure: false },
    result: (if $pass then "pass" else "fail" end),
    pass: $pass
  }' >"$report"

jq -e --arg fixture "$fixture" --arg top "$top_module" \
  --arg creator "$yosys_creator" --argjson stages "$stages" \
  --argjson leaves "$payload_leaf_count" --argjson states "$state_count" \
  --arg expected_sha "$expected_sha" --arg json_sha "$pre_map_json_sha" \
  --arg rtlil_sha "$rtlil_sha" --arg lock_sha "$lock_sha" \
  --argjson expected_bytes "$expected_bytes" \
  --argjson json_bytes "$pre_map_json_bytes" \
  --argjson rtlil_bytes "$rtlil_bytes" --argjson lock_bytes "$lock_bytes" '
  def exact_keys($wanted): (keys | sort) == ($wanted | sort);
  def binding($sha; $bytes):
    exact_keys(["sha256", "bytes", "nonempty"]) and
    .sha256 == $sha and .bytes == $bytes and .nonempty == true;
  .checks as $checks |
  ($checks | to_entries | map(select(.value == false) | .key)) as $failed |
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
    "memory_cells"])) and
  (.checks | exact_keys(["single_expected_module", "exact_state_count",
    "exact_state_inventory", "exact_clock_reset_domains", "exact_widths",
    "exact_sync_reset_enable_shape", "no_extra_state", "no_memory"]) and
    all(.[]; type == "boolean")) and
  .issues == $failed and
  .counts == {checks_total: 8, checks_passed: (8 - ($failed | length)),
    checks_failed: ($failed | length), issues: ($failed | length)} and
  .pass == (($failed | length) == 0) and
  .result == (if .pass then "pass" else "fail" end) and
  .classification == (if .pass then "exact-toggle-state-shape"
    else "toggle-state-shape-mismatch" end) and
  .claim_boundary == { pre_map_state_shape: .pass,
    combinational_protocol_logic: false, physical_placement: false,
    metastability: false, mtbf: false, timing_closure: false }
' "$report" >/dev/null || fail "report failed exact structural schema validation"
[ "$pass" = true ] || fail "$fixture does not match its exact pre-map state shape"
