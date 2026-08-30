#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
validator="$repo_dir/scripts/phase3-verilator-validate.sh"
runner="$repo_dir/scripts/phase3-verilator-run.sh"
lock_file="$repo_dir/toolchain/verilator/lock.json"
fixture_dir="$repo_dir/toolchain/verilator/fixtures"
scratch=$(mktemp -d /tmp/lunachip-verilator-selftest.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM

fail() {
  printf '%s\n' "phase3-verilator-selftest: $*" >&2
  exit 1
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

verify_receipt() {
  receipt=$1
  operation=$2
  mode=$3
  initializer=$4
  [ -f "$receipt" ] && [ ! -L "$receipt" ] ||
    fail "$operation receipt is absent or symbolic"
  [ "$(sed -n '1p' "$receipt")" = \
    'LUNACHIP-VERILATOR-OPERATION-RECEIPT 1' ] ||
    fail "$operation receipt header drifted"
  [ "$(sed -n '2p' "$receipt")" = "OPERATION $operation" ] ||
    fail "$operation receipt operation drifted"
  [ "$(sed -n '3p' "$receipt")" = "PLATFORM $platform" ] ||
    fail "$operation receipt platform drifted"
  [ "$(sed -n '4p' "$receipt")" = "OCI-IMAGE $image" ] ||
    fail "$operation receipt image drifted"
  [ "$(sed -n '5p' "$receipt")" = "IMAGE-ID $image_id" ] ||
    fail "$operation receipt image ID drifted"
  printf '%s\n' "$(sed -n '6p' "$receipt")" |
    grep -Eq '^RUNTIME-USER [0-9]+:[0-9]+$' ||
    fail "$operation receipt runtime user is not numeric"
  [ "$(sed -n '7p' "$receipt")" = "MOUNT-MODE $mode" ] ||
    fail "$operation receipt mount mode drifted"
  [ "$(sed -n '8p' "$receipt")" = \
    "VOLUME-PERMISSION-INITIALIZER $initializer" ] ||
    fail "$operation receipt initializer drifted"
  arguments=$(sed -n '10s/^ARGUMENTS //p' "$receipt")
  printf '%s\n' "$arguments" | grep -Eq '^[1-9][0-9]*$' ||
    fail "$operation receipt argument count is not canonical"
  [ "$(wc -l <"$receipt" | tr -d ' ')" -eq $((11 + arguments)) ] ||
    fail "$operation receipt line count drifted"
  LC_ALL=C awk -v arguments="$arguments" '
    NR >= 11 && NR < 11 + arguments {
      if ($1 != "ARG" || $2 != NR - 11 || NF != 3 ||
          $3 !~ /^([0-9a-f][0-9a-f])+$/) exit 1
    }
    END { if ($0 != "END") exit 1 }
  ' "$receipt" || fail "$operation receipt argument grammar drifted"
  command_copy="$scratch/$operation.command"
  {
    printf '%s\n' 'LUNACHIP-VERILATOR-COMMAND 1'
    sed -n '10,$p' "$receipt" | sed '$d'
    printf '%s\n' END
  } >"$command_copy"
  expected_sha=$(sed -n '9s/^COMMAND-SHA256 //p' "$receipt")
  [ "$(sha256_file "$command_copy")" = "$expected_sha" ] ||
    fail "$operation receipt command digest is not bound to its arguments"
}

"$validator"
"$validator" --harness-json "$fixture_dir/minimal-harness.json"
"$validator" --harness-json "$fixture_dir/atomic-harness.json"
"$validator" --stimulus-tsv \
  "$fixture_dir/atomic-harness.json" "$fixture_dir/atomic-stimulus.tsv"

if "$validator" --harness-json "$fixture_dir/invalid-harness-traversal.json" \
  >/dev/null 2>&1; then
  echo "phase3-verilator-selftest: traversal fixture was accepted" >&2
  exit 1
fi

for invalid_manifest in \
  "$fixture_dir/invalid-atomic-harness.json" \
  "$fixture_dir/invalid-atomic-harness-order.json"
do
  if "$validator" --harness-json "$invalid_manifest" >/dev/null 2>&1
  then
    echo "phase3-verilator-selftest: invalid v2 domain fixture was accepted: $invalid_manifest" >&2
    exit 1
  fi
done

for invalid_stimulus in \
  "$fixture_dir/invalid-atomic-order.tsv" \
  "$fixture_dir/invalid-atomic-duplicate.tsv" \
  "$fixture_dir/invalid-atomic-malformed.tsv" \
  "$fixture_dir/invalid-atomic-coincident.tsv" \
  "$fixture_dir/invalid-atomic-domain-order.tsv" \
  "$fixture_dir/invalid-atomic-unknown-domain.tsv"
do
  if "$validator" --stimulus-tsv \
    "$fixture_dir/atomic-harness.json" "$invalid_stimulus" >/dev/null 2>&1
  then
    echo "phase3-verilator-selftest: invalid atomic stimulus was accepted: $invalid_stimulus" >&2
    exit 1
  fi
done

if "$repo_dir/scripts/phase3-verilator-run.sh" unknown version \
  >/dev/null 2>&1; then
  echo "phase3-verilator-selftest: unknown provider was accepted" >&2
  exit 1
fi

# Receipt publication remains OCI-specific and operation-specific. Phase 3
# still permits bind transport, while later evidence gates may require volume.
grep -F 'receipt_name="verilator-$receipt_operation-receipt.txt"' \
  "$runner" >/dev/null || fail "runner no longer uses operation-specific receipts"
grep -F 'permission_initializer=pinned-image-chmod-0777-v1' \
  "$runner" >/dev/null || fail "volume permission initializer is not explicit"
grep -F 'permission_initializer=not-applicable' \
  "$runner" >/dev/null || fail "bind receipt initializer is not explicit"
grep -F 'ln "$receipt_temp" "$receipt_path"' "$runner" >/dev/null ||
  fail "receipt publication no longer refuses overwrite atomically"
grep -F '"$output_dir" lint "$permission_initializer" "$@"' \
  "$runner" >/dev/null || fail "lint receipt publisher is absent"
grep -F '"$output_dir" build "$permission_initializer" "$@"' \
  "$runner" >/dev/null || fail "build receipt publisher is absent"
grep -F 'publish_operation_receipt "$output_dir" execute "$permission_initializer"' \
  "$runner" >/dev/null || fail "execute receipt publisher is absent"

fake_bin="$scratch/fake-bin"
bundle="$scratch/bundle"
lint_output="$scratch/lint"
build_output="$scratch/build"
mkdir "$fake_bin" "$bundle" "$bundle/rtl" "$bundle/harness" \
  "$lint_output" "$build_output"
cp "$fixture_dir/atomic-harness.json" "$bundle/manifest.json"
cp "$fixture_dir/atomic-stimulus.tsv" "$bundle/atomic-stimulus.tsv"
printf '%s\n' 'module fixture_top(); endmodule' >"$bundle/rtl/fixture_top.sv"
printf '%s\n' 'int main() { return 0; }' >"$bundle/harness/lunachip_harness.cpp"

{
  printf '%s\n' \
    '#!/bin/sh' \
    'set -eu' \
    'case "$1" in' \
    '  info) exit 0 ;;' \
    '  image)' \
    '    [ "$2" = inspect ] || exit 91' \
    '    printf "[{\"Id\":\"%s\",\"Descriptor\":{\"digest\":\"%s\"},\"RepoDigests\":[\"%s\"],\"Os\":\"linux\",\"Architecture\":\"%s\"}]\\n" "$FAKE_IMAGE_ID" "$FAKE_IMAGE_DIGEST" "${FAKE_REPO_DIGEST:-$FAKE_IMAGE}" "$FAKE_ARCHITECTURE"' \
    '    ;;' \
    '  run)' \
    '    shift' \
    '    output=' \
    '    previous=' \
    '    arguments=' \
    '    for argument in "$@"; do' \
    '      arguments="$arguments $argument"' \
    '      if [ "$previous" = v ]; then' \
    '        case "$argument" in *:/out:rw) output=${argument%:/out:rw} ;; esac' \
    '        previous=' \
    '      elif [ "$argument" = -v ]; then' \
    '        previous=v' \
    '      fi' \
    '    done' \
    '    case "$arguments" in' \
    '      *" --version"*) printf "%s\\n" "Verilator 5.050 2026-07-01 fake" ;;' \
    '      *" --lint-only "*) : ;;' \
    '      *" --build "*)' \
    '        [ -n "$output" ] || exit 92' \
    '        mkdir -p "$output/obj_dir"' \
    '        printf "%s\\n" "#!/bin/sh" "exit 0" >"$output/obj_dir/Vlunachip_model"' \
    '        chmod 755 "$output/obj_dir/Vlunachip_model"' \
    '        ;;' \
    '      *" --entrypoint /out/obj_dir/Vlunachip_model "*)' \
    '        [ -n "$output" ] || exit 93' \
    '        printf "%s\\n" fake-result >"$output/actual.tsv"' \
    '        ;;' \
    '      *) exit 94 ;;' \
    '    esac' \
    '    ;;' \
    '  *) exit 95 ;;' \
    'esac'
} >"$fake_bin/docker"
chmod 755 "$fake_bin/docker"

case $(uname -m) in
  arm64|aarch64) platform=linux/arm64 ;;
  x86_64|amd64) platform=linux/amd64 ;;
  *) fail "unsupported selftest architecture" ;;
