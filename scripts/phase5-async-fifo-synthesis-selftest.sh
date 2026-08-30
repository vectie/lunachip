#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"
checker="$repo_dir/scripts/phase5-async-fifo-synthesis-report-check.sh"
gate="$repo_dir/scripts/phase5-async-fifo-synthesis-gate.sh"
header='LUNACHIP-PHASE5-ASYNC-FIFO-SYNTHESIS-EVIDENCE 1'
records='HEAD,STATUS_START,INPUTS_START,CONTEXT,DAEMON,PROVIDER,TRANSPORT,PIN,COMMAND,FIXTURE,INPUTS_END,STATUS_END,MATRIX,CLAIM,RECHECK,ARTIFACT_MANIFEST'

fail() {
  printf '%s\n' "phase5-async-fifo-synthesis-selftest: $*" >&2
  exit 1
}

expect_failure() {
  mutant=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$mutant unexpectedly passed"
  fi
}

scratch=$(mktemp -d /tmp/lunachip-phase5-async-fifo-synthesis-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
command -v jq >/dev/null 2>&1 || fail "jq is required"

"$repo_dir/scripts/evidence-receipt-selftest.sh" >/dev/null
grep -F "allowed_records='$records'" "$gate" >/dev/null ||
  fail "gate receipt schema drifted"
grep -F 'mount_mode=volume' "$gate" >/dev/null ||
  fail "gate no longer defaults to volume transport"
grep -F 'require_volume "$mount_mode"' "$gate" >/dev/null ||
  fail "gate no longer requires volume transport"

mkdir "$scratch/fake-bin" "$scratch/bind-run"
ln -s "$(command -v true)" "$scratch/fake-bin/docker"
if PATH="$scratch/fake-bin:$PATH" LUNACHIP_YOSYS_MOUNT_MODE=bind \
  "$gate" "$scratch/bind-run" >/dev/null 2>&1; then
  fail "gate accepted non-volume transport"
fi
bind_receipt="$scratch/bind-run/phase5-async-fifo-synthesis-evidence.incomplete"
[ -f "$bind_receipt" ] && [ ! -L "$bind_receipt" ] ||
  fail "failed preflight did not retain incomplete evidence"
grep -Fx 'STATE incomplete' "$bind_receipt" >/dev/null ||
  fail "failed preflight changed incomplete state"
grep -Fx 'COMMAND preflight-volume status=1' "$bind_receipt" >/dev/null ||
  fail "failed preflight command status was not recorded"
[ ! -e "$scratch/bind-run/phase5-async-fifo-synthesis-evidence.txt" ] ||
  fail "failed preflight published passing evidence"

moon -C "$repo_dir" run --target native --release \
  cmd/phase5-async-fifo-synthesis-fixtures -- matrix "$scratch/bundles"
observed=$(
  find "$scratch/bundles" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | LC_ALL=C sort
)
expected='async-fifo-aggregate-depth4-stages3
async-fifo-scalar-depth4-stages2
async-fifo-scalar-depth8-stages4'
[ "$observed" = "$expected" ] || fail "native fixture matrix is not exact"
for fixture in $observed; do
  inventory="$scratch/bundles/$fixture/async-fifo-role-inventory.json"
  [ -s "$inventory" ] && [ ! -L "$inventory" ] ||
    fail "$fixture inventory is absent or symbolic"
  [ "$(jq -r '.fixture' "$inventory")" = "$fixture" ] ||
    fail "$fixture inventory identity drifted"
done

fixture=async-fifo-scalar-depth4-stages2
inventory="$scratch/inventory.json"
pre_map_json="$scratch/pre-map.json"
pre_map_rtlil="$scratch/pre-map.rtlil"
lock_file="$scratch/lock.json"
printf '%s\n' '{"inventory":true}' >"$inventory"
printf '%s\n' '{"creator":"Yosys 0.68 test"}' >"$pre_map_json"
printf '%s\n' 'module \\fixture' 'end' >"$pre_map_rtlil"
printf '%s\n' '{"lock":true}' >"$lock_file"

inventory_sha="sha256:$(lc_evidence_sha256_file "$inventory")"
json_sha="sha256:$(lc_evidence_sha256_file "$pre_map_json")"
rtlil_sha="sha256:$(lc_evidence_sha256_file "$pre_map_rtlil")"
lock_sha="sha256:$(lc_evidence_sha256_file "$lock_file")"
inventory_bytes=$(wc -c <"$inventory" | tr -d ' ')
json_bytes=$(wc -c <"$pre_map_json" | tr -d ' ')
rtlil_bytes=$(wc -c <"$pre_map_rtlil" | tr -d ' ')
lock_bytes=$(wc -c <"$lock_file" | tr -d ' ')
checks='[
  "audit.identity", "audit.roles", "audit.ports", "audit.owned_state",
  "audit.registers", "audit.pipelines", "audit.transfers",
  "audit.binary_next", "audit.gray_next", "audit.full", "audit.nonempty",
  "audit.addresses", "audit.memory_shape", "audit.memory_write",
  "audit.memory_read", "audit.visible_payload", "audit.dependency_cutsets",
  "audit.crossing_fanout", "audit.payload_barriers", "audit.lane_isolation",
  "audit.graph_closure", "provenance.inventory_json",
  "provenance.pre_map_json", "provenance.pre_map_rtlil",
  "provenance.yosys_lock"
]'
passing="$scratch/passing.json"
jq -n \
  --arg fixture "$fixture" --arg inventory_sha "$inventory_sha" \
  --arg json_sha "$json_sha" --arg rtlil_sha "$rtlil_sha" \
  --arg lock_sha "$lock_sha" --argjson inventory_bytes "$inventory_bytes" \
  --argjson json_bytes "$json_bytes" --argjson rtlil_bytes "$rtlil_bytes" \
  --argjson lock_bytes "$lock_bytes" --argjson checks "$checks" '
  {
    schema_version: "lunachip.async-fifo-synthesis-evidence/v1",
    artifact_kind: "async-fifo-pre-map-final-evidence",
    fixture: $fixture, top_module: "fixture", yosys_creator: "Yosys 0.68 test",
    inputs: {
      inventory_json: {sha256:$inventory_sha, bytes:$inventory_bytes, nonempty:true},
      pre_map_json: {sha256:$json_sha, bytes:$json_bytes, nonempty:true},
      pre_map_rtlil: {sha256:$rtlil_sha, bytes:$rtlil_bytes, nonempty:true},
      yosys_lock: {sha256:$lock_sha, bytes:$lock_bytes, nonempty:true}
    },
    checks: ($checks | map({name:., status:"pass"})), issues: [],
    counts: {checks_total:25, checks_passed:25, checks_failed:0, issues:0,
      sequential_bits:26, memory_bits:52},
    claim_boundary: {pre_map_typed_graph:true, two_state_role_equivalence:true,
      owned_state_exact:true, memory_topology:true, ram_mapping:false,
      timing:false, physical_cdc:false, metastability:false,
      four_state_equivalence:false},
    result:"pass", pass:true
  }
