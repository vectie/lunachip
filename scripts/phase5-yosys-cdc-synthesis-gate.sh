#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"

runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
checker="$repo_dir/scripts/yosys-cdc-synthesis-check.sh"
selftest="$repo_dir/scripts/yosys-cdc-synthesis-selftest.sh"
runner_selftest="$repo_dir/scripts/phase4-yosys-selftest.sh"
receipt_selftest="$repo_dir/scripts/evidence-receipt-selftest.sh"
receipt_lib="$repo_dir/scripts/evidence-receipt-lib.sh"
manifest_lib="$repo_dir/scripts/evidence-manifest-lib.sh"
lock_file="$repo_dir/toolchain/yosys/lock.json"
gate="$repo_dir/scripts/phase5-yosys-cdc-synthesis-gate.sh"

header='LUNACHIP-PHASE5-YOSYS-CDC-SYNTHESIS-EVIDENCE 1'
allowed_records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,CLAIM,BUNDLES,FIXTURE,RESULTS,MATRIX,RECHECK,ARTIFACTS'
required_records=$allowed_records

fail() {
  printf '%s\n' "phase5-yosys-cdc-synthesis-gate: $*" >&2
  exit 1
}
require_command() { command -v "$1" >/dev/null 2>&1; }
require_sha256() {
  command -v shasum >/dev/null 2>&1 ||
    command -v sha256sum >/dev/null 2>&1
}
require_volume() {
  [ "$1" = volume ] || {
    printf '%s\n' 'LUNACHIP_YOSYS_MOUNT_MODE must be volume for this gate' >&2
    return 1
  }
}
verify_image_metadata() {
  lcpcsg_inspect=$1
  lcpcsg_image=$2
  lcpcsg_manifest=$3
  lcpcsg_config=$4
  lcpcsg_platform=$5
  jq -e --arg image "$lcpcsg_image" --arg manifest "$lcpcsg_manifest" \
    --arg config "$lcpcsg_config" --arg platform "$lcpcsg_platform" '
      length == 1 and
      (.[0].Id == $manifest or .[0].Id == $config) and
      ((.[0].Descriptor.digest? // $manifest) == $manifest) and
      (.[0].RepoDigests | index($image)) != null and
      (.[0].Os + "/" + .[0].Architecture) == $platform
    ' "$lcpcsg_inspect" >/dev/null
}
verify_transport() {
  lcpcsg_transport=$1
  lcpcsg_image=$2
  [ -f "$lcpcsg_transport" ] && [ ! -L "$lcpcsg_transport" ] || return 1
  [ "$(wc -l <"$lcpcsg_transport" | tr -d ' ')" -eq 5 ] &&
    grep -Fx 'LUNACHIP-YOSYS-TRANSPORT 1' "$lcpcsg_transport" >/dev/null &&
    grep -Fx 'MODE volume' "$lcpcsg_transport" >/dev/null &&
    grep -Fx 'PERMISSION-INITIALIZER pinned-image-python-os-chmod-v1' \
      "$lcpcsg_transport" >/dev/null &&
    grep -Eq '^RUNTIME-USER [0-9]+:[0-9]+$' "$lcpcsg_transport" &&
    grep -Fx "OCI-IMAGE $lcpcsg_image" "$lcpcsg_transport" >/dev/null
}
verify_synthesis_inventory() {
  lcpcsg_output=$1
  [ -d "$lcpcsg_output" ] && [ ! -L "$lcpcsg_output" ] || return 1
  lcpcsg_observed=$(
    find "$lcpcsg_output" -mindepth 1 -maxdepth 1 -type f \
      -exec basename {} \; | LC_ALL=C sort
  ) || return 1
  lcpcsg_expected=$(printf '%s\n' command.txt netlist.json netlist.v \
    pre-map.json pre-map.rtlil status.txt tool-versions.txt \
    transport-receipt.txt yosys.log yosys.ys | LC_ALL=C sort)
  [ "$lcpcsg_observed" = "$lcpcsg_expected" ] &&
    [ -z "$(find "$lcpcsg_output" -mindepth 1 -maxdepth 1 ! -type f -print)" ]
}
verify_report() {
  lcpcsg_fixture=$1
  lcpcsg_stages=$2
  lcpcsg_report=$3
  [ -f "$lcpcsg_report" ] && [ ! -L "$lcpcsg_report" ] || return 1
  jq -e --arg fixture "$lcpcsg_fixture" --argjson stages "$lcpcsg_stages" '
    def keys_are($allowed): ((keys - $allowed) | length) == 0;
    keys_are(["schema_version", "fixture", "stage_count", "observed",
      "checks", "classification", "claim_boundary", "pass"]) and
    .schema_version == 1 and .fixture == $fixture and
    .stage_count == $stages and .pass == true and
    .classification == "exact-bit-synchronizer-shape" and
    (.observed | keys_are(["module_count", "dff_cells", "stateful_cells",
      "memory_cells", "cells"])) and
    .observed.module_count == 1 and .observed.dff_cells == $stages and
    .observed.stateful_cells == $stages and .observed.memory_cells == 0 and
    (.observed.cells | type == "array" and length == $stages) and
    (.checks | keys_are(["single_expected_module", "exact_stage_count",
      "positive_edge_one_bit_dff_only", "same_destination_clock",
      "exact_source_to_stage_chain", "final_stage_to_output", "no_bypass",
      "no_extra_state", "no_memory"]) and all(.[]; . == true)) and
    .claim_boundary == {pre_map_structural_shape: true,
      physical_placement: false, metastability: false, mtbf: false,
      timing_closure: false}
  ' "$lcpcsg_report" >/dev/null
}
verify_bundle_inventory() {
  lcpcsg_bundle=$1
  lcpcsg_fixture=$2
  lcpcsg_stages=$3
  [ -d "$lcpcsg_bundle" ] && [ ! -L "$lcpcsg_bundle" ] || return 1
  lcpcsg_source=$(jq -r '.sources | if length == 1 then .[0].path else "" end' \
    "$lcpcsg_bundle/job.json") || return 1
  lc_evidence_token "$lcpcsg_source" &&
    printf '%s\n' "$lcpcsg_source" | grep -Eq '\.sv$' || return 1
  lcpcsg_observed=$(
    find "$lcpcsg_bundle" -mindepth 1 -maxdepth 1 -type f \
      -exec basename {} \; | LC_ALL=C sort
  ) || return 1
  lcpcsg_expected=$(printf '%s\n' design.lcir expected-cdc-shape.json \
    job.json "$lcpcsg_source" names.lcnm | LC_ALL=C sort)
  [ "$lcpcsg_observed" = "$lcpcsg_expected" ] || return 1
  [ -z "$(find "$lcpcsg_bundle" -mindepth 1 -maxdepth 1 ! -type f -print)" ] ||
    return 1
  jq -e --arg fixture "$lcpcsg_fixture" --argjson stages "$lcpcsg_stages" '
    .fixture == $fixture and .stage_count == $stages and
    .schema_version == "lunachip.cdc-synthesis-shape/v1" and
    .edge == "positive" and .width == 1 and .reset == false
  ' "$lcpcsg_bundle/expected-cdc-shape.json" >/dev/null
}

[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d /tmp/lunachip-phase5-cdc-synthesis.XXXXXX)
else
  requested_root=$1
  [ -n "$requested_root" ] || fail "run root must not be empty"
  [ ! -L "$requested_root" ] || fail "run root must not be symbolic"
  if [ -e "$requested_root" ]; then
    [ -d "$requested_root" ] || fail "run root is not a directory"
    if find "$requested_root" -mindepth 1 -print | grep -q .; then
      fail "explicit run root must be empty"
    fi
    run_root=$(CDPATH= cd -- "$requested_root" && pwd -P)
  else
    requested_parent=$(dirname -- "$requested_root")
    requested_name=$(basename -- "$requested_root")
    [ -d "$requested_parent" ] && [ ! -L "$requested_parent" ] ||
      fail "run-root parent is absent or symbolic"
    requested_parent=$(CDPATH= cd -- "$requested_parent" && pwd -P)
    run_root="$requested_parent/$requested_name"
    [ "$run_root" != / ] || fail "refusing filesystem root"
    mkdir "$run_root"
  fi
fi
case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac

artifacts="$run_root/artifacts"
bundles="$artifacts/bundles"
synthesis="$artifacts/synthesis"
reports="$artifacts/reports"
logs="$artifacts/logs"
metadata="$artifacts/metadata"
manifests="$artifacts/manifests"
mkdir "$artifacts" "$synthesis" "$reports" "$logs" "$metadata" "$manifests"
evidence="$run_root/phase5-yosys-cdc-synthesis-evidence.incomplete"
final_evidence="$run_root/phase5-yosys-cdc-synthesis-evidence.txt"
repository_start="$metadata/repository-inputs.start.sha256"
repository_end="$metadata/repository-inputs.end.sha256"
status_start="$metadata/repository-status.start"
status_end="$metadata/repository-status.end"
schemas_manifest="$metadata/yosys-schemas.sha256"
bundles_manifest="$metadata/synchronizer-bundles.sha256"
result_manifests="$metadata/synchronizer-result-manifests.sha256"
artifact_manifest="$run_root/artifacts.sha256"

lc_evidence_receipt_begin "$evidence" "$header" ||
  fail "could not create incomplete evidence receipt"
record() {
  lc_evidence_receipt_record "$evidence" "$@" ||
    fail "could not append evidence record: $1"
}
logged() {
  lcpcsg_log=$1
  lcpcsg_label=$2
  shift 2
  if lc_evidence_run_logged "$evidence" "$lcpcsg_log" "$lcpcsg_label" "$@"; then
    return 0
  else
    lcpcsg_status=$?
    tail -n 80 "$lcpcsg_log" >&2 || true
    fail "$lcpcsg_label failed with status $lcpcsg_status; incomplete evidence: $evidence"
  fi
}

mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}
export LUNACHIP_YOSYS_MOUNT_MODE=$mount_mode
for lcpcsg_command in moon jq git docker readlink realpath; do
  logged "$logs/preflight-$lcpcsg_command.log" "preflight-$lcpcsg_command" \
    require_command "$lcpcsg_command"
done
logged "$logs/preflight-sha256.log" preflight-sha256 require_sha256
logged "$logs/preflight-volume.log" preflight-volume require_volume "$mount_mode"
logged "$logs/docker-context.log" docker-context docker context show
logged "$logs/docker-daemon.log" docker-daemon docker info --format '{{json .}}'

docker_context=$(sed -n '1p' "$logs/docker-context.log")
[ "$(wc -l <"$logs/docker-context.log" | tr -d ' ')" -eq 1 ] &&
  lc_evidence_token "$docker_context" || fail "unsafe Docker context name"

logged "$logs/repository-snapshot-start.log" repository-snapshot-start \
  lc_evidence_snapshot_repository "$repo_dir" "$repository_start"
logged "$status_start" repository-status-start \
  git -C "$repo_dir" status --porcelain=v1 --untracked-files=all
logged "$logs/git-head.start.log" git-head-start git -C "$repo_dir" rev-parse HEAD
head=$(sed -n '1p' "$logs/git-head.start.log")

lock_sha=$(lc_evidence_sha256_file "$lock_file")
runner_sha=$(lc_evidence_sha256_file "$runner")
validator_sha=$(lc_evidence_sha256_file "$validator")
checker_sha=$(lc_evidence_sha256_file "$checker")
selftest_sha=$(lc_evidence_sha256_file "$selftest")
runner_selftest_sha=$(lc_evidence_sha256_file "$runner_selftest")
receipt_selftest_sha=$(lc_evidence_sha256_file "$receipt_selftest")
receipt_lib_sha=$(lc_evidence_sha256_file "$receipt_lib")
manifest_lib_sha=$(lc_evidence_sha256_file "$manifest_lib")
gate_sha=$(lc_evidence_sha256_file "$gate")
logged "$logs/schema-manifest.log" schema-manifest \
  lc_evidence_create_artifact_manifest "$repo_dir/toolchain/yosys" "$schemas_manifest"
schemas_sha=$(lc_evidence_sha256_file "$schemas_manifest")

logged "$logs/lock-validation.log" lock-validation "$validator"
logged "$logs/focused-selftest.log" focused-selftest "$selftest"
logged "$logs/runner-selftest.log" runner-selftest "$runner_selftest"

provider=$(jq -r '.provider.kind' "$lock_file")
platform=$(jq -r '.provider.platform' "$lock_file")
repository=$(jq -r '.provider.repository' "$lock_file")
manifest_digest=$(jq -r '.provider.manifest_digest' "$lock_file")
config_digest=$(jq -r '.provider.config_digest' "$lock_file")
image="$repository@$manifest_digest"
[ "$provider" = oci ] || fail "locked provider is not OCI"
for lcpcsg_token in "$platform" "$image" "$config_digest"; do
  lc_evidence_token "$lcpcsg_token" || fail "unsafe provider token"
done
logged "$logs/docker-image.log" docker-image docker image inspect "$image"
logged "$logs/docker-image-metadata.log" docker-image-metadata \
  verify_image_metadata "$logs/docker-image.log" "$image" \
  "$manifest_digest" "$config_digest" "$platform"
logged "$logs/provider-version.log" provider-version "$runner" oci version

record HEAD "$head"
record STATUS "start=$(lc_evidence_sha256_file "$status_start")"
record REPOSITORY "start=$(lc_evidence_sha256_file "$repository_start")" \
  "manifest=$(basename "$repository_start")"
record PIN "lock=$lock_sha" "runner=$runner_sha" "validator=$validator_sha" \
  "checker=$checker_sha" "focused-selftest=$selftest_sha" \
  "runner-selftest=$runner_selftest_sha" \
  "receipt-selftest=$receipt_selftest_sha" "receipt-lib=$receipt_lib_sha" \
  "manifest-lib=$manifest_lib_sha" "gate=$gate_sha" \
  "schemas-manifest=$schemas_sha"
record PROVENANCE provider=oci "platform=$platform" "image=$image" \
  "config=$config_digest" transport=volume "docker-context=$docker_context" \
  "docker-context-sha256=$(lc_evidence_sha256_file "$logs/docker-context.log")" \
  "docker-daemon-sha256=$(lc_evidence_sha256_file "$logs/docker-daemon.log")" \
  "docker-image-sha256=$(lc_evidence_sha256_file "$logs/docker-image.log")"
record CLAIM pre-map-structural-shape=true physical-placement=false \
  metastability=false mtbf=false timing-closure=false

logged "$logs/materialize.log" materialize moon -C "$repo_dir" run \
  --target native --release cmd/phase5-sync-fixtures -- matrix "$bundles"
observed_fixtures=$(
  find "$bundles" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | LC_ALL=C sort
)
expected_fixtures='bit-synchronizer-2-stage
bit-synchronizer-3-stage
bit-synchronizer-4-stage'
[ "$observed_fixtures" = "$expected_fixtures" ] || fail "fixture matrix drifted"
[ -z "$(find "$bundles" -mindepth 1 -maxdepth 1 ! -type d -print)" ] ||
  fail "fixture root contains a non-directory entry"
logged "$logs/bundles-manifest.log" bundles-manifest \
  lc_evidence_create_artifact_manifest "$bundles" "$bundles_manifest"
bundles_sha=$(lc_evidence_sha256_file "$bundles_manifest")
record BUNDLES "manifest=$bundles_sha" fixtures=3

fixture_count=0
check_count=0
for fixture in $expected_fixtures; do
  case "$fixture" in
    bit-synchronizer-2-stage) stages=2 ;;
    bit-synchronizer-3-stage) stages=3 ;;
    bit-synchronizer-4-stage) stages=4 ;;
    *) fail "unclassified fixture: $fixture" ;;
  esac
  bundle="$bundles/$fixture"
  output="$synthesis/$fixture"
  report_dir="$reports/$fixture"
  fixture_logs="$logs/$fixture"
  mkdir "$output" "$report_dir" "$fixture_logs"
  logged "$fixture_logs/inventory.log" "inventory-$fixture" \
    verify_bundle_inventory "$bundle" "$fixture" "$stages"
  logged "$fixture_logs/validate.log" "validate-$fixture" \
    "$validator" --job-json "$bundle/job.json" "$bundle"
  logged "$fixture_logs/synthesize.log" "synthesize-$fixture" \
    "$runner" oci synth "$bundle" "$output"
  logged "$fixture_logs/output-inventory.log" "output-inventory-$fixture" \
    verify_synthesis_inventory "$output"
  logged "$fixture_logs/transport.log" "transport-$fixture" \
    verify_transport "$output/transport-receipt.txt" "$image"
  report="$report_dir/cdc-synthesis.json"
  logged "$fixture_logs/check.log" "check-$fixture" "$checker" \
    "$bundle/expected-cdc-shape.json" "$output/pre-map.rtlil" "$report"
  logged "$fixture_logs/report.log" "report-$fixture" \
    verify_report "$fixture" "$stages" "$report"
  [ "$(find "$report_dir" -mindepth 1 -maxdepth 1 -type f \
    -exec basename {} \;)" = cdc-synthesis.json ] &&
    [ -z "$(find "$report_dir" -mindepth 1 -maxdepth 1 ! -type f -print)" ] ||
    fail "$fixture report inventory drifted"

  bundle_manifest="$manifests/$fixture.bundle.sha256"
  synthesis_manifest="$manifests/$fixture.synthesis.sha256"
  report_manifest="$manifests/$fixture.report.sha256"
  logged "$fixture_logs/manifest-bundle.log" "manifest-bundle-$fixture" \
    lc_evidence_create_artifact_manifest "$bundle" "$bundle_manifest"
  logged "$fixture_logs/manifest-synthesis.log" "manifest-synthesis-$fixture" \
    lc_evidence_create_artifact_manifest "$output" "$synthesis_manifest"
  logged "$fixture_logs/manifest-report.log" "manifest-report-$fixture" \
    lc_evidence_create_artifact_manifest "$report_dir" "$report_manifest"
  logged "$fixture_logs/verify-bundle.log" "verify-bundle-$fixture" \
    lc_evidence_verify_manifest "$bundle" "$bundle_manifest" artifacts
  logged "$fixture_logs/verify-synthesis.log" "verify-synthesis-$fixture" \
    lc_evidence_verify_manifest "$output" "$synthesis_manifest" artifacts
  logged "$fixture_logs/verify-report.log" "verify-report-$fixture" \
    lc_evidence_verify_manifest "$report_dir" "$report_manifest" artifacts
  record FIXTURE "$fixture" "stages=$stages" checks=9 \
    "dff-cells=$stages" shape=exact
  record RESULTS "$fixture" \
    "bundle-manifest=$(lc_evidence_sha256_file "$bundle_manifest")" \
    "synthesis-manifest=$(lc_evidence_sha256_file "$synthesis_manifest")" \
    "report-manifest=$(lc_evidence_sha256_file "$report_manifest")"
  fixture_count=$((fixture_count + 1))
  check_count=$((check_count + 9))
