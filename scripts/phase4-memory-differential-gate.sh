#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner="$repo_dir/scripts/phase3-verilator-run.sh"
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
lock_file="$repo_dir/toolchain/verilator/lock.json"
mount_mode=${LUNACHIP_VERILATOR_MOUNT_MODE-bind}

fail() {
  echo "phase4-memory-differential-gate: $*" >&2
  exit 1
}

command -v moon >/dev/null 2>&1 || fail "moon is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v git >/dev/null 2>&1 || fail "git is required"
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
  sha256_stdin() { shasum -a 256 | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
  sha256_stdin() { sha256sum | awk '{print $1}'; }
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
        printf '%s  %s\n' "$(sha256_file "$source")" "${source#./}"
      done
  ) >"$destination"
}
case "$mount_mode" in bind|volume) ;; *) fail "invalid Verilator mount mode" ;; esac
[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"

if [ "$#" -eq 0 ]; then
  temporary_parent=${TMPDIR:-/tmp}
  [ -d "$temporary_parent" ] || fail "temporary parent does not exist"
  [ ! -L "$temporary_parent" ] || fail "temporary parent must not be a symbolic link"
  run_root=$(mktemp -d "$temporary_parent/lunachip-phase4-memory.XXXXXX")
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
    [ "$run_root" != "/" ] || fail "refusing filesystem root"
    case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac
    mkdir "$run_root"
  fi
fi

case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac
bundles_root="$run_root/bundles"
negative_bundles_root="$run_root/negative-bundles"
lint_root="$run_root/lint"
results_root="$run_root/results"
negative_results_root="$run_root/negative-results"
logs_root="$run_root/logs"
mkdir "$lint_root" "$results_root" "$negative_results_root" "$logs_root"
evidence_incomplete="$run_root/phase4-memory-evidence.incomplete"
evidence_final="$run_root/phase4-memory-evidence.txt"
printf '%s\n' 'LUNACHIP-PHASE4-MEMORY-EVIDENCE 1' 'STATE incomplete' >"$evidence_incomplete"

record() { printf '%s\n' "$1" >>"$evidence_incomplete"; }
run_recorded() {
  step=$1
  shift
  if "$@"; then
    record "COMMAND\t$step\tstatus=0"
  else
    status=$?
    record "COMMAND\t$step\tstatus=$status"
    fail "$step failed with status $status; evidence retained at $evidence_incomplete"
  fi
}

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
git_head=$(git rev-parse HEAD)
snapshot_repository "$run_root/repository-inputs.start.sha256"
repository_inputs_start_sha=$(sha256_file "$run_root/repository-inputs.start.sha256")
run_recorded validate-lock "$validator"
if observed_version=$("$runner" oci version); then
  record 'COMMAND\tverilator-version\tstatus=0'
else
  status=$?
  record "COMMAND\tverilator-version\tstatus=$status"
  fail "pinned Verilator identity check failed"
fi
case "$observed_version" in
  *'
'*) fail "Verilator identity must be one line" ;;
esac
moon_version=$(moon version | awk 'NF { if (seen) printf " | "; printf "%s", $0; seen=1 } END { print "" }')
git_status_digest=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
case $(uname -m) in
  arm64|aarch64) oci_platform=linux/arm64 ;;
  x86_64|amd64) oci_platform=linux/amd64 ;;
  *) fail "unsupported OCI architecture" ;;
esac
oci_repository=$(jq -r '.providers.oci.repository' "$lock_file")
oci_digest=$(jq -r --arg platform "$oci_platform" \
  '.providers.oci.platforms[] | select(.platform == $platform) | .digest' \
  "$lock_file")
