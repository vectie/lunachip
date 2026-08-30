#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
scratch=$(mktemp -d /tmp/lunachip-phase5-handshake-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  echo "phase5-handshake-differential-selftest: $*" >&2
  exit 1
}

cd "$repo_dir"
moon run cmd/phase5-handshake-differential-fixtures --target native -- \
  matrix "$scratch/bundles"
moon run cmd/phase5-handshake-differential-fixtures --target native -- \
  negative "$scratch/negative"

fixtures='directed-2-stage-scalar rational-3-stage-multi-leaf coincident-4-stage-refill coordinated-reset-unilateral-flush seeded-rational-stream'
event_total=0
coincidence_total=0
for fixture in $fixtures; do
  bundle="$scratch/bundles/$fixture"
  "$validator" --harness-json "$bundle/manifest.json" >/dev/null
  "$validator" --stimulus-tsv \
    "$bundle/manifest.json" "$bundle/stimulus.tsv" >/dev/null
  moon run cmd/phase5-handshake-differential-fixtures --target native -- \
    verify "$fixture" "$bundle/expected.tsv" >/dev/null
  grep -F '    top.eval();' "$bundle/harness.cpp" >/dev/null ||
    fail "$fixture atomic harness has no post-batch evaluation"
  if grep -F '      top.eval();' "$bundle/harness.cpp" >/dev/null; then
    fail "$fixture production harness contains the sequential-edge bridge"
  fi
  header=$(sed -n '2p' "$bundle/expected.tsv")
  case "$header" in
    *destination_valid*destination_word*source_ready*) ;;
    *) fail "$fixture does not compare every defined base output" ;;
  esac
  events=$(awk -F '\t' '$1 == "EVENTS" { print $2 }' "$bundle/stimulus.tsv")
  coincidences=$(awk -F '\t' '$1 == "EVENT" && $6 == 2 { count++ } END { print count + 0 }' "$bundle/stimulus.tsv")
  event_total=$((event_total + events))
  coincidence_total=$((coincidence_total + coincidences))
done

[ "$event_total" -eq 295 ] || fail "event total drifted to $event_total"
[ "$coincidence_total" -eq 45 ] ||
  fail "coincidence total drifted to $coincidence_total"

multi="$scratch/bundles/rational-3-stage-multi-leaf"
sed -n '2p' "$multi/expected.tsv" | grep -F 'destination_tag' >/dev/null ||
  fail "multi-leaf output is absent"
wide_field=$(printf '\t8\t')
grep -F 'DRIVE' "$multi/stimulus.tsv" | grep -F "$wide_field" >/dev/null ||
  fail "multi-leaf fixture has no wide drive"

refill="$scratch/bundles/coincident-4-stage-refill/expected.tsv"
grep -F "$(printf '70\t35\t1\t19\t0')" "$refill" >/dev/null ||
  fail "pre-refill response drifted"
grep -F "$(printf '72\t36\t1\te6\t0')" "$refill" >/dev/null ||
  fail "same-event consume/refill response drifted"

reset_bundle="$scratch/bundles/coordinated-reset-unilateral-flush"
grep -Fx 'expected-reset-flush-loss' "$reset_bundle/evidence-class.txt" >/dev/null ||
  fail "unilateral reset is not classified as expected flush/loss"
grep -Fx 'seed=0x5eed1234' \
  "$scratch/bundles/seeded-rational-stream/fixture-metadata.txt" >/dev/null ||
  fail "fixed seed drifted"

negative="$scratch/negative/coincident-sequential-negative"
"$validator" --harness-json "$negative/manifest.json" >/dev/null
"$validator" --stimulus-tsv \
  "$negative/manifest.json" "$negative/stimulus.tsv" >/dev/null
grep -F '      top.eval();' "$negative/harness.cpp" >/dev/null ||
  fail "negative harness does not evaluate each edge sequentially"
moon run cmd/phase5-handshake-differential-fixtures --target native -- \
  verify-negative "$negative/expected-sequential.tsv" >"$scratch/mismatch.txt"
grep -F "$(printf 'required-mismatch\ttime=40\tboundary=20\toutput=destination_valid\texpected=0\tactual=1')" \
  "$scratch/mismatch.txt" >/dev/null ||
  fail "required negative mismatch identity drifted"
if moon run cmd/phase5-handshake-differential-fixtures --target native -- \
  verify-negative "$negative/expected.tsv" >/dev/null 2>&1; then
  fail "atomic expected result was accepted as the sequential negative"
fi

sed "s/$(printf 'EVENT\t0\t5\t0\t6\t2')/$(printf 'EVENT\t0\t5\t0\t6\t1')/" \
  "$multi/stimulus.tsv" >"$scratch/malformed-wide-stimulus.tsv"
if "$validator" --stimulus-tsv \
  "$multi/manifest.json" "$scratch/malformed-wide-stimulus.tsv" \
  >/dev/null 2>&1; then
  fail "malformed atomic domain count was accepted"
fi

echo "Phase 5 toggle-handshake differential self-tests pass"
