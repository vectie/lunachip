#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
checker="$repo_dir/scripts/phase4-yosys-inference-check.sh"
lock_file="$repo_dir/toolchain/yosys/lock.json"
mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-bind}

fail() {
  echo "phase4-yosys-synthesis-gate: $*" >&2
  exit 1
}

command -v moon >/dev/null 2>&1 || fail "moon is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v git >/dev/null 2>&1 || fail "git is required"
command -v docker >/dev/null 2>&1 || fail "Docker is required"
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
  sha256_stdin() { shasum -a 256 | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
  sha256_stdin() { sha256sum | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required"
fi
tree_digest() {
  root=$1
  if find "$root" -type l -print | grep -q .; then
    fail "artifact tree contains a symbolic link: $root"
  fi
  (
    cd "$root"
    find . -type f -print | sort | while IFS= read -r relative; do
      printf '%s  %s\n' "$(sha256_file "$relative")" "$relative"
    done
  ) | sha256_stdin
}
case "$mount_mode" in bind|volume) ;; *) fail "invalid Yosys mount mode" ;; esac
[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"

if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d "${TMPDIR:-/tmp}/lunachip-phase4-synthesis.XXXXXX")
else
  requested_root=$1
  [ -n "$requested_root" ] || fail "run root must not be empty"
  [ ! -L "$requested_root" ] || fail "run root must not be a symbolic link"
  if [ -e "$requested_root" ]; then
    [ -d "$requested_root" ] || fail "run root is not a directory"
    if find "$requested_root" -mindepth 1 -print | grep -q .; then
      fail "explicit run root must be empty"
    fi
    run_root=$(CDPATH= cd -- "$requested_root" && pwd)
  else
    requested_parent=$(dirname -- "$requested_root")
    requested_name=$(basename -- "$requested_root")
    [ -d "$requested_parent" ] || fail "run-root parent does not exist"
    [ ! -L "$requested_parent" ] || fail "run-root parent must not be a symbolic link"
    canonical_parent=$(CDPATH= cd -- "$requested_parent" && pwd)
    run_root="$canonical_parent/$requested_name"
    [ "$run_root" != / ] || fail "refusing filesystem root"
    mkdir "$run_root"
  fi
fi
case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac

bundles_root="$run_root/bundles"
results_root="$run_root/results"
logs_root="$run_root/logs"
mkdir "$results_root" "$logs_root"
evidence_incomplete="$run_root/phase4-yosys-synthesis-evidence.incomplete"
evidence_final="$run_root/phase4-yosys-synthesis-evidence.txt"
printf '%s\n' 'LUNACHIP-PHASE4-YOSYS-SYNTHESIS-EVIDENCE 1' 'STATE incomplete' >"$evidence_incomplete"

record() { printf '%s\n' "$1" >>"$evidence_incomplete"; }
run_tool_logged() {
  log=$1
  step=$2
  shift 2
  if "$@" >"$log" 2>&1; then
    record "COMMAND\t$step\tstatus=0"
  else
    status=$?
    record "COMMAND\t$step\tstatus=$status"
    tail -n 80 "$log" >&2
    fail "$step failed with status $status; log retained at $log"
  fi
}

cd "$repo_dir"
run_tool_logged "$logs_root/lock-validation.log" validate-lock "$validator"
run_tool_logged "$logs_root/inference-selftest.log" inference-selftest \
  "$repo_dir/scripts/phase4-yosys-inference-selftest.sh"
run_tool_logged "$logs_root/tool-version.log" yosys-version "$runner" oci version
run_tool_logged "$logs_root/materialize.log" materialize \
  moon run --target native --release cmd/phase4-synthesis-fixtures -- matrix "$bundles_root"

platform=$(jq -r '.provider.platform' "$lock_file")
repository=$(jq -r '.provider.repository' "$lock_file")
manifest_digest=$(jq -r '.provider.manifest_digest' "$lock_file")
config_digest=$(jq -r '.provider.config_digest' "$lock_file")
image="$repository@$manifest_digest"
run_tool_logged "$logs_root/image-inspect.json" image-inspect docker image inspect "$image"

