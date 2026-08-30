#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/evidence-receipt-lib.sh"

gate="$repo_dir/scripts/phase5-toggle-formal-gate.sh"
receipt_selftest="$repo_dir/scripts/evidence-receipt-selftest.sh"
typed_selftest="$repo_dir/scripts/formal-typed-artifact-selftest.sh"
header='LUNACHIP-PHASE5-TOGGLE-FORMAL-EVIDENCE 1'
records='HEAD,STATUS,REPOSITORY,PIN,COMMAND,PROVENANCE,TIMING,RESET,CLAIM,BUNDLES,COUNTEREXAMPLE,RESULTS,MATRIX,RECHECK,ARTIFACTS'

fail() {
  printf '%s\n' "phase5-toggle-formal-selftest: $*" >&2
  exit 1
}

require_gate_text() {
  grep -F "$1" "$gate" >/dev/null || fail "$2"
}

selftest_root=$(mktemp -d /tmp/lunachip-toggle-formal-selftest.XXXXXX)
trap 'rm -rf "$selftest_root"' EXIT HUP INT TERM

# Reuse the shared adversarial suites for strict receipt/manifest grammar and
# canonical typed result, receipt, output, and evidence bindings.
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
  'gate no longer canonically verifies typed task artifacts'
require_gate_text 'lc_evidence_receipt_seal' \
  'gate no longer seals strict incomplete evidence'
require_gate_text 'lc_evidence_receipt_publish_pass' \
  'gate no longer atomically publishes pass evidence'
require_gate_text 'lc_evidence_create_artifact_manifest "$artifacts"' \
  'gate no longer creates its complete artifact manifest'
require_gate_text 'lc_evidence_snapshot_repository "$repo_dir" "$repository_start"' \
  'gate no longer captures the adapter source in its start repository manifest'
require_gate_text 'lc_evidence_snapshot_repository "$repo_dir" "$repository_end"' \
  'gate no longer rechecks the adapter source in its end repository manifest'
require_gate_text 'lc_evidence_create_artifact_manifest "$bundles" "$bundles_manifest"' \
  'gate no longer content-binds the adapted formal DUT bundles'

for binding in \
  'lock=$lock_sha' \
  'runner=$runner_sha' \
  'validator=$validator_sha' \
  'artifact-cli=$cli_sha' \
  'registry-selftest=$registry_sha' \
  'toggle-selftest=$toggle_selftest_sha' \
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
  lock runner validator artifact_cli registry_selftest toggle_selftest runner_selftest \
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
  'record MATRIX fixtures=9 tasks=12 passes=3 covers=3 counterexamples=6' \
  'exact public toggle matrix binding drifted'

moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-toggle-handshakes "$selftest_root/first"
moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-toggle-handshakes "$selftest_root/second"
diff -r "$selftest_root/first" "$selftest_root/second" >/dev/null ||
  fail "toggle bundles are not byte deterministic"

expected_fixtures='broken-toggle-backpressure
broken-toggle-capacity
broken-toggle-completion
broken-toggle-data-integrity
broken-toggle-duplicate
broken-toggle-source-payload
valid-toggle-record-3
valid-toggle-record-4
valid-toggle-scalar-2'
observed_fixtures=$(
  find "$selftest_root/first" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | LC_ALL=C sort
)
[ "$observed_fixtures" = "$expected_fixtures" ] ||
  fail "public fixture names drifted"
