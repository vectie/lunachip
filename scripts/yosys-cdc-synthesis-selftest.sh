#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
checker="$repo_dir/scripts/yosys-cdc-synthesis-check.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"
expected="$fixtures/cdc-sync-2.expected.json"
scratch=$(mktemp -d /tmp/lunachip-cdc-synthesis-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  echo "yosys-cdc-synthesis-selftest: $*" >&2
  exit 1
}

"$checker" "$expected" "$fixtures/cdc-sync-2-pass.rtlil" "$scratch/pass.json"
jq -e '
  .pass and .classification == "exact-bit-synchronizer-shape" and
  .observed.dff_cells == 2 and
  (.checks | all(.[]; .))
' "$scratch/pass.json" >/dev/null || fail "passing shape report is incorrect"

expect_failure() {
  name=$1
  check=$2
  report="$scratch/$name.json"
  if "$checker" "$expected" "$fixtures/cdc-sync-2-$name.rtlil" "$report" \
    >/dev/null 2>&1; then
    fail "$name fixture was accepted"
  fi
  jq -e --arg check "$check" '
    (.pass | not) and
    .classification == "bit-synchronizer-shape-mismatch" and
    (.checks[$check] | not) and
    .claim_boundary == {
      pre_map_structural_shape: true, physical_placement: false,
      metastability: false, mtbf: false, timing_closure: false
    }
  ' "$report" >/dev/null || fail "$name failure report is incorrect"
}

expect_failure missing-stage exact_stage_count
expect_failure wrong-clock same_destination_clock
expect_failure wrong-width positive_edge_one_bit_dff_only
expect_failure bypass no_bypass
expect_failure extra-state no_extra_state

echo "Yosys CDC synthesis checker self-tests pass"
