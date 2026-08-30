#!/bin/sh
set -eu
LC_ALL=C; export LC_ALL; umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
artifact_cli="$repo_dir/scripts/formal-artifact-cli.sh"
registry_selftest="$repo_dir/scripts/formal-bundle-selftest.sh"
async_selftest="$repo_dir/scripts/phase5-async-fifo-formal-selftest.sh"
lock="$repo_dir/toolchain/yosys/lock.json"
fail() { echo "phase5-async-fifo-formal-gate: $*" >&2; exit 1; }
for command in moon jq git; do command -v "$command" >/dev/null || fail "$command required"; done
if command -v shasum >/dev/null; then
  sha_file() { shasum -a 256 "$1" | awk '{print $1}'; }
  sha_in() { shasum -a 256 | awk '{print $1}'; }
else
  sha_file() { sha256sum "$1" | awk '{print $1}'; }
  sha_in() { sha256sum | awk '{print $1}'; }
fi
tree_digest() {
  (cd "$1"; find . -type f -print | sort | while IFS= read -r f; do printf '%s  %s\n' "$(sha_file "$f")" "$f"; done) | sha_in
}
snapshot() {
  (cd "$repo_dir"; find . -path './.git' -prune -o -path './_build' -prune -o -type f -print | sort | while IFS= read -r f; do printf '%s  %s\n' "$(sha_file "$f")" "${f#./}"; done) >"$1"
}

[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  root=$(mktemp -d /tmp/lunachip-phase5-async-fifo-formal.XXXXXX)
else
  root=$1
  [ -n "$root" ] && [ ! -L "$root" ] || fail "unsafe run root"
  if [ -e "$root" ]; then
    [ -d "$root" ] && ! find "$root" -mindepth 1 -print | grep -q . || fail "run root must be empty"
    root=$(CDPATH= cd -- "$root" && pwd)
  else
    parent=$(CDPATH= cd -- "$(dirname -- "$root")" && pwd)
    root="$parent/$(basename -- "$root")"; [ "$root" != / ] || fail "refusing root"; mkdir "$root"
  fi
fi
case "$root/" in "$repo_dir/"*) fail "run root must be outside repository";; esac
mkdir "$root/results" "$root/logs"
evidence="$root/phase5-async-fifo-formal-evidence.incomplete"
printf '%s\n' 'LUNACHIP-PHASE5-ASYNC-FIFO-FORMAL-EVIDENCE 1' 'STATE incomplete' >"$evidence"
record() { printf '%s\n' "$1" >>"$evidence"; }
command -v docker >/dev/null || fail "docker required; incomplete evidence retained at $evidence"
logged() {
  log=$1; label=$2; shift 2
  if "$@" >"$log" 2>&1; then
    record "COMMAND $label status=0"
  else
    status=$?
    record "COMMAND $label status=$status"
    tail -n 80 "$log" >&2
    fail "$label failed status $status; log $log"
  fi
}

cd "$repo_dir"
head=$(git rev-parse HEAD)
git status --porcelain=v1 --untracked-files=all >"$root/repository-status.start"
snapshot "$root/repository-inputs.start.sha256"
inputs=$(sha_file "$root/repository-inputs.start.sha256")
lock_sha=$(sha_file "$lock"); runner_sha=$(sha_file "$runner"); validator_sha=$(sha_file "$validator"); cli_sha=$(sha_file "$artifact_cli"); registry_sha=$(sha_file "$registry_selftest"); selftest_sha=$(sha_file "$async_selftest"); gate_sha=$(sha_file "$0")
schemas_sha=$(tree_digest "$repo_dir/toolchain/yosys")
record "HEAD $head"; record "STATUS $(sha_file "$root/repository-status.start")"; record "INPUTS $inputs"; record "PIN lock=$lock_sha runner=$runner_sha validator=$validator_sha artifact-cli=$cli_sha registry-selftest=$registry_sha async-selftest=$selftest_sha gate=$gate_sha schemas-tree=$schemas_sha"
logged "$root/logs/lock.log" lock "$validator"
logged "$root/logs/registry.log" registry "$repo_dir/scripts/formal-bundle-selftest.sh"
logged "$root/logs/selftest.log" selftest "$repo_dir/scripts/phase5-async-fifo-formal-selftest.sh"
logged "$root/logs/runner.log" runner "$repo_dir/scripts/phase4-yosys-selftest.sh"
logged "$root/logs/materialize.log" materialize moon run --target native --release cmd/phase4-formal -- generate-async-fifos "$root/bundles"
bundles_sha=$(tree_digest "$root/bundles"); record "BUNDLES sha256=$bundles_sha"
logged "$root/logs/version.log" version "$runner" oci version
record "TIMING global-steps=2 max-idle=3 eventual-ready=3 coincidence=atomic-global-pre-state"
record "CLAIM digital-two-state-bounded metastability=false mtbf=false unilateral-reset=false timing=false"

