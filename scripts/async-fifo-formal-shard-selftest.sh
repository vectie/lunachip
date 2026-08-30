#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd -P)
. "$repo_dir/scripts/async-fifo-formal-shard-lib.sh"

fail() {
  printf '%s\n' "async-fifo-formal-shard-selftest: $*" >&2
  exit 1
}

expect_failure() {
  lcafsst_label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$lcafsst_label unexpectedly passed"
  fi
}

write_child_statuses() {
  lcafsst_output=$1
  lcafsst_work="$lcafsst_output/valid-async-fifo-bmc-work"
  for lcafsst_id in protocol-pointer-gray sync-status-address \
    backpressure-order integrity completion completion-nonvacuity; do
    mkdir -p "$lcafsst_work/shards/$lcafsst_id-work"
    lcafsst_depth=128
    if [ "$lcafsst_id" = completion-nonvacuity ]; then
      lcafsst_depth=204
    fi
    printf 'PASS 0 %s\n' "$lcafsst_depth" \
      >"$lcafsst_work/shards/$lcafsst_id-work/status"
  done
  printf '%s\n' PASS >"$lcafsst_work/status"
}

write_realistic_footprints() {
  lcafsst_output=$1
  lcafsst_work="$lcafsst_output/valid-async-fifo-bmc-work"
  write_child_statuses "$lcafsst_output"
  for lcafsst_id in protocol-pointer-gray sync-status-address \
    backpressure-order integrity completion completion-nonvacuity; do
    lcafsst_child="$lcafsst_work/shards/$lcafsst_id-work"
    lcafsst_depth=128
    if [ "$lcafsst_id" = completion-nonvacuity ]; then
      lcafsst_depth=204
    fi
    mkdir -p "$lcafsst_child/engine_0" "$lcafsst_child/model"
    cp "$lcafsst_work/shards/$lcafsst_id.sby" "$lcafsst_child/config.sby"
    printf '%s\n' \
      "SBY 0:00:00 [$lcafsst_id] summary: engine_0 (smtbmc bitwuzla) returned pass" \
      "SBY 0:00:00 [$lcafsst_id] summary: engine_0 did not produce any traces" \
      "SBY 0:00:00 [$lcafsst_id] DONE (PASS, rc=0)" \
      >"$lcafsst_child/logfile.txt"
    printf '%s\n' \
      "##   0:00:00  Checking assertions in step $((lcafsst_depth - 1)).." \
      "##   0:00:00  Status: passed" >"$lcafsst_child/engine_0/logfile.txt"
    printf '%s\n' '(set-logic QF_AUFBV)' \
      >"$lcafsst_child/model/design_smt2.smt2"
  done
}

scratch=$(mktemp -d "/tmp/lunachip-async-fifo-shards.XXXXXX")
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
bundles="$scratch/bundles"
moon -C "$repo_dir" run --target native cmd/phase4-formal -- \
  generate-async-fifos "$bundles" >/dev/null
bundle="$bundles/valid-async-fifo"
clean="$scratch/clean"
mkdir "$clean"
lc_async_fifo_prepare_internal_shards \
  "$bundle" valid-async-fifo-bmc "$clean"
write_realistic_footprints "$clean"
lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$clean" || fail "clean aggregate failed"

plan="$clean/valid-async-fifo-bmc-work/internal-shards.lcfs"
[ "$(grep -c '^SHARD ' "$plan")" -eq 6 ] || fail "shard count drifted"
[ "$(grep -c '^ASSUMPTIONS 7$' "$plan")" -eq 6 ] ||
  fail "assumptions are not replicated into every shard"
grep -Fx 'BASE-UNION properties 22 duplicates 0 missing 0 extra 0' \
  "$plan" >/dev/null || fail "base union record drifted"
grep -Fx \
  'PREP-TRANSFORM proc ; flatten ; memory -nomap ; memory_map ; opt -full ; wreduce ; opt_clean ; prep' \
  "$plan" >/dev/null || fail "integrity transform record drifted"
