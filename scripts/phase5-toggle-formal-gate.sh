#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"
. "$repo_dir/scripts/formal-typed-artifact-lib.sh"

runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
artifact_cli="$repo_dir/scripts/formal-artifact-cli.sh"
registry_selftest="$repo_dir/scripts/formal-bundle-selftest.sh"
toggle_selftest="$repo_dir/scripts/phase5-toggle-formal-selftest.sh"
runner_selftest="$repo_dir/scripts/phase4-yosys-selftest.sh"
receipt_selftest="$repo_dir/scripts/evidence-receipt-selftest.sh"
typed_artifact_selftest="$repo_dir/scripts/formal-typed-artifact-selftest.sh"
receipt_lib="$repo_dir/scripts/evidence-receipt-lib.sh"
manifest_lib="$repo_dir/scripts/evidence-manifest-lib.sh"
typed_artifact_lib="$repo_dir/scripts/formal-typed-artifact-lib.sh"
shard_lib="$repo_dir/scripts/async-fifo-formal-shard-lib.sh"
footprint_lib="$repo_dir/scripts/async-fifo-formal-footprint-lib.sh"
lock="$repo_dir/toolchain/yosys/lock.json"
gate="$repo_dir/scripts/phase5-toggle-formal-gate.sh"
mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}
export LUNACHIP_YOSYS_MOUNT_MODE=$mount_mode

header='LUNACHIP-PHASE5-TOGGLE-FORMAL-EVIDENCE 1'
allowed_records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,TIMING,RESET,CLAIM,BUNDLES,COUNTEREXAMPLE,RESULTS,MATRIX,RECHECK,ARTIFACTS'
required_records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,TIMING,RESET,CLAIM,BUNDLES,COUNTEREXAMPLE,RESULTS,MATRIX,RECHECK,ARTIFACTS'

fail() {
  echo "phase5-toggle-formal-gate: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1
}

require_sha256() {
  command -v shasum >/dev/null 2>&1 ||
    command -v sha256sum >/dev/null 2>&1
}

require_volume() {
  case "$1" in
    volume) return 0 ;;
    *)
      printf '%s\n' \
        'LUNACHIP_YOSYS_MOUNT_MODE must be volume for this gate' >&2
      return 1
      ;;
  esac
}

[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d /tmp/lunachip-phase5-toggle-formal.XXXXXX)
else
  requested=$1
  [ -n "$requested" ] || fail "run root must not be empty"
  [ ! -L "$requested" ] || fail "run root must not be a symbolic link"
  if [ -e "$requested" ]; then
    [ -d "$requested" ] || fail "run root is not a directory"
    if find "$requested" -mindepth 1 -print | grep -q .; then
      fail "explicit run root must be empty"
    fi
    run_root=$(CDPATH= cd -- "$requested" && pwd -P)
  else
    parent=$(dirname -- "$requested")
    name=$(basename -- "$requested")
    [ -d "$parent" ] || fail "run-root parent does not exist"
    [ ! -L "$parent" ] || fail "run-root parent must not be symbolic"
    parent=$(CDPATH= cd -- "$parent" && pwd -P)
    run_root="$parent/$name"
    [ "$run_root" != / ] || fail "refusing filesystem root"
    mkdir "$run_root"
  fi
fi
case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac

artifacts="$run_root/artifacts"
bundles="$artifacts/bundles"
results="$artifacts/results"
logs="$artifacts/logs"
metadata="$artifacts/metadata"
mkdir "$artifacts" "$results" "$logs" "$metadata"
evidence="$run_root/phase5-toggle-formal-evidence.incomplete"
final_evidence="$run_root/phase5-toggle-formal-evidence.txt"
repository_start="$metadata/repository-inputs.start.sha256"
repository_end="$metadata/repository-inputs.end.sha256"
status_start="$metadata/repository-status.start"
status_end="$metadata/repository-status.end"
schemas_manifest="$metadata/yosys-schemas.sha256"
bundles_manifest="$metadata/formal-bundles.sha256"
artifact_manifest="$run_root/artifacts.sha256"