moon_version=$(moon version | awk 'NF { if (seen) printf " | "; printf "%s", $0; seen=1 } END { print "" }')
git_head=$(git rev-parse HEAD)
git_status_digest=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
lock_digest=$(sha256_file "$lock_file")
runner_digest=$(sha256_file "$runner")
checker_digest=$(sha256_file "$checker")
gate_digest=$(sha256_file "$repo_dir/scripts/phase4-yosys-synthesis-gate.sh")
bundle_tree_digest=$(tree_digest "$bundles_root")
record "MOON\t$moon_version"
record "GIT_HEAD\t$git_head"
record "GIT_STATUS_SHA256\t$git_status_digest"
record "PROVIDER\toci\tplatform=$platform\timage=$image\tconfig=$config_digest"
record "TRANSPORT\tworkspace=$mount_mode\truntime=host-uid-gid"
record "CLAIM-BOUNDARY\tpre-map-memory-cells-only\tphysical-ram=false\ttiming=false\ttechnology-map=false"
record "ARTIFACT\tglobal\tyosys-lock\tsha256\t$lock_digest\ttoolchain/yosys/lock.json"
record "ARTIFACT\tglobal\trunner\tsha256\t$runner_digest\tscripts/phase4-yosys-run.sh"
record "ARTIFACT\tglobal\tinference-checker\tsha256\t$checker_digest\tscripts/phase4-yosys-inference-check.sh"
record "ARTIFACT\tglobal\tgate\tsha256\t$gate_digest\tscripts/phase4-yosys-synthesis-gate.sh"
record "ARTIFACT\tglobal\temitted-bundle-tree\tsha256\t$bundle_tree_digest\tbundles"
record "ARTIFACT\tglobal\timage-inspect\tsha256\t$(sha256_file "$logs_root/image-inspect.json")\tlogs/image-inspect.json"
record "ARTIFACT\tglobal\tlock-validation-log\tsha256\t$(sha256_file "$logs_root/lock-validation.log")\tlogs/lock-validation.log"
record "ARTIFACT\tglobal\ttool-version-log\tsha256\t$(sha256_file "$logs_root/tool-version.log")\tlogs/tool-version.log"
record "ARTIFACT\tglobal\tmaterialize-log\tsha256\t$(sha256_file "$logs_root/materialize.log")\tlogs/materialize.log"
record "ARTIFACT\tglobal\tinference-selftest-log\tsha256\t$(sha256_file "$logs_root/inference-selftest.log")\tlogs/inference-selftest.log"

