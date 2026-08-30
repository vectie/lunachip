#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
scratch=$(mktemp -d /tmp/lunachip-phase5-fifo-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  echo "phase5-fifo-differential-selftest: $*" >&2
  exit 1
}

cd "$repo_dir"
moon run cmd/phase5-fifo-differential-fixtures --target native -- \
  matrix "$scratch/bundles"
moon run cmd/phase5-fifo-differential-fixtures --target native -- \
  negative "$scratch/negative"

fixtures='depth4-coprime-scalar-2stage depth8-noncoprime-aggregate64-3stage depth4-asymmetric-coincident-4stage'
event_total=0
coincidence_total=0
for fixture in $fixtures; do
  bundle="$scratch/bundles/$fixture"
  "$validator" --harness-json "$bundle/manifest.json" >/dev/null
  "$validator" --stimulus-tsv \
    "$bundle/manifest.json" "$bundle/stimulus.tsv" >/dev/null
  moon run cmd/phase5-fifo-differential-fixtures --target native -- \
    verify "$fixture" "$bundle/expected.tsv" >/dev/null
  grep -Fx '    top.eval();' "$bundle/harness.cpp" >/dev/null ||
    fail "$fixture atomic harness has no post-batch evaluation"
  if grep -Fx '      top.eval();' "$bundle/harness.cpp" >/dev/null; then
    fail "$fixture production harness contains the sequential-edge bridge"
  fi
  events=$(awk -F '\t' '$1 == "EVENTS" { print $2 }' "$bundle/stimulus.tsv")
  coincidences=$(awk -F '\t' '$1 == "EVENT" && $6 == 2 { count++ } END { print count + 0 }' "$bundle/stimulus.tsv")
  event_total=$((event_total + events))
  coincidence_total=$((coincidence_total + coincidences))
  for metric in source_reset_assertions source_reset_releases \
    destination_reset_assertions destination_reset_releases; do
    [ "$(awk -F= -v key="$metric" '$1 == key { print $2 }' "$bundle/coverage.txt")" -eq 1 ] ||
      fail "$fixture $metric coverage drifted"
  done
done

[ "$event_total" -eq 559 ] || fail "event total drifted to $event_total"
[ "$coincidence_total" -eq 104 ] ||
  fail "coincidence total drifted to $coincidence_total"

check_coverage() {
  fixture=$1
  expected=$2
  actual=$(tr '\n' ' ' <"$scratch/bundles/$fixture/coverage.txt" | sed 's/ $//')
  [ "$actual" = "$expected" ] || fail "$fixture coverage totals drifted: $actual"
}
check_coverage depth4-coprime-scalar-2stage \
  'enqueues=49 dequeues=49 enqueue_only=48 dequeue_only=48 simultaneous=1 coincidences=13 backpressure=1 full_entries=21 full_exits=21 empty_entries=27 empty_exits=27 write_wraps=12 read_wraps=12 source_reset_assertions=1 source_reset_releases=1 destination_reset_assertions=1 destination_reset_releases=1'
check_coverage depth8-noncoprime-aggregate64-3stage \
  'enqueues=24 dequeues=24 enqueue_only=18 dequeue_only=18 simultaneous=6 coincidences=65 backpressure=2 full_entries=6 full_exits=6 empty_entries=11 empty_exits=11 write_wraps=3 read_wraps=3 source_reset_assertions=1 source_reset_releases=1 destination_reset_assertions=1 destination_reset_releases=1'
check_coverage depth4-asymmetric-coincident-4stage \
  'enqueues=12 dequeues=12 enqueue_only=11 dequeue_only=11 simultaneous=1 coincidences=26 backpressure=3 full_entries=8 full_exits=8 empty_entries=4 empty_exits=4 write_wraps=3 read_wraps=3 source_reset_assertions=1 source_reset_releases=1 destination_reset_assertions=1 destination_reset_releases=1'

aggregate="$scratch/bundles/depth8-noncoprime-aggregate64-3stage"
expected_header='time	boundary	destination_lane0	destination_lane1	destination_lane2	destination_tag	destination_valid	destination_word	filler_observed1	filler_observed2	source_ready'
[ "$(sed -n '2p' "$aggregate/expected.tsv")" = "$(printf "$expected_header")" ] ||
  fail "aggregate result identity/order drifted"
[ "$(awk 'BEGIN { count=0; raw[0]=51; raw[1]=54; raw[2]=57; raw[3]=60; raw[4]=63 } $1 == "MAP" && $2 == "async-fifo-lane" { if ($3 != 0 || $4 != raw[count] || $6 != "lc_f0_l" count) bad=1; count++ } END { if (bad) print -1; else print count+0 }' "$aggregate/names.lcnm")" -eq 5 ] ||
  fail "aggregate FIFO lane identity/order drifted"
