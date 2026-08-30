#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
fail() { echo "phase5-async-fifo-formal-selftest: $*" >&2; exit 1; }
root=$(mktemp -d /tmp/lunachip-async-fifo-formal-selftest.XXXXXX)
trap 'rm -rf "$root"' EXIT HUP INT TERM

moon -C "$repo_dir" check --target native --deny-warn --warn-list +73 validation/formal
moon -C "$repo_dir" test --target native --deny-warn --warn-list +73 validation/formal

moon -C "$repo_dir" run --target native cmd/phase4-formal -- generate-async-fifos "$root/first"
moon -C "$repo_dir" run --target native cmd/phase4-formal -- generate-async-fifos "$root/second"
diff -r "$root/first" "$root/second" >/dev/null || fail "bundle bytes drifted"
[ "$(find "$root/first" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 9 ] || fail "fixture count drifted"
tasks=0
negatives=0
covers=0
for bundle in "$root/first"/*; do
  "$repo_dir/scripts/phase4-yosys-validate.sh" --job-json "$bundle/job.json" "$bundle" >/dev/null
  for task_file in "$bundle"/*.lcft; do
    task=$(basename "$task_file" .lcft)
    "$repo_dir/scripts/formal-artifact-cli.sh" verify "$bundle" "$task" >/dev/null
    tasks=$((tasks + 1))
    case "$task" in
      broken-async-fifo-*-bmc)
        expected=$(awk '$1 == "EXPECTED-FAILURE" {print $2}' "$bundle/$task.lcfg")
        [ -n "$expected" ] && [ "$expected" != none ] || fail "$task lacks label"
        case "$(basename "$bundle")" in
          broken-async-fifo-gray) fixed=lc_p11_b77726974655f677261795f6571756174696f6e5f6578616374;;
          broken-async-fifo-full) fixed=lc_p17_b66756c6c5f6571756174696f6e5f6578616374;;
          broken-async-fifo-address) fixed=lc_p19_b77726974655f616464726573735f73656c656374696f6e5f6578616374;;
          broken-async-fifo-storage-order) fixed=lc_p27_b776174636865645f746f6b656e5f646174615f696e74656772697479;;
          broken-async-fifo-read-pipeline) fixed=lc_p15_b726561645f677261795f736f757263655f706970656c696e655f6578616374;;
          broken-async-fifo-write-pipeline) fixed=lc_p16_b77726974655f677261795f64657374696e6174696f6e5f706970656c696e655f6578616374;;
          broken-async-fifo-write-address-bounds) fixed=lc_p20_b77726974655f616464726573735f696e5f626f756e6473;;
          broken-async-fifo-read-address-bounds) fixed=lc_p22_b726561645f616464726573735f696e5f626f756e6473;;
          *) fail "$task lacks fixed fixture mapping";;
        esac
        [ "$expected" = "$fixed" ] || fail "$task fixed label mismatch"
        negatives=$((negatives + 1)) ;;
      valid-async-fifo-cover-*) covers=$((covers + 1)) ;;
    esac
  done
done
[ "$tasks" -eq 15 ] || fail "task count drifted"
[ "$negatives" -eq 8 ] || fail "negative count drifted"
[ "$covers" -eq 6 ] || fail "cover count drifted"

tampered="$root/tampered"
cp -R "$root/first/valid-async-fifo" "$tampered"
printf '%s\n' '// forged' >>"$tampered/formal-harness.sv"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify "$tampered" valid-async-fifo-bmc >/dev/null 2>&1; then
  fail "tampered harness passed"
fi
missing="$root/missing"
cp -R "$root/first/valid-async-fifo" "$missing"
rm "$missing/properties.lcfp"
if "$repo_dir/scripts/formal-artifact-cli.sh" verify "$missing" valid-async-fifo-bmc >/dev/null 2>&1; then
  fail "missing properties passed"
fi
echo "Phase 5 asynchronous-FIFO formal self-tests pass: 9 fixtures, 15 tasks, strict native 20/20"
