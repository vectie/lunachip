#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
fixture_dir="$repo_dir/toolchain/verilator/fixtures"

"$validator"
"$validator" --harness-json "$fixture_dir/minimal-harness.json"

if "$validator" --harness-json "$fixture_dir/invalid-harness-traversal.json" \
  >/dev/null 2>&1; then
  echo "phase3-verilator-selftest: traversal fixture was accepted" >&2
  exit 1
fi

if "$repo_dir/scripts/phase3-verilator-run.sh" unknown version \
  >/dev/null 2>&1; then
  echo "phase3-verilator-selftest: unknown provider was accepted" >&2
  exit 1
fi

echo "Verilator boundary self-tests pass"