task_count=0
negative_count=0
cover_count=0
for bundle in "$selftest_root/first"/*; do
  "$repo_dir/scripts/phase4-yosys-validate.sh" \
    --job-json "$bundle/job.json" "$bundle" >/dev/null
  harness="$bundle/formal-harness.sv"
  if grep -F 'lc_dut.' "$harness" >/dev/null; then
    fail "$(basename "$bundle") retained a hierarchical DUT tap"
  fi
  dut_source=$(find "$bundle" -maxdepth 1 -type f -name '*.sv' \
    ! -name 'formal-harness.sv')
  [ -n "$dut_source" ] && [ "$(printf '%s\n' "$dut_source" | wc -l | tr -d ' ')" -eq 1 ] ||
    fail "$(basename "$bundle") must contain exactly one adapted DUT source"
  case "$(basename "$bundle")" in
    valid-toggle-scalar-2) expected_observations=5 ;;
    *) expected_observations=6 ;;
  esac
  observed_observations=0
  for role in source_accept destination_capture destination_consume \
    acknowledge_toggle held_word held_tag; do
    port="lc_formal_observe_$role"
    if [ "$role" = held_tag ] && [ "$expected_observations" -eq 5 ]; then
      if grep -F "$port" "$dut_source" >/dev/null ||
        grep -F ".$port(lc_$role)" "$harness" >/dev/null; then
        fail "scalar fixture unexpectedly exposes held_tag"
      fi
    else
      case "$role" in
        held_word) range='[7:0] ' ;;
        held_tag) range='[2:0] ' ;;
        *) range= ;;
      esac
      declaration_count=$(
        grep -Fxc "  output logic ${range}${port}," "$dut_source" || true
        grep -Fxc "  output logic ${range}${port}" "$dut_source" || true
      )
      declaration_count=$(printf '%s\n' "$declaration_count" |
        awk '{ total += $1 } END { print total + 0 }')
      assignment_count=$(grep -Ec \
        "^  assign ${port} = lc_n[0-9]+;$" "$dut_source" || true)
      harness_count=$(
        grep -Fxc "    .$port(lc_$role)," "$harness" || true
        grep -Fxc "    .$port(lc_$role)" "$harness" || true
      )
      harness_count=$(printf '%s\n' "$harness_count" |
        awk '{ total += $1 } END { print total + 0 }')
      [ "$declaration_count" -eq 1 ] ||
        fail "$(basename "$bundle") DUT declaration for $port is not exact"
      [ "$assignment_count" -eq 1 ] ||
        fail "$(basename "$bundle") DUT assignment for $port is not exact"
      [ "$harness_count" -eq 1 ] ||
        fail "$(basename "$bundle") harness does not connect $port exactly once"
      observed_observations=$((observed_observations + 1))
    fi
  done
  [ "$observed_observations" -eq "$expected_observations" ] ||
    fail "$(basename "$bundle") observation inventory drifted"
  for task_file in "$bundle"/*.lcft; do
    task=$(basename "$task_file" .lcft)
    "$repo_dir/scripts/formal-artifact-cli.sh" verify "$bundle" "$task" \
      >/dev/null
    task_count=$((task_count + 1))
    case "$task" in
      broken-toggle-*-bmc)
        expected=$(awk '$1 == "EXPECTED-FAILURE" { print $2 }' "$bundle/$task.lcfg")
        case "$(basename "$bundle")" in
          broken-toggle-backpressure)
            fixed=lc_p9_b64657374696e6174696f6e5f726573706f6e73655f737461626c655f756e6465725f6261636b7072657373757265
            ;;
          broken-toggle-capacity)
            fixed=lc_p7_b6f6e655f6974656d5f696e5f666c696768745f6361706163697479
            ;;
          broken-toggle-completion)
            fixed=lc_p12_b776174636865645f7472616e73616374696f6e5f636f6d706c657465735f756e6465725f626f756e6465645f636c6f636b735f616e645f6576656e7475616c5f7265616479
            ;;
          broken-toggle-data-integrity)
            fixed=lc_p11_b776174636865645f7472616e73616374696f6e5f646174615f696e74656772697479
            ;;
          broken-toggle-duplicate)
            fixed=lc_p10_b6e6f5f6475706c69636174655f61636b6e6f776c656467655f6f725f636f6e73756d65
            ;;
          broken-toggle-source-payload)
            fixed=lc_p8_b736f757263655f7061796c6f61645f737461626c655f7768696c655f6f75747374616e64696e67
            ;;
          *) fail "$task lacks a fixed fixture mapping" ;;
        esac
        [ "$expected" = "$fixed" ] || fail "$task fixed label drifted"
        negative_count=$((negative_count + 1))
        ;;
      valid-toggle-record-3-cover-*) cover_count=$((cover_count + 1)) ;;
    esac
  done
done
[ "$task_count" -eq 12 ] || fail "expected twelve formal tasks"
[ "$negative_count" -eq 6 ] || fail "expected six isolated negatives"
[ "$cover_count" -eq 3 ] || fail "expected three individual cover tasks"
observed_tasks=$(
  for task_file in "$selftest_root"/first/*/*.lcft; do
    basename "$task_file" .lcft
  done | LC_ALL=C sort
)
expected_tasks='broken-toggle-backpressure-bmc
broken-toggle-capacity-bmc
broken-toggle-completion-bmc
broken-toggle-data-integrity-bmc
broken-toggle-duplicate-bmc
broken-toggle-source-payload-bmc
valid-toggle-record-3-bmc
valid-toggle-record-3-cover-coincident
valid-toggle-record-3-cover-consume-refill
valid-toggle-record-3-cover-watched
valid-toggle-record-4-bmc
valid-toggle-scalar-2-bmc'
[ "$observed_tasks" = "$expected_tasks" ] || fail "public task names drifted"

tampered="$selftest_root/tampered"
cp -R "$selftest_root/first/valid-toggle-record-3" "$tampered"
printf '%s\n' '// forged predicate' >>"$tampered/formal-harness.sv"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify \
  "$tampered" valid-toggle-record-3-bmc >/dev/null 2>&1; then
  fail "tampered harness passed canonical regeneration"
fi

missing="$selftest_root/missing"
cp -R "$selftest_root/first/valid-toggle-scalar-2" "$missing"
rm "$missing/properties.lcfp"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify \
  "$missing" valid-toggle-scalar-2-bmc >/dev/null 2>&1; then
  fail "missing property manifest passed verification"
fi

forged="$selftest_root/forged"
cp -R "$selftest_root/first/valid-toggle-scalar-2" "$forged"
sed 's/FAMILY toggle-handshake/FAMILY forged-toggle/' \
  "$forged/source-set.lcfs" >"$forged/source-set.changed"
mv "$forged/source-set.changed" "$forged/source-set.lcfs"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify \
  "$forged" valid-toggle-scalar-2-bmc >/dev/null 2>&1; then
  fail "unknown source-set family passed verification"
fi

# A bind-mode preflight fails before any Docker command, retains the exact
# failed status in incomplete evidence, and cannot publish a false pass.
mkdir "$selftest_root/fake-bin" "$selftest_root/bind-run"
ln -s "$(command -v false)" "$selftest_root/fake-bin/docker"
if PATH="$selftest_root/fake-bin:$PATH" LUNACHIP_YOSYS_MOUNT_MODE=bind \
  "$gate" "$selftest_root/bind-run" >/dev/null 2>&1; then
  fail "gate accepted non-volume transport"
fi
incomplete="$selftest_root/bind-run/phase5-toggle-formal-evidence.incomplete"
final="$selftest_root/bind-run/phase5-toggle-formal-evidence.txt"
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

retained="$selftest_root/retained-prefix.incomplete"
cp "$incomplete" "$retained"
printf '%s\n' END >>"$retained"
lc_evidence_validate_receipt \
  "$retained" "$header" incomplete COMMAND COMMAND ||
  fail "retained failed-preflight receipt prefix is not strict"

printf '%s\n' \
  'Phase 5 toggle formal self-tests pass: 9 fixtures, 12 tasks, strict lifecycle'