# Retain incomplete evidence before every executable preflight. A failing
# logged command records its exact status and cannot publish a pass receipt.
lc_evidence_receipt_begin "$evidence" "$header" ||
  fail "could not create incomplete evidence receipt"

record() {
  lc_evidence_receipt_record "$evidence" "$@" ||
    fail "could not append evidence record: $1"
}

logged() {
  log=$1
  label=$2
  shift 2
  if lc_evidence_run_logged "$evidence" "$log" "$label" "$@"; then
    return 0
  else
    status=$?
    tail -n 80 "$log" >&2 || true
    fail "$label failed with status $status; log retained at $log"
  fi
}

logged "$logs/preflight-moon.log" preflight-moon require_command moon
logged "$logs/preflight-jq.log" preflight-jq require_command jq
logged "$logs/preflight-git.log" preflight-git require_command git
logged "$logs/preflight-docker.log" preflight-docker require_command docker
logged "$logs/preflight-sha256.log" preflight-sha256 require_sha256
logged "$logs/preflight-readlink.log" preflight-readlink require_command readlink
logged "$logs/preflight-realpath.log" preflight-realpath require_command realpath
logged "$logs/preflight-volume.log" preflight-volume require_volume "$mount_mode"
logged "$logs/docker-context.log" docker-context docker context show
logged "$logs/docker-daemon.log" docker-daemon docker info

docker_context=$(sed -n '1p' "$logs/docker-context.log")
[ "$(wc -l <"$logs/docker-context.log" | tr -d ' ')" -eq 1 ] &&
  lc_evidence_token "$docker_context" || fail "unsafe Docker context name"

cd "$repo_dir"
head=$(git rev-parse HEAD)
git status --porcelain=v1 --untracked-files=all >"$status_start"
lc_evidence_snapshot_repository "$repo_dir" "$repository_start" ||
  fail "could not create start repository snapshot"

inputs_sha=$(lc_evidence_sha256_file "$repository_start")
status_start_sha=$(lc_evidence_sha256_file "$status_start")
lock_sha=$(lc_evidence_sha256_file "$lock")
runner_sha=$(lc_evidence_sha256_file "$runner")
validator_sha=$(lc_evidence_sha256_file "$validator")
cli_sha=$(lc_evidence_sha256_file "$artifact_cli")
registry_sha=$(lc_evidence_sha256_file "$registry_selftest")
toggle_selftest_sha=$(lc_evidence_sha256_file "$toggle_selftest")
runner_selftest_sha=$(lc_evidence_sha256_file "$runner_selftest")
receipt_selftest_sha=$(lc_evidence_sha256_file "$receipt_selftest")
typed_selftest_sha=$(lc_evidence_sha256_file "$typed_artifact_selftest")
receipt_lib_sha=$(lc_evidence_sha256_file "$receipt_lib")
manifest_lib_sha=$(lc_evidence_sha256_file "$manifest_lib")
typed_lib_sha=$(lc_evidence_sha256_file "$typed_artifact_lib")
shard_lib_sha=$(lc_evidence_sha256_file "$shard_lib")
footprint_lib_sha=$(lc_evidence_sha256_file "$footprint_lib")
gate_sha=$(lc_evidence_sha256_file "$gate")
lc_evidence_create_artifact_manifest \
  "$repo_dir/toolchain/yosys" "$schemas_manifest" ||
  fail "could not create pinned Yosys schema manifest"
schemas_sha=$(lc_evidence_sha256_file "$schemas_manifest")

provider=$(jq -r '.provider.kind' "$lock")
platform=$(jq -r '.provider.platform' "$lock")
image=$(jq -r '.provider.repository + "@" + .provider.manifest_digest' "$lock")
config=$(jq -r '.provider.config_digest' "$lock")
[ "$provider" = oci ] || fail "locked provider is not OCI"
for token in "$platform" "$image" "$config"; do
  lc_evidence_token "$token" || fail "unsafe provider provenance token"
done
context_sha=$(lc_evidence_sha256_file "$logs/docker-context.log")
daemon_sha=$(lc_evidence_sha256_file "$logs/docker-daemon.log")

record HEAD "$head"
record STATUS "start=$status_start_sha"
record REPOSITORY "start=$inputs_sha" \
  "manifest=$(basename "$repository_start")"
