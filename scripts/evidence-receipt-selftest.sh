#!/bin/sh
set -eu

LC_ALL=C
export LC_ALL
umask 077

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$repo_dir/scripts/evidence-receipt-lib.sh"
. "$repo_dir/scripts/evidence-manifest-lib.sh"

fail() {
  printf '%s\n' "evidence-receipt-selftest: $*" >&2
  exit 1
}

expect_failure() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "$label unexpectedly passed"
  fi
}

scratch=$(mktemp -d /tmp/lunachip-evidence-receipt-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
header='LUNACHIP-SELFTEST-EVIDENCE 1'
allowed_records='HEAD,COMMAND'
required_records='HEAD,COMMAND'

mkdir "$scratch/logs"
incomplete="$scratch/evidence.incomplete"
final="$scratch/evidence.txt"
lc_evidence_receipt_begin "$incomplete" "$header"
lc_evidence_receipt_record "$incomplete" HEAD 0123456789abcdef
lc_evidence_run_logged "$incomplete" "$scratch/logs/pass.log" pass-command \
  sh -c 'printf "%s\n" pass'
if lc_evidence_run_logged "$incomplete" "$scratch/logs/fail.log" fail-command \
  sh -c 'printf "%s\n" fail; exit 7'; then
  fail "failing command unexpectedly passed"
else
  observed=$?
fi
[ "$observed" -eq 7 ] || fail "failing command status changed to $observed"
grep -Fx 'COMMAND pass-command status=0' "$incomplete" >/dev/null ||
  fail "successful command was not recorded"
grep -Fx 'COMMAND fail-command status=7' "$incomplete" >/dev/null ||
  fail "failed command was not recorded"
lc_evidence_receipt_seal \
  "$incomplete" "$header" "$allowed_records" "$required_records"
lc_evidence_validate_receipt \
  "$incomplete" "$header" incomplete "$allowed_records" "$required_records"
lc_evidence_receipt_publish_pass \
  "$incomplete" "$final" "$header" "$allowed_records" "$required_records"
[ ! -e "$incomplete" ] || fail "incomplete receipt survived pass publication"
lc_evidence_validate_receipt \
  "$final" "$header" pass "$allowed_records" "$required_records"

malformed="$scratch/malformed"
printf '%s\n' "$header" 'STATE pass' 'COMMAND\tbad\tstatus=0' END >"$malformed"
expect_failure literal-backslash-tab \
  lc_evidence_validate_receipt \
    "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' 'COMMAND  bad status=0' END >"$malformed"
expect_failure double-space lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' 'STATE pass' END >"$malformed"
expect_failure duplicate-state lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' 'COMMAND same status=0' \
  'COMMAND same status=0' END >"$malformed"
expect_failure duplicate-command lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' >"$malformed"
expect_failure missing-end lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' END 'TRAILING record' >"$malformed"
expect_failure trailing-record lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' "COMMAND${tab-$(printf '\t')}bad status=0" END >"$malformed"
expect_failure control-character lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' 'HEAD abc' 'COMMAND ok status=0' \
  'UNKNOWN forbidden' END >"$malformed"
expect_failure unknown-record lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' 'COMMAND ok status=0' END >"$malformed"
expect_failure missing-required-head lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"
printf '%s\n' "$header" 'STATE pass' 'HEAD abc' END >"$malformed"
expect_failure missing-required-command lc_evidence_validate_receipt \
  "$malformed" "$header" pass "$allowed_records" "$required_records"

second_incomplete="$scratch/second.incomplete"
lc_evidence_receipt_begin "$second_incomplete" "$header"
lc_evidence_receipt_record "$second_incomplete" HEAD abcdef
lc_evidence_receipt_record "$second_incomplete" COMMAND second status=0
lc_evidence_receipt_seal \
  "$second_incomplete" "$header" "$allowed_records" "$required_records"
expect_failure overwrite-final \
  lc_evidence_receipt_publish_pass \
    "$second_incomplete" "$final" "$header" "$allowed_records" "$required_records"

repository="$scratch/repository"
mkdir -p "$repository/.git" "$repository/_build" "$repository/src/nested"
printf '%s\n' tracked >"$repository/src/nested/file with space.txt"
printf '%s\n' unicode >"$repository/src/月.txt"
printf '%s\n' ignored-git >"$repository/.git/ignored"
printf '%s\n' ignored-build >"$repository/_build/ignored"
snapshot_one="$scratch/repository-one.sha256"
snapshot_two="$scratch/repository-two.sha256"
lc_evidence_snapshot_repository "$repository" "$snapshot_one"
lc_evidence_validate_manifest "$snapshot_one" repository
printf '%s\n' changed-git >"$repository/.git/ignored"
printf '%s\n' changed-build >"$repository/_build/ignored"
lc_evidence_snapshot_repository "$repository" "$snapshot_two"
cmp -s "$snapshot_one" "$snapshot_two" ||
  fail "excluded repository paths changed the snapshot"
printf '%s\n' changed >"$repository/src/nested/file with space.txt"
expect_failure repository-drift \
  lc_evidence_verify_manifest "$repository" "$snapshot_one" repository

artifacts="$scratch/artifacts"
mkdir -p "$artifacts/nested"
printf '%s\n' alpha >"$artifacts/a.txt"
printf '%s\n' beta >"$artifacts/nested/file with space.txt"
artifact_manifest="$scratch/artifacts.sha256"
lc_evidence_create_artifact_manifest "$artifacts" "$artifact_manifest"
lc_evidence_validate_manifest "$artifact_manifest" artifacts

printf '%s\n' changed >"$artifacts/a.txt"
expect_failure digest-drift \
  lc_evidence_verify_manifest "$artifacts" "$artifact_manifest" artifacts
printf '%s\n' alpha >"$artifacts/a.txt"
printf '%s\n' extra >"$artifacts/extra.txt"
expect_failure extra-file \
  lc_evidence_verify_manifest "$artifacts" "$artifact_manifest" artifacts
rm "$artifacts/extra.txt"
rm "$artifacts/a.txt"
expect_failure missing-file \
  lc_evidence_verify_manifest "$artifacts" "$artifact_manifest" artifacts
printf '%s\n' alpha >"$artifacts/a.txt"
lc_evidence_verify_manifest "$artifacts" "$artifact_manifest" artifacts

duplicate_manifest="$scratch/duplicate.sha256"
awk '/^END$/ && !done { print first; done = 1 } /^FILE / && first == "" { first = $0 } { print }' \
  "$artifact_manifest" >"$duplicate_manifest"
expect_failure duplicate-path \
  lc_evidence_validate_manifest "$duplicate_manifest" artifacts
unsafe_manifest="$scratch/unsafe.sha256"
printf '%s\n' 'LUNACHIP-EVIDENCE-FILE-MANIFEST 1' 'KIND artifacts' \
  'FILE 0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef 2e2e2f6576696c' \
  END >"$unsafe_manifest"
expect_failure unsafe-path lc_evidence_validate_manifest "$unsafe_manifest" artifacts

ln -s a.txt "$artifacts/link"
expect_failure artifact-symlink \
  lc_evidence_create_artifact_manifest "$artifacts" "$scratch/symlink.sha256"
rm "$artifacts/link"
mkfifo "$artifacts/pipe"
expect_failure artifact-special-file \
  lc_evidence_create_artifact_manifest "$artifacts" "$scratch/special.sha256"
rm "$artifacts/pipe"
newline=$(printf '\nx')
newline=${newline%x}
newline_file="$artifacts/bad${newline}name"
printf '%s\n' bad >"$newline_file"
expect_failure artifact-control-path \
  lc_evidence_create_artifact_manifest "$artifacts" "$scratch/control.sha256"
rm "$newline_file"
expect_failure manifest-inside-tree \
  lc_evidence_create_artifact_manifest "$artifacts" "$artifacts/manifest.sha256"

printf '%s\n' 'Evidence receipt helper self-tests pass'
