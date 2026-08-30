#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
checker="$repo_dir/scripts/yosys-toggle-synthesis-check.sh"
fixtures="$repo_dir/toolchain/yosys/fixtures"
expected="$fixtures/toggle-scalar-2.expected.json"
passing="$fixtures/toggle-scalar-2-pass.rtlil"
scratch=$(mktemp -d /tmp/lunachip-toggle-synthesis-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  echo "yosys-toggle-synthesis-selftest: $*" >&2
  exit 1
}

"$checker" "$expected" "$passing" "$scratch/pass.json"
jq -e '.pass and .classification == "exact-toggle-state-shape" and
  .observed.stateful_cells == 9 and (.checks | all(.[]; .))' \
  "$scratch/pass.json" >/dev/null || fail "passing shape report is incorrect"

expect_failure() {
  name=$1
  check=$2
  report="$scratch/$name.json"
  if "$checker" "$expected" "$scratch/$name.rtlil" "$report" >/dev/null 2>&1; then
    fail "$name mutation was accepted"
  fi
  jq -e --arg check "$check" '(.pass | not) and
    .classification == "toggle-state-shape-mismatch" and
    (.checks[$check] | not) and
    .claim_boundary.combinational_protocol_logic == false' \
    "$report" >/dev/null || fail "$name failure report is incorrect"
}

awk '!changed && /WIDTH 1/ { sub(/WIDTH 1/, "WIDTH 2"); changed = 1 } { print }' "$passing" >"$scratch/wrong-width.rtlil"
expect_failure wrong-width exact_widths
awk '!changed && /CLK \\source_clock/ { sub(/CLK \\source_clock/, "CLK \\destination_clock"); changed = 1 } { print }' "$passing" >"$scratch/wrong-clock.rtlil"
expect_failure wrong-clock exact_clock_reset_domains
awk '!changed && /S \\source_reset/ { sub(/S \\source_reset/, "S \\destination_reset"); changed = 1 } { print }' "$passing" >"$scratch/wrong-reset.rtlil"
expect_failure wrong-reset exact_clock_reset_domains
awk '!changed && /B 1\0470/ { sub(/B 1\0470/, "B 1\0471"); changed = 1 } { print }' "$passing" >"$scratch/nonzero-reset.rtlil"
expect_failure nonzero-reset exact_sync_reset_enable_shape
awk '!changed && /A \\held/ { sub(/A \\held/, "A \\source_payload"); changed = 1 } { print }' "$passing" >"$scratch/wrong-enable.rtlil"
expect_failure wrong-enable exact_sync_reset_enable_shape
sed '/cell \$dff \\acknowledge_stage1_cell/,/  end/d' "$passing" >"$scratch/missing-state.rtlil"
expect_failure missing-state exact_state_count
awk '/^end$/ { print "  cell $dff \\extra_cell"; print "    parameter \\CLK_POLARITY 1\0471"; print "    parameter \\WIDTH 1"; print "    connect \\CLK \\source_clock"; print "    connect \\D \\extra_next"; print "    connect \\Q \\extra"; print "  end" } { print }' "$passing" >"$scratch/extra-state.rtlil"
expect_failure extra-state exact_state_count
awk '/^end$/ { print "  memory width 1 size 2 \\hidden" } { print }' "$passing" >"$scratch/memory.rtlil"
expect_failure memory no_memory

echo "Yosys toggle synthesis checker self-tests pass"
