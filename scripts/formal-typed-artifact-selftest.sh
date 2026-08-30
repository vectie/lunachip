#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"
. "$repo_dir/scripts/async-fifo-formal-shard-lib.sh"
. "$repo_dir/scripts/formal-typed-artifact-lib.sh"
artifact_cli="$repo_dir/scripts/formal-artifact-cli.sh"

fail() {
  printf '%s\n' "formal-typed-artifact-selftest: $*" >&2
  exit 1
}

expect_failure() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label unexpectedly passed"
  fi
}

verify_typed() {
  lc_formal_verify_typed_artifacts "$artifact_cli" "$@"
}

write_outputs_manifest() {
  output=$1
  (
    cd "$output"
    find . -type f ! -path './outputs.sha256' ! -path './result.lcfr' \
      ! -path './receipt.lcfe' -print | LC_ALL=C sort |
      while IFS= read -r relative; do
        printf '%s  %s\n' "$(lc_evidence_sha256_file "$relative")" \
          "${relative#./}"
      done
  ) >"$output/outputs.sha256"
}

write_receipt() {
  bundle=$1
  output=$2
  evidence_sha=$(lc_evidence_sha256_file \
    "$output/$test_task-work/engine_0/trace.vcd")
  printf '%s\n' \
    'LUNACHIP-PHASE4-FORMAL-RECEIPT 1' \
    "EXECUTION-MANIFEST sha256 $(lc_evidence_sha256_file "$bundle/$test_task.lcfg")" \
    'RUNNER-EXIT 0' \
    "RESULT sha256 $(lc_evidence_sha256_file "$output/result.lcfr")" \
    "STATUS sby/status sha256 $(lc_evidence_sha256_file "$output/$test_task-work/status")" \
    "TOOL-VERSIONS tool-versions.txt sha256 $(lc_evidence_sha256_file "$output/tool-versions.txt")" \
    "OUTPUT-DIGESTS outputs.sha256 sha256 $(lc_evidence_sha256_file "$output/outputs.sha256")" \
    "PROVENANCE provenance.txt sha256 $(lc_evidence_sha256_file "$output/provenance.txt")" \
    "EVIDENCE engine_0/trace.vcd sha256 $evidence_sha" \
    END >"$output/receipt.lcfe"
}

make_fixture() {
  fixture=$1
  bundle="$fixture/bundle"
  output="$fixture/output"
  mkdir -p "$bundle" "$output/$test_task-work/engine_0"
  cp "$template_task" "$bundle/$test_task.lcft"
  printf '%s\n' 'LUNACHIP-PHASE5-FORMAL-EXECUTION 1' \
    >"$bundle/$test_task.lcfg"
  printf '%s\n' PASS >"$output/$test_task-work/status"
  printf '%s\n' 'Yosys 0.68' 'SBY v0.68' 'Bitwuzla 0.9.1' \
    >"$output/tool-versions.txt"
  printf '%s\n' locked-oci-provider >"$output/provenance.txt"
  printf '%s\n' canonical-trace \
    >"$output/$test_task-work/engine_0/trace.vcd"
  evidence_sha=$(lc_evidence_sha256_file \
    "$output/$test_task-work/engine_0/trace.vcd")
  task_version=$(awk 'NR == 1 { print $2 }' "$bundle/$test_task.lcft")
  task_sha=$(lc_evidence_sha256_file "$bundle/$test_task.lcft")
  {
    printf '%s\n' "LUNACHIP-FORMAL-RESULT $task_version" \
      "TASK-MANIFEST sha256 $task_sha"
    sed '1d;$d' "$bundle/$test_task.lcft"
    printf '%s\n' \
      'RESULT counterexample' \
      "COUNTEREXAMPLE artifact 74726163652e766364 sha256 $evidence_sha" \
      'WITNESS none' \
      'DETAIL none' \
      END
  } >"$output/result.lcfr"
  write_outputs_manifest "$output"
  write_receipt "$bundle" "$output"
}

