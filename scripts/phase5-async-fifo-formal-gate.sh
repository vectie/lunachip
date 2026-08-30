#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"
. "$repo_dir/scripts/async-fifo-formal-shard-lib.sh"
. "$repo_dir/scripts/formal-typed-artifact-lib.sh"

runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
artifact_cli="$repo_dir/scripts/formal-artifact-cli.sh"
registry_selftest="$repo_dir/scripts/formal-bundle-selftest.sh"
async_selftest="$repo_dir/scripts/phase5-async-fifo-formal-selftest.sh"
shard_selftest="$repo_dir/scripts/async-fifo-formal-shard-selftest.sh"
runner_selftest="$repo_dir/scripts/phase4-yosys-selftest.sh"
lock="$repo_dir/toolchain/yosys/lock.json"
receipt_lib="$repo_dir/scripts/evidence-receipt-lib.sh"
manifest_lib="$repo_dir/scripts/evidence-manifest-lib.sh"
typed_artifact_lib="$repo_dir/scripts/formal-typed-artifact-lib.sh"
typed_artifact_selftest="$repo_dir/scripts/formal-typed-artifact-selftest.sh"
shard_lib="$repo_dir/scripts/async-fifo-formal-shard-lib.sh"
footprint_lib="$repo_dir/scripts/async-fifo-formal-footprint-lib.sh"
gate="$repo_dir/scripts/phase5-async-fifo-formal-gate.sh"
mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}
export LUNACHIP_YOSYS_MOUNT_MODE=$mount_mode

header='LUNACHIP-PHASE5-ASYNC-FIFO-FORMAL-EVIDENCE 1'
allowed_records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,TIMING,CLAIM,BUNDLES,COUNTEREXAMPLE,RESULTS,MATRIX,RECHECK,ARTIFACTS'
required_records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,TIMING,CLAIM,BUNDLES,COUNTEREXAMPLE,RESULTS,MATRIX,RECHECK,ARTIFACTS'

fail() {
  printf '%s\n' "phase5-async-fifo-formal-gate: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1
}

require_sha256() {
  command -v shasum >/dev/null 2>&1 ||
    command -v sha256sum >/dev/null 2>&1
}

validate_mount_mode() {
  case "$1" in
    volume) return 0 ;;
    *)
      printf '%s\n' 'LUNACHIP_YOSYS_MOUNT_MODE must be volume for this gate' >&2
      return 1
      ;;
  esac
}
[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  root=$(mktemp -d /tmp/lunachip-phase5-async-fifo-formal.XXXXXX)
else
  requested_root=$1
  [ -n "$requested_root" ] || fail "run root must not be empty"
  [ ! -L "$requested_root" ] || fail "run root must not be a symbolic link"
  if [ -e "$requested_root" ]; then
    [ -d "$requested_root" ] || fail "run root is not a directory"
    if find "$requested_root" -mindepth 1 -print | grep -q .; then
      fail "explicit run root must be empty"
    fi
    root=$(CDPATH= cd -- "$requested_root" && pwd -P)
  else
    parent=$(dirname -- "$requested_root")
    name=$(basename -- "$requested_root")
    [ -d "$parent" ] || fail "run-root parent does not exist"
    parent=$(CDPATH= cd -- "$parent" && pwd -P)
    root="$parent/$name"
    [ "$root" != / ] || fail "refusing filesystem root"
    mkdir "$root"
  fi
fi
case "$root/" in
  "$repo_dir/"*) fail "run root must be outside repository" ;;
esac

artifacts="$root/artifacts"
bundles="$artifacts/bundles"
results="$artifacts/results"
logs="$artifacts/logs"
metadata="$artifacts/metadata"
mkdir "$artifacts" "$results" "$logs" "$metadata"

evidence="$root/phase5-async-fifo-formal-evidence.incomplete"
final_evidence="$root/phase5-async-fifo-formal-evidence.txt"
repository_start="$metadata/repository-inputs.start.sha256"
repository_end="$metadata/repository-inputs.end.sha256"
status_start="$metadata/repository-status.start"
status_end="$metadata/repository-status.end"
schemas_manifest="$metadata/yosys-schemas.sha256"
bundles_manifest="$metadata/formal-bundles.sha256"
artifact_manifest="$root/artifacts.sha256"

