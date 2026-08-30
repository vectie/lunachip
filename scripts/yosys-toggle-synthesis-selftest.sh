#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"
checker="$repo_dir/scripts/yosys-toggle-synthesis-check.sh"
report_checker="$repo_dir/scripts/yosys-toggle-synthesis-report-check.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
gate="$repo_dir/scripts/phase5-yosys-toggle-synthesis-gate.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"
expected="$fixtures/toggle-scalar-2.expected.json"
passing="$fixtures/toggle-scalar-2-pass.rtlil"
lock_file="$repo_dir/toolchain/yosys/lock.json"
report_schema="$repo_dir/toolchain/yosys/toggle-synthesis-report.schema.json"
header='LUNACHIP-PHASE5-YOSYS-TOGGLE-SYNTHESIS-EVIDENCE 1'
records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,CLAIM,BUNDLES,FIXTURE,RESULTS,MATRIX,RECHECK,ARTIFACTS'
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

"$repo_dir/scripts/evidence-receipt-selftest.sh" >/dev/null
require_gate_text "allowed_records='$records'" 'gate receipt schema drifted'
require_gate_text 'mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}' \
  'gate no longer defaults to volume transport'
require_gate_text 'require_volume "$mount_mode"' \
  'gate no longer rejects non-volume transport'
require_gate_text 'verify_transport "$output/transport-receipt.txt" "$image"' \
  'gate no longer validates runner transport provenance'
require_gate_text 'verify_synthesis_inventory "$output"' \
  'gate no longer validates the exact synthesis inventory'
require_gate_text 'lc_evidence_snapshot_repository "$repo_dir" "$repository_start"' \
  'gate no longer captures its start repository snapshot'
require_gate_text 'lc_evidence_snapshot_repository "$repo_dir" "$repository_end"' \
  'gate no longer captures its end repository snapshot'
require_gate_text 'lc_evidence_create_artifact_manifest "$artifacts" "$artifact_manifest"' \
  'gate no longer creates a complete artifact manifest'
require_gate_text 'lc_evidence_receipt_seal' \
  'gate no longer seals strict incomplete evidence'
require_gate_text 'lc_evidence_receipt_publish_pass' \
  'gate no longer atomically publishes passing evidence'
require_gate_text 'record MATRIX fixtures=3 reports=3 checks=24 stage-counts=2,3,4 \' \
  'exact toggle synthesis matrix receipt drifted'
require_gate_text 'payload-leaves=1,2,2 state-counts=9,13,15' \
  'exact leaf and state matrix receipt drifted'
require_gate_text '"$report_checker" "$fixture" "$report" \' \
  'gate omits independent report verification'
require_gate_text '"$bundle/expected-toggle-shape.json" "$output/pre-map.json" \' \
  'gate producer omits expected shape or pre-map JSON'
require_gate_text '"$output/pre-map.rtlil" "$lock_file" "$report"' \
  'gate producer omits RTLIL, lock, or isolated report output'

for binding in \
  'lock=$lock_sha' \
  'runner=$runner_sha' \
  'validator=$validator_sha' \
  'producer=$checker_sha' \
  'verifier=$report_checker_sha' \
  'focused-selftest=$selftest_sha' \
  'runner-selftest=$runner_selftest_sha' \
  'receipt-selftest=$receipt_selftest_sha' \
  'receipt-lib=$receipt_lib_sha' \
  'manifest-lib=$manifest_lib_sha' \
  'shape-schema=$shape_schema_sha' \
  'report-schema=$report_schema_sha' \
  'gate=$gate_sha' \
  'schemas-manifest=$schemas_sha'; do
  require_gate_text "$binding" "gate PIN omits $binding"
done
for dependency in lock_file runner validator checker report_checker selftest \
  runner_selftest receipt_selftest receipt_lib manifest_lib shape_schema \
  report_schema gate; do
  count=$(grep -Fc "lc_evidence_sha256_file \"\$$dependency\"" "$gate")
  [ "$count" -eq 2 ] ||
    fail "$dependency must be hashed initially and at recheck"
done
require_gate_text 'lc_evidence_verify_manifest "$repo_dir/toolchain/yosys"' \
  'gate does not recheck its complete Yosys schema manifest'
require_gate_text 'lc_evidence_verify_manifest "$bundles" "$bundles_manifest"' \
  'gate does not recheck its generated bundle manifest'
require_gate_text 'lc_evidence_verify_manifest "$manifests" "$result_manifests"' \
  'gate does not freeze and recheck per-fixture result manifests'

