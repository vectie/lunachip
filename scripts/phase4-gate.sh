#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
verilator_mount_mode=${LUNACHIP_VERILATOR_MOUNT_MODE-volume}
yosys_mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}
export LUNACHIP_VERILATOR_MOUNT_MODE="$verilator_mount_mode"
export LUNACHIP_YOSYS_MOUNT_MODE="$yosys_mount_mode"

fail() {
  echo "phase4-gate: $*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail "git is required"
command -v moon >/dev/null 2>&1 || fail "moon is required"
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
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

verify_manifest() {
  root=$1
  manifest=$2
  count=0
  while IFS='  ' read -r expected relative; do
    [ -n "$expected" ] || fail "empty digest in $manifest"
    [ -n "$relative" ] || fail "empty path in $manifest"
    case "$relative" in
      /* | ../* | */../* | */..) fail "unsafe path in $manifest: $relative" ;;
    esac
    [ -f "$root/$relative" ] || fail "manifest artifact is absent: $relative"
    observed=$(sha256_file "$root/$relative")
    [ "$observed" = "$expected" ] || fail "manifest digest mismatch: $relative"
    count=$((count + 1))
  done <"$manifest"
  [ "$count" -gt 0 ] || fail "empty artifact manifest: $manifest"
}

run_logged() {
  log=$1
  step=$2
  shift 2
  if "$@" >"$log" 2>&1; then
    record "COMMAND\t$step\tstatus=0"
  else
    status=$?
    record "COMMAND\t$step\tstatus=$status"
    tail -n 100 "$log" >&2
    fail "$step failed with status $status; log retained at $log"
  fi
}

assert_one_state_pass() {
  evidence=$1
  [ "$(grep -c '^STATE ' "$evidence")" -eq 1 ] ||
    fail "$evidence does not contain exactly one state"
  grep -Fx 'STATE pass' "$evidence" >/dev/null ||
    fail "$evidence is not passing evidence"
}

[ "$#" -le 1 ] || fail "usage: $0 [EMPTY_RUN_ROOT]"
if [ "$#" -eq 0 ]; then
  run_root=$(mktemp -d "${TMPDIR:-/tmp}/lunachip-phase4-gate.XXXXXX")
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

logs_root="$run_root/logs"
mkdir "$logs_root"
evidence_incomplete="$run_root/phase4-evidence.incomplete"
evidence_final="$run_root/phase4-evidence.txt"
printf '%s\n' 'LUNACHIP-PHASE4-EVIDENCE 1' 'STATE incomplete' >"$evidence_incomplete"
record() { printf '%s\n' "$1" >>"$evidence_incomplete"; }

cd "$repo_dir"
git_head_start=$(git rev-parse HEAD)
snapshot_repository "$run_root/repository-inputs.start.sha256"
repository_inputs_start_sha=$(sha256_file "$run_root/repository-inputs.start.sha256")
record "GIT_HEAD\t$git_head_start"
record "REPOSITORY_INPUTS_START_SHA256\t$repository_inputs_start_sha"
record "TRANSPORT\tverilator=$verilator_mount_mode\tyosys=$yosys_mount_mode"

run_logged "$logs_root/codec.log" codec \
  moon test ir/codec --target native --deny-warn
grep -E '^Total tests: [1-9][0-9]*, passed: [1-9][0-9]*, failed: 0\.$' \
  "$logs_root/codec.log" >/dev/null || fail "codec gate did not report a clean test set"
run_logged "$logs_root/native.log" native "$repo_dir/scripts/phase-gate.sh"
grep -F 'LunaChip dependency and source-size boundaries pass' \
  "$logs_root/native.log" >/dev/null || fail "dependency boundary result is absent"
run_logged "$logs_root/verilator-selftest.log" verilator-selftest \
  "$repo_dir/scripts/phase3-verilator-selftest.sh"
run_logged "$logs_root/yosys-selftest.log" yosys-selftest \
  "$repo_dir/scripts/phase4-yosys-selftest.sh"

run_logged "$logs_root/memory.log" memory-differential \
  "$repo_dir/scripts/phase4-memory-differential-gate.sh" "$run_root/memory"
memory_evidence="$run_root/memory/phase4-memory-evidence.txt"
assert_one_state_pass "$memory_evidence"
grep -F 'CYCLES\tpost-reset\t104000' "$memory_evidence" >/dev/null ||
  fail "memory evidence has the wrong cycle total"
grep -F 'COMPARISON\tequal\tfixtures=8' "$memory_evidence" >/dev/null ||
  fail "memory evidence has the wrong positive fixture result"
grep -F 'NEGATIVE\tfault-out-of-bounds\t' "$memory_evidence" |
  grep -F 'marker=lc_mem0_read0_bounds' |
  grep -F 'result=expected-failure' >/dev/null ||
  fail "enabled out-of-bounds assertion evidence is absent"
grep -F 'NEGATIVE\tdynamic-reject-collision\t' "$memory_evidence" |
  grep -F 'marker=lc_mem0_write0_write1_collision' |
  grep -F 'result=expected-failure' >/dev/null ||
  fail "dynamic Reject assertion evidence is absent"
grep -F 'RECHECK\t' "$memory_evidence" >/dev/null ||
  fail "memory source-drift recheck is absent"

run_logged "$logs_root/synthesis.log" synthesis \
  "$repo_dir/scripts/phase4-yosys-synthesis-gate.sh" "$run_root/synthesis"
