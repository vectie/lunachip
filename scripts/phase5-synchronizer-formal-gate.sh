#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
lock_file="$repo_dir/toolchain/yosys/lock.json"

fail() {
  echo "phase5-synchronizer-formal-gate: $*" >&2
  exit 1
}

for command in moon jq git docker; do
  command -v "$command" >/dev/null 2>&1 || fail "$command is required"
done
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
  sha256_stdin() { shasum -a 256 | awk '{print $1}'; }
else
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
  sha256_stdin() { sha256sum | awk '{print $1}'; }
fi
tree_digest() {
  root=$1
  (
    cd "$root"
    find . -type f -print | sort | while IFS= read -r relative; do
      printf '%s  %s\n' "$(sha256_file "$relative")" "$relative"
    done
  ) | sha256_stdin
}

[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d /tmp/lunachip-phase5-sync-formal.XXXXXX)
else
  requested=$1
  [ -n "$requested" ] || fail "run root must not be empty"
  [ ! -L "$requested" ] || fail "run root must not be a symbolic link"
  if [ -e "$requested" ]; then
    [ -d "$requested" ] || fail "run root is not a directory"
    if find "$requested" -mindepth 1 -print | grep -q .; then
      fail "explicit run root must be empty"
    fi
    run_root=$(CDPATH= cd -- "$requested" && pwd)
  else
    parent=$(dirname -- "$requested")
    name=$(basename -- "$requested")
    [ -d "$parent" ] || fail "run-root parent does not exist"
    parent=$(CDPATH= cd -- "$parent" && pwd)
    run_root="$parent/$name"
    [ "$run_root" != / ] || fail "refusing filesystem root"
    mkdir "$run_root"
  fi
fi
case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac

bundles="$run_root/bundles"
results="$run_root/results"
logs="$run_root/logs"
mkdir "$results" "$logs"
evidence="$run_root/phase5-synchronizer-formal-evidence.incomplete"
printf '%s\n' \
  'LUNACHIP-PHASE5-SYNCHRONIZER-FORMAL-EVIDENCE 1' \
  'STATE incomplete' >"$evidence"
record() { printf '%s\n' "$1" >>"$evidence"; }
run_logged() {
  log=$1
  label=$2
  shift 2
  if "$@" >"$log" 2>&1; then
    record "COMMAND\t$label\tstatus=0"
  else
    status=$?
    tail -n 80 "$log" >&2
    fail "$label failed with status $status; log retained at $log"
  fi
}

cd "$repo_dir"
run_logged "$logs/lock-validation.log" validate-lock "$validator"
run_logged "$logs/bundle-selftest.log" bundle-selftest \
  "$repo_dir/scripts/formal-bundle-selftest.sh"
run_logged "$logs/runner-selftest.log" runner-selftest \
  "$repo_dir/scripts/phase4-yosys-selftest.sh"
run_logged "$logs/tool-version.log" tool-version "$runner" oci version
run_logged "$logs/materialize.log" materialize \
  moon run --target native --release cmd/phase4-formal -- \
  generate-synchronizers "$bundles"

git_head=$(git rev-parse HEAD)
git_status=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
lock_digest=$(sha256_file "$lock_file")
runner_digest=$(sha256_file "$runner")
gate_digest=$(sha256_file "$repo_dir/scripts/phase5-synchronizer-formal-gate.sh")
bundle_digest=$(tree_digest "$bundles")
record "GIT_HEAD\t$git_head"
record "GIT_STATUS_SHA256\t$git_status"
record "PIN\tlock=$lock_digest\trunner=$runner_digest\tgate=$gate_digest\tbundles=$bundle_digest"
record "TIMING\tglobal-engine-steps=2\tlegal=one-step-pulses\tfair=max-three-idle-steps\tcoincidence=atomic-global-pre-state"
record "CLAIM-BOUNDARY\tdigital-two-state-bounded\tmetastability=false\tmtbf=false\tplacement=false\ttiming-closure=false"