grep -Fx \
  'SUPPLEMENTAL-RELATION completion-nonvacuity repeats completion property-exact bound 204 parent-claim false' \
  "$plan" >/dev/null || fail "supplemental relation drifted"
grep -Eq \
  '^FOOTPRINT-HELPER scripts/async-fifo-formal-footprint-lib[.]sh sha256 [0-9a-f]{64}$' \
  "$plan" || fail "footprint-helper digest binding drifted"
grep -Eq '^FOOTPRINT-ARTIFACT footprint-verifier[.]sh sha256 [0-9a-f]{64}$' \
  "$plan" || fail "footprint artifact digest binding drifted"
command_file="$clean/valid-async-fifo-bmc-work/internal-shards-command.sh"
[ "$(sed -n '3p' "$command_file")" = \
  '. /out/valid-async-fifo-bmc-work/footprint-verifier.sh' ] ||
  fail "aggregate command does not source its bound footprint verifier"
[ "$(grep -Fc "grep -Eq '^PASS( [0-9]+){2}$'" "$command_file")" -eq 6 ] ||
  fail "child command status shape drifted"
[ "$(grep -c '^lc_async_fifo_verify_child_footprint ' "$command_file")" -eq 6 ] ||
  fail "aggregate command does not structurally verify every child"
[ "$(tail -n 1 "$command_file")" = \
  "printf '%s\\n' PASS > /out/valid-async-fifo-bmc-work/status" ] ||
  fail "synthetic parent PASS command drifted"

missing="$scratch/missing"
cp -R "$clean" "$missing"
sed -n '2,$p' \
  "$missing/valid-async-fifo-bmc-work/shards/integrity.assertions" \
  >"$missing/valid-async-fifo-bmc-work/shards/integrity.changed"
mv "$missing/valid-async-fifo-bmc-work/shards/integrity.changed" \
  "$missing/valid-async-fifo-bmc-work/shards/integrity.assertions"
expect_failure missing lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$missing"

duplicate="$scratch/duplicate"
cp -R "$clean" "$duplicate"
sed -n '1p' \
  "$duplicate/valid-async-fifo-bmc-work/shards/protocol-pointer-gray.assertions" \
  >>"$duplicate/valid-async-fifo-bmc-work/shards/protocol-pointer-gray.assertions"
expect_failure duplicate lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$duplicate"

extra="$scratch/extra"
cp -R "$clean" "$extra"
sed -n '1p' "$extra/valid-async-fifo-bmc-work/parent.assertions" \
  >>"$extra/valid-async-fifo-bmc-work/shards/completion.assertions"
expect_failure extra lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$extra"

wrong_role="$scratch/wrong-role"
cp -R "$clean" "$wrong_role"
sed -n '1p' "$wrong_role/valid-async-fifo-bmc-work/parent.assumptions" \
  >"$wrong_role/valid-async-fifo-bmc-work/shards/integrity.assertions"
expect_failure wrong-role lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$wrong_role"

wrong_bound="$scratch/wrong-bound"
cp -R "$clean" "$wrong_bound"
sed 's/^depth 204$/depth 128/' \
  "$wrong_bound/valid-async-fifo-bmc-work/shards/completion-nonvacuity.sby" \
  >"$wrong_bound/valid-async-fifo-bmc-work/shards/completion-nonvacuity.changed"
mv "$wrong_bound/valid-async-fifo-bmc-work/shards/completion-nonvacuity.changed" \
  "$wrong_bound/valid-async-fifo-bmc-work/shards/completion-nonvacuity.sby"
expect_failure bound lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$wrong_bound"

wrong_transform="$scratch/wrong-transform"
cp -R "$clean" "$wrong_transform"
sed '/^wreduce$/d' \
  "$wrong_transform/valid-async-fifo-bmc-work/shards/integrity.sby" \
  >"$wrong_transform/valid-async-fifo-bmc-work/shards/integrity.changed"
mv "$wrong_transform/valid-async-fifo-bmc-work/shards/integrity.changed" \
  "$wrong_transform/valid-async-fifo-bmc-work/shards/integrity.sby"
expect_failure transform lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$wrong_transform"