tasks=0; passes=0; counters=0; witnesses=0
for bundle in "$root/bundles"/*; do
  fixture=$(basename "$bundle"); mkdir "$root/results/$fixture" "$root/logs/$fixture"
  "$validator" --job-json "$bundle/job.json" "$bundle" >/dev/null || fail "invalid $fixture"
  for task in $(jq -r '.formal_tasks[].name' "$bundle/job.json"); do
    output="$root/results/$fixture/$task"; mkdir "$output"
    logged "$root/logs/$fixture/$task.log" "$task" "$runner" oci formal "$task" "$bundle" "$output"
    result="$output/result.lcfr"; [ -s "$result" ] && [ -s "$output/receipt.lcfe" ] || fail "$task omitted typed artifacts"
    ! grep -E '^RESULT (inconclusive|tool-error)$' "$result" >/dev/null || fail "$task non-gating result"
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
        record "COUNTEREXAMPLE $task label=$expected exact=1"; counters=$((counters+1));;
      *) fail "unclassified $task";;
    esac
    tasks=$((tasks+1))
  done
done
[ "$tasks" -eq 15 ] && [ "$passes" -eq 1 ] && [ "$counters" -eq 8 ] && [ "$witnesses" -eq 6 ] || fail "matrix drift"
snapshot "$root/repository-inputs.end.sha256"
git status --porcelain=v1 --untracked-files=all >"$root/repository-status.end"
[ "$(git rev-parse HEAD)" = "$head" ] || fail "HEAD drift"
cmp -s "$root/repository-inputs.start.sha256" "$root/repository-inputs.end.sha256" || fail "input drift"
cmp -s "$root/repository-status.start" "$root/repository-status.end" || fail "git status drift"
[ "$(sha_file "$lock")" = "$lock_sha" ] && [ "$(sha_file "$runner")" = "$runner_sha" ] && [ "$(sha_file "$validator")" = "$validator_sha" ] && [ "$(sha_file "$artifact_cli")" = "$cli_sha" ] && [ "$(sha_file "$registry_selftest")" = "$registry_sha" ] && [ "$(sha_file "$async_selftest")" = "$selftest_sha" ] && [ "$(sha_file "$0")" = "$gate_sha" ] && [ "$(tree_digest "$repo_dir/toolchain/yosys")" = "$schemas_sha" ] || fail "pin drift"
[ "$(tree_digest "$root/bundles")" = "$bundles_sha" ] || fail "bundle drift"
results_sha=$(tree_digest "$root/results"); record "RESULTS sha256=$results_sha"
record "MATRIX fixtures=9 tasks=15 passes=1 covers=6 counterexamples=8"; record "RECHECK drift=none"
awk 'NR==2 {print "STATE pass"; next} {print}' "$evidence" >"$root/.pass"
mv "$root/.pass" "$root/phase5-async-fifo-formal-evidence.txt"; rm "$evidence"
echo "Phase 5 asynchronous-FIFO formal gate passes: $root/phase5-async-fifo-formal-evidence.txt"