record PIN "lock=$lock_sha" "runner=$runner_sha" \
  "validator=$validator_sha" "artifact-cli=$cli_sha" \
  "registry-selftest=$registry_sha" \
  "toggle-selftest=$toggle_selftest_sha" \
  "runner-selftest=$runner_selftest_sha" \
  "receipt-selftest=$receipt_selftest_sha" \
  "typed-artifact-selftest=$typed_selftest_sha" \
  "receipt-lib=$receipt_lib_sha" "manifest-lib=$manifest_lib_sha" \
  "typed-artifact-lib=$typed_lib_sha" "shard-lib=$shard_lib_sha" \
  "footprint-lib=$footprint_lib_sha" "gate=$gate_sha" \
  "schemas-manifest=$schemas_sha"
record PROVENANCE "provider=$provider" "platform=$platform" \
  "image=$image" "config=$config" "transport=$mount_mode" \
  "docker-context=$docker_context" "docker-context-sha256=$context_sha" \
  "docker-daemon-sha256=$daemon_sha"
record TIMING global-steps=2 max-idle=3 eventual-ready=3 \
  coincidence=atomic-global-pre-state
record RESET coordinated-idle-initialization unilateral-recovery=false
record CLAIM digital-two-state-bounded metastability=false mtbf=false \
  placement=false timing=false

logged "$logs/lock.log" lock "$validator"
logged "$logs/registry.log" registry "$registry_selftest"
logged "$logs/selftest.log" toggle-selftest "$toggle_selftest"
logged "$logs/runner.log" runner-selftest "$runner_selftest"
logged "$logs/version.log" provider-version "$runner" oci version
logged "$logs/materialize.log" materialize moon run --target native \
  --release cmd/phase4-formal -- generate-toggle-handshakes "$bundles"

lc_evidence_create_artifact_manifest "$bundles" "$bundles_manifest" ||
  fail "could not create formal bundle manifest"
bundles_sha=$(lc_evidence_sha256_file "$bundles_manifest")
record BUNDLES "manifest=$bundles_sha" fixtures=9

expected_fixtures='broken-toggle-backpressure
broken-toggle-capacity
broken-toggle-completion
broken-toggle-data-integrity
broken-toggle-duplicate
broken-toggle-source-payload
valid-toggle-record-3
valid-toggle-record-4
valid-toggle-scalar-2'
observed_fixtures=$(
  find "$bundles" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | LC_ALL=C sort
)
[ "$observed_fixtures" = "$expected_fixtures" ] ||
  fail "formal fixture matrix is not exact"
expected_tasks='broken-toggle-backpressure-bmc
broken-toggle-capacity-bmc
broken-toggle-completion-bmc
broken-toggle-data-integrity-bmc
broken-toggle-duplicate-bmc
broken-toggle-source-payload-bmc
valid-toggle-record-3-bmc
valid-toggle-record-3-cover-coincident
valid-toggle-record-3-cover-consume-refill
valid-toggle-record-3-cover-watched
valid-toggle-record-4-bmc
valid-toggle-scalar-2-bmc'
observed_tasks=$(
  for fixture in $expected_fixtures; do
    jq -r '.formal_tasks[].name' "$bundles/$fixture/job.json"
  done | LC_ALL=C sort
)
[ "$observed_tasks" = "$expected_tasks" ] ||
  fail "formal task matrix is not exact"

