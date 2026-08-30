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
report_checker="$repo_dir/scripts/phase5-async-fifo-synthesis-report-check.sh"
focused_selftest="$repo_dir/scripts/phase5-async-fifo-synthesis-selftest.sh"
receipt_lib="$repo_dir/scripts/evidence-receipt-lib.sh"
manifest_lib="$repo_dir/scripts/evidence-manifest-lib.sh"
lock_file="$repo_dir/toolchain/yosys/lock.json"
schema="$repo_dir/toolchain/yosys/async-fifo-synthesis-evidence.schema.json"
gate="$repo_dir/scripts/phase5-async-fifo-synthesis-gate.sh"
header='LUNACHIP-PHASE5-ASYNC-FIFO-SYNTHESIS-EVIDENCE 1'
allowed_records='HEAD,STATUS_START,INPUTS_START,CONTEXT,DAEMON,PROVIDER,TRANSPORT,PIN,COMMAND,FIXTURE,INPUTS_END,STATUS_END,MATRIX,CLAIM,RECHECK,ARTIFACT_MANIFEST'
required_records=$allowed_records

fail() {
  printf '%s\n' "phase5-async-fifo-synthesis-gate: $*" >&2
  exit 1
}

[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d /tmp/lunachip-phase5-async-fifo-synthesis.XXXXXX)
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
    [ -d "$requested_parent" ] || fail "run-root parent does not exist"
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
evidence_outputs="$artifacts/evidence"
manifests="$artifacts/manifests"
logs="$artifacts/logs"
metadata="$artifacts/metadata"
evidence="$run_root/phase5-async-fifo-synthesis-evidence.incomplete"
final_evidence="$run_root/phase5-async-fifo-synthesis-evidence.txt"
artifact_manifest="$run_root/artifacts.sha256"
inputs_start="$metadata/repository-inputs.start.sha256"
inputs_end="$metadata/repository-inputs.end.sha256"
status_start="$metadata/repository-status.start"
status_end="$metadata/repository-status.end"
mkdir "$artifacts" "$synthesis" "$evidence_outputs" "$manifests" \
  "$logs" "$metadata"
lc_evidence_receipt_begin "$evidence" "$header" ||
  fail "could not create incomplete evidence receipt"

record() {
  lc_evidence_receipt_record "$evidence" "$@" ||
    fail "could not append evidence record"
}

logged() {
  lcp5s_log=$1
  lcp5s_label=$2
  shift 2
  if lc_evidence_run_logged "$evidence" "$lcp5s_log" "$lcp5s_label" "$@"; then
    return 0
  else
    lcp5s_status=$?
    tail -n 80 "$lcp5s_log" >&2 || true
    fail "$lcp5s_label failed status $lcp5s_status; incomplete evidence: $evidence"
  fi
}

require_command() { command -v "$1"; }
require_sha256() {
  command -v shasum >/dev/null 2>&1 ||
    command -v sha256sum >/dev/null 2>&1
}
require_volume() {
  [ "$1" = volume ] || {
    printf '%s\n' "locked synthesis requires volume transport, observed $1" >&2
    return 1
  }
}

verify_image_metadata() {
  lcp5s_inspect=$1
  lcp5s_expected_image=$2
  lcp5s_expected_manifest=$3
  lcp5s_expected_platform=$4
  jq -e --arg image "$lcp5s_expected_image" \
    --arg manifest "$lcp5s_expected_manifest" \
    --arg platform "$lcp5s_expected_platform" '
      length == 1 and
      .[0].Id == $manifest and
      .[0].Descriptor.digest == $manifest and
      (.[0].RepoDigests | index($image)) != null and
      (.[0].Os + "/" + .[0].Architecture) == $platform
    ' "$lcp5s_inspect" >/dev/null
}

verify_transport() {
  lcp5s_transport=$1
  lcp5s_image=$2
  [ -f "$lcp5s_transport" ] && [ ! -L "$lcp5s_transport" ] || return 1
  grep -Fx 'MODE volume' "$lcp5s_transport" >/dev/null &&
    grep -Fx "OCI-IMAGE $lcp5s_image" "$lcp5s_transport" >/dev/null &&
    grep -Fx 'PERMISSION-INITIALIZER pinned-image-python-os-chmod-v1' \
      "$lcp5s_transport" >/dev/null
}

mount_mode=$(printenv LUNACHIP_YOSYS_MOUNT_MODE || true)
[ -n "$mount_mode" ] || mount_mode=volume
LUNACHIP_YOSYS_MOUNT_MODE=$mount_mode
export LUNACHIP_YOSYS_MOUNT_MODE

for lcp5s_command in moon jq git docker readlink realpath; do
  logged "$logs/preflight-$lcp5s_command.log" "preflight-$lcp5s_command" \
    require_command "$lcp5s_command"
done
logged "$logs/preflight-sha256.log" preflight-sha256 require_sha256
logged "$logs/preflight-volume.log" preflight-volume require_volume "$mount_mode"
logged "$logs/repository-snapshot-start.log" repository-snapshot-start \
  lc_evidence_snapshot_repository "$repo_dir" "$inputs_start"