aggregate_widths=$(jq -r '.ports[] | select(.direction == "output") | .width' "$aggregate/manifest.json" |
  sort -n | tr '\n' ' ' | sed 's/ $//')
[ "$aggregate_widths" = '1 1 1 1 8 8 8 8 32' ] ||
  fail "aggregate public output widths drifted: $aggregate_widths"
aggregate_bits=0
for output_spec in 4:32 5:8 6:8 7:8 8:8; do
  ordinal=${output_spec%:*}
  width=${output_spec#*:}
  emitted=$(awk -v ordinal="$ordinal" '$1 == "MAP" && $2 == "output" && $4 == ordinal { print $6 }' "$aggregate/names.lcnm")
  [ -n "$emitted" ] || fail "aggregate output ordinal $ordinal is absent"
  [ "$(jq -r --arg name "$emitted" '.ports[] | select(.name == $name and .direction == "output") | .width' "$aggregate/manifest.json")" -eq "$width" ] ||
    fail "aggregate output ordinal $ordinal width drifted"
  aggregate_bits=$((aggregate_bits + width))
done
[ "$aggregate_bits" -eq 64 ] || fail "aggregate payload is not exactly 64 bits"

jq '.domains[1].id = 0' "$aggregate/manifest.json" >"$scratch/bad-manifest.json"
if "$validator" --harness-json "$scratch/bad-manifest.json" >/dev/null 2>&1; then
  fail "duplicate-domain manifest was accepted"
fi
awk -F '\t' 'BEGIN { OFS="\t" } !changed && $1 == "EVENT" && $6 == 2 { $6=1; changed=1 } { print }' \
  "$aggregate/stimulus.tsv" >"$scratch/bad-stimulus.tsv"
if "$validator" --stimulus-tsv "$aggregate/manifest.json" "$scratch/bad-stimulus.tsv" >/dev/null 2>&1; then
  fail "malformed atomic domain count was accepted"
fi

negative="$scratch/negative/depth4-asymmetric-sequential-negative"
"$validator" --harness-json "$negative/manifest.json" >/dev/null
"$validator" --stimulus-tsv \
  "$negative/manifest.json" "$negative/stimulus.tsv" >/dev/null
grep -Fx '      top.eval();' "$negative/harness.cpp" >/dev/null ||
  fail "negative harness does not evaluate each edge sequentially"
moon run cmd/phase5-fifo-differential-fixtures --target native -- \
  verify-negative "$negative/expected-sequential.tsv" >"$scratch/mismatch.txt"
grep -Fx "$(printf 'required-mismatch\ttime=133\tboundary=133\toutput=destination_lane0\texpected=00\tactual=fc')" \
  "$scratch/mismatch.txt" >/dev/null || fail "required negative mismatch identity drifted"
if moon run cmd/phase5-fifo-differential-fixtures --target native -- \
  verify-negative "$negative/expected.tsv" >/dev/null 2>&1; then
  fail "atomic expected result was accepted as the sequential negative"
fi

positive="$scratch/bundles/depth4-coprime-scalar-2stage/expected.tsv"
reject_result() {
  label=$1
  path=$2
  if moon run cmd/phase5-fifo-differential-fixtures --target native -- \
    verify depth4-coprime-scalar-2stage "$path" >/dev/null 2>&1; then
    fail "$label malformed result was accepted"
  fi
}
sed '1s/LUNACHIP-PHASE5-FIFO-RESULT/BAD/' "$positive" >"$scratch/bad-identity.tsv"
reject_result bad-identity "$scratch/bad-identity.tsv"
sed '3s/\t00\t/\t0A\t/' "$positive" >"$scratch/bad-hex.tsv"
reject_result bad-hex "$scratch/bad-hex.tsv"
sed '3s/^0\t/00\t/' "$positive" >"$scratch/bad-decimal.tsv"
reject_result bad-decimal "$scratch/bad-decimal.tsv"
sed '3s/\t[^\t]*$//' "$positive" >"$scratch/bad-columns.tsv"
reject_result bad-columns "$scratch/bad-columns.tsv"
sed '$d' "$positive" >"$scratch/missing-row.tsv"
reject_result missing-row "$scratch/missing-row.tsv"
sed '3s/\t00\t/\t01\t/; $s/\t0$/\tA/' "$positive" >"$scratch/early-mismatch-late-malformed.tsv"
reject_result early-mismatch-late-malformed "$scratch/early-mismatch-late-malformed.tsv"
awk 'NR > 1 { printf "\n" } { printf "%s", $0 }' "$positive" >"$scratch/no-final-newline.tsv"
reject_result no-final-newline "$scratch/no-final-newline.tsv"

echo "Phase 5 asynchronous-FIFO differential self-tests pass"