scratch=$(mktemp -d /tmp/lunachip-formal-typed-artifact-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
zero=0000000000000000000000000000000000000000000000000000000000000000
test_task=valid-synchronizer-bmc
moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-synchronizers "$scratch/generated" >/dev/null
template_task="$scratch/generated/valid-synchronizer/$test_task.lcft"

clean="$scratch/clean"
make_fixture "$clean"
verify_typed "$clean/bundle" "$test_task" "$clean/output" ||
  fail "clean typed artifacts did not verify"

tampered_result="$scratch/tampered-result"
make_fixture "$tampered_result"
printf '%s\n' forged >>"$tampered_result/output/result.lcfr"
expect_failure tampered-result verify_typed \
  "$tampered_result/bundle" "$test_task" "$tampered_result/output"

duplicate_result="$scratch/duplicate-result"
make_fixture "$duplicate_result"
awk '{ print } $1 == "RESULT" { print }' \
  "$duplicate_result/output/result.lcfr" \
  >"$duplicate_result/output/result.changed"
mv "$duplicate_result/output/result.changed" \
  "$duplicate_result/output/result.lcfr"
write_receipt "$duplicate_result/bundle" "$duplicate_result/output"
expect_failure duplicate-resigned-result verify_typed \
  "$duplicate_result/bundle" "$test_task" "$duplicate_result/output"

unknown_result="$scratch/unknown-result"
make_fixture "$unknown_result"
awk '/^END$/ { print "UNKNOWN forbidden" } { print }' \
  "$unknown_result/output/result.lcfr" \
  >"$unknown_result/output/result.changed"
mv "$unknown_result/output/result.changed" "$unknown_result/output/result.lcfr"
write_receipt "$unknown_result/bundle" "$unknown_result/output"
expect_failure unknown-resigned-result verify_typed \
  "$unknown_result/bundle" "$test_task" "$unknown_result/output"

contradictory_result="$scratch/contradictory-result"
make_fixture "$contradictory_result"
sed 's/^RESULT counterexample$/RESULT bounded-pass/' \
  "$contradictory_result/output/result.lcfr" \
  >"$contradictory_result/output/result.changed"
mv "$contradictory_result/output/result.changed" \
  "$contradictory_result/output/result.lcfr"
write_receipt "$contradictory_result/bundle" "$contradictory_result/output"
expect_failure contradictory-resigned-result verify_typed \
  "$contradictory_result/bundle" "$test_task" "$contradictory_result/output"

receipt_binding="$scratch/receipt-binding"
make_fixture "$receipt_binding"
awk -v zero="$zero" \
  '$1 == "RESULT" { print "RESULT sha256 " zero; next } { print }' \
  "$receipt_binding/output/receipt.lcfe" \
  >"$receipt_binding/output/receipt.changed"
mv "$receipt_binding/output/receipt.changed" \
  "$receipt_binding/output/receipt.lcfe"
expect_failure receipt-binding verify_typed \
  "$receipt_binding/bundle" "$test_task" "$receipt_binding/output"

outputs_entry="$scratch/outputs-entry"
make_fixture "$outputs_entry"
awk -v zero="$zero" 'NR == 1 { sub(/^[0-9a-f]+/, zero) } { print }' \
  "$outputs_entry/output/outputs.sha256" \
  >"$outputs_entry/output/outputs.changed"
mv "$outputs_entry/output/outputs.changed" \
  "$outputs_entry/output/outputs.sha256"
write_receipt "$outputs_entry/bundle" "$outputs_entry/output"
expect_failure outputs-entry verify_typed \
  "$outputs_entry/bundle" "$test_task" "$outputs_entry/output"

outputs_artifact="$scratch/outputs-artifact"
make_fixture "$outputs_artifact"
printf '%s\n' forged >>"$outputs_artifact/output/provenance.txt"
write_receipt "$outputs_artifact/bundle" "$outputs_artifact/output"
expect_failure outputs-artifact verify_typed \
  "$outputs_artifact/bundle" "$test_task" "$outputs_artifact/output"

unlisted_artifact="$scratch/unlisted-artifact"
make_fixture "$unlisted_artifact"
printf '%s\n' unbound >"$unlisted_artifact/output/unlisted.log"
expect_failure unlisted-artifact verify_typed \
  "$unlisted_artifact/bundle" "$test_task" "$unlisted_artifact/output"

nested_reserved="$scratch/nested-reserved"
make_fixture "$nested_reserved"
mkdir -p "$nested_reserved/output/$test_task-work/nested"
printf '%s\n' nested-result \
  >"$nested_reserved/output/$test_task-work/nested/result.lcfr"
write_outputs_manifest "$nested_reserved/output"
write_receipt "$nested_reserved/bundle" "$nested_reserved/output"
verify_typed \
  "$nested_reserved/bundle" "$test_task" "$nested_reserved/output" ||
  fail "nested reserved basename was not inventoried as ordinary output"

nested_unlisted="$scratch/nested-unlisted"
make_fixture "$nested_unlisted"
mkdir -p "$nested_unlisted/output/$test_task-work/nested"
printf '%s\n' unlisted-nested-result \
  >"$nested_unlisted/output/$test_task-work/nested/result.lcfr"
expect_failure nested-unlisted verify_typed \
  "$nested_unlisted/bundle" "$test_task" "$nested_unlisted/output"

symbolic_output="$scratch/symbolic-output"
make_fixture "$symbolic_output"
ln -s ../provenance.txt \
  "$symbolic_output/output/$test_task-work/symbolic.log"
expect_failure symbolic-output verify_typed \
  "$symbolic_output/bundle" "$test_task" "$symbolic_output/output"

if command -v mkfifo >/dev/null 2>&1; then
  fifo_output="$scratch/fifo-output"
  make_fixture "$fifo_output"
  mkfifo "$fifo_output/output/$test_task-work/engine_0/diagnostic.fifo"
  expect_failure fifo-output verify_typed \
    "$fifo_output/bundle" "$test_task" "$fifo_output/output"
fi

unsafe_path="$scratch/unsafe-path"
make_fixture "$unsafe_path"
printf '%s  %s\n' "$zero" ../escape >>"$unsafe_path/output/outputs.sha256"
write_receipt "$unsafe_path/bundle" "$unsafe_path/output"
expect_failure unsafe-path verify_typed \
  "$unsafe_path/bundle" "$test_task" "$unsafe_path/output"

evidence_mismatch="$scratch/evidence-mismatch"
make_fixture "$evidence_mismatch"
awk -v zero="$zero" \
  '$1 == "COUNTEREXAMPLE" { $5 = zero } { print }' \
  "$evidence_mismatch/output/result.lcfr" \
  >"$evidence_mismatch/output/result.changed"
mv "$evidence_mismatch/output/result.changed" \
  "$evidence_mismatch/output/result.lcfr"
write_receipt "$evidence_mismatch/bundle" "$evidence_mismatch/output"
expect_failure evidence-result-mismatch verify_typed \
  "$evidence_mismatch/bundle" "$test_task" "$evidence_mismatch/output"

printf '%s\n' 'Formal typed-artifact self-tests pass'
