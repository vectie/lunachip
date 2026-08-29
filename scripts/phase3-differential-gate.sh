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
  echo "phase3-differential-gate: $*" >&2
  exit 1
}

usage() {
  fail "usage: $0 [EMPTY_RUN_ROOT]"
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v moon >/dev/null 2>&1 || fail "moon is required"
command -v git >/dev/null 2>&1 || fail "git is required"
case "$mount_mode" in
  bind|volume) ;;
  *) fail "LUNACHIP_VERILATOR_MOUNT_MODE must be bind or volume" ;;
esac
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
  sha256_stdin() { shasum -a 256 | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
  sha256_stdin() { sha256sum | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required"
fi

[ "$#" -le 1 ] || usage
if [ "$#" -eq 0 ]; then
  temp_parent=${TMPDIR:-/tmp}
  [ -d "$temp_parent" ] || fail "temporary parent does not exist: $temp_parent"
  [ ! -L "$temp_parent" ] || fail "temporary parent must not be a symbolic link"
  run_root=$(mktemp -d "$temp_parent/lunachip-phase3-gate.XXXXXX")
else
  requested_root=$1
  [ -n "$requested_root" ] || usage
  [ ! -L "$requested_root" ] || fail "run root must not be a symbolic link"
  if [ -e "$requested_root" ]; then
    [ -d "$requested_root" ] || fail "run root is not a directory: $requested_root"
    if find "$requested_root" -mindepth 1 -print | grep -q .; then
      fail "explicit run root must be empty: $requested_root"
    fi
    run_root=$(CDPATH= cd -- "$requested_root" && pwd)
  else
    requested_parent=$(dirname -- "$requested_root")
    requested_name=$(basename -- "$requested_root")
    [ "$requested_name" != "." ] || fail "invalid run root"
    [ "$requested_name" != ".." ] || fail "invalid run root"
    [ -d "$requested_parent" ] || fail \
      "run-root parent does not exist: $requested_parent"
    [ ! -L "$requested_parent" ] || fail \
      "run-root parent must not be a symbolic link"
    canonical_parent=$(CDPATH= cd -- "$requested_parent" && pwd)
    run_root="$canonical_parent/$requested_name"
    [ "$run_root" != "/" ] || fail "refusing to use the filesystem root"
    case "$run_root/" in
      "$repo_dir/"*) fail "run root must be outside the repository" ;;
    esac
    mkdir "$run_root"
  fi
fi

[ "$run_root" != "/" ] || fail "refusing to use the filesystem root"
case "$run_root/" in
  "$repo_dir/"*) fail "run root must be outside the repository" ;;
esac

bundles_root="$run_root/bundles"
lint_root="$run_root/lint"
results_root="$run_root/results"
mkdir "$lint_root" "$results_root"

incomplete_evidence="$run_root/phase3-evidence.incomplete"
final_evidence="$run_root/phase3-evidence.txt"
printf '%s\n' \
  'LUNACHIP-PHASE3-EVIDENCE 1' \
  'STATE incomplete' >"$incomplete_evidence"

record() {
  printf '%s\n' "$1" >>"$incomplete_evidence"
}

run_recorded() {
  step_name=$1
  canonical_command=$2
  shift 2
  if "$@"; then
    record "COMMAND\t$step_name\tstatus=0\t$canonical_command"
  else
    command_status=$?
    record "COMMAND\t$step_name\tstatus=$command_status\t$canonical_command"
    fail "$step_name failed with status $command_status; incomplete evidence retained at $incomplete_evidence"
  fi
}

cd "$repo_dir"

run_recorded \
  validate-lock \
  'scripts/phase3-verilator-validate.sh' \
  "$validator"

if observed_version=$("$runner" oci version); then
  record "COMMAND\toci-version\tstatus=0\tscripts/phase3-verilator-run.sh oci version"
else
  version_status=$?
  record "COMMAND\toci-version\tstatus=$version_status\tscripts/phase3-verilator-run.sh oci version"
  fail "pinned OCI version check failed with status $version_status; no provider fallback is permitted"
fi
case "$observed_version" in
  *'
'*) fail "Verilator version output must be one line" ;;
esac