fixtures='single-read-old single-read-new single-no-change single-undefined single-masked multiwrite-lower-port-id-wins multiwrite-reject fifo banked-memory'
fixture_count=0
eligible_count=0
multiwrite_count=0
for fixture in $fixtures; do
  bundle="$bundles_root/$fixture"
  output="$results_root/$fixture"
  fixture_logs="$logs_root/$fixture"
  mkdir "$output" "$fixture_logs"
  case "$fixture" in
    multiwrite-*) expectation=observe-only-multiwrite; expected_shapes=observe; multiwrite_count=$((multiwrite_count + 1)) ;;
    banked-memory)
      expectation=require-memory-cell
      expected_shapes='64:32:2:1,64:32:2:1,64:32:2:1,64:32:2:1'
      eligible_count=$((eligible_count + 1))
      ;;
    fifo) expectation=require-memory-cell; expected_shapes='16:32:2:1'; eligible_count=$((eligible_count + 1)) ;;
    *) expectation=require-memory-cell; expected_shapes='64:32:2:1'; eligible_count=$((eligible_count + 1)) ;;
  esac
  run_tool_logged "$fixture_logs/runner.log" "synthesize-$fixture" \
    "$runner" oci synth "$bundle" "$output"
  run_tool_logged "$fixture_logs/inference-check.log" "inference-$fixture" \
    "$checker" "$fixture" "$expectation" "$expected_shapes" \
    "$output/pre-map.rtlil" "$output/yosys.log" "$output/inference.json"
  classification=$(jq -r '.classification' "$output/inference.json")
  observed=$(jq -r '.observed.pre_map_memory_total' "$output/inference.json")
  stat_observed=$(jq -r '.observed.yosys_stat_mem_v2_max' "$output/inference.json")
  claim=$(jq -r '.inferred_memory_claim' "$output/inference.json")
  [ "$(jq -r '.physical_ram_claim' "$output/inference.json")" = false ] ||
    fail "$fixture incorrectly claims physical RAM inference"
  shapes=$(jq -c '.observed.memory_shapes' "$output/inference.json")
  record "FIXTURE\t$fixture\texpectation=$expectation\texpected-shapes=$expected_shapes\tpre-map-memory-cells=$observed\tshapes=$shapes\tstat-mem-v2=$stat_observed\tclassification=$classification\tinferred-memory-claim=$claim\tphysical-ram-claim=false"
  record "ARTIFACT\t$fixture\tir\tsha256\t$(sha256_file "$bundle/design.lcir")\tbundles/$fixture/design.lcir"
  record "ARTIFACT\t$fixture\tnames\tsha256\t$(sha256_file "$bundle/names.lcnm")\tbundles/$fixture/names.lcnm"
  record "ARTIFACT\t$fixture\tjob\tsha256\t$(sha256_file "$bundle/job.json")\tbundles/$fixture/job.json"
  for source in $(jq -r '.sources[].path' "$bundle/job.json"); do
    record "ARTIFACT\t$fixture\trtl\tsha256\t$(sha256_file "$bundle/$source")\tbundles/$fixture/$source"
  done
  for artifact in command.txt yosys.ys tool-versions.txt transport-receipt.txt yosys.log pre-map.rtlil pre-map.json netlist.json netlist.v status.txt inference.json; do
    [ -f "$output/$artifact" ] || fail "$fixture is missing $artifact"
    record "ARTIFACT\t$fixture\t$artifact\tsha256\t$(sha256_file "$output/$artifact")\tresults/$fixture/$artifact"
  done
  record "ARTIFACT\t$fixture\trunner-log\tsha256\t$(sha256_file "$fixture_logs/runner.log")\tlogs/$fixture/runner.log"
  record "ARTIFACT\t$fixture\tinference-check-log\tsha256\t$(sha256_file "$fixture_logs/inference-check.log")\tlogs/$fixture/inference-check.log"
  fixture_count=$((fixture_count + 1))
done

[ "$fixture_count" -eq 9 ] || fail "fixture matrix changed to $fixture_count"
[ "$eligible_count" -eq 7 ] || fail "inference-eligible matrix changed to $eligible_count"
[ "$multiwrite_count" -eq 2 ] || fail "multiwrite observation matrix changed to $multiwrite_count"
record "MATRIX\tfixtures=$fixture_count\tinference-eligible=$eligible_count\tmultiwrite-observe-only=$multiwrite_count"
record 'RESULT\tall-required-pre-map-memory-cells-retained\tphysical-ram-claim=false'

final_git_head=$(git rev-parse HEAD)
final_git_status_digest=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
[ "$final_git_head" = "$git_head" ] || fail "git HEAD changed during the gate"
[ "$final_git_status_digest" = "$git_status_digest" ] || fail "git status changed during the gate"
[ "$(sha256_file "$lock_file")" = "$lock_digest" ] || fail "Yosys lock changed during the gate"
[ "$(sha256_file "$runner")" = "$runner_digest" ] || fail "Yosys runner changed during the gate"
[ "$(sha256_file "$checker")" = "$checker_digest" ] || fail "inference checker changed during the gate"
[ "$(sha256_file "$repo_dir/scripts/phase4-yosys-synthesis-gate.sh")" = "$gate_digest" ] ||
  fail "synthesis gate changed during execution"
[ "$(tree_digest "$bundles_root")" = "$bundle_tree_digest" ] || fail "emitted bundles changed during the gate"
record "RECHECK\tgit-head=$final_git_head\tgit-status-sha256=$final_git_status_digest\tlock=$lock_digest\trunner=$runner_digest\tchecker=$checker_digest\tgate=$gate_digest\tbundles=$bundle_tree_digest"

evidence_passing="$run_root/.phase4-yosys-synthesis-evidence.pass.$$"
awk 'NR == 2 { print "STATE pass"; next } { print }' \
  "$evidence_incomplete" >"$evidence_passing"
mv "$evidence_passing" "$evidence_final"
rm "$evidence_incomplete"
evidence_digest=$(sha256_file "$evidence_final")
echo "Phase 4 pinned-Yosys synthesis gate passes: $fixture_count fixtures"
echo "Evidence: $evidence_final"
echo "Evidence sha256:$evidence_digest"