record "MOON\t$moon_version"
record "GIT_HEAD\t$git_head"
record "GIT_STATUS_SHA256\t$git_status_digest"
record "REPOSITORY_INPUTS_START_SHA256\t$repository_inputs_start_sha"
record "TOOL\t$observed_version"
record "PROVIDER\toci\tplatform=$oci_platform\timage=$oci_repository@$oci_digest"
record "TRANSPORT\tworkspace=$mount_mode"
record "ARTIFACT\tglobal\tverilator-lock\tsha256\t$(sha256_file "$lock_file")\ttoolchain/verilator/lock.json"
run_recorded materialize moon run cmd/phase4-fixtures --target native --release -- standard "$bundles_root"
run_recorded materialize-negative moon run cmd/phase4-fixtures --target native --release -- negative "$negative_bundles_root"

fixtures='whole-read-old whole-read-new no-change undefined-safe masked-write non-power-of-two enables lower-port-id-wins'
cycles_per_fixture=13000
total_cycles=0
for fixture in $fixtures; do
  bundle="$bundles_root/$fixture"
  lint_output="$lint_root/$fixture"
  result_output="$results_root/$fixture"
  fixture_logs="$logs_root/$fixture"
  mkdir "$lint_output" "$result_output"
  mkdir "$fixture_logs"
  [ -f "$bundle/design.lcir" ] || fail "$fixture missing design.lcir"
  [ -f "$bundle/names.lcnm" ] || fail "$fixture missing names.lcnm"
  run_recorded "validate-$fixture" "$validator" --harness-json "$bundle/manifest.json"
  lint_log="$fixture_logs/lint.log"
  build_log="$fixture_logs/build.log"
  execute_log="$fixture_logs/execute.log"
  run_tool_logged "$lint_log" "lint-$fixture" \
    "$runner" oci lint "$bundle" "$lint_output"
  run_tool_logged "$build_log" "build-$fixture" \
    "$runner" oci build "$bundle" "$result_output"
  executable="$result_output/obj_dir/Vlunachip_model"
  [ -x "$executable" ] || fail "$fixture compiled executable is absent"
  run_tool_logged "$execute_log" "execute-$fixture" \
    "$runner" oci execute "$bundle" "$result_output"
  actual="$result_output/actual.tsv"
  [ -f "$actual" ] || fail "$fixture did not produce actual.tsv"
  rows=$(awk 'END { print NR - 2 }' "$actual")
  [ "$rows" -eq "$cycles_per_fixture" ] || fail "$fixture produced $rows rows"
  awk -F '\t' -v expected="$cycles_per_fixture" '
    NR == 1 && ($1 != "LUNACHIP-PHASE4-RESULT" || $2 != "1") { exit 1 }
    NR == 2 && $1 != "cycle" { exit 1 }
    NR == 3 && $1 != "1" { exit 1 }
    END { if (NR != expected + 2 || $1 != expected) exit 1 }
  ' "$actual" || fail "$fixture result has a non-canonical cycle range"
  total_cycles=$((total_cycles + rows))
  record "FIXTURE\t$fixture\tpost-reset-cycles=$rows"
  record "ARTIFACT\t$fixture\tir\tsha256\t$(sha256_file "$bundle/design.lcir")\tbundles/$fixture/design.lcir"
  record "ARTIFACT\t$fixture\tname-manifest\tsha256\t$(sha256_file "$bundle/names.lcnm")\tbundles/$fixture/names.lcnm"
  record "ARTIFACT\t$fixture\tharness-manifest\tsha256\t$(sha256_file "$bundle/manifest.json")\tbundles/$fixture/manifest.json"
  record "ARTIFACT\t$fixture\tharness\tsha256\t$(sha256_file "$bundle/harness.cpp")\tbundles/$fixture/harness.cpp"
  for source_relative in $(jq -r '.sources[]' "$bundle/manifest.json"); do
    record "ARTIFACT\t$fixture\trtl\tsha256\t$(sha256_file "$bundle/$source_relative")\tbundles/$fixture/$source_relative"
  done
  record "ARTIFACT\t$fixture\tstimulus\tsha256\t$(sha256_file "$bundle/stimulus.tsv")\tbundles/$fixture/stimulus.tsv"
  record "ARTIFACT\t$fixture\texpected\tsha256\t$(sha256_file "$bundle/expected.tsv")\tbundles/$fixture/expected.tsv"
  record "ARTIFACT\t$fixture\tstimulus-audit\tsha256\t$(sha256_file "$bundle/stimulus.audit")\tbundles/$fixture/stimulus.audit"
  record "ARTIFACT\t$fixture\texpected-audit\tsha256\t$(sha256_file "$bundle/expected.audit")\tbundles/$fixture/expected.audit"
  record "ARTIFACT\t$fixture\tverilator-lint-log\tsha256\t$(sha256_file "$lint_log")\tlogs/$fixture/lint.log"
  record "ARTIFACT\t$fixture\tverilator-build-log\tsha256\t$(sha256_file "$build_log")\tlogs/$fixture/build.log"
  record "ARTIFACT\t$fixture\tverilator-execute-log\tsha256\t$(sha256_file "$execute_log")\tlogs/$fixture/execute.log"
  record "ARTIFACT\t$fixture\texecutable\tsha256\t$(sha256_file "$executable")\tresults/$fixture/obj_dir/Vlunachip_model"
  record "ARTIFACT\t$fixture\tactual\tsha256\t$(sha256_file "$actual")\tresults/$fixture/actual.tsv"