# Create immutable incomplete evidence before tool, daemon, and provider
# preflights. Any failed logged command retains both status and output.
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
logged "$logs/preflight-transport.log" preflight-transport \
  validate_mount_mode "$mount_mode"
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
selftest_sha=$(lc_evidence_sha256_file "$async_selftest")
shard_selftest_sha=$(lc_evidence_sha256_file "$shard_selftest")
runner_selftest_sha=$(lc_evidence_sha256_file "$runner_selftest")
receipt_lib_sha=$(lc_evidence_sha256_file "$receipt_lib")
manifest_lib_sha=$(lc_evidence_sha256_file "$manifest_lib")
typed_artifact_lib_sha=$(lc_evidence_sha256_file "$typed_artifact_lib")
typed_artifact_selftest_sha=$(lc_evidence_sha256_file "$typed_artifact_selftest")
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
[ "$provider" = oci ] || fail "locked provider is not OCI"
for token in "$platform" "$image"; do
  lc_evidence_token "$token" || fail "unsafe provider provenance token"
done
context_sha=$(lc_evidence_sha256_file "$logs/docker-context.log")
daemon_sha=$(lc_evidence_sha256_file "$logs/docker-daemon.log")

record HEAD "$head"
record STATUS "start=$status_start_sha"
record REPOSITORY "start=$inputs_sha" "manifest=$(basename "$repository_start")"
record PIN "lock=$lock_sha" "runner=$runner_sha" "validator=$validator_sha" \
  "artifact-cli=$cli_sha" "registry-selftest=$registry_sha" \
  "async-selftest=$selftest_sha" "runner-selftest=$runner_selftest_sha" \
  "shard-selftest=$shard_selftest_sha" \
  "receipt-lib=$receipt_lib_sha" "manifest-lib=$manifest_lib_sha" \
  "typed-artifact-lib=$typed_artifact_lib_sha" \
  "typed-artifact-selftest=$typed_artifact_selftest_sha" \
  "shard-lib=$shard_lib_sha" \
  "footprint-lib=$footprint_lib_sha" \
  "gate=$gate_sha" "schemas-manifest=$schemas_sha"
record PROVENANCE "provider=$provider" "platform=$platform" "image=$image" \
  "transport=$mount_mode" "docker-context=$docker_context" \
  "docker-context-sha256=$context_sha" "docker-daemon-sha256=$daemon_sha"
record TIMING global-steps=2 max-idle=3 eventual-ready=3 \
  coincidence=atomic-global-pre-state
record CLAIM digital-two-state-bounded metastability=false mtbf=false \
  unilateral-reset=false timing=false

logged "$logs/lock.log" lock "$validator"
logged "$logs/registry.log" registry "$registry_selftest"
logged "$logs/typed-artifact-selftest.log" typed-artifact-selftest \
  "$typed_artifact_selftest"
logged "$logs/selftest.log" selftest "$async_selftest"
logged "$logs/runner.log" runner-selftest "$runner_selftest"
logged "$logs/version.log" provider-version "$runner" oci version
logged "$logs/materialize.log" materialize moon run --target native \
  --release cmd/phase4-formal -- generate-async-fifos "$bundles"

lc_evidence_create_artifact_manifest "$bundles" "$bundles_manifest" ||
  fail "could not create formal bundle manifest"
bundles_sha=$(lc_evidence_sha256_file "$bundles_manifest")
record BUNDLES "manifest=$bundles_sha" fixtures=9