done
[ "$fixture_count" -eq 3 ] && [ "$check_count" -eq 27 ] ||
  fail "synthesis matrix count drifted"
logged "$logs/result-manifests.log" result-manifests \
  lc_evidence_create_artifact_manifest "$manifests" "$result_manifests"
result_manifests_sha=$(lc_evidence_sha256_file "$result_manifests")
record RESULTS "manifest=$result_manifests_sha" fixtures=3 reports=3

logged "$logs/repository-snapshot-end.log" repository-snapshot-end \
  lc_evidence_snapshot_repository "$repo_dir" "$repository_end"
logged "$status_end" repository-status-end \
  git -C "$repo_dir" status --porcelain=v1 --untracked-files=all
logged "$logs/git-head.end.log" git-head-end git -C "$repo_dir" rev-parse HEAD
end_head=$(sed -n '1p' "$logs/git-head.end.log")
[ "$end_head" = "$head" ] || fail "repository HEAD drifted"
cmp -s "$repository_start" "$repository_end" || fail "repository inputs drifted"
cmp -s "$status_start" "$status_end" || fail "repository status drifted"
[ "$(lc_evidence_sha256_file "$lock_file")" = "$lock_sha" ] || fail "lock changed"
[ "$(lc_evidence_sha256_file "$runner")" = "$runner_sha" ] || fail "runner changed"
[ "$(lc_evidence_sha256_file "$validator")" = "$validator_sha" ] || fail "validator changed"
[ "$(lc_evidence_sha256_file "$checker")" = "$checker_sha" ] || fail "checker changed"
[ "$(lc_evidence_sha256_file "$selftest")" = "$selftest_sha" ] || fail "selftest changed"
[ "$(lc_evidence_sha256_file "$runner_selftest")" = "$runner_selftest_sha" ] || fail "runner selftest changed"
[ "$(lc_evidence_sha256_file "$receipt_selftest")" = "$receipt_selftest_sha" ] || fail "receipt selftest changed"
[ "$(lc_evidence_sha256_file "$receipt_lib")" = "$receipt_lib_sha" ] || fail "receipt library changed"
[ "$(lc_evidence_sha256_file "$manifest_lib")" = "$manifest_lib_sha" ] || fail "manifest library changed"
[ "$(lc_evidence_sha256_file "$gate")" = "$gate_sha" ] || fail "gate changed"
[ "$(lc_evidence_sha256_file "$schemas_manifest")" = "$schemas_sha" ] ||
  fail "Yosys schema manifest changed"
