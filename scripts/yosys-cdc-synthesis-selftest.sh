#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"

checker="$repo_dir/scripts/yosys-cdc-synthesis-check.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
gate="$repo_dir/scripts/phase5-yosys-cdc-synthesis-gate.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"
expected="$fixtures/cdc-sync-2.expected.json"
header='LUNACHIP-PHASE5-YOSYS-CDC-SYNTHESIS-EVIDENCE 1'
records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,CLAIM,BUNDLES,FIXTURE,RESULTS,MATRIX,RECHECK,ARTIFACTS'

fail() {
  printf '%s\n' "yosys-cdc-synthesis-selftest: $*" >&2
  exit 1
}
expect_failure() {
  lcpcsst_name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$lcpcsst_name unexpectedly passed"
  fi
}
require_gate_text() {
  grep -F "$1" "$gate" >/dev/null || fail "$2"
}

scratch=$(mktemp -d /tmp/lunachip-cdc-synthesis-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

"$repo_dir/scripts/evidence-receipt-selftest.sh" >/dev/null
require_gate_text "allowed_records='$records'" 'gate receipt schema drifted'
require_gate_text 'mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}' \
  'gate no longer defaults to volume transport'
require_gate_text 'require_volume "$mount_mode"' \
  'gate no longer rejects non-volume transport'
require_gate_text 'verify_transport "$output/transport-receipt.txt" "$image"' \
  'gate no longer validates runner transport provenance'
require_gate_text 'verify_synthesis_inventory "$output"' \
  'gate no longer rejects missing, extra, symbolic, or special runner outputs'
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
require_gate_text 'record MATRIX fixtures=3 reports=3 checks=27 stage-counts=2,3,4' \
  'exact synthesis matrix receipt drifted'
require_gate_text 'all(.[]; . == true)' \
  'gate no longer independently requires all nine report checks'

for binding in \
  'lock=$lock_sha' \
  'runner=$runner_sha' \
  'validator=$validator_sha' \
  'checker=$checker_sha' \
  'focused-selftest=$selftest_sha' \
  'runner-selftest=$runner_selftest_sha' \
  'receipt-selftest=$receipt_selftest_sha' \
  'receipt-lib=$receipt_lib_sha' \
  'manifest-lib=$manifest_lib_sha' \
  'gate=$gate_sha' \
  'schemas-manifest=$schemas_sha'; do
  require_gate_text "$binding" "gate PIN omits $binding"
done
for dependency in lock_file runner validator checker selftest runner_selftest \
  receipt_selftest receipt_lib manifest_lib gate; do
  count=$(grep -Fc "lc_evidence_sha256_file \"\$$dependency\"" "$gate")
  [ "$count" -eq 2 ] || fail "$dependency must be hashed initially and at recheck"
done
require_gate_text 'lc_evidence_verify_manifest "$repo_dir/toolchain/yosys"' \
  'gate does not recheck its complete Yosys schema manifest'
require_gate_text 'lc_evidence_verify_manifest "$bundles" "$bundles_manifest"' \
  'gate does not recheck its generated bundle manifest'
require_gate_text 'lc_evidence_verify_manifest "$manifests" "$result_manifests"' \
  'gate does not freeze and recheck its per-fixture result manifests'

# Fixture generation is byte deterministic and exposes only the exact public
# 2/3/4-stage matrix. Each bundle is independently accepted by the locked job
# validator before any Docker-based synthesis is evidence-eligible.
moon -C "$repo_dir" run --target native --release \
  cmd/phase5-sync-fixtures -- matrix "$scratch/first"
moon -C "$repo_dir" run --target native --release \
  cmd/phase5-sync-fixtures -- matrix "$scratch/second"
diff -r "$scratch/first" "$scratch/second" >/dev/null ||
  fail 'native synchronizer bundles are not byte deterministic'
observed_fixtures=$(
  find "$scratch/first" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | LC_ALL=C sort
)
expected_fixtures='bit-synchronizer-2-stage
bit-synchronizer-3-stage
bit-synchronizer-4-stage'
[ "$observed_fixtures" = "$expected_fixtures" ] || fail 'fixture matrix drifted'
for fixture in $expected_fixtures; do
  case "$fixture" in
    bit-synchronizer-2-stage) stages=2 ;;
    bit-synchronizer-3-stage) stages=3 ;;
    bit-synchronizer-4-stage) stages=4 ;;
    *) fail "unclassified fixture $fixture" ;;
  esac
  bundle="$scratch/first/$fixture"
  "$validator" --job-json "$bundle/job.json" "$bundle" >/dev/null
  jq -e --arg fixture "$fixture" --argjson stages "$stages" '
    .fixture == $fixture and .stage_count == $stages and
    .edge == "positive" and .width == 1 and .reset == false
  ' "$bundle/expected-cdc-shape.json" >/dev/null ||
    fail "$fixture shape identity drifted"
  [ "$(find "$bundle" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')" -eq 5 ] ||
    fail "$fixture bundle inventory drifted"
done

# Parser-level positive and five orthogonal structural negative fixtures.
"$checker" "$expected" "$fixtures/cdc-sync-2-pass.rtlil" "$scratch/pass.json"
jq -e '
  .pass and .fixture == "bit-synchronizer-2-stage" and
  .stage_count == 2 and .classification == "exact-bit-synchronizer-shape" and
  .observed.dff_cells == 2 and .observed.stateful_cells == 2 and
  .observed.memory_cells == 0 and (.checks | all(.[]; .)) and
  .claim_boundary == {pre_map_structural_shape: true,
    physical_placement: false, metastability: false, mtbf: false,
    timing_closure: false}
' "$scratch/pass.json" >/dev/null || fail 'passing shape report is not exact'

check_failure() {
  lcpcsst_name=$1
  lcpcsst_check=$2
  lcpcsst_report="$scratch/$lcpcsst_name.json"
  if "$checker" "$expected" "$fixtures/cdc-sync-2-$lcpcsst_name.rtlil" \
    "$lcpcsst_report" >/dev/null 2>&1; then
    fail "$lcpcsst_name fixture was accepted"
  fi
  jq -e --arg check "$lcpcsst_check" '
    (.pass | not) and .classification == "bit-synchronizer-shape-mismatch" and
    (.checks[$check] | not) and
    .claim_boundary == {pre_map_structural_shape: true,
      physical_placement: false, metastability: false, mtbf: false,
      timing_closure: false}
  ' "$lcpcsst_report" >/dev/null || fail "$lcpcsst_name report is incorrect"
}
check_failure missing-stage exact_stage_count
check_failure wrong-clock same_destination_clock
check_failure wrong-width positive_edge_one_bit_dff_only
check_failure bypass no_bypass
check_failure extra-state no_extra_state

# Bind transport is rejected before Docker is contacted. The exact nonzero
# command remains in strict incomplete evidence and no pass receipt appears.
mkdir "$scratch/fake-bin" "$scratch/bind-run"
ln -s "$(command -v false)" "$scratch/fake-bin/docker"
if PATH="$scratch/fake-bin:$PATH" LUNACHIP_YOSYS_MOUNT_MODE=bind \
  "$gate" "$scratch/bind-run" >/dev/null 2>&1; then
  fail 'gate accepted bind transport'
fi
incomplete="$scratch/bind-run/phase5-yosys-cdc-synthesis-evidence.incomplete"
final="$scratch/bind-run/phase5-yosys-cdc-synthesis-evidence.txt"
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
  'Yosys CDC synthesis self-tests pass: exact 3-fixture matrix and strict evidence lifecycle'
