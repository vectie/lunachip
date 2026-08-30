#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"
checker="$repo_dir/scripts/yosys-toggle-synthesis-check.sh"
report_checker="$repo_dir/scripts/yosys-toggle-synthesis-report-check.sh"
gate="$repo_dir/scripts/phase5-yosys-toggle-synthesis-gate.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"
expected="$fixtures/toggle-scalar-2.expected.json"
passing="$fixtures/toggle-scalar-2-pass.rtlil"
lock_file="$repo_dir/toolchain/yosys/lock.json"
report_schema="$repo_dir/toolchain/yosys/toggle-synthesis-report.schema.json"
scratch=$(mktemp -d /tmp/lunachip-toggle-synthesis-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  printf '%s\n' "yosys-toggle-synthesis-selftest: $*" >&2
  exit 1
}

expect_rejection() {
  name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$name unexpectedly passed"
  fi
}

require_gate_text() {
  grep -F "$1" "$gate" >/dev/null || fail "$2"
}
require_gate_text 'report-checker=$report_checker_digest' \
  "gate PIN omits independent report checker"
require_gate_text 'manifest-lib=$manifest_lib_digest' \
  "gate PIN omits verifier hashing dependency"
require_gate_text 'report-schema=$report_schema_digest' \
  "gate PIN omits v2 report schema"
require_gate_text '"$output/pre-map.json" "$output/pre-map.rtlil" "$lock_file" \' \
  "gate checker omits provenance-bound inputs"
require_gate_text '"$report_checker" "$fixture" "$output/toggle-synthesis.json"' \
  "gate omits independent report verification"
require_gate_text 'payload-leaves=1,2,2\tchecks=24' \
  "gate matrix is not fixed at eight checks per fixture"
for dependency in report_checker manifest_lib report_schema; do
  count=$(grep -Fc "sha256_file \"\$$dependency\"" "$gate")
  [ "$count" -eq 2 ] ||
    fail "$dependency must be pinned initially and rechecked after the matrix"
done

pre_map_json="$scratch/pre-map.json"
jq -n '
  {creator:"Yosys 0.68 selftest", modules:{toggle2:{cells:
    (reduce range(0;9) as $index ({};
      .["state-\($index)"]={type:"$dff"}))}}}
' >"$pre_map_json"
"$checker" "$expected" "$pre_map_json" "$passing" "$lock_file" \
  "$scratch/pass.json"
jq -e '
  .schema_version == "lunachip.toggle-synthesis-report/v2" and
  .artifact_kind == "toggle-handshake-pre-map-state-structural-evidence" and
  .pass and .result == "pass" and
  .fixture == "toggle-scalar-2-stage" and .top_module == "toggle2" and
  .synchronizer_stages == 2 and .payload_leaf_count == 1 and
  .expected_state_count == 9 and .yosys_creator == "Yosys 0.68 selftest" and
  .observed.stateful_cells == 9 and (.checks | all(.[]; .)) and
  .issues == [] and
  .counts == {checks_total:8, checks_passed:8, checks_failed:0, issues:0} and
  .claim_boundary == {pre_map_state_shape:true,
    combinational_protocol_logic:false, physical_placement:false,
    metastability:false, mtbf:false, timing_closure:false}
' \
  "$scratch/pass.json" >/dev/null || fail "passing shape report is incorrect"
"$report_checker" toggle-scalar-2-stage "$scratch/pass.json" "$expected" \
  "$pre_map_json" "$passing" "$lock_file" >/dev/null