logged "$status_start" repository-status-start \
  git -C "$repo_dir" status --porcelain=v1 --untracked-files=all
logged "$logs/git-head.start.log" git-head-start git -C "$repo_dir" rev-parse HEAD
logged "$logs/docker-context.log" docker-context docker context show
logged "$logs/docker-daemon.log" docker-daemon docker info --format '{{json .}}'
logged "$logs/lock-validation.log" lock-validation "$validator"
logged "$logs/focused-selftest.log" focused-selftest "$focused_selftest"

git_head=$(sed -n '1p' "$logs/git-head.start.log")
inputs_start_sha=$(lc_evidence_sha256_file "$inputs_start")
status_start_sha=$(lc_evidence_sha256_file "$status_start")
context_sha=$(lc_evidence_sha256_file "$logs/docker-context.log")
daemon_sha=$(lc_evidence_sha256_file "$logs/docker-daemon.log")
provider=$(jq -r '.provider.kind' "$lock_file")
platform=$(jq -r '.provider.platform' "$lock_file")
repository=$(jq -r '.provider.repository' "$lock_file")
manifest_digest=$(jq -r '.provider.manifest_digest' "$lock_file")
config_digest=$(jq -r '.provider.config_digest' "$lock_file")
image="$repository@$manifest_digest"
[ "$provider" = oci ] || fail "locked provider is not OCI"
logged "$logs/docker-image.log" docker-image docker image inspect "$image"
logged "$logs/docker-image-metadata.log" docker-image-metadata \
  verify_image_metadata "$logs/docker-image.log" "$image" \
  "$manifest_digest" "$platform"
image_sha=$(lc_evidence_sha256_file "$logs/docker-image.log")

record HEAD "$git_head"
record STATUS_START "sha256=$status_start_sha" path=artifacts/metadata/repository-status.start
record INPUTS_START "sha256=$inputs_start_sha" path=artifacts/metadata/repository-inputs.start.sha256
record CONTEXT provider=docker artifact=artifacts/logs/docker-context.log "sha256=$context_sha"
record DAEMON provider=docker artifact=artifacts/logs/docker-daemon.log "sha256=$daemon_sha"
record PROVIDER kind=oci "platform=$platform" "image=$image" \
  "config=$config_digest" "inspect-sha256=$image_sha"
record TRANSPORT workspace=volume runtime=host-uid-gid network=none \
  permission-initializer=pinned-image-python-os-chmod-v1
record PIN \
  "lock=$(lc_evidence_sha256_file "$lock_file")" \
  "schema=$(lc_evidence_sha256_file "$schema")" \
  "runner=$(lc_evidence_sha256_file "$runner")" \
  "validator=$(lc_evidence_sha256_file "$validator")" \
  "report-checker=$(lc_evidence_sha256_file "$report_checker")" \
  "focused-selftest=$(lc_evidence_sha256_file "$focused_selftest")" \
  "receipt-lib=$(lc_evidence_sha256_file "$receipt_lib")" \
  "manifest-lib=$(lc_evidence_sha256_file "$manifest_lib")" \
  "gate=$(lc_evidence_sha256_file "$gate")"

logged "$logs/materialize.log" materialize moon -C "$repo_dir" run \
  --target native --release cmd/phase5-async-fifo-synthesis-fixtures -- \
  matrix "$bundles"
observed_fixtures=$(
  find "$bundles" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; |
    LC_ALL=C sort
)
expected_fixtures='async-fifo-aggregate-depth4-stages3
async-fifo-scalar-depth4-stages2
async-fifo-scalar-depth8-stages4'
[ "$observed_fixtures" = "$expected_fixtures" ] || fail "fixture matrix drift"