done

[ "$total_cycles" -eq 104000 ] || fail "locked cycle total changed to $total_cycles"
comparison="$run_root/comparison.txt"
if moon run cmd/phase4-fixtures --target native --release -- verify-standard "$results_root" >"$comparison"; then
  record 'COMMAND\tcompare-standard\tstatus=0'
else
  status=$?
  record "COMMAND\tcompare-standard\tstatus=$status"
  fail "LunaWave/Verilator comparison failed"
fi
record "ARTIFACT\tglobal\tcomparison\tsha256\t$(sha256_file "$comparison")\tcomparison.txt"
record "CYCLES\tpost-reset\t$total_cycles"
record 'COMPARISON\tequal\tfixtures=8'
negative_fixtures='fault-out-of-bounds dynamic-reject-collision'
negative_count=0
for fixture in $negative_fixtures; do
  bundle="$negative_bundles_root/$fixture"
  lint_output="$lint_root/$fixture"
  result_output="$negative_results_root/$fixture"
  fixture_logs="$logs_root/$fixture"
  mkdir "$lint_output" "$result_output" "$fixture_logs"
  [ -f "$bundle/expected-failure.txt" ] || fail "$fixture missing expected-failure.txt"
  marker=$(awk '$1 == "MARKER" { print $2 }' "$bundle/expected-failure.txt")
  [ -n "$marker" ] || fail "$fixture has no expected assertion marker"
  case "$marker" in *[!A-Za-z0-9_]*) fail "$fixture has invalid assertion marker" ;; esac
  run_recorded "validate-$fixture" "$validator" --harness-json "$bundle/manifest.json"
  run_tool_logged "$fixture_logs/lint.log" "lint-$fixture" \
    "$runner" oci lint "$bundle" "$lint_output"
  run_tool_logged "$fixture_logs/build.log" "build-$fixture" \
    "$runner" oci build "$bundle" "$result_output"
  execute_log="$fixture_logs/execute.log"
  if "$runner" oci execute "$bundle" "$result_output" >"$execute_log" 2>&1; then
    fail "$fixture unexpectedly completed without its required assertion"
  else
    status=$?
  fi
  [ "$status" -ne 0 ] || fail "$fixture returned a zero failure status"
  grep -F "$marker" "$execute_log" >/dev/null ||
    fail "$fixture failed without exact assertion marker $marker"
  assertion_lines=$(grep -F "$marker" "$execute_log" | wc -l | tr -d ' ')
  [ "$assertion_lines" -ge 1 ] || fail "$fixture assertion marker count is zero"
  record "NEGATIVE\t$fixture\tstatus=$status\tmarker=$marker\tresult=expected-failure"
  for artifact in design.lcir names.lcnm manifest.json harness.cpp stimulus.tsv expected-failure.txt; do
    [ -f "$bundle/$artifact" ] || fail "$fixture is missing $artifact"
    record "ARTIFACT\t$fixture\t$artifact\tsha256\t$(sha256_file "$bundle/$artifact")\tnegative-bundles/$fixture/$artifact"
  done
  for source_relative in $(jq -r '.sources[]' "$bundle/manifest.json"); do
    record "ARTIFACT\t$fixture\trtl\tsha256\t$(sha256_file "$bundle/$source_relative")\tnegative-bundles/$fixture/$source_relative"
  done
  executable="$result_output/obj_dir/Vlunachip_model"
  [ -x "$executable" ] || fail "$fixture compiled executable is absent"
  record "ARTIFACT\t$fixture\tverilator-lint-log\tsha256\t$(sha256_file "$fixture_logs/lint.log")\tlogs/$fixture/lint.log"
  record "ARTIFACT\t$fixture\tverilator-build-log\tsha256\t$(sha256_file "$fixture_logs/build.log")\tlogs/$fixture/build.log"
  record "ARTIFACT\t$fixture\tverilator-execute-log\tsha256\t$(sha256_file "$execute_log")\tlogs/$fixture/execute.log"
  record "ARTIFACT\t$fixture\texecutable\tsha256\t$(sha256_file "$executable")\tnegative-results/$fixture/obj_dir/Vlunachip_model"
  negative_count=$((negative_count + 1))
