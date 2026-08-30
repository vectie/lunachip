#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
fixture_dir="$repo_dir/toolchain/verilator/fixtures"

"$validator"
"$validator" --harness-json "$fixture_dir/minimal-harness.json"
"$validator" --harness-json "$fixture_dir/atomic-harness.json"
"$validator" --stimulus-tsv \
  "$fixture_dir/atomic-harness.json" "$fixture_dir/atomic-stimulus.tsv"

if "$validator" --harness-json "$fixture_dir/invalid-harness-traversal.json" \
  >/dev/null 2>&1; then
  echo "phase3-verilator-selftest: traversal fixture was accepted" >&2
  exit 1
fi

if "$validator" --harness-json "$fixture_dir/invalid-atomic-harness.json" \
  >/dev/null 2>&1
then
  echo "phase3-verilator-selftest: duplicate v2 domain fixture was accepted" >&2
  exit 1
fi

for invalid_stimulus in \
  "$fixture_dir/invalid-atomic-order.tsv" \
  "$fixture_dir/invalid-atomic-duplicate.tsv" \
  "$fixture_dir/invalid-atomic-malformed.tsv" \
  "$fixture_dir/invalid-atomic-coincident.tsv" \
  "$fixture_dir/invalid-atomic-domain-order.tsv" \
  "$fixture_dir/invalid-atomic-unknown-domain.tsv"
do
  if "$validator" --stimulus-tsv \
    "$fixture_dir/atomic-harness.json" "$invalid_stimulus" >/dev/null 2>&1
  then
    echo "phase3-verilator-selftest: invalid atomic stimulus was accepted: $invalid_stimulus" >&2
    exit 1
  fi
done

if "$repo_dir/scripts/phase3-verilator-run.sh" unknown version \
  >/dev/null 2>&1; then
  echo "phase3-verilator-selftest: unknown provider was accepted" >&2
  exit 1
fi

echo "Verilator boundary self-tests pass"