if command -v jsonschema >/dev/null 2>&1; then
  jsonschema -i "$scratch/pass.json" "$report_schema" >/dev/null 2>&1 ||
    fail "passing report violates its v2 JSON Schema"
  schema_reject() {
    name=$1
    filter=$2
    mutant="$scratch/schema-$name.json"
    jq "$filter" "$scratch/pass.json" >"$mutant"
    if jsonschema -i "$mutant" "$report_schema" >/dev/null 2>&1; then
      fail "schema mutant $name unexpectedly passed"
    fi
  }
  schema_reject fixture-tuple '.synchronizer_stages=3'
  schema_reject observed-state '.observed.stateful_cells=8'
  schema_reject issue-membership '
    .checks.no_memory=false | .issues=["exact_widths"] |
    .counts={checks_total:8,checks_passed:7,checks_failed:1,issues:1} |
    .classification="toggle-state-shape-mismatch" |
    .claim_boundary.pre_map_state_shape=false | .result="fail" | .pass=false'
  schema_reject count-arithmetic '
    .checks.no_memory=false | .issues=["no_memory"] |
    .counts={checks_total:8,checks_passed:6,checks_failed:1,issues:1} |
    .classification="toggle-state-shape-mismatch" |
    .claim_boundary.pre_map_state_shape=false | .result="fail" | .pass=false'
fi
ln -s absent.json "$scratch/dangling-output.json"
expect_rejection dangling-report-output "$checker" "$expected" \
  "$pre_map_json" "$passing" "$lock_file" "$scratch/dangling-output.json"
[ -L "$scratch/dangling-output.json" ] ||
  fail "producer replaced dangling report-output link"
printf '%s\n' sentinel >"$scratch/existing-output.json"
expect_rejection existing-report-output "$checker" "$expected" \
  "$pre_map_json" "$passing" "$lock_file" "$scratch/existing-output.json"
[ "$(sed -n '1p' "$scratch/existing-output.json")" = sentinel ] ||
  fail "producer changed existing report output"
ln -s "$scratch/existing-output.json" "$scratch/symbolic-output.json"
expect_rejection symbolic-report-output "$checker" "$expected" \
  "$pre_map_json" "$passing" "$lock_file" "$scratch/symbolic-output.json"
[ "$(sed -n '1p' "$scratch/existing-output.json")" = sentinel ] ||
  fail "producer followed symbolic report output"
mkfifo "$scratch/special-output"
expect_rejection special-report-output "$checker" "$expected" \
  "$pre_map_json" "$passing" "$lock_file" "$scratch/special-output"
[ -p "$scratch/special-output" ] || fail "producer replaced special report output"
mkdir "$scratch/real-report-parent"
ln -s "$scratch/real-report-parent" "$scratch/symbolic-report-parent"
expect_rejection symbolic-report-parent "$checker" "$expected" \
  "$pre_map_json" "$passing" "$lock_file" \
  "$scratch/symbolic-report-parent/report.json"
[ ! -e "$scratch/real-report-parent/report.json" ] ||
  fail "producer followed a symbolic report parent"

ln -s "$expected" "$scratch/symbolic-expected.json"
ln -s "$pre_map_json" "$scratch/symbolic-pre-map.json"
ln -s "$passing" "$scratch/symbolic-pre-map.rtlil"
ln -s "$lock_file" "$scratch/symbolic-lock.json"
expect_rejection symbolic-expected "$checker" "$scratch/symbolic-expected.json" \
  "$pre_map_json" "$passing" "$lock_file" "$scratch/symbolic-expected-report.json"
expect_rejection symbolic-pre-map-json "$checker" "$expected" \
  "$scratch/symbolic-pre-map.json" "$passing" "$lock_file" \
  "$scratch/symbolic-json-report.json"
expect_rejection symbolic-rtlil "$checker" "$expected" "$pre_map_json" \
  "$scratch/symbolic-pre-map.rtlil" "$lock_file" \
  "$scratch/symbolic-rtlil-report.json"
expect_rejection symbolic-lock "$checker" "$expected" "$pre_map_json" \
  "$passing" "$scratch/symbolic-lock.json" "$scratch/symbolic-lock-report.json"
mkfifo "$scratch/special-input"
expect_rejection special-input "$checker" "$scratch/special-input" \
  "$pre_map_json" "$passing" "$lock_file" "$scratch/special-input-report.json"