tasks=0
passes=0
counters=0
witnesses=0
for fixture in $expected_fixtures; do
  bundle="$bundles/$fixture"
  mkdir "$results/$fixture" "$logs/$fixture"
  logged "$logs/$fixture/validate.log" "validate-$fixture" \
    "$validator" --job-json "$bundle/job.json" "$bundle"
  for task in $(jq -r '.formal_tasks[].name' "$bundle/job.json"); do
    lc_evidence_token "$task" || fail "unsafe task name: $task"
    output="$results/$fixture/$task"
    mkdir "$output"
    logged "$logs/$fixture/$task.log" "$task" \
      "$runner" oci formal "$task" "$bundle" "$output"
    result="$output/result.lcfr"
    [ -s "$result" ] && [ -s "$output/receipt.lcfe" ] ||
      fail "$task omitted typed artifacts"
    logged "$logs/$fixture/verify-$task.log" "typed-$task" \
      lc_formal_verify_typed_artifacts \
      "$artifact_cli" "$bundle" "$task" "$output"
    if grep -E '^RESULT (inconclusive|tool-error)$' "$result" >/dev/null; then
      fail "$task produced a non-gating result"
    fi
    case "$task" in
      valid-toggle-*-bmc)
        [ "$task" = "$fixture-bmc" ] || fail "$task fixture mismatch"
        grep -Fx 'RESULT bounded-pass' "$result" >/dev/null ||
          fail "$task did not produce its bounded safety pass"
        passes=$((passes + 1))
        ;;
      valid-toggle-record-3-cover-coincident|\
      valid-toggle-record-3-cover-consume-refill|\
      valid-toggle-record-3-cover-watched)
        [ "$fixture" = valid-toggle-record-3 ] ||
          fail "$task fixture mismatch"
        grep -Fx 'RESULT cover-witness' "$result" >/dev/null ||
          fail "$task did not produce its cover witness"
        [ "$(grep -Ec '^WITNESS artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$result")" -eq 1 ] ||
          fail "$task did not retain exactly one typed cover artifact"
        witnesses=$((witnesses + 1))
        ;;
      broken-toggle-*-bmc)
        [ "$task" = "$fixture-bmc" ] || fail "$task fixture mismatch"
        grep -Fx 'RESULT counterexample' "$result" >/dev/null ||
          fail "$task did not produce its isolated counterexample"
        [ "$(grep -Ec '^COUNTEREXAMPLE artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$result")" -eq 1 ] ||
          fail "$task did not retain exactly one counterexample artifact"
        expected=$(awk '$1 == "EXPECTED-FAILURE" { print $2 }' \
          "$bundle/$task.lcfg")
        case "$fixture" in
          broken-toggle-backpressure)
            fixed=lc_p9_b64657374696e6174696f6e5f726573706f6e73655f737461626c655f756e6465725f6261636b7072657373757265
            ;;
          broken-toggle-capacity)
            fixed=lc_p7_b6f6e655f6974656d5f696e5f666c696768745f6361706163697479
            ;;
          broken-toggle-completion)
            fixed=lc_p12_b776174636865645f7472616e73616374696f6e5f636f6d706c657465735f756e6465725f626f756e6465645f636c6f636b735f616e645f6576656e7475616c5f7265616479
            ;;
          broken-toggle-data-integrity)
            fixed=lc_p11_b776174636865645f7472616e73616374696f6e5f646174615f696e74656772697479
            ;;
          broken-toggle-duplicate)
            fixed=lc_p10_b6e6f5f6475706c69636174655f61636b6e6f776c656467655f6f725f636f6e73756d65
            ;;
          broken-toggle-source-payload)
            fixed=lc_p8_b736f757263655f7061796c6f61645f737461626c655f7768696c655f6f75747374616e64696e67
            ;;
          *) fail "$task has no fixed label mapping" ;;
        esac
        [ "$expected" = "$fixed" ] ||
          fail "$task label does not match fixed fixture mapping"
        record COUNTEREXAMPLE "$task" "label=$expected" exact=1
        counters=$((counters + 1))
        ;;
      *) fail "unclassified toggle formal task: $task" ;;
    esac
    tasks=$((tasks + 1))
  done
done
[ "$tasks" -eq 12 ] || fail "formal task matrix changed to $tasks"
[ "$passes" -eq 3 ] || fail "bounded-pass matrix changed to $passes"
[ "$witnesses" -eq 3 ] || fail "cover matrix changed to $witnesses"
[ "$counters" -eq 6 ] || fail "counterexample matrix changed to $counters"

git status --porcelain=v1 --untracked-files=all >"$status_end"
lc_evidence_snapshot_repository "$repo_dir" "$repository_end" ||
  fail "could not create end repository snapshot"
