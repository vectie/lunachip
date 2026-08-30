#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"

gate="$repo_dir/scripts/phase5-synchronizer-formal-gate.sh"
receipt_selftest="$repo_dir/scripts/evidence-receipt-selftest.sh"
typed_selftest="$repo_dir/scripts/formal-typed-artifact-selftest.sh"
header='LUNACHIP-PHASE5-SYNCHRONIZER-FORMAL-EVIDENCE 1'
records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,TIMING,CLAIM,BUNDLES,COUNTEREXAMPLE,RESULTS,MATRIX,RECHECK,ARTIFACTS'

fail() {
  printf '%s\n' "phase5-synchronizer-formal-selftest: $*" >&2
  exit 1
}

require_gate_text() {
  grep -F "$1" "$gate" >/dev/null || fail "$2"
}

scratch=$(mktemp -d /tmp/lunachip-phase5-sync-formal-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

# Reuse the shared adversarial suites for receipt/manifest grammar and every
# typed formal result, receipt, output-manifest, and evidence binding.
"$receipt_selftest" >/dev/null
"$typed_selftest" >/dev/null

require_gate_text "allowed_records='$records'" \
  'gate allowed receipt records drifted'
require_gate_text "required_records='$records'" \
  'gate required receipt records drifted'
require_gate_text 'mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-volume}' \
  'gate no longer defaults to volume transport'
require_gate_text 'require_volume "$mount_mode"' \
  'gate no longer rejects non-volume transport'
require_gate_text '"$artifact_cli" "$bundle" "$task" "$output"' \
  'gate no longer independently verifies typed task artifacts'
require_gate_text 'lc_evidence_receipt_seal' \
  'gate no longer seals strict incomplete evidence'
require_gate_text 'lc_evidence_receipt_publish_pass' \
  'gate no longer atomically publishes pass evidence'
require_gate_text 'lc_evidence_create_artifact_manifest "$artifacts"' \
  'gate no longer creates its complete artifact manifest'

# Every directly executed helper, selftest, runner boundary, and shared
# library must be represented in the PIN record and independently rehashed.
for binding in \
  'runner=$runner_sha' \
  'validator=$validator_sha' \
  'artifact-cli=$cli_sha' \
  'registry-selftest=$registry_sha' \
  'synchronizer-selftest=$sync_selftest_sha' \
  'runner-selftest=$runner_selftest_sha' \
  'receipt-selftest=$receipt_selftest_sha' \
  'typed-artifact-selftest=$typed_selftest_sha' \
  'receipt-lib=$receipt_lib_sha' \
  'manifest-lib=$manifest_lib_sha' \
  'typed-artifact-lib=$typed_lib_sha' \
  'shard-lib=$shard_lib_sha' \
  'footprint-lib=$footprint_lib_sha' \
  'gate=$gate_sha' \
  'schemas-manifest=$schemas_sha'; do
  require_gate_text "$binding" "gate PIN omits $binding"
done
for dependency in \
  artifact_cli registry_selftest sync_selftest runner_selftest \
  receipt_selftest typed_artifact_selftest receipt_lib manifest_lib \
  typed_artifact_lib shard_lib footprint_lib gate; do
  count=$(grep -Fc "lc_evidence_sha256_file \"\$$dependency\"" "$gate")
  [ "$count" -eq 2 ] ||
    fail "$dependency must be hashed initially and during recheck"
done
require_gate_text 'lc_evidence_verify_manifest "$repo_dir/toolchain/yosys"' \
  'gate does not recheck its complete schema manifest'
require_gate_text 'lc_evidence_verify_manifest "$bundles"' \
  'gate does not recheck its generated bundle manifest'

require_gate_text \
  'fixed=lc_p4_b706970656c696e655f6d6174636865735f70726576696f75735f64657374696e6174696f6e5f73616d706c6573' \
  'pipeline fixed-label binding drifted'
require_gate_text \
  'fixed=lc_p6_b6f75747075745f6368616e6765735f6f6e6c795f6f6e5f64657374696e6174696f6e5f65646765' \
  'destination-edge fixed-label binding drifted'
require_gate_text \
  'fixed=lc_p7_b737461626c655f736f757263655f636f6e7665726765735f77697468696e5f74687265655f64657374696e6174696f6e5f6564676573' \
  'convergence fixed-label binding drifted'
require_gate_text \
  'record MATRIX fixtures=4 tasks=5 passes=1 covers=1 counterexamples=3' \
  'exact public formal matrix binding drifted'

# A bind-mode preflight fails before any Docker command, retains its failure
# status in incomplete evidence, and cannot leave a false pass receipt.
mkdir "$scratch/fake-bin" "$scratch/bind-run"
ln -s "$(command -v false)" "$scratch/fake-bin/docker"
if PATH="$scratch/fake-bin:$PATH" LUNACHIP_YOSYS_MOUNT_MODE=bind \
  "$gate" "$scratch/bind-run" >/dev/null 2>&1; then
  fail "gate accepted non-volume transport"
fi
incomplete="$scratch/bind-run/phase5-synchronizer-formal-evidence.incomplete"
final="$scratch/bind-run/phase5-synchronizer-formal-evidence.txt"
[ -f "$incomplete" ] && [ ! -L "$incomplete" ] ||
  fail "failed preflight did not retain regular incomplete evidence"
[ ! -e "$final" ] && [ ! -L "$final" ] ||
  fail "failed preflight published false pass evidence"
grep -Fx "$header" "$incomplete" >/dev/null ||
  fail "retained evidence header drifted"
grep -Fx 'STATE incomplete' "$incomplete" >/dev/null ||
  fail "retained evidence state drifted"
grep -Fx 'COMMAND preflight-volume status=1' "$incomplete" >/dev/null ||
  fail "failed transport preflight status was not recorded"
if grep -Eq '^(COMMAND docker-context |STATE pass$|END$)' "$incomplete"; then
  fail "failed transport preflight advanced beyond its safe boundary"
fi

# The retained prefix itself must use the strict command grammar. Seal a copy
# with the reduced record set because the full required gate records cannot
# exist after an intentionally failed preflight.
retained="$scratch/retained-prefix.incomplete"
cp "$incomplete" "$retained"
printf '%s\n' END >>"$retained"
lc_evidence_validate_receipt \
  "$retained" "$header" incomplete COMMAND COMMAND ||
  fail "retained failed-preflight receipt prefix is not strict"

printf '%s\n' \
  'Phase 5 synchronizer formal self-tests pass: strict lifecycle and dependency bindings'