[ "$(lc_evidence_sha256_file "$bundles_manifest")" = "$bundles_sha" ] ||
  fail "bundle manifest changed"
[ "$(lc_evidence_sha256_file "$result_manifests")" = "$result_manifests_sha" ] ||
  fail "result manifests changed"
lc_evidence_verify_manifest "$repo_dir/toolchain/yosys" "$schemas_manifest" artifacts ||
  fail "Yosys schema tree changed"
lc_evidence_verify_manifest "$bundles" "$bundles_manifest" artifacts ||
  fail "generated bundles changed"
lc_evidence_verify_manifest "$manifests" "$result_manifests" artifacts ||
  fail "result manifests changed"
for fixture in $expected_fixtures; do
  lc_evidence_verify_manifest "$synthesis/$fixture" \
    "$manifests/$fixture.synthesis.sha256" artifacts || fail "$fixture synthesis changed"
  lc_evidence_verify_manifest "$reports/$fixture" \
    "$manifests/$fixture.report.sha256" artifacts || fail "$fixture report changed"
done

record STATUS "end=$(lc_evidence_sha256_file "$status_end")" drift=none
record REPOSITORY "end=$(lc_evidence_sha256_file "$repository_end")" drift=none \
  "manifest=$(basename "$repository_end")"
record MATRIX fixtures=3 reports=3 checks=27 stage-counts=2,3,4
record RECHECK "head=$end_head" repository=unchanged bundles=unchanged \
  results=unchanged pins=unchanged transport=volume

if lc_evidence_create_artifact_manifest "$artifacts" "$artifact_manifest"; then
  record COMMAND artifact-manifest status=0
else
  artifact_status=$?
  record COMMAND artifact-manifest "status=$artifact_status"
  fail "complete artifact manifest failed"
fi
artifact_sha=$(lc_evidence_sha256_file "$artifact_manifest")
artifact_files=$(grep -c '^FILE ' "$artifact_manifest" | tr -d ' ')
record ARTIFACTS "manifest=$artifact_sha" "files=$artifact_files" complete=1
lc_evidence_receipt_seal \
  "$evidence" "$header" "$allowed_records" "$required_records" ||
  fail "could not seal incomplete evidence"
lc_evidence_receipt_publish_pass \
  "$evidence" "$final_evidence" "$header" "$allowed_records" \
  "$required_records" || fail "could not atomically publish passing evidence"

printf '%s\n' \
  'Phase 5 pinned-Yosys CDC synthesis gate passes: 3 fixtures, 27 checks' \
  "Evidence: $final_evidence" \
  "Evidence sha256:$(lc_evidence_sha256_file "$final_evidence")"
