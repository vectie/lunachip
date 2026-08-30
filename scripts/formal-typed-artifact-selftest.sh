#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-manifest-lib.sh"
. "$repo_dir/scripts/formal-typed-artifact-lib.sh"

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

write_outputs_manifest() {
  output=$1
  {
    printf '%s  %s\n' \
      "$(lc_evidence_sha256_file "$output/provenance.txt")" provenance.txt
    printf '%s  %s\n' \
      "$(lc_evidence_sha256_file "$output/task-work/engine_0/trace.vcd")" \
      task-work/engine_0/trace.vcd
    printf '%s  %s\n' \
      "$(lc_evidence_sha256_file "$output/task-work/status")" \
      task-work/status
    printf '%s  %s\n' \
      "$(lc_evidence_sha256_file "$output/tool-versions.txt")" \
      tool-versions.txt
  } >"$output/outputs.sha256"
}

write_receipt() {
  bundle=$1
  output=$2
  evidence_sha=$(lc_evidence_sha256_file \
    "$output/task-work/engine_0/trace.vcd")
  printf '%s\n' \
    'LUNACHIP-PHASE4-FORMAL-RECEIPT 1' \
    "EXECUTION-MANIFEST sha256 $(lc_evidence_sha256_file "$bundle/task.lcfg")" \
    'RUNNER-EXIT 0' \
    "RESULT sha256 $(lc_evidence_sha256_file "$output/result.lcfr")" \
    "STATUS sby/status sha256 $(lc_evidence_sha256_file "$output/task-work/status")" \
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
  mkdir -p "$bundle" "$output/task-work/engine_0"
  printf '%s\n' 'LUNACHIP-PHASE5-FORMAL-EXECUTION 1' >"$bundle/task.lcfg"
  printf '%s\n' PASS >"$output/task-work/status"
  printf '%s\n' 'Yosys 0.68' 'SBY v0.68' 'Bitwuzla 0.9.1' \
    >"$output/tool-versions.txt"
  printf '%s\n' locked-oci-provider >"$output/provenance.txt"
  printf '%s\n' canonical-trace >"$output/task-work/engine_0/trace.vcd"
  evidence_sha=$(lc_evidence_sha256_file \
    "$output/task-work/engine_0/trace.vcd")
  printf '%s\n' \
    'LUNACHIP-FORMAL-RESULT 1' \
    'RESULT counterexample' \
    "COUNTEREXAMPLE artifact 74726163652e766364 sha256 $evidence_sha" \
    'WITNESS none' \
    END >"$output/result.lcfr"
  write_outputs_manifest "$output"
  write_receipt "$bundle" "$output"
}

scratch=$(mktemp -d /tmp/lunachip-formal-typed-artifact-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
zero=0000000000000000000000000000000000000000000000000000000000000000

clean="$scratch/clean"
make_fixture "$clean"
lc_formal_verify_typed_artifacts "$clean/bundle" task "$clean/output" ||
  fail "clean typed artifacts did not verify"

tampered_result="$scratch/tampered-result"
make_fixture "$tampered_result"
printf '%s\n' forged >>"$tampered_result/output/result.lcfr"
expect_failure tampered-result lc_formal_verify_typed_artifacts \
  "$tampered_result/bundle" task "$tampered_result/output"

receipt_binding="$scratch/receipt-binding"
make_fixture "$receipt_binding"
awk -v zero="$zero" \
  '$1 == "RESULT" { print "RESULT sha256 " zero; next } { print }' \
  "$receipt_binding/output/receipt.lcfe" \
  >"$receipt_binding/output/receipt.changed"
mv "$receipt_binding/output/receipt.changed" \
  "$receipt_binding/output/receipt.lcfe"
expect_failure receipt-binding lc_formal_verify_typed_artifacts \
  "$receipt_binding/bundle" task "$receipt_binding/output"

outputs_entry="$scratch/outputs-entry"
make_fixture "$outputs_entry"
awk -v zero="$zero" 'NR == 1 { sub(/^[0-9a-f]+/, zero) } { print }' \
  "$outputs_entry/output/outputs.sha256" \
  >"$outputs_entry/output/outputs.changed"
mv "$outputs_entry/output/outputs.changed" \
  "$outputs_entry/output/outputs.sha256"
write_receipt "$outputs_entry/bundle" "$outputs_entry/output"
expect_failure outputs-entry lc_formal_verify_typed_artifacts \
  "$outputs_entry/bundle" task "$outputs_entry/output"

outputs_artifact="$scratch/outputs-artifact"
make_fixture "$outputs_artifact"
printf '%s\n' forged >>"$outputs_artifact/output/provenance.txt"
write_receipt "$outputs_artifact/bundle" "$outputs_artifact/output"
expect_failure outputs-artifact lc_formal_verify_typed_artifacts \
  "$outputs_artifact/bundle" task "$outputs_artifact/output"

unsafe_path="$scratch/unsafe-path"
make_fixture "$unsafe_path"
printf '%s  %s\n' "$zero" ../escape >>"$unsafe_path/output/outputs.sha256"
write_receipt "$unsafe_path/bundle" "$unsafe_path/output"
expect_failure unsafe-path lc_formal_verify_typed_artifacts \
  "$unsafe_path/bundle" task "$unsafe_path/output"

evidence_mismatch="$scratch/evidence-mismatch"
make_fixture "$evidence_mismatch"
awk -v zero="$zero" \
  '$1 == "COUNTEREXAMPLE" { $5 = zero } { print }' \
  "$evidence_mismatch/output/result.lcfr" \
  >"$evidence_mismatch/output/result.changed"
mv "$evidence_mismatch/output/result.changed" \
  "$evidence_mismatch/output/result.lcfr"
write_receipt "$evidence_mismatch/bundle" "$evidence_mismatch/output"
expect_failure evidence-result-mismatch lc_formal_verify_typed_artifacts \
  "$evidence_mismatch/bundle" task "$evidence_mismatch/output"

printf '%s\n' 'Formal typed-artifact self-tests pass'