esac
architecture=${platform#linux/}
repository=$(jq -r '.providers.oci.repository' "$lock_file")
digest=$(jq -r --arg platform "$platform" \
  '.providers.oci.platforms[] | select(.platform == $platform) | .digest' \
  "$lock_file")
image="$repository@$digest"
image_id=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa

run_fake() {
  PATH="$fake_bin:$PATH" \
    LUNACHIP_VERILATOR_MOUNT_MODE=bind \
    FAKE_IMAGE="$image" FAKE_IMAGE_DIGEST="$digest" \
    FAKE_REPO_DIGEST="${image#docker.io/}" \
    FAKE_IMAGE_ID="$image_id" FAKE_ARCHITECTURE="$architecture" \
    "$runner" "$@"
}
run_fake oci lint "$bundle" "$lint_output"
run_fake oci build "$bundle" "$build_output"
run_fake oci execute "$bundle" "$build_output"

lint_receipt="$lint_output/verilator-lint-receipt.txt"
build_receipt="$build_output/verilator-build-receipt.txt"
execute_receipt="$build_output/verilator-execute-receipt.txt"
verify_receipt "$lint_receipt" lint bind not-applicable
verify_receipt "$build_receipt" build bind not-applicable
verify_receipt "$execute_receipt" execute bind not-applicable
[ -x "$build_output/obj_dir/Vlunachip_model" ] ||
  fail "fake OCI build did not preserve its executable"
[ -f "$build_output/actual.tsv" ] ||
  fail "fake OCI execution did not preserve its result"
grep -Fx 'ARG 0 766572696c61746f72' "$lint_receipt" >/dev/null ||
  fail "lint receipt does not bind the logical Verilator command"
grep -Fx 'ARG 0 766572696c61746f72' "$build_receipt" >/dev/null ||
  fail "build receipt does not bind the logical Verilator command"
grep -Fx 'ARG 0 2f6f75742f6f626a5f6469722f566c756e61636869705f6d6f64656c' \
  "$execute_receipt" >/dev/null ||
  fail "execute receipt does not bind the compiled model command"

mutant="$scratch/mutated-receipt.txt"
sed 's/^COMMAND-SHA256 .*/COMMAND-SHA256 0000000000000000000000000000000000000000000000000000000000000000/' \
  "$build_receipt" >"$mutant"
{
  printf '%s\n' 'LUNACHIP-VERILATOR-COMMAND 1'
  sed -n '10,$p' "$mutant" | sed '$d'
  printf '%s\n' END
} >"$scratch/mutated-command.txt"
[ "$(sha256_file "$scratch/mutated-command.txt")" != \
  "$(sed -n '9s/^COMMAND-SHA256 //p' "$mutant")" ] ||
  fail "mutated command digest remained valid"

invalid_output="$scratch/invalid-mode"
mkdir "$invalid_output"
if PATH="$fake_bin:$PATH" LUNACHIP_VERILATOR_MOUNT_MODE=unsafe \
  FAKE_IMAGE="$image" FAKE_IMAGE_DIGEST="$digest" \
  FAKE_IMAGE_ID="$image_id" FAKE_ARCHITECTURE="$architecture" \
  "$runner" oci lint "$bundle" "$invalid_output" >/dev/null 2>&1; then
  fail "invalid mount mode was accepted"
fi
[ -z "$(find "$invalid_output" -mindepth 1 -print)" ] ||
  fail "invalid mount mode published an artifact"

bad_digest=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
if PATH="$fake_bin:$PATH" LUNACHIP_VERILATOR_MOUNT_MODE=bind \
  FAKE_IMAGE="$image" FAKE_IMAGE_DIGEST="$bad_digest" \
  FAKE_IMAGE_ID="$image_id" FAKE_ARCHITECTURE="$architecture" \
  "$runner" oci version >/dev/null 2>&1; then
  fail "image metadata with the wrong locked digest was accepted"
fi

echo "Verilator boundary self-tests pass"