tasks=0
passes=0
counters=0
witnesses=0
for bundle in "$bundles"/*; do
  fixture=$(basename "$bundle")
  lc_evidence_token "$fixture" || fail "unsafe fixture name: $fixture"
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
      lc_formal_verify_typed_artifacts "$bundle" "$task" "$output"
    if grep -E '^RESULT (inconclusive|tool-error)$' "$result" >/dev/null; then
      fail "$task produced a non-gating result"
    fi
    case "$task" in
      valid-async-fifo-bmc)
        grep -Fx 'RESULT bounded-pass' "$result" >/dev/null || fail "$task not pass"; passes=$((passes+1));;
      valid-async-fifo-cover-*)
        grep -Fx 'RESULT cover-witness' "$result" >/dev/null || fail "$task no witness"
        [ "$(grep -Ec '^WITNESS artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$result")" -eq 1 ] || fail "$task witness count"
        witnesses=$((witnesses+1));;
      broken-async-fifo-*-bmc)
        grep -Fx 'RESULT counterexample' "$result" >/dev/null || fail "$task no counterexample"
        [ "$(grep -Ec '^COUNTEREXAMPLE artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$result")" -eq 1 ] || fail "$task counterexample count"
        expected=$(awk '$1=="EXPECTED-FAILURE" {print $2}' "$bundle/$task.lcfg"); [ -n "$expected" ] && [ "$expected" != none ] || fail "$task wrong label"
        case "$fixture" in
          broken-async-fifo-gray) fixed=lc_p11_b77726974655f677261795f6571756174696f6e5f6578616374;;
          broken-async-fifo-full) fixed=lc_p17_b66756c6c5f6571756174696f6e5f6578616374;;
          broken-async-fifo-address) fixed=lc_p19_b77726974655f616464726573735f73656c656374696f6e5f6578616374;;
          broken-async-fifo-storage-order) fixed=lc_p27_b776174636865645f746f6b656e5f646174615f696e74656772697479;;
          broken-async-fifo-read-pipeline) fixed=lc_p15_b726561645f677261795f736f757263655f706970656c696e655f6578616374;;
          broken-async-fifo-write-pipeline) fixed=lc_p16_b77726974655f677261795f64657374696e6174696f6e5f706970656c696e655f6578616374;;
          broken-async-fifo-write-address-bounds) fixed=lc_p20_b77726974655f616464726573735f696e5f626f756e6473;;
          broken-async-fifo-read-address-bounds) fixed=lc_p22_b726561645f616464726573735f696e5f626f756e6473;;
          *) fail "$task has no fixed label mapping";;
        esac
        [ "$expected" = "$fixed" ] || fail "$task label does not match fixed mapping"
        record COUNTEREXAMPLE "$task" "label=$expected" exact=1
        counters=$((counters+1));;
      *) fail "unclassified $task";;
    esac
    tasks=$((tasks+1))
  done
done
[ "$tasks" -eq 15 ] || fail "formal task matrix changed to $tasks"
[ "$passes" -eq 1 ] || fail "bounded-pass matrix changed to $passes"
[ "$witnesses" -eq 6 ] || fail "cover matrix changed to $witnesses"
[ "$counters" -eq 8 ] || fail "counterexample matrix changed to $counters"

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
[ "$(lc_evidence_sha256_file "$async_selftest")" = "$selftest_sha" ] || fail "async selftest changed"
[ "$(lc_evidence_sha256_file "$shard_selftest")" = \
  "$shard_selftest_sha" ] || fail "async-FIFO shard selftest changed"
[ "$(lc_evidence_sha256_file "$runner_selftest")" = "$runner_selftest_sha" ] || fail "runner selftest changed"
[ "$(lc_evidence_sha256_file "$receipt_lib")" = "$receipt_lib_sha" ] || fail "receipt library changed"
[ "$(lc_evidence_sha256_file "$manifest_lib")" = "$manifest_lib_sha" ] || fail "manifest library changed"
[ "$(lc_evidence_sha256_file "$typed_artifact_lib")" = \
  "$typed_artifact_lib_sha" ] || fail "typed artifact library changed"
[ "$(lc_evidence_sha256_file "$typed_artifact_selftest")" = \
  "$typed_artifact_selftest_sha" ] || fail "typed artifact selftest changed"
[ "$(lc_evidence_sha256_file "$shard_lib")" = "$shard_lib_sha" ] ||
  fail "async-FIFO shard helper changed"
[ "$(lc_evidence_sha256_file "$footprint_lib")" = \
  "$footprint_lib_sha" ] || fail "async-FIFO footprint helper changed"
[ "$(lc_evidence_sha256_file "$gate")" = "$gate_sha" ] || fail "gate changed"
lc_evidence_verify_manifest "$repo_dir/toolchain/yosys" "$schemas_manifest" artifacts ||
  fail "Yosys schemas changed"
lc_evidence_verify_manifest "$bundles" "$bundles_manifest" artifacts ||
  fail "formal bundles changed"

record STATUS "end=$status_end_sha" drift=none
record REPOSITORY "end=$inputs_end_sha" drift=none \
  "manifest=$(basename "$repository_end")"
record RESULTS typed-results=15 typed-receipts=15
record MATRIX fixtures=9 tasks=15 passes=1 covers=6 counterexamples=8
record RECHECK "head=$end_head" repository=unchanged bundles=unchanged pins=unchanged

# Cover every generated bundle, command log, typed result, witness,
# counterexample, and per-task transport receipt. The manifest lives outside
# the artifact tree so its bytes never recursively describe themselves.
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
  "Phase 5 asynchronous-FIFO formal gate passes: 9 fixtures, 15 tasks" \
  "Evidence: $final_evidence" \
  "Evidence sha256:$(lc_evidence_sha256_file "$final_evidence")"