synthesis_evidence="$run_root/synthesis/phase4-yosys-synthesis-evidence.txt"
assert_one_state_pass "$synthesis_evidence"
grep -F 'MATRIX\tfixtures=9\tinference-eligible=7\tmultiwrite-observe-only=2' \
  "$synthesis_evidence" >/dev/null || fail "synthesis matrix result is absent"
grep -F 'RESULT\tall-required-pre-map-memory-cells-retained\tphysical-ram-claim=false' \
  "$synthesis_evidence" >/dev/null || fail "synthesis claim boundary is absent"
grep -F 'RECHECK\t' "$synthesis_evidence" >/dev/null ||
  fail "synthesis source-drift recheck is absent"

run_logged "$logs_root/formal.log" formal \
  "$repo_dir/scripts/phase4-formal-gate.sh" "$run_root/formal"
formal_manifest="$run_root/formal/evidence.sha256"
[ -f "$formal_manifest" ] || fail "formal evidence manifest is absent"
verify_manifest "$run_root/formal" "$formal_manifest"
grep -Fx 'DRIFT none' "$run_root/formal/repository-identity.txt" >/dev/null ||
  fail "formal source-drift result is absent"
for broken in broken-bounds broken-fifo-data broken-response-protocol; do
  result="$run_root/formal/results/$broken/$broken-bmc/result.lcfr"
  grep -Fx 'RESULT counterexample' "$result" >/dev/null ||
    fail "$broken did not retain the required counterexample"
  grep -E '^COUNTEREXAMPLE artifact [0-9a-f]+ sha256 [0-9a-f]{64}$' \
    "$result" >/dev/null || fail "$broken counterexample identity is absent"
done
grep -Fx 'RESULT bounded-pass' \
  "$run_root/formal/results/valid-fifo/valid-fifo-bmc/result.lcfr" >/dev/null ||
  fail "valid FIFO bounded result is absent"
grep -Fx 'RESULT cover-witness' \
  "$run_root/formal/results/valid-fifo/valid-fifo-cover/result.lcfr" >/dev/null ||
  fail "valid FIFO cover witness is absent"
grep -Fx 'RESULT proved' \
  "$run_root/formal/results/valid-fifo/valid-fifo-prove/result.lcfr" >/dev/null ||
  fail "valid FIFO unbounded proof is absent"

git_head_end=$(git rev-parse HEAD)
snapshot_repository "$run_root/repository-inputs.end.sha256"
repository_inputs_end_sha=$(sha256_file "$run_root/repository-inputs.end.sha256")
[ "$git_head_start" = "$git_head_end" ] || fail "git HEAD drifted during Phase 4"
cmp -s "$run_root/repository-inputs.start.sha256" "$run_root/repository-inputs.end.sha256" ||
  fail "repository inputs drifted during Phase 4"

(
  cd "$run_root"
  find formal logs memory synthesis -type f -print
  printf '%s\n' repository-inputs.start.sha256 repository-inputs.end.sha256
) | sort |
  while IFS= read -r artifact; do
    printf '%s  %s\n' "$(sha256_file "$run_root/$artifact")" "$artifact"
  done >"$run_root/artifacts.sha256"
verify_manifest "$run_root" "$run_root/artifacts.sha256"
artifacts_manifest_sha=$(sha256_file "$run_root/artifacts.sha256")
memory_evidence_sha=$(sha256_file "$memory_evidence")
synthesis_evidence_sha=$(sha256_file "$synthesis_evidence")
formal_manifest_sha=$(sha256_file "$formal_manifest")

record "REPOSITORY_INPUTS_END_SHA256\t$repository_inputs_end_sha"
record "RECHECK\tgit-head=$git_head_end\trepository-inputs=$repository_inputs_end_sha"
record "CHILD\tmemory\tsha256\t$memory_evidence_sha\tmemory/phase4-memory-evidence.txt"
record "CHILD\tsynthesis\tsha256\t$synthesis_evidence_sha\tsynthesis/phase4-yosys-synthesis-evidence.txt"
record "CHILD\tformal\tsha256\t$formal_manifest_sha\tformal/evidence.sha256"
record "ARTIFACTS\tsha256\t$artifacts_manifest_sha\tartifacts.sha256"
record 'CLAIM\t1\tcodec-schema-1-2-byte-stability-and-schema-3-memory-policies'
record 'CLAIM\t2\tlunawave-verilator-memory-agreement-and-two-external-assertion-failures'
record 'CLAIM\t3\tpinned-yosys-nine-fixture-synthesis-matrix'
record 'CLAIM\t4\tfifo-bounded-safety-and-selected-unbounded-proof'
record 'CLAIM\t5\tthree-broken-formal-counterexamples-retained'
record 'CLAIM\t6\tall-child-input-output-and-comparison-artifacts-content-digested'
record 'CLAIM\t7\twarning-strict-native-and-dependency-boundary-gates'
record 'CLAIM-BOUNDARY\tno-fpga-no-timing-closure-no-physical-ram-no-silicon'
record 'END'

evidence_passing="$run_root/.phase4-evidence.pass.$$"
awk 'NR == 2 { print "STATE pass"; next } { print }' \
  "$evidence_incomplete" >"$evidence_passing"
mv "$evidence_passing" "$evidence_final"
rm "$evidence_incomplete"
evidence_sha=$(sha256_file "$evidence_final")
echo "Phase 4 aggregate gate passes all seven contract claims"
echo "Evidence: $evidence_final"
echo "Evidence sha256:$evidence_sha"
