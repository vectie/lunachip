#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

fail() {
  echo "formal-bundle-selftest: $*" >&2
  exit 1
}

selftest_root=$(mktemp -d /tmp/lunachip-formal-bundle-selftest.XXXXXX)
trap 'rm -rf "$selftest_root"' EXIT HUP INT TERM

moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate "$selftest_root/phase4-first"
moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate "$selftest_root/phase4-second"
diff -r "$selftest_root/phase4-first" "$selftest_root/phase4-second" >/dev/null ||
  fail "Phase 4 bundle generation is not byte-deterministic"

moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-synchronizers "$selftest_root/synchronizers"
expected='broken-synchronizer-convergence
broken-synchronizer-destination-edge
broken-synchronizer-pipeline
valid-synchronizer'
observed=$(
  find "$selftest_root/synchronizers" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | sort
)
[ "$observed" = "$expected" ] || fail "synchronizer fixture registry drifted"

moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-toggle-handshakes "$selftest_root/toggle-handshakes"
expected='broken-toggle-backpressure
broken-toggle-capacity
broken-toggle-completion
broken-toggle-data-integrity
broken-toggle-duplicate
broken-toggle-source-payload
valid-toggle-record-3
valid-toggle-record-4
valid-toggle-scalar-2'
observed=$(
  find "$selftest_root/toggle-handshakes" -mindepth 1 -maxdepth 1 -type d \
    -exec basename {} \; | sort
)
[ "$observed" = "$expected" ] || fail "toggle fixture registry drifted"

for root in \
  "$selftest_root/phase4-first" \
  "$selftest_root/synchronizers" \
  "$selftest_root/toggle-handshakes"; do
  for bundle in "$root"/*; do
    "$repo_dir/scripts/phase4-yosys-validate.sh" \
      --job-json "$bundle/job.json" "$bundle" >/dev/null
    for task_file in "$bundle"/*.lcft; do
      task=$(basename "$task_file" .lcft)
      "$repo_dir/scripts/formal-artifact-cli.sh" verify "$bundle" "$task" \
        >/dev/null
    done
  done
done

tampered="$selftest_root/tampered"
cp -R "$selftest_root/synchronizers/valid-synchronizer" "$tampered"
printf '%s\n' '// tampered after canonical generation' >>"$tampered/formal-harness.sv"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify \
  "$tampered" valid-synchronizer-bmc >/dev/null 2>&1; then
  fail "phase-neutral regeneration accepted a tampered bundle"
fi

tampered_toggle="$selftest_root/tampered-toggle"
cp -R "$selftest_root/toggle-handshakes/valid-toggle-record-3" \
  "$tampered_toggle"
printf '%s\n' '// tampered after canonical generation' >>"$tampered_toggle/formal-harness.sv"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify \
  "$tampered_toggle" valid-toggle-record-3-bmc >/dev/null 2>&1; then
  fail "phase-neutral regeneration accepted a tampered toggle bundle"
fi

echo "Formal bundle registry self-tests pass"
