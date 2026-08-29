#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase4-yosys-validate.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"

fail() {
  echo "phase4-yosys-selftest: $*" >&2
  exit 1
}

"$validator"
"$validator" --job-json "$fixtures/minimal-job.json" "$fixtures"

if "$validator" --job-json "$fixtures/invalid-traversal.json" >/dev/null 2>&1; then
  fail "parent-traversal manifest was accepted"
fi
if "$validator" --job-json "$fixtures/invalid-claim.json" >/dev/null 2>&1; then
  fail "mode/claim mismatch was accepted"
fi
if "$validator" --job-json "$fixtures/invalid-unknown-key.json" >/dev/null 2>&1; then
  fail "unknown manifest key was accepted"
fi
if "$repo_dir/scripts/phase4-yosys-run.sh" archive version >/dev/null 2>&1; then
  fail "fallback provider was accepted"
fi

grep -F -- '--user "$uid:$gid"' "$repo_dir/scripts/phase4-yosys-run.sh" >/dev/null ||
  fail "runtime is not fixed to the host UID/GID"
grep -F 'permission-init=pinned-image-python-os-chmod-v1' \
  "$repo_dir/scripts/phase4-yosys-run.sh" >/dev/null ||
  fail "volume transport lacks the pinned-image permission receipt"
grep -F 'PERMISSION-INITIALIZER pinned-image-python-os-chmod-v1' \
  "$repo_dir/scripts/phase4-yosys-run.sh" >/dev/null ||
  fail "volume transport receipt does not bind the permission initializer"

selftest_root=$(mktemp -d "${TMPDIR:-/tmp}/lunachip-yosys-selftest.XXXXXX")
trap 'rm -rf "$selftest_root"' EXIT HUP INT TERM
cp "$fixtures/minimal-job.json" "$selftest_root/job.json"
cp "$fixtures/minimal.sv" "$selftest_root/minimal.sv"
printf '%s\n' '// digest tamper' >>"$selftest_root/minimal.sv"
if "$validator" --job-json "$selftest_root/job.json" "$selftest_root" >/dev/null 2>&1; then
  fail "source digest mismatch was accepted"
fi

echo "Yosys/SBY boundary self-tests pass"