wrong_status="$scratch/wrong-status"
cp -R "$clean" "$wrong_status"
printf '%s\n' 'PASS forged' \
  >"$wrong_status/valid-async-fifo-bmc-work/shards/completion-work/status"
expect_failure status lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$wrong_status"

extra_status="$scratch/extra-status"
cp -R "$clean" "$extra_status"
printf '%s\n' 'PASS 0 128' 'PASS 0 128' \
  >"$extra_status/valid-async-fifo-bmc-work/shards/completion-work/status"
expect_failure extra-status-line lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$extra_status"

malformed_status="$scratch/malformed-status"
cp -R "$clean" "$malformed_status"
printf '%s\n' 'PASS 0 128 forged' \
  >"$malformed_status/valid-async-fifo-bmc-work/shards/completion-work/status"
expect_failure malformed-status lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$malformed_status"

status_only="$scratch/status-only"
mkdir "$status_only"
lc_async_fifo_prepare_internal_shards \
  "$bundle" valid-async-fifo-bmc "$status_only"
write_child_statuses "$status_only"
expect_failure status-only lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$status_only"

missing_execution="$scratch/missing-execution"
cp -R "$clean" "$missing_execution"
rm "$missing_execution/valid-async-fifo-bmc-work/shards/integrity-work/model/design_smt2.smt2"
expect_failure missing-execution lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$missing_execution"

tampered_config="$scratch/tampered-config"
cp -R "$clean" "$tampered_config"
printf '%s\n' '# forged' \
  >>"$tampered_config/valid-async-fifo-bmc-work/shards/integrity-work/config.sby"
expect_failure tampered-config lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$tampered_config"

tampered_log="$scratch/tampered-log"
cp -R "$clean" "$tampered_log"
sed 's/returned pass/returned fail/' \
  "$tampered_log/valid-async-fifo-bmc-work/shards/integrity-work/logfile.txt" \
  >"$tampered_log/valid-async-fifo-bmc-work/shards/integrity-work/logfile.changed"
mv "$tampered_log/valid-async-fifo-bmc-work/shards/integrity-work/logfile.changed" \
  "$tampered_log/valid-async-fifo-bmc-work/shards/integrity-work/logfile.txt"
expect_failure tampered-log lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$tampered_log"

wrong_depth="$scratch/wrong-depth"
cp -R "$clean" "$wrong_depth"
sed 's/Checking assertions in step 127../Checking assertions in step 126../' \
  "$wrong_depth/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.txt" \
  >"$wrong_depth/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.changed"
mv "$wrong_depth/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.changed" \
  "$wrong_depth/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.txt"
expect_failure wrong-depth lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$wrong_depth"

later_step="$scratch/later-step"
cp -R "$clean" "$later_step"
awk \
  '/Status: passed$/ { print "##   0:00:00  Checking assertions in step 128.." } { print }' \
  "$later_step/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.txt" \
  >"$later_step/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.changed"
mv "$later_step/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.changed" \
  "$later_step/valid-async-fifo-bmc-work/shards/integrity-work/engine_0/logfile.txt"
expect_failure later-step lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$later_step"

wrong_digest="$scratch/wrong-digest"
cp -R "$clean" "$wrong_digest"
zero=0000000000000000000000000000000000000000000000000000000000000000
sed "s/^PARENT-EXECUTION .* sha256 .*/PARENT-EXECUTION valid-async-fifo-bmc.lcfg sha256 $zero/" \
  "$wrong_digest/valid-async-fifo-bmc-work/internal-shards.lcfs" \
  >"$wrong_digest/valid-async-fifo-bmc-work/internal-shards.changed"
mv "$wrong_digest/valid-async-fifo-bmc-work/internal-shards.changed" \
  "$wrong_digest/valid-async-fifo-bmc-work/internal-shards.lcfs"
expect_failure digest lc_async_fifo_verify_internal_shards \
  "$bundle" valid-async-fifo-bmc "$wrong_digest"

printf '%s\n' \
  'Asynchronous-FIFO internal shard self-tests pass: exact union plus 16 adversarial cases'
