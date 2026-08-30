#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
runner="$repo_dir/scripts/phase3-verilator-run.sh"
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
selftest="$repo_dir/scripts/phase5-handshake-differential-selftest.sh"
lock_file="$repo_dir/toolchain/verilator/lock.json"
mount_mode=$(printenv LUNACHIP_VERILATOR_MOUNT_MODE || true)
[ -n "$mount_mode" ] || mount_mode=bind

fail() {
  echo "phase5-handshake-differential-gate: $*" >&2
  exit 1
}

command -v moon >/dev/null 2>&1 || fail "moon is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v git >/dev/null 2>&1 || fail "git is required"
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
        relative=$(printf '%s\n' "$source" | sed 's#^\./##')
        printf '%s  %s\n' "$(sha256_file "$source")" "$relative"
      done
  ) >"$destination"
}
case "$mount_mode" in bind|volume) ;; *) fail "invalid Verilator mount mode" ;; esac
[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"

if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d /tmp/lunachip-phase5-handshake-differential.XXXXXX)
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
    [ ! -L "$parent" ] || fail "run-root parent must not be a symbolic link"
    parent=$(CDPATH= cd -- "$parent" && pwd)
    run_root="$parent/$name"
    [ "$run_root" != / ] || fail "refusing filesystem root"
    mkdir "$run_root"
  fi
fi
case "$run_root/" in "$repo_dir/"*) fail "run root must be outside repository" ;; esac

bundles="$run_root/bundles"
negative_bundles="$run_root/negative-bundles"
lint_root="$run_root/lint"
results="$run_root/results"
negative_results="$run_root/negative-results"
logs="$run_root/logs"
mkdir "$lint_root" "$results" "$negative_results" "$logs"
evidence="$run_root/phase5-handshake-differential-evidence.incomplete"
printf '%s\n' \
  'LUNACHIP-PHASE5-HANDSHAKE-DIFFERENTIAL-EVIDENCE 1' \
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
    fail "$label failed with status $status; incomplete evidence retained at $evidence"
  fi
}

cd "$repo_dir"
git_head=$(git rev-parse HEAD)
git_status=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
snapshot_repository "$run_root/repository.start.sha256"
repository_start=$(sha256_file "$run_root/repository.start.sha256")
lock_digest=$(sha256_file "$lock_file")
runner_digest=$(sha256_file "$runner")
validator_digest=$(sha256_file "$validator")
selftest_digest=$(sha256_file "$selftest")
gate_digest=$(sha256_file "$repo_dir/scripts/phase5-handshake-differential-gate.sh")

run_logged "$logs/lock.log" validate-lock "$validator"
run_logged "$logs/selftest.log" boundary-selftest "$selftest"
run_logged "$logs/version.log" verilator-version "$runner" oci version
run_logged "$logs/materialize.log" materialize \
  moon run cmd/phase5-handshake-differential-fixtures --target native --release -- \
  matrix "$bundles"
run_logged "$logs/materialize-negative.log" materialize-negative \
  moon run cmd/phase5-handshake-differential-fixtures --target native --release -- \
  negative "$negative_bundles"

bundle_digest=$(tree_digest "$bundles")
negative_bundle_digest=$(tree_digest "$negative_bundles")
observed_version=$(tail -n 1 "$logs/version.log")
case $(uname -m) in
  arm64|aarch64) platform=linux/arm64 ;;
  x86_64|amd64) platform=linux/amd64 ;;
  *) fail "unsupported OCI architecture" ;;
esac
repository=$(jq -r '.providers.oci.repository' "$lock_file")
image_digest=$(jq -r --arg platform "$platform" \
  '.providers.oci.platforms[] | select(.platform == $platform) | .digest' \
  "$lock_file")
record "GIT_HEAD\t$git_head"
record "GIT_STATUS_SHA256\t$git_status"
record "REPOSITORY_INPUTS_START_SHA256\t$repository_start"
record "TOOL\t$observed_version"
record "PROVIDER\toci\tplatform=$platform\timage=$repository@$image_digest"
record "TRANSPORT\tworkspace=$mount_mode"
record "PIN\tlock=$lock_digest\trunner=$runner_digest\tvalidator=$validator_digest\tselftest=$selftest_digest\tgate=$gate_digest"
record "CLAIM-BOUNDARY\ttwo-state-handshake=true\tatomic-coincident-edges=true\texact-rational-time=true\treset-flush-loss-classified=true\tplacement=false\tmetastability=false\tmtbf=false\trecovery-removal=false\ttiming-closure=false"