fixtures='broken-synchronizer-convergence broken-synchronizer-destination-edge broken-synchronizer-pipeline valid-synchronizer'
task_count=0
counterexamples=0
covers=0
for fixture in $fixtures; do
  bundle="$bundles/$fixture"
  mkdir "$results/$fixture" "$logs/$fixture"
  "$validator" --job-json "$bundle/job.json" "$bundle" >/dev/null ||
    fail "bundle validation failed for $fixture"
  for task in $(jq -r '.formal_tasks[].name' "$bundle/job.json"); do
    output="$results/$fixture/$task"
    mkdir "$output"
    run_logged "$logs/$fixture/$task.log" "$task" \
      "$runner" oci formal "$task" "$bundle" "$output"
    result="$output/result.lcfr"
    [ -s "$result" ] || fail "$task omitted typed result"
    [ -s "$output/receipt.lcfe" ] || fail "$task omitted evidence receipt"
    if grep -E '^RESULT (inconclusive|tool-error)$' "$result" >/dev/null; then
      fail "$task produced a non-gating result"
    fi
    case "$task" in
      valid-synchronizer-bmc)
        grep -Fx 'RESULT bounded-pass' "$result" >/dev/null ||
          fail "$task did not produce its bounded safety pass"
        ;;
      valid-synchronizer-cover)
        grep -Fx 'RESULT cover-witness' "$result" >/dev/null ||
          fail "$task did not produce its coincident-edge cover witness"
        [ "$(grep -Ec '^WITNESS artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$result")" -eq 1 ] ||
          fail "$task did not retain exactly one typed cover artifact"
        covers=$((covers + 1))
        ;;
      broken-synchronizer-*-bmc)
        grep -Fx 'RESULT counterexample' "$result" >/dev/null ||
          fail "$task did not produce its isolated reachable counterexample"
        [ "$(grep -Ec '^COUNTEREXAMPLE artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' "$result")" -eq 1 ] ||
          fail "$task did not retain exactly one typed counterexample artifact"
        expected=$(awk '$1 == "EXPECTED-FAILURE" { print $2 }' "$bundle/$task.lcfg")
        [ -n "$expected" ] && [ "$expected" != none ] ||
          fail "$task lacks its exact expected stable label"
        record "COUNTEREXAMPLE\t$task\tlabel=$expected\tartifact=exactly-one"
        counterexamples=$((counterexamples + 1))
        ;;
      *) fail "unclassified synchronizer formal task: $task" ;;
    esac
    task_count=$((task_count + 1))
  done
done
[ "$task_count" -eq 5 ] || fail "formal task matrix changed to $task_count"
[ "$counterexamples" -eq 3 ] || fail "counterexample matrix changed"
[ "$covers" -eq 1 ] || fail "cover matrix changed"

final_head=$(git rev-parse HEAD)
final_status=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
[ "$final_head" = "$git_head" ] || fail "git HEAD changed during gate"
[ "$final_status" = "$git_status" ] || fail "git status changed during gate"
[ "$(sha256_file "$lock_file")" = "$lock_digest" ] || fail "tool lock changed"
[ "$(sha256_file "$runner")" = "$runner_digest" ] || fail "runner changed"
[ "$(sha256_file "$repo_dir/scripts/phase5-synchronizer-formal-gate.sh")" = "$gate_digest" ] ||
  fail "gate changed"
[ "$(tree_digest "$bundles")" = "$bundle_digest" ] || fail "formal bundles changed"
record "MATRIX\tfixtures=4\ttasks=5\tbounded-passes=1\tcovers=1\tcounterexamples=3"
record "RECHECK\tgit-head=$final_head\tgit-status-sha256=$final_status"

passing="$run_root/.phase5-synchronizer-formal-evidence.pass.$$"
awk 'NR == 2 { print "STATE pass"; next } { print }' "$evidence" >"$passing"
final_evidence="$run_root/phase5-synchronizer-formal-evidence.txt"
mv "$passing" "$final_evidence"
rm "$evidence"
echo "Phase 5 synchronizer formal gate passes: 4 fixtures, 5 tasks"
echo "Evidence: $final_evidence"
echo "Evidence sha256:$(sha256_file "$final_evidence")"
