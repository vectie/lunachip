#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner="$repo_dir/scripts/phase4-yosys-run.sh"
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
checker="$repo_dir/scripts/yosys-toggle-synthesis-check.sh"
selftest="$repo_dir/scripts/yosys-toggle-synthesis-selftest.sh"
lock_file="$repo_dir/toolchain/yosys/lock.json"
shape_schema="$repo_dir/toolchain/yosys/toggle-synthesis-shape.schema.json"
report_schema="$repo_dir/toolchain/yosys/toggle-synthesis-report.schema.json"
mount_mode=$(printenv LUNACHIP_YOSYS_MOUNT_MODE || true)
[ -n "$mount_mode" ] || mount_mode=bind

fail() {
  echo "phase5-yosys-toggle-synthesis-gate: $*" >&2
  exit 1
}

command -v moon >/dev/null 2>&1 || fail "moon is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v git >/dev/null 2>&1 || fail "git is required"
command -v docker >/dev/null 2>&1 || fail "Docker is required"
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
case "$mount_mode" in bind|volume) ;; *) fail "invalid Yosys mount mode" ;; esac
[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"

if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d /tmp/lunachip-phase5-toggle-synthesis.XXXXXX)
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
    parent=$(dirname -- "$requested_root")
    name=$(basename -- "$requested_root")
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
evidence="$run_root/phase5-yosys-toggle-synthesis-evidence.incomplete"
printf '%s\n' \
  'LUNACHIP-PHASE5-YOSYS-TOGGLE-SYNTHESIS-EVIDENCE 1' \
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
run_logged "$logs/checker-selftest.log" checker-selftest "$selftest"
run_logged "$logs/tool-version.log" yosys-version "$runner" oci version
run_logged "$logs/materialize.log" materialize \
  moon run --target native --release cmd/phase5-toggle-synthesis-fixtures -- matrix "$bundles"

git_head=$(git rev-parse HEAD)
git_status=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
lock_digest=$(sha256_file "$lock_file")
runner_digest=$(sha256_file "$runner")
checker_digest=$(sha256_file "$checker")
selftest_digest=$(sha256_file "$selftest")
shape_schema_digest=$(sha256_file "$shape_schema")
report_schema_digest=$(sha256_file "$report_schema")
gate_digest=$(sha256_file "$repo_dir/scripts/phase5-yosys-toggle-synthesis-gate.sh")
bundle_digest=$(tree_digest "$bundles")
image=$(jq -r '.provider.repository + "@" + .provider.manifest_digest' "$lock_file")
platform=$(jq -r '.provider.platform' "$lock_file")
record "GIT_HEAD\t$git_head"
record "GIT_STATUS_SHA256\t$git_status"
record "PROVIDER\toci\tplatform=$platform\timage=$image"
record "TRANSPORT\tworkspace=$mount_mode\truntime=host-uid-gid"
record "CLAIM-BOUNDARY\tpre-map-state-shape-only\tprotocol-logic=false\tplacement=false\tmetastability=false\tmtbf=false\ttiming-closure=false"
record "PIN\tlock=$lock_digest\trunner=$runner_digest\tchecker=$checker_digest\tselftest=$selftest_digest\tshape-schema=$shape_schema_digest\treport-schema=$report_schema_digest\tgate=$gate_digest\tbundles=$bundle_digest"

fixtures='toggle-scalar-2-stage toggle-record-3-stage toggle-record-4-stage'
count=0
for fixture in $fixtures; do
  bundle="$bundles/$fixture"
  output="$results/$fixture"
  fixture_logs="$logs/$fixture"
  mkdir "$output" "$fixture_logs"
  run_logged "$fixture_logs/runner.log" "synthesize-$fixture" \
    "$runner" oci synth "$bundle" "$output"
  run_logged "$fixture_logs/check.log" "check-$fixture" \
    "$checker" "$bundle/expected-toggle-shape.json" \
    "$output/pre-map.rtlil" "$output/toggle-synthesis.json"
  jq -e '.pass and .classification == "exact-toggle-state-shape" and
    .claim_boundary == { pre_map_state_shape: true,
      combinational_protocol_logic: false, physical_placement: false,
      metastability: false, mtbf: false, timing_closure: false }' \
    "$output/toggle-synthesis.json" >/dev/null ||
    fail "$fixture produced a non-passing or overclaiming report"
  expected=$(jq -r '.state_count' "$bundle/expected-toggle-shape.json")
  observed=$(jq -r '.observed.stateful_cells' "$output/toggle-synthesis.json")
  [ "$expected" -eq "$observed" ] || fail "$fixture state count drifted"
  record "FIXTURE\t$fixture\tstate=$observed\tshape=exact\tprotocol-logic=false\tplacement=false\tmetastability=false\tmtbf=false\ttiming-closure=false"
  record "BUNDLE\t$fixture\tsha256=$(tree_digest "$bundle")"
  record "RESULTS\t$fixture\tsha256=$(tree_digest "$output")"
  count=$((count + 1))
done
[ "$count" -eq 3 ] || fail "fixture matrix changed to $count"

final_head=$(git rev-parse HEAD)
final_status=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
[ "$final_head" = "$git_head" ] || fail "git HEAD changed during the gate"
[ "$final_status" = "$git_status" ] || fail "git status changed during the gate"
[ "$(sha256_file "$lock_file")" = "$lock_digest" ] || fail "Yosys lock changed"
[ "$(sha256_file "$runner")" = "$runner_digest" ] || fail "runner changed"
[ "$(sha256_file "$checker")" = "$checker_digest" ] || fail "checker changed"
[ "$(sha256_file "$selftest")" = "$selftest_digest" ] || fail "selftest changed"
[ "$(sha256_file "$shape_schema")" = "$shape_schema_digest" ] || fail "shape schema changed"
[ "$(sha256_file "$report_schema")" = "$report_schema_digest" ] || fail "report schema changed"
[ "$(sha256_file "$repo_dir/scripts/phase5-yosys-toggle-synthesis-gate.sh")" = "$gate_digest" ] || fail "gate changed"
[ "$(tree_digest "$bundles")" = "$bundle_digest" ] || fail "bundles changed"
record "MATRIX\tfixtures=3\tstage-counts=2,3,4\tpayload-leaves=1,2,2"
record "RESULT\texact-pre-map-toggle-state-shapes\tprotocol-logic=false\tplacement=false\tmetastability=false\tmtbf=false\ttiming-closure=false"
record "RECHECK\tgit-head=$final_head\tgit-status-sha256=$final_status"

passing="$run_root/.phase5-yosys-toggle-synthesis-evidence.pass.$$"
awk 'NR == 2 { print "STATE pass"; next } { print }' "$evidence" >"$passing"
final_evidence="$run_root/phase5-yosys-toggle-synthesis-evidence.txt"
mv "$passing" "$final_evidence"
rm "$evidence"
echo "Phase 5 pinned-Yosys toggle synthesis gate passes: 3 fixtures"
echo "Evidence: $final_evidence"
echo "Evidence sha256:$(sha256_file "$final_evidence")"