moon_version=$(moon version | awk 'NF { if (seen) printf " | "; printf "%s", $0; seen=1 } END { print "" }')
git_head=$(git rev-parse HEAD)
git_status_digest=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
lock_digest=$(sha256_file "$lock_file")
case $(uname -m) in
  arm64|aarch64) oci_platform=linux/arm64 ;;
  x86_64|amd64) oci_platform=linux/amd64 ;;
  *) fail "unsupported OCI host architecture: $(uname -m)" ;;
esac
oci_repository=$(jq -r '.providers.oci.repository' "$lock_file")
oci_digest=$(jq -r --arg platform "$oci_platform" \
  '.providers.oci.platforms[] | select(.platform == $platform) | .digest' \
  "$lock_file")

record "MOON\t$moon_version"
record "GIT_HEAD\t$git_head"
record "GIT_STATUS_SHA256\t$git_status_digest"
record "TOOL\t$observed_version"
record "PROVIDER\toci\tplatform=$oci_platform\timage=$oci_repository@$oci_digest"
record "TRANSPORT\tworkspace=$mount_mode"
record "ARTIFACT\tglobal\tlock\tsha256\t$lock_digest\ttoolchain/verilator/lock.json"

run_recorded \
  materialize-standard \
  'moon run cmd/phase3-fixtures --target native --release -- standard $RUN_ROOT/bundles' \
  moon run cmd/phase3-fixtures --target native --release -- \
  standard "$bundles_root"

fixtures='combinational-logic arithmetic controlled-counter pipeline lfsr ready-valid'
expected_cycles_per_fixture=17000
total_cycles=0

for fixture in $fixtures; do
  bundle="$bundles_root/$fixture"
  lint_output="$lint_root/$fixture"
  result_output="$results_root/$fixture"
  manifest="$bundle/manifest.json"
  [ -d "$bundle" ] || fail "materializer omitted fixture: $fixture"
  [ ! -L "$bundle" ] || fail "fixture bundle must not be a symbolic link: $fixture"
  mkdir "$lint_output" "$result_output"

  run_recorded \
    "validate-$fixture" \
    "scripts/phase3-verilator-validate.sh --harness-json \$RUN_ROOT/bundles/$fixture/manifest.json" \
    "$validator" --harness-json "$manifest"

  [ -f "$bundle/design.lcir" ] || fail "$fixture is missing canonical IR artifact design.lcir"
  [ -f "$bundle/names.lcnm" ] || fail "$fixture is missing emitted-name manifest names.lcnm"
  [ -f "$bundle/harness.cpp" ] || fail "$fixture is missing harness.cpp"
  [ -f "$bundle/stimulus.tsv" ] || fail "$fixture is missing stimulus.tsv"
  [ -f "$bundle/expected.tsv" ] || fail "$fixture is missing expected.tsv"
  result_relative=$(jq -r '.result' "$manifest")
  [ "$result_relative" = "actual.tsv" ] || fail \
    "$fixture uses unsupported result path: $result_relative"
  top_module=$(jq -r '.top_module' "$manifest")
  sources_command=''
  for source_relative in $(jq -r '.sources[]' "$manifest"); do
    [ -f "$bundle/$source_relative" ] || fail \
      "$fixture is missing RTL source: $source_relative"
    sources_command="$sources_command /work/$source_relative"
  done

  lint_command="verilator --lint-only --language 1800-2017 --Wall -Wpedantic --no-timing --assert --top-module $top_module$sources_command"
  run_recorded \
    "lint-$fixture" \
    "$lint_command" \
    "$runner" oci lint "$bundle" "$lint_output"

  build_command="verilator --cc --exe --build --language 1800-2017 --Wall -Wpedantic --no-timing --assert --x-initial 0 --x-assign 0 --build-jobs 1 --prefix Vlunachip_model --Mdir /out/obj_dir --top-module $top_module$sources_command /work/harness.cpp"
  run_recorded \
    "build-$fixture" \
    "$build_command" \
    "$runner" oci build "$bundle" "$result_output"

  run_recorded \
    "execute-$fixture" \
    '/out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv' \
    "$runner" oci execute "$bundle" "$result_output"

  actual="$result_output/actual.tsv"
  [ -f "$actual" ] || fail "$fixture did not produce actual.tsv"
  cycle_rows=$(awk 'END { print NR - 2 }' "$actual")
  [ "$cycle_rows" -eq "$expected_cycles_per_fixture" ] || fail \
    "$fixture produced $cycle_rows post-reset rows; expected $expected_cycles_per_fixture"
  awk -F '\t' -v expected="$expected_cycles_per_fixture" '
    NR == 1 && $1 != "LUNACHIP-PHASE3-RESULT" { exit 1 }
    NR == 2 && $1 != "cycle" { exit 1 }
    NR == 3 && $1 != "1" { exit 1 }
    END { if (NR != expected + 2 || $1 != expected) exit 1 }
  ' "$actual" || fail "$fixture result does not span canonical post-reset cycles 1..$expected_cycles_per_fixture"
  total_cycles=$((total_cycles + cycle_rows))
