#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
scratch=$(mktemp -d /tmp/lunachip-phase5-sync-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  echo "phase5-sync-differential-selftest: $*" >&2
  exit 1
}

cd "$repo_dir"
moon run cmd/phase5-sync-differential-fixtures --target native -- \
  matrix "$scratch/bundles"
moon run cmd/phase5-sync-differential-fixtures --target native -- \
  negative "$scratch/negative"

fixtures='async-2-stage-reset timed-3-stage-coprime timed-4-stage-noncoprime'
for fixture in $fixtures; do
  bundle="$scratch/bundles/$fixture"
  "$validator" --harness-json "$bundle/manifest.json" >/dev/null
  "$validator" --stimulus-tsv \
    "$bundle/manifest.json" "$bundle/stimulus.tsv" >/dev/null
  moon run cmd/phase5-sync-differential-fixtures --target native -- \
    verify "$fixture" "$bundle/expected.tsv" >/dev/null
  grep -F '    top.eval();' "$bundle/harness.cpp" >/dev/null ||
    fail "$fixture atomic harness has no post-batch evaluation"
  if grep -F '      top.eval();' "$bundle/harness.cpp" >/dev/null; then
    fail "$fixture production harness contains the sequential-edge bridge"
  fi
done

negative="$scratch/negative/timed-3-stage-sequential-negative"
"$validator" --harness-json "$negative/manifest.json" >/dev/null
"$validator" --stimulus-tsv \
  "$negative/manifest.json" "$negative/stimulus.tsv" >/dev/null
grep -F '      top.eval();' "$negative/harness.cpp" >/dev/null ||
  fail "negative harness does not evaluate each edge sequentially"
moon run cmd/phase5-sync-differential-fixtures --target native -- \
  verify-negative "$negative/expected-sequential.tsv" >"$scratch/mismatch.txt"
grep -F 'required-mismatch	time=93	boundary=18	output=synchronized	expected=0	actual=1' \
  "$scratch/mismatch.txt" >/dev/null ||
  fail "negative mismatch identity drifted"

if moon run cmd/phase5-sync-differential-fixtures --target native -- \
  verify-negative "$negative/expected.tsv" >/dev/null 2>&1; then
  fail "atomic expected result was accepted as the sequential negative"
fi

sed 's/EVENT	15	75	15	3	2/EVENT	15	75	15	3	1/' \
  "$negative/stimulus.tsv" >"$scratch/malformed-stimulus.tsv"
if "$validator" --stimulus-tsv \
  "$negative/manifest.json" "$scratch/malformed-stimulus.tsv" \
  >/dev/null 2>&1; then
  fail "malformed coincident event count was accepted"
fi

echo "Phase 5 synchronizer differential self-tests pass"
