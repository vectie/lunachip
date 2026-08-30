#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
  echo "phase5-toggle-formal-selftest: $*" >&2
  exit 1
}

selftest_root=$(mktemp -d /tmp/lunachip-toggle-formal-selftest.XXXXXX)
trap 'rm -rf "$selftest_root"' EXIT HUP INT TERM

moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-toggle-handshakes "$selftest_root/first"
moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-toggle-handshakes "$selftest_root/second"
diff -r "$selftest_root/first" "$selftest_root/second" >/dev/null ||
  fail "toggle bundles are not byte deterministic"

fixture_count=$(find "$selftest_root/first" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$fixture_count" -eq 9 ] || fail "expected nine isolated fixtures"
task_count=0
negative_count=0
cover_count=0
for bundle in "$selftest_root/first"/*; do
  "$repo_dir/scripts/phase4-yosys-validate.sh" \
    --job-json "$bundle/job.json" "$bundle" >/dev/null
  for task_file in "$bundle"/*.lcft; do
    task=$(basename "$task_file" .lcft)
    "$repo_dir/scripts/formal-artifact-cli.sh" verify "$bundle" "$task" \
      >/dev/null
    task_count=$((task_count + 1))
    case "$task" in
      broken-toggle-*-bmc)
        expected=$(awk '$1 == "EXPECTED-FAILURE" { print $2 }' "$bundle/$task.lcfg")
        [ -n "$expected" ] && [ "$expected" != none ] ||
          fail "$task omitted its stable negative label"
        negative_count=$((negative_count + 1))
        ;;
      valid-toggle-record-3-cover-*) cover_count=$((cover_count + 1)) ;;
    esac
  done
done
[ "$task_count" -eq 12 ] || fail "expected twelve formal tasks"
[ "$negative_count" -eq 6 ] || fail "expected six isolated negatives"
[ "$cover_count" -eq 3 ] || fail "expected three individual cover tasks"

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

echo "Phase 5 toggle formal structural self-tests pass: 9 fixtures, 12 tasks"