fixtures='directed-2-stage-scalar rational-3-stage-multi-leaf coincident-4-stage-refill coordinated-reset-unilateral-flush seeded-rational-stream'
event_total=0
coincidence_total=0
fixture_count=0
for fixture in $fixtures; do
  bundle="$bundles/$fixture"
  lint="$lint_root/$fixture"
  output="$results/$fixture"
  fixture_logs="$logs/$fixture"
  mkdir "$lint" "$output" "$fixture_logs"
  run_logged "$fixture_logs/manifest.log" "validate-manifest-$fixture" \
    "$validator" --harness-json "$bundle/manifest.json"
  run_logged "$fixture_logs/stimulus.log" "validate-stimulus-$fixture" \
    "$validator" --stimulus-tsv "$bundle/manifest.json" "$bundle/stimulus.tsv"
  run_logged "$fixture_logs/lint.log" "lint-$fixture" \
    "$runner" oci lint "$bundle" "$lint"
  run_logged "$fixture_logs/build.log" "build-$fixture" \
    "$runner" oci build "$bundle" "$output"
  run_logged "$fixture_logs/execute.log" "execute-$fixture" \
    "$runner" oci execute "$bundle" "$output"
  run_logged "$fixture_logs/compare.log" "compare-$fixture" \
    moon run cmd/phase5-handshake-differential-fixtures --target native --release -- \
    verify "$fixture" "$output/actual.tsv"
  events=$(awk -F '\t' '$1 == "EVENTS" { print $2 }' "$bundle/stimulus.tsv")
  coincidences=$(awk -F '\t' '$1 == "EVENT" && $6 == 2 { count++ } END { print count + 0 }' "$bundle/stimulus.tsv")
  event_total=$((event_total + events))
  coincidence_total=$((coincidence_total + coincidences))
  fixture_count=$((fixture_count + 1))
  evidence_class=$(sed -n '1p' "$bundle/evidence-class.txt")
  record "FIXTURE\t$fixture\tevents=$events\tcoincidences=$coincidences\tclass=$evidence_class\tresult=equal"
  record "BUNDLE\t$fixture\tsha256=$(tree_digest "$bundle")"
  record "RESULT\t$fixture\tsha256=$(sha256_file "$output/actual.tsv")"
done
[ "$fixture_count" -eq 5 ] || fail "fixture count drifted"
[ "$event_total" -eq 295 ] || fail "event total drifted to $event_total"
[ "$coincidence_total" -eq 45 ] || fail "coincidence total drifted to $coincidence_total"

negative="$negative_bundles/coincident-sequential-negative"
negative_output="$negative_results/coincident-sequential-negative"
negative_lint="$lint_root/coincident-sequential-negative"
negative_logs="$logs/coincident-sequential-negative"
mkdir "$negative_output" "$negative_lint" "$negative_logs"
run_logged "$negative_logs/manifest.log" validate-manifest-negative \
  "$validator" --harness-json "$negative/manifest.json"
run_logged "$negative_logs/stimulus.log" validate-stimulus-negative \
  "$validator" --stimulus-tsv "$negative/manifest.json" "$negative/stimulus.tsv"
run_logged "$negative_logs/lint.log" lint-negative \
  "$runner" oci lint "$negative" "$negative_lint"
run_logged "$negative_logs/build.log" build-negative \
  "$runner" oci build "$negative" "$negative_output"
run_logged "$negative_logs/execute.log" execute-negative \
  "$runner" oci execute "$negative" "$negative_output"
run_logged "$negative_logs/compare.log" compare-required-negative \
  moon run cmd/phase5-handshake-differential-fixtures --target native --release -- \
  verify-negative "$negative_output/actual.tsv"
grep -F "$(printf 'required-mismatch\ttime=40\tboundary=20\toutput=destination_valid\texpected=0\tactual=1')" \
  "$negative_logs/compare.log" >/dev/null ||
  fail "required negative mismatch identity changed"
record 'NEGATIVE\tcoincident-sequential-negative\ttime=40\tboundary=20\toutput=destination_valid\texpected=0\tactual=1'
record "NEGATIVE-BUNDLE\tsha256=$negative_bundle_digest"
record "NEGATIVE-RESULT\tsha256=$(sha256_file "$negative_output/actual.tsv")"

[ "$(tree_digest "$bundles")" = "$bundle_digest" ] ||
  fail "production bundles changed during execution"
[ "$(tree_digest "$negative_bundles")" = "$negative_bundle_digest" ] ||
  fail "negative bundle changed during execution"
[ "$(sha256_file "$lock_file")" = "$lock_digest" ] || fail "lock changed"
[ "$(sha256_file "$runner")" = "$runner_digest" ] || fail "runner changed"
[ "$(sha256_file "$validator")" = "$validator_digest" ] || fail "validator changed"
[ "$(sha256_file "$selftest")" = "$selftest_digest" ] || fail "selftest changed"
[ "$(sha256_file "$repo_dir/scripts/phase5-handshake-differential-gate.sh")" = "$gate_digest" ] ||
  fail "gate changed"
final_head=$(git rev-parse HEAD)
final_status=$(git status --porcelain=v1 --untracked-files=all | sort | sha256_stdin)
snapshot_repository "$run_root/repository.end.sha256"
repository_end=$(sha256_file "$run_root/repository.end.sha256")
[ "$final_head" = "$git_head" ] || fail "git HEAD changed during gate"
[ "$final_status" = "$git_status" ] || fail "git status changed during gate"
cmp -s "$run_root/repository.start.sha256" "$run_root/repository.end.sha256" ||
  fail "repository snapshot changed during gate"

record 'MATRIX\tfixtures=5\tstages=2,3,4\tevents=295\tcoincidences=45\tmulti-leaf=true\tfixed-seed=0x5eed1234\treset-flush-loss=explicit'
record 'RESULT\tatomic-LunaWave-equals-pinned-Verilator\tfixtures=5\tnegative-bridge=required-mismatch'
record "RECHECK\tgit-head=$final_head\tgit-status-sha256=$final_status\trepository-inputs=$repository_end"
passing="$run_root/.phase5-handshake-differential-evidence.pass.$$"
awk 'NR == 2 { print "STATE pass"; next } { print }' "$evidence" >"$passing"
final="$run_root/phase5-handshake-differential-evidence.txt"
mv "$passing" "$final"
rm "$evidence"
echo "Phase 5 toggle-handshake differential gate passes: 5 fixtures, $event_total exact-time events"
echo "Evidence: $final"
echo "Evidence sha256:$(sha256_file "$final")"