' >"$passing"
"$checker" "$fixture" "$passing" "$inventory" "$pre_map_json" \
  "$pre_map_rtlil" "$lock_file" 26 52 >/dev/null

mutate_and_reject() {
  name=$1
  expression=$2
  mutant_file="$scratch/$name.json"
  jq "$expression" "$passing" >"$mutant_file"
  expect_failure "$name" "$checker" "$fixture" "$mutant_file" \
    "$inventory" "$pre_map_json" "$pre_map_rtlil" "$lock_file" 26 52
}
mutate_and_reject failed-result '.pass=false | .result="fail"'
mutate_and_reject failed-check '.checks[0].status="fail"'
mutate_and_reject missing-check '.checks = .checks[0:24]'
mutate_and_reject reordered-checks '.checks[0:2] |= reverse'
mutate_and_reject sequential-count '.counts.sequential_bits=27'
mutate_and_reject memory-count '.counts.memory_bits=53'
mutate_and_reject overclaim '.claim_boundary.ram_mapping=true'
mutate_and_reject extra-key '.unexpected=true'
mutate_and_reject input-digest '.inputs.pre_map_json.sha256="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"'
cp "$pre_map_json" "$scratch/tampered-pre-map.json"
printf '%s\n' '{"tampered":true}' >>"$scratch/tampered-pre-map.json"
expect_failure tampered-input "$checker" "$fixture" "$passing" "$inventory" \
  "$scratch/tampered-pre-map.json" "$pre_map_rtlil" "$lock_file" 26 52
ln -s "$passing" "$scratch/symbolic-report.json"
expect_failure symbolic-report "$checker" "$fixture" \
  "$scratch/symbolic-report.json" "$inventory" "$pre_map_json" \
  "$pre_map_rtlil" "$lock_file" 26 52

receipt="$scratch/evidence.incomplete"
lc_evidence_receipt_begin "$receipt" "$header"
for name in HEAD STATUS_START INPUTS_START CONTEXT DAEMON PROVIDER TRANSPORT PIN; do
  lc_evidence_receipt_record "$receipt" "$name" value
done
lc_evidence_receipt_record "$receipt" COMMAND selftest status=0
lc_evidence_receipt_record "$receipt" FIXTURE scalar sequential-bits=26 memory-bits=52
lc_evidence_receipt_record "$receipt" FIXTURE aggregate sequential-bits=32 memory-bits=64
lc_evidence_receipt_record "$receipt" FIXTURE deep sequential-bits=50 memory-bits=104
for name in INPUTS_END STATUS_END MATRIX CLAIM RECHECK ARTIFACT_MANIFEST; do
  lc_evidence_receipt_record "$receipt" "$name" value
done
lc_evidence_receipt_seal "$receipt" "$header" "$records" "$records"
lc_evidence_validate_receipt "$receipt" "$header" incomplete "$records" "$records"

printf '%s\n' \
  'Phase 5 async-FIFO synthesis self-tests pass: strict 3-fixture matrix and adversarial report/receipt mutants'
