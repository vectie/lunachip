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

for root in "$selftest_root/phase4-first" "$selftest_root/synchronizers"; do
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

echo "Formal bundle registry self-tests pass"