expect_failure() {
  name=$1
  check=$2
  report="$scratch/$name.json"
  if "$checker" "$expected" "$pre_map_json" "$scratch/$name.rtlil" \
    "$lock_file" "$report" >/dev/null 2>&1; then
    fail "$name mutation was accepted"
  fi
  jq -e --arg check "$check" '(.pass | not) and
    .classification == "toggle-state-shape-mismatch" and
    (.checks[$check] | not) and (.issues | index($check)) != null and
    .counts.checks_failed == (.issues | length) and
    .counts.issues == (.issues | length) and .result == "fail" and
    .claim_boundary == {pre_map_state_shape:false,
      combinational_protocol_logic:false, physical_placement:false,
      metastability:false, mtbf:false, timing_closure:false}' \
    "$report" >/dev/null || fail "$name failure report is incorrect"
  if command -v jsonschema >/dev/null 2>&1; then
    jsonschema -i "$report" "$report_schema" >/dev/null 2>&1 ||
      fail "$name diagnostic violates its v2 JSON Schema"
  fi
}

awk '!changed && /WIDTH 1/ { sub(/WIDTH 1/, "WIDTH 2"); changed = 1 } { print }' "$passing" >"$scratch/wrong-width.rtlil"
expect_failure wrong-width exact_widths
awk '!changed && /CLK \\source_clock/ { sub(/CLK \\source_clock/, "CLK \\destination_clock"); changed = 1 } { print }' "$passing" >"$scratch/wrong-clock.rtlil"
expect_failure wrong-clock exact_clock_reset_domains
awk '!changed && /S \\source_reset/ { sub(/S \\source_reset/, "S \\destination_reset"); changed = 1 } { print }' "$passing" >"$scratch/wrong-reset.rtlil"
expect_failure wrong-reset exact_clock_reset_domains
awk '!changed && /B 1\0470/ { sub(/B 1\0470/, "B 1\0471"); changed = 1 } { print }' "$passing" >"$scratch/nonzero-reset.rtlil"
expect_failure nonzero-reset exact_sync_reset_enable_shape
awk '!changed && /A \\held/ { sub(/A \\held/, "A \\source_payload"); changed = 1 } { print }' "$passing" >"$scratch/wrong-enable.rtlil"
expect_failure wrong-enable exact_sync_reset_enable_shape
awk '
  /cell \$mux \\request_reset_mux/ {
    print "  cell $mux \\unexpected_request_hold_mux"
    print "    parameter \\WIDTH 1"
    print "    connect \\A \\request"
    print "    connect \\B \\request_functional_next"
    print "    connect \\S \\unexpected_enable"
    print "    connect \\Y \\unexpected_request_hold"
    print "  end"
  }
  /connect \\A \\request_functional_next/ {
    sub(/request_functional_next/, "unexpected_request_hold")
  }
  { print }
' "$passing" >"$scratch/unexpected-enable.rtlil"
expect_failure unexpected-enable exact_sync_reset_enable_shape
awk '
  /cell \$mux \\request_reset_mux/ {
    print "  cell $mux \\inverted_request_hold_mux"
    print "    parameter \\WIDTH 1"
    print "    connect \\A \\request_functional_next"
    print "    connect \\B \\request"
    print "    connect \\S \\unexpected_enable_n"
    print "    connect \\Y \\inverted_request_hold"
    print "  end"
  }
  /connect \\A \\request_functional_next/ {
    sub(/request_functional_next/, "inverted_request_hold")
  }
  { print }
' "$passing" >"$scratch/inverted-unexpected-enable.rtlil"
expect_failure inverted-unexpected-enable exact_sync_reset_enable_shape
sed '/cell \$dff \\acknowledge_stage1_cell/,/  end/d' "$passing" >"$scratch/missing-state.rtlil"
expect_failure missing-state exact_state_count
awk '/^end$/ { print "  cell $dff \\extra_cell"; print "    parameter \\CLK_POLARITY 1\0471"; print "    parameter \\WIDTH 1"; print "    connect \\CLK \\source_clock"; print "    connect \\D \\extra_next"; print "    connect \\Q \\extra"; print "  end" } { print }' "$passing" >"$scratch/extra-state.rtlil"
expect_failure extra-state exact_state_count
awk '/^end$/ { print "  memory width 1 size 2 \\hidden" } { print }' "$passing" >"$scratch/memory.rtlil"
expect_failure memory no_memory