end_head=$(git rev-parse HEAD)
status_end_sha=$(lc_evidence_sha256_file "$status_end")
inputs_end_sha=$(lc_evidence_sha256_file "$repository_end")
[ "$end_head" = "$head" ] || fail "git HEAD changed during gate"
cmp -s "$repository_start" "$repository_end" ||
  fail "repository inputs changed during gate"
cmp -s "$status_start" "$status_end" || fail "git status changed during gate"
[ "$(lc_evidence_sha256_file "$lock")" = "$lock_sha" ] || fail "lock changed"
[ "$(lc_evidence_sha256_file "$runner")" = "$runner_sha" ] || fail "runner changed"
[ "$(lc_evidence_sha256_file "$validator")" = "$validator_sha" ] || fail "validator changed"
[ "$(lc_evidence_sha256_file "$artifact_cli")" = "$cli_sha" ] || fail "artifact CLI changed"
[ "$(lc_evidence_sha256_file "$registry_selftest")" = "$registry_sha" ] || fail "registry selftest changed"
[ "$(lc_evidence_sha256_file "$toggle_selftest")" = "$toggle_selftest_sha" ] || fail "toggle selftest changed"
[ "$(lc_evidence_sha256_file "$runner_selftest")" = "$runner_selftest_sha" ] || fail "runner selftest changed"
[ "$(lc_evidence_sha256_file "$receipt_selftest")" = "$receipt_selftest_sha" ] || fail "receipt selftest changed"
[ "$(lc_evidence_sha256_file "$typed_artifact_selftest")" = "$typed_selftest_sha" ] || fail "typed-artifact selftest changed"
[ "$(lc_evidence_sha256_file "$receipt_lib")" = "$receipt_lib_sha" ] || fail "receipt library changed"
[ "$(lc_evidence_sha256_file "$manifest_lib")" = "$manifest_lib_sha" ] || fail "manifest library changed"
[ "$(lc_evidence_sha256_file "$typed_artifact_lib")" = "$typed_lib_sha" ] || fail "typed-artifact library changed"
[ "$(lc_evidence_sha256_file "$shard_lib")" = "$shard_lib_sha" ] || fail "shard library changed"
[ "$(lc_evidence_sha256_file "$footprint_lib")" = "$footprint_lib_sha" ] || fail "footprint library changed"
[ "$(lc_evidence_sha256_file "$gate")" = "$gate_sha" ] || fail "gate changed"
lc_evidence_verify_manifest "$repo_dir/toolchain/yosys" \
  "$schemas_manifest" artifacts || fail "Yosys schemas changed"
lc_evidence_verify_manifest "$bundles" "$bundles_manifest" artifacts ||
  fail "formal bundles changed"

record STATUS "end=$status_end_sha" drift=none
record REPOSITORY "end=$inputs_end_sha" drift=none \
  "manifest=$(basename "$repository_end")"
record RESULTS typed-results=12 typed-receipts=12
record MATRIX fixtures=9 tasks=12 passes=3 covers=3 counterexamples=6
record RECHECK "head=$end_head" repository=unchanged bundles=unchanged \
  pins=unchanged

# Cover every bundle, command log, typed result, transport receipt, witness,
# counterexample, and metadata file. The manifest stays outside its tree.
lc_evidence_create_artifact_manifest "$artifacts" "$artifact_manifest" ||
  fail "could not create complete artifact manifest"
artifact_sha=$(lc_evidence_sha256_file "$artifact_manifest")
artifact_files=$(grep -c '^FILE ' "$artifact_manifest" | tr -d ' ')
record ARTIFACTS "manifest=$artifact_sha" "files=$artifact_files" complete=1

lc_evidence_receipt_seal \
  "$evidence" "$header" "$allowed_records" "$required_records" ||
  fail "could not seal incomplete evidence"
lc_evidence_receipt_publish_pass \
  "$evidence" "$final_evidence" "$header" \
  "$allowed_records" "$required_records" ||
  fail "could not atomically publish passing evidence"

printf '%s\n' \
  "Phase 5 toggle formal gate passes: 9 fixtures, 12 tasks" \
  "Evidence: $final_evidence" \
  "Evidence sha256:$(lc_evidence_sha256_file "$final_evidence")"