fixture_count=0
for fixture in $observed_fixtures; do
  case "$fixture" in
    async-fifo-scalar-depth4-stages2) sequential_bits=26; memory_bits=52 ;;
    async-fifo-aggregate-depth4-stages3) sequential_bits=32; memory_bits=64 ;;
    async-fifo-scalar-depth8-stages4) sequential_bits=50; memory_bits=104 ;;
    *) fail "unclassified fixture: $fixture" ;;
  esac
  bundle="$bundles/$fixture"
  output="$synthesis/$fixture"
  report_dir="$evidence_outputs/$fixture"
  fixture_logs="$logs/$fixture"
  mkdir "$output" "$fixture_logs"
  logged "$fixture_logs/validate.log" "validate-$fixture" \
    "$validator" --job-json "$bundle/job.json" "$bundle"
  logged "$fixture_logs/synthesize.log" "synthesize-$fixture" \
    "$runner" oci synth "$bundle" "$output"
  logged "$fixture_logs/transport.log" "transport-$fixture" \
    verify_transport "$output/transport-receipt.txt" "$image"
  logged "$fixture_logs/check.log" "check-$fixture" \
    moon -C "$repo_dir" run --target native --release \
    cmd/phase5-async-fifo-synthesis-check -- check \
    "$bundle/async-fifo-role-inventory.json" "$output/pre-map.json" \
    "$output/pre-map.rtlil" "$lock_file" "$report_dir"
  report="$report_dir/async-fifo-synthesis-evidence.json"
  logged "$fixture_logs/report.log" "report-$fixture" "$report_checker" \
    "$fixture" "$report" "$bundle/async-fifo-role-inventory.json" \
    "$output/pre-map.json" "$output/pre-map.rtlil" "$lock_file" \
    "$sequential_bits" "$memory_bits"

  bundle_manifest="$manifests/$fixture.bundle.sha256"
  synthesis_manifest="$manifests/$fixture.synthesis.sha256"
  report_manifest="$manifests/$fixture.evidence.sha256"
  logged "$fixture_logs/manifest-bundle.log" "manifest-bundle-$fixture" \
    lc_evidence_create_artifact_manifest "$bundle" "$bundle_manifest"
  logged "$fixture_logs/manifest-synthesis.log" "manifest-synthesis-$fixture" \
    lc_evidence_create_artifact_manifest "$output" "$synthesis_manifest"
  logged "$fixture_logs/manifest-evidence.log" "manifest-evidence-$fixture" \
    lc_evidence_create_artifact_manifest "$report_dir" "$report_manifest"
  logged "$fixture_logs/verify-bundle.log" "verify-bundle-$fixture" \
    lc_evidence_verify_manifest "$bundle" "$bundle_manifest" artifacts
  logged "$fixture_logs/verify-synthesis.log" "verify-synthesis-$fixture" \
    lc_evidence_verify_manifest "$output" "$synthesis_manifest" artifacts
  logged "$fixture_logs/verify-evidence.log" "verify-evidence-$fixture" \
    lc_evidence_verify_manifest "$report_dir" "$report_manifest" artifacts
  record FIXTURE "$fixture" "sequential-bits=$sequential_bits" \
    "memory-bits=$memory_bits" \
    "bundle-manifest=$(lc_evidence_sha256_file "$bundle_manifest")" \
    "synthesis-manifest=$(lc_evidence_sha256_file "$synthesis_manifest")" \
    "evidence-manifest=$(lc_evidence_sha256_file "$report_manifest")"
  fixture_count=$((fixture_count + 1))
done
[ "$fixture_count" -eq 3 ] || fail "fixture count drifted"

logged "$logs/repository-snapshot-end.log" repository-snapshot-end \
  lc_evidence_snapshot_repository "$repo_dir" "$inputs_end"
logged "$status_end" repository-status-end \
  git -C "$repo_dir" status --porcelain=v1 --untracked-files=all
logged "$logs/git-head.end.log" git-head-end git -C "$repo_dir" rev-parse HEAD
final_head=$(sed -n '1p' "$logs/git-head.end.log")
inputs_end_sha=$(lc_evidence_sha256_file "$inputs_end")
status_end_sha=$(lc_evidence_sha256_file "$status_end")
[ "$final_head" = "$git_head" ] || fail "repository HEAD drift"
cmp -s "$inputs_start" "$inputs_end" || fail "repository input drift"
cmp -s "$status_start" "$status_end" || fail "repository status drift"

record INPUTS_END "sha256=$inputs_end_sha" drift=none path=artifacts/metadata/repository-inputs.end.sha256
record STATUS_END "sha256=$status_end_sha" drift=none path=artifacts/metadata/repository-status.end
record MATRIX fixtures=3 checks-per-fixture=25 \
  sequential-bits=26,32,50 memory-bits=52,64,104
record CLAIM pre-map-typed-graph=true two-state-role-equivalence=true \
  owned-state-exact=true memory-topology=true ram-mapping=false timing=false \
  physical-cdc=false metastability=false four-state-equivalence=false
record RECHECK "git-head=$final_head" repository-drift=none \
  transport=volume outputs=independently-bound

if lc_evidence_create_artifact_manifest "$artifacts" "$artifact_manifest"; then
  record COMMAND artifact-manifest status=0
else
  artifact_status=$?
  record COMMAND artifact-manifest "status=$artifact_status"
  fail "complete artifact manifest failed"
fi
artifact_sha=$(lc_evidence_sha256_file "$artifact_manifest")
artifact_files=$(grep -c '^FILE ' "$artifact_manifest" | tr -d ' ')
record ARTIFACT_MANIFEST "sha256=$artifact_sha" path=artifacts.sha256 \
  "files=$artifact_files" complete=1
lc_evidence_receipt_seal \
  "$evidence" "$header" "$allowed_records" "$required_records" ||
  fail "could not seal incomplete evidence"
lc_evidence_receipt_publish_pass \
  "$evidence" "$final_evidence" "$header" "$allowed_records" \
  "$required_records" || fail "could not atomically publish pass evidence"

printf '%s\n' \
  "Phase 5 async-FIFO pinned synthesis gate passes: 3 fixtures, 25 checks each" \
  "Evidence: $final_evidence" \
  "Evidence sha256:$(lc_evidence_sha256_file "$final_evidence")"