mutate_report() {
  name=$1
  filter=$2
  mutant="$scratch/report-$name.json"
  jq "$filter" "$scratch/pass.json" >"$mutant"
  expect_rejection "report-$name" "$report_checker" toggle-scalar-2-stage \
    "$mutant" "$expected" "$pre_map_json" "$passing" "$lock_file"
}
mutate_report extra-key '.unexpected=true'
mutate_report digest '.inputs.pre_map_rtlil.sha256="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
mutate_report creator '.yosys_creator="Yosys 0.69 forged"'
mutate_report issue '.issues=["no_memory"]'
mutate_report count '.counts.checks_passed=7'
mutate_report observed-state '.observed.stateful_cells=8'
mutate_report stage '.synchronizer_stages=3'
mutate_report result '.result="fail"'
mutate_report overclaim '.claim_boundary.combinational_protocol_logic=true'
mutate_report false-pass '.pass=false | .claim_boundary.pre_map_state_shape=true'

mutate_expected() {
  name=$1
  filter=$2
  mutant_expected="$scratch/expected-$name.json"
  mutant_report="$scratch/expected-$name-report.json"
  jq "$filter" "$expected" >"$mutant_expected"
  sha="sha256:$(lc_evidence_sha256_file "$mutant_expected")"
  bytes=$(wc -c <"$mutant_expected" | tr -d ' ')
  jq --arg sha "$sha" --argjson bytes "$bytes" '
    .inputs.expected_contract_json.sha256=$sha |
    .inputs.expected_contract_json.bytes=$bytes
  ' "$scratch/pass.json" >"$mutant_report"
  expect_rejection "expected-$name" "$report_checker" toggle-scalar-2-stage \
    "$mutant_report" "$mutant_expected" "$pre_map_json" "$passing" \
    "$lock_file"
}
mutate_expected extra-key '.unexpected=true'
mutate_expected bad-identifier '.state[0].signal="bad signal"'
mutate_expected duplicate-state '.state[1].signal=.state[0].signal'
mutate_expected enabled-count '.state[0].enable=true'

mutate_pre_map() {
  name=$1
  filter=$2
  mutant_json="$scratch/pre-map-$name.json"
  mutant_report="$scratch/pre-map-$name-report.json"
  jq "$filter" "$pre_map_json" >"$mutant_json"
  sha="sha256:$(lc_evidence_sha256_file "$mutant_json")"
  bytes=$(wc -c <"$mutant_json" | tr -d ' ')
  jq --arg sha "$sha" --argjson bytes "$bytes" '
    .inputs.pre_map_json.sha256=$sha | .inputs.pre_map_json.bytes=$bytes
  ' "$scratch/pass.json" >"$mutant_report"
  expect_rejection "pre-map-$name" "$report_checker" toggle-scalar-2-stage \
    "$mutant_report" "$expected" "$mutant_json" "$passing" "$lock_file"
}
mutate_pre_map wrong-top '.modules={wrong:.modules.toggle2}'
mutate_pre_map missing-dff 'del(.modules.toggle2.cells["state-8"])'
mutate_pre_map alternate-state '.modules.toggle2.cells.alternate={type:"$adff"}'
mutate_pre_map memory '.modules.toggle2.cells.memory={type:"$mem_v2"}'
mutate_pre_map module-memory \
  '.modules.toggle2.memories.hidden={width:1,size:2,start_offset:0}'

alternate_json="$scratch/pre-map-alternate-state.json"
expect_rejection producer-alternate-state "$checker" "$expected" \
  "$alternate_json" "$passing" "$lock_file" "$scratch/alternate-report.json"
module_memory_json="$scratch/pre-map-module-memory.json"
expect_rejection producer-module-memory "$checker" "$expected" \
  "$module_memory_json" "$passing" "$lock_file" \
  "$scratch/module-memory-report.json"

ln -s "$scratch/pass.json" "$scratch/symbolic-report.json"
expect_rejection symbolic-report "$report_checker" toggle-scalar-2-stage \
  "$scratch/symbolic-report.json" "$expected" "$pre_map_json" "$passing" \
  "$lock_file"

printf '%s\n' \
  "Yosys toggle synthesis self-tests pass: exact graph and provenance mutants"
