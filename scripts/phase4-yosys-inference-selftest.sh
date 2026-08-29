#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
checker="$repo_dir/scripts/phase4-yosys-inference-check.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"
root=$(mktemp -d "${TMPDIR:-/tmp}/lunachip-inference-selftest.XXXXXX")
trap 'rm -rf "$root"' EXIT HUP INT TERM

fail() {
  echo "phase4-yosys-inference-selftest: $*" >&2
  exit 1
}

"$checker" single-read-old require-memory-cell 64:32:2:1 \
  "$fixtures/inferred.rtlil" "$fixtures/inferred-yosys.log" "$root/required.json"
jq -e '.pass and .inferred_memory_claim and (.observed.pre_map_mem_v2_cells == 1)' \
  "$root/required.json" >/dev/null || fail "required inference report is incorrect"

if "$checker" single-read-old require-memory-cell 64:32:2:1 \
  "$fixtures/logic-only.rtlil" "$fixtures/logic-only-yosys.log" "$root/missing.json" \
  >/dev/null 2>&1; then
  fail "missing required memory cell was accepted"
fi
jq -e '(.pass | not) and (.classification == "required-memory-shape-mismatch")' \
  "$root/missing.json" >/dev/null || fail "failure report is incorrect"

"$checker" multiwrite-reject observe-only-multiwrite observe \
  "$fixtures/logic-only.rtlil" "$fixtures/logic-only-yosys.log" "$root/multi.json"
jq -e '.pass and (.inferred_memory_claim | not) and (.physical_ram_claim | not) and
  (.classification == "logic-lowered-observe-only")' "$root/multi.json" >/dev/null ||
  fail "multiwrite classification report is incorrect"

echo "Yosys memory-inference report self-tests pass"