# The exact 2/3/4-stage fixture matrix is byte deterministic. Every bundle has
# one job-bound top-module source plus the four fixed contract artifacts.
moon -C "$repo_dir" run --target native --release \
  cmd/phase5-toggle-synthesis-fixtures -- matrix "$scratch/first"
moon -C "$repo_dir" run --target native --release \
  cmd/phase5-toggle-synthesis-fixtures -- matrix "$scratch/second"
diff -r "$scratch/first" "$scratch/second" >/dev/null ||
  fail 'native toggle bundles are not byte deterministic'
observed_fixtures=$(
  find "$scratch/first" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | LC_ALL=C sort
)
expected_fixtures='toggle-record-3-stage
toggle-record-4-stage
toggle-scalar-2-stage'
[ "$observed_fixtures" = "$expected_fixtures" ] || fail 'fixture matrix drifted'
[ -z "$(find "$scratch/first" -mindepth 1 -maxdepth 1 ! -type d -print)" ] ||
  fail 'fixture root contains a non-directory entry'
for fixture in $expected_fixtures; do
  case "$fixture" in
    toggle-scalar-2-stage) stages=2; leaves=1; states=9 ;;
    toggle-record-3-stage) stages=3; leaves=2; states=13 ;;
    toggle-record-4-stage) stages=4; leaves=2; states=15 ;;
    *) fail "unclassified fixture $fixture" ;;
  esac
  bundle="$scratch/first/$fixture"
  "$validator" --job-json "$bundle/job.json" "$bundle" >/dev/null
  source=$(jq -r '.sources | if length == 1 then .[0].path else "" end' \
    "$bundle/job.json")
  top=$(jq -r '.top_module' "$bundle/expected-toggle-shape.json")
  [ "$source" = "$top.sv" ] || fail "$fixture job source is not its top module"
  jq -e --arg fixture "$fixture" --argjson stages "$stages" \
    --argjson leaves "$leaves" --argjson states "$states" '
      .fixture == $fixture and .synchronizer_stages == $stages and
      .payload_leaf_count == $leaves and .state_count == $states
    ' "$bundle/expected-toggle-shape.json" >/dev/null ||
    fail "$fixture topology drifted"
  observed=$(find "$bundle" -mindepth 1 -maxdepth 1 -type f \
    -exec basename {} \; | LC_ALL=C sort)
  wanted=$(printf '%s\n' design.lcir expected-toggle-shape.json job.json \
    names.lcnm "$source" | LC_ALL=C sort)
  [ "$observed" = "$wanted" ] &&
    [ -z "$(find "$bundle" -mindepth 1 -maxdepth 1 ! -type f -print)" ] ||
    fail "$fixture bundle inventory drifted"
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

# Bind transport is rejected before Docker is contacted. The exact nonzero
# command remains in strict incomplete evidence and no pass receipt appears.
mkdir "$scratch/fake-bin" "$scratch/bind-run"
ln -s "$(command -v false)" "$scratch/fake-bin/docker"
if PATH="$scratch/fake-bin:$PATH" LUNACHIP_YOSYS_MOUNT_MODE=bind \
  "$gate" "$scratch/bind-run" >/dev/null 2>&1; then
  fail 'gate accepted bind transport'
fi
incomplete="$scratch/bind-run/phase5-yosys-toggle-synthesis-evidence.incomplete"
final="$scratch/bind-run/phase5-yosys-toggle-synthesis-evidence.txt"
[ -f "$incomplete" ] && [ ! -L "$incomplete" ] ||
  fail 'failed preflight did not retain regular incomplete evidence'
[ ! -e "$final" ] && [ ! -L "$final" ] ||
  fail 'failed preflight published false passing evidence'
grep -Fx "$header" "$incomplete" >/dev/null || fail 'receipt header drifted'
grep -Fx 'STATE incomplete' "$incomplete" >/dev/null || fail 'receipt state drifted'
grep -Fx 'COMMAND preflight-volume status=1' "$incomplete" >/dev/null ||
  fail 'failed volume preflight status was not recorded'
if grep -Eq '^(COMMAND docker-context |STATE pass$|END$)' "$incomplete"; then
  fail 'failed volume preflight advanced beyond its safe boundary'
fi
retained="$scratch/retained-prefix.incomplete"
cp "$incomplete" "$retained"
printf '%s\n' END >>"$retained"
lc_evidence_validate_receipt "$retained" "$header" incomplete COMMAND COMMAND ||
  fail 'retained failed-preflight prefix is not strict'

printf '%s\n' \
  'Yosys toggle synthesis self-tests pass: exact 3-fixture matrix and strict evidence lifecycle'