done
[ "$negative_count" -eq 2 ] || fail "locked negative fixture count changed to $negative_count"
record 'COVERAGE\twhole-write,masked-write,read-old,read-new,no-change,undefined-collision-recovery,undefined-bounds-recovery,fault-bounds-expected-failure,enables,lower-port-id-per-granule-wins,reject-collision-expected-failure'
record 'LIMITATION\tUndefined X payload is intentionally hidden by a known validity mux because two-state Verilator cannot independently validate X; recovery and committed state are compared on following cycles'
git_head_end=$(git rev-parse HEAD)
git_status_digest_end=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
snapshot_repository "$run_root/repository-inputs.end.sha256"
repository_inputs_end_sha=$(sha256_file "$run_root/repository-inputs.end.sha256")
[ "$git_head" = "$git_head_end" ] || fail "git HEAD changed during the gate"
[ "$git_status_digest" = "$git_status_digest_end" ] || fail "git status changed during the gate"
cmp -s "$run_root/repository-inputs.start.sha256" "$run_root/repository-inputs.end.sha256" ||
  fail "repository inputs drifted during the gate"
record "REPOSITORY_INPUTS_END_SHA256\t$repository_inputs_end_sha"
record "RECHECK\tgit-head=$git_head_end\tgit-status-sha256=$git_status_digest_end\trepository-inputs=$repository_inputs_end_sha"
record "ARTIFACT\tglobal\trepository-inputs-start\tsha256\t$repository_inputs_start_sha\trepository-inputs.start.sha256"
record "ARTIFACT\tglobal\trepository-inputs-end\tsha256\t$repository_inputs_end_sha\trepository-inputs.end.sha256"
evidence_passing="$run_root/.phase4-memory-evidence.pass.$$"
awk 'NR == 2 { print "STATE pass"; next } { print }' \
  "$evidence_incomplete" >"$evidence_passing"
mv "$evidence_passing" "$evidence_final"
rm "$evidence_incomplete"
evidence_digest=$(sha256_file "$evidence_final")
echo "Phase 4 memory differential gate passes: 8 positive fixtures, $negative_count expected-failure fixtures, $total_cycles post-reset cycles"
echo "Evidence: $evidence_final"
echo "Evidence sha256:$evidence_digest"