done

[ "$total_cycles" -ge 100000 ] || fail \
  "only $total_cycles post-reset cycles were executed; at least 100000 are required"
[ "$total_cycles" -eq 102000 ] || fail \
  "standard plan cycle total changed from locked value 102000 to $total_cycles"

comparison_report="$run_root/comparison.txt"
comparison_command='moon run cmd/phase3-fixtures --target native --release -- verify-standard $RUN_ROOT/results'
if moon run cmd/phase3-fixtures --target native --release -- \
  verify-standard "$results_root" >"$comparison_report"; then
  record "COMMAND\tcompare-standard\tstatus=0\t$comparison_command"
else
  comparison_status=$?
  record "COMMAND\tcompare-standard\tstatus=$comparison_status\t$comparison_command"
  fail "compare-standard failed with status $comparison_status; incomplete evidence retained at $incomplete_evidence"
fi

record "CYCLES\tpost-reset\t$total_cycles"
record 'COMPARISON\tequal\tfixtures=6'
record "ARTIFACT\tglobal\tcomparison\tsha256\t$(sha256_file "$comparison_report")\tcomparison.txt"

for fixture in $fixtures; do
  bundle="$bundles_root/$fixture"
  result_output="$results_root/$fixture"
  manifest="$bundle/manifest.json"
  record "FIXTURE\t$fixture\tpost-reset-cycles=$expected_cycles_per_fixture"
  record "ARTIFACT\t$fixture\tir\tsha256\t$(sha256_file "$bundle/design.lcir")\tbundles/$fixture/design.lcir"
  for source_relative in $(jq -r '.sources[]' "$manifest"); do
    record "ARTIFACT\t$fixture\trtl\tsha256\t$(sha256_file "$bundle/$source_relative")\tbundles/$fixture/$source_relative"
  done
  record "ARTIFACT\t$fixture\tharness-manifest\tsha256\t$(sha256_file "$manifest")\tbundles/$fixture/manifest.json"
  record "ARTIFACT\t$fixture\tname-manifest\tsha256\t$(sha256_file "$bundle/names.lcnm")\tbundles/$fixture/names.lcnm"
  record "ARTIFACT\t$fixture\tharness\tsha256\t$(sha256_file "$bundle/harness.cpp")\tbundles/$fixture/harness.cpp"
  record "ARTIFACT\t$fixture\tstimulus\tsha256\t$(sha256_file "$bundle/stimulus.tsv")\tbundles/$fixture/stimulus.tsv"
  record "ARTIFACT\t$fixture\texpected\tsha256\t$(sha256_file "$bundle/expected.tsv")\tbundles/$fixture/expected.tsv"
  record "ARTIFACT\t$fixture\tactual\tsha256\t$(sha256_file "$result_output/actual.tsv")\tresults/$fixture/actual.tsv"
done

record 'STATE pass'
mv "$incomplete_evidence" "$final_evidence"
evidence_digest=$(sha256_file "$final_evidence")
echo "Phase 3 differential gate passes: 6 fixtures, $total_cycles post-reset cycles"
echo "Evidence: $final_evidence"
echo "Evidence sha256:$evidence_digest"
