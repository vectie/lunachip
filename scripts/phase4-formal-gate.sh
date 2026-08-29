#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
  echo "phase4-formal-gate: $*" >&2
  exit 1
}

if command -v shasum >/dev/null 2>&1; then
  evidence_sha() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  evidence_sha() { sha256sum "$1" | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required"
fi

snapshot_repository() {
  destination=$1
  (
    cd "$repo_dir"
    find . \
      -path './.git' -prune -o \
      -path './_build' -prune -o \
      -type f -print |
      sort |
      while IFS= read -r source; do
        printf '%s  %s\n' "$(evidence_sha "$source")" "${source#./}"
      done
  ) >"$destination"
}

[ "$#" -eq 1 ] || fail "usage: $0 EVIDENCE_ROOT"
evidence_root=$1
[ ! -e "$evidence_root" ] || fail "refusing to overwrite evidence root: $evidence_root"

mkdir -p "$evidence_root"
repository_head_start=$(git -C "$repo_dir" rev-parse HEAD)
snapshot_repository "$evidence_root/repository-inputs.start.sha256"
repository_inputs_start_sha=$(evidence_sha "$evidence_root/repository-inputs.start.sha256")
moon -C "$repo_dir" run --target native cmd/phase4-formal -- generate "$evidence_root/bundles"
mkdir -p "$evidence_root/results"

expected_fixtures='broken-bounds
broken-fifo-data
broken-response-protocol
valid-fifo'
observed_fixtures=$(
  find "$evidence_root/bundles" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; |
    sort
)
[ "$observed_fixtures" = "$expected_fixtures" ] ||
  fail "generated formal fixture set does not match the Phase 4 contract"

for fixture in $observed_fixtures; do
  bundle="$evidence_root/bundles/$fixture"
  "$repo_dir/scripts/phase4-yosys-validate.sh" --job-json "$bundle/job.json" "$bundle" >/dev/null
  mkdir -p "$evidence_root/results/$fixture"
  observed_tasks=$(jq -r '.formal_tasks[].name' "$bundle/job.json" | sort)
  case "$fixture" in
    valid-fifo)
      expected_tasks='valid-fifo-bmc
valid-fifo-cover
valid-fifo-prove'
      ;;
    broken-bounds) expected_tasks='broken-bounds-bmc' ;;
    broken-fifo-data) expected_tasks='broken-fifo-data-bmc' ;;
    broken-response-protocol) expected_tasks='broken-response-protocol-bmc' ;;
    *) fail "unexpected formal fixture: $fixture" ;;
  esac
  [ "$observed_tasks" = "$expected_tasks" ] ||
    fail "task set mismatch for $fixture"
  for task in $(jq -r '.formal_tasks[].name' "$bundle/job.json"); do
    output="$evidence_root/results/$fixture/$task"
    mkdir -p "$output"
    "$repo_dir/scripts/phase4-yosys-run.sh" oci formal "$task" "$bundle" "$output"
    [ -s "$output/result.lcfr" ] || fail "runner omitted typed result for $task"
    [ -s "$output/receipt.lcfe" ] || fail "runner omitted evidence receipt for $task"
    case "$task" in
      valid-fifo-bmc)
        grep -Fx "RESULT bounded-pass" "$output/result.lcfr" >/dev/null ||
          fail "$task did not produce the required bounded safety pass"
        ;;
      valid-fifo-prove)
        grep -Fx "RESULT proved" "$output/result.lcfr" >/dev/null ||
          fail "$task did not produce the required unbounded structural proof"
        ;;
      valid-fifo-cover)
        grep -Fx "RESULT cover-witness" "$output/result.lcfr" >/dev/null ||
          fail "$task did not produce the required cover result"
        grep -E '^WITNESS artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$output/result.lcfr" >/dev/null ||
          fail "$task did not retain its cover witness"
        ;;
      broken-*-bmc)
        grep -Fx "RESULT counterexample" "$output/result.lcfr" >/dev/null ||
          fail "$task did not produce the required reachable counterexample"
        grep -E '^COUNTEREXAMPLE artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$output/result.lcfr" >/dev/null ||
          fail "$task did not retain its counterexample"
        ;;
      *) fail "unclassified formal task outcome: $task" ;;
    esac
    if grep -E '^RESULT (inconclusive|tool-error)$' "$output/result.lcfr" >/dev/null; then
      fail "$task produced a non-gating formal outcome"
    fi
  done
done

repository_head_end=$(git -C "$repo_dir" rev-parse HEAD)
snapshot_repository "$evidence_root/repository-inputs.end.sha256"
repository_inputs_end_sha=$(evidence_sha "$evidence_root/repository-inputs.end.sha256")
[ "$repository_head_start" = "$repository_head_end" ] ||
  fail "repository HEAD drifted during formal execution"
cmp -s \
  "$evidence_root/repository-inputs.start.sha256" \
  "$evidence_root/repository-inputs.end.sha256" ||
  fail "repository inputs drifted during formal execution"
{
  printf '%s\n' 'LUNACHIP-PHASE4-FORMAL-REPOSITORY-IDENTITY 1'
  printf 'HEAD %s\n' "$repository_head_start"
  printf 'INPUTS-START repository-inputs.start.sha256 sha256 %s\n' "$repository_inputs_start_sha"
  printf 'INPUTS-END repository-inputs.end.sha256 sha256 %s\n' "$repository_inputs_end_sha"
  printf '%s\n' 'DRIFT none' 'END'
} >"$evidence_root/repository-identity.txt"
(
  cd "$evidence_root"
  find bundles results -type f -print
  printf '%s\n' \
    repository-inputs.start.sha256 \
    repository-inputs.end.sha256 \
    repository-identity.txt
) | sort |
  while IFS= read -r artifact; do
    printf '%s  %s\n' "$(evidence_sha "$evidence_root/$artifact")" "$artifact"
  done >"$evidence_root/evidence.sha256"
evidence_manifest_sha=$(evidence_sha "$evidence_root/evidence.sha256")
echo "Phase 4 FIFO formal gate passed; evidence retained at $evidence_root (manifest sha256:$evidence_manifest_sha)"
