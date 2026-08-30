#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
export LUNACHIP_VERILATOR_EVIDENCE_LIB_DIR="$repo_dir/scripts"
# shellcheck source=./verilator-evidence-lib.sh
. "$repo_dir/scripts/verilator-evidence-lib.sh"

fail() {
  printf '%s\n' "verilator-evidence-selftest: $*" >&2
  exit 1
}

passed=0
expect_pass() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    passed=$((passed + 1))
  else
    fail "expected pass: $label"
  fi
}
expect_fail() {
  label=$1
  shift
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $label"
  else
    passed=$((passed + 1))
  fi
}

test_root=$(mktemp -d "${TMPDIR:-/tmp}/lunachip-verilator-evidence.XXXXXX")
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

arm_digest=sha256:dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
amd_digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
image_id=sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
image="docker.io/verilator/verilator@$arm_digest"
lock="$test_root/lock.json"
printf '%s\n' \
  '{' \
  '  "providers": {' \
  '    "oci": {' \
  '      "repository": "docker.io/verilator/verilator",' \
  '      "platforms": [' \
  "        {\"platform\":\"linux/amd64\",\"digest\":\"$amd_digest\"}," \
  "        {\"platform\":\"linux/arm64\",\"digest\":\"$arm_digest\"}" \
  '      ]' \
  '    }' \
  '  }' \
  '}' >"$lock"

expect_pass "arm64 lock selection" \
  lc_verilator_select_locked_image "$lock" arm64
expect_pass "aarch64 lock selection" \
  lc_verilator_select_locked_image "$lock" aarch64
expect_pass "amd64 lock selection" \
  lc_verilator_select_locked_image "$lock" amd64
expect_pass "x86_64 lock selection" \
  lc_verilator_select_locked_image "$lock" x86_64
expect_fail "unknown host architecture" \
  lc_verilator_select_locked_image "$lock" riscv64

inspect="$test_root/inspect.json"
printf '[{"Id":"%s","RepoDigests":["%s"],"Os":"linux","Architecture":"arm64","Descriptor":{"digest":"%s"}}]\n' \
  "$image_id" "${image#docker.io/}" "$arm_digest" >"$inspect"
expect_pass "strict matching image inspect" \
  lc_verilator_verify_image_inspect "$lock" arm64 "$inspect"

bad_inspect="$test_root/bad-inspect.json"
sed 's/"Architecture":"arm64"/"Architecture":"amd64"/' \
  "$inspect" >"$bad_inspect"
expect_fail "wrong inspect platform" \
  lc_verilator_verify_image_inspect "$lock" arm64 "$bad_inspect"
sed "s/$arm_digest/$amd_digest/g" "$inspect" >"$bad_inspect"
expect_fail "wrong inspect repository digest" \
  lc_verilator_verify_image_inspect "$lock" arm64 "$bad_inspect"
sed "s/\"Descriptor\":{\"digest\":\"$arm_digest\"}/\"Descriptor\":{\"digest\":\"$amd_digest\"}/" \
  "$inspect" >"$bad_inspect"
expect_fail "wrong inspect descriptor digest" \
  lc_verilator_verify_image_inspect "$lock" arm64 "$bad_inspect"
sed "s/$image_id/sha256:short/" "$inspect" >"$bad_inspect"
expect_fail "malformed inspect image ID" \
  lc_verilator_verify_image_inspect "$lock" arm64 "$bad_inspect"
printf '[{"Id":"%s","RepoDigests":[],"Os":"linux","Architecture":"arm64"}]\n' \
  "$image_id" >"$bad_inspect"
expect_fail "missing locked repo digest" \
  lc_verilator_verify_image_inspect "$lock" arm64 "$bad_inspect"
ln -s "$inspect" "$test_root/inspect-link.json"
expect_fail "symbolic inspect document" \
  lc_verilator_verify_image_inspect \
    "$lock" arm64 "$test_root/inspect-link.json"

write_operation_receipt() {
  output=$1
  operation=$2
  platform=$3
  selected_image=$4
  selected_image_id=$5
  runtime_user=$6
  mode=$7
  initializer=$8
  shift 8
  command_file="$test_root/command.$$"
  {
    printf '%s\n' \
      'LUNACHIP-VERILATOR-COMMAND 1' \
      "ARGUMENTS $#"
    index=0
    for argument in "$@"; do
      printf 'ARG %s %s\n' \
        "$index" "$(lc_verilator_evidence_hex "$argument")"
      index=$((index + 1))
    done
    printf '%s\n' END
  } >"$command_file"
  command_sha=$(lc_manifest_sha256_file "$command_file")
  {
    printf '%s\n' \
      'LUNACHIP-VERILATOR-OPERATION-RECEIPT 1' \
      "OPERATION $operation" \
      "PLATFORM $platform" \
      "OCI-IMAGE $selected_image" \
      "IMAGE-ID $selected_image_id" \
      "RUNTIME-USER $runtime_user" \
      "MOUNT-MODE $mode" \
      "VOLUME-PERMISSION-INITIALIZER $initializer" \
      "COMMAND-SHA256 $command_sha"
    sed -n '2,$p' "$command_file"
  } >"$output"
  rm -f "$command_file"
}

receipt_dir="$test_root/receipts"
mkdir -p "$receipt_dir"
receipt="$receipt_dir/verilator-execute-receipt.txt"
write_operation_receipt "$receipt" execute linux/arm64 "$image" \
  "$image_id" 501:20 volume pinned-image-chmod-0777-v1 \
  /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv
expect_pass "exact execute operation receipt" \
  lc_verilator_verify_operation_receipt \
    "$receipt" execute linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv
expect_fail "receipt wrong expected command" \
  lc_verilator_verify_operation_receipt \
    "$receipt" execute linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/other.tsv /out/actual.tsv
expect_fail "receipt wrong expected platform" \
  lc_verilator_verify_operation_receipt \
    "$receipt" execute linux/amd64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv
wrong_image_id=sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
expect_fail "receipt wrong observed image ID metadata" \
  lc_verilator_verify_operation_receipt \
    "$receipt" execute linux/arm64 "$image" "$wrong_image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv
expect_fail "receipt inconsistent mount initializer" \
  lc_verilator_verify_operation_receipt \
    "$receipt" execute linux/arm64 "$image" "$image_id" 501:20 \
    bind pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv

lint_receipt="$receipt_dir/verilator-lint-receipt.txt"
write_operation_receipt "$lint_receipt" lint linux/arm64 "$image" \
  "$image_id" 501:20 volume pinned-image-chmod-0777-v1 \
  verilator --lint-only --top-module chip_top /work/chip_top.sv
expect_pass "exact lint operation receipt" \
  lc_verilator_verify_operation_receipt \
    "$lint_receipt" lint linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    verilator --lint-only --top-module chip_top /work/chip_top.sv
build_receipt="$receipt_dir/verilator-build-receipt.txt"
write_operation_receipt "$build_receipt" build linux/arm64 "$image" \
  "$image_id" 501:20 volume pinned-image-chmod-0777-v1 \
  verilator --cc --build --top-module chip_top /work/chip_top.sv /work/harness.cpp
expect_pass "exact build operation receipt" \
  lc_verilator_verify_operation_receipt \
    "$build_receipt" build linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    verilator --cc --build --top-module chip_top \
    /work/chip_top.sv /work/harness.cpp
noncanonical="$receipt_dir/noncanonical-execute.txt"
write_operation_receipt "$noncanonical" execute linux/arm64 "$image" \
  "$image_id" 501:20 volume pinned-image-chmod-0777-v1 \
  verilator /work/stimulus.tsv /out/actual.tsv
expect_fail "noncanonical execute executable" \
  lc_verilator_verify_operation_receipt \
    "$noncanonical" execute linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    verilator /work/stimulus.tsv /out/actual.tsv

malformed="$receipt_dir/malformed.txt"
sed 's/^ARG 1 /ARG 7 /' "$receipt" >"$malformed"
expect_fail "malformed receipt argument index" \
  lc_verilator_verify_operation_receipt \
    "$malformed" execute linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv
sed 's/^IMAGE-ID .*/IMAGE-ID sha256:ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff/' \
  "$receipt" >"$malformed"
expect_fail "receipt image ID mismatch" \
  lc_verilator_verify_operation_receipt \
    "$malformed" execute linux/arm64 "$image" "$image_id" 501:20 \
    volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv
ln -s "$receipt" "$receipt_dir/receipt-link.txt"
expect_fail "symbolic operation receipt" \
  lc_verilator_verify_operation_receipt \
    "$receipt_dir/receipt-link.txt" execute linux/arm64 "$image" \
    "$image_id" 501:20 volume pinned-image-chmod-0777-v1 \
    /out/obj_dir/Vlunachip_model /work/stimulus.tsv /out/actual.tsv

write_bundle() {
  root=$1
  mkdir -p "$root"
  printf '%s\n' \
    '{' \
    '  "$schema": "https://lunachip.dev/schema/verilator-harness-v2.json",' \
    '  "schema_version": "lunachip.verilator-harness/v2",' \
    '  "top_module": "chip_top",' \
    '  "sources": ["chip_top.sv"],' \
    '  "harness_cpp": "harness.cpp",' \
    '  "stimulus": "stimulus.tsv",' \
    '  "stimulus_schema": "lunachip.verilator-stimulus/v2",' \
    '  "result": "actual.tsv",' \
    '  "domains": [{"id":0,"clock_port":"clock","edge":"rising"}],' \
    '  "ports": [{"name":"clock","direction":"input","width":1,"signed":false}]' \
    '}' >"$root/manifest.json"
  printf '%s\n' 'module chip_top; endmodule' >"$root/chip_top.sv"
  printf '%s\n' 'int main() { return 0; }' >"$root/harness.cpp"
  printf '%s\n' 'LUNACHIP-ATOMIC-STIMULUS 2' >"$root/stimulus.tsv"
  printf '%s\n' 'design' >"$root/design.lcir"
  printf '%s\n' 'expected' >"$root/expected.tsv"
  printf '%s\n' 'names' >"$root/names.lcnm"
}

bundle="$test_root/bundle"
write_bundle "$bundle"
expect_pass "exact harness-v2 bundle closure" \
  lc_verilator_verify_harness_v2_bundle \
    "$bundle" chip_top design.lcir expected.tsv names.lcnm

missing="$test_root/bundle-missing"
cp -R "$bundle" "$missing"
rm "$missing/expected.tsv"
expect_fail "missing bundle file" \
  lc_verilator_verify_harness_v2_bundle \
    "$missing" chip_top design.lcir expected.tsv names.lcnm
extra="$test_root/bundle-extra"
cp -R "$bundle" "$extra"
printf '%s\n' surprise >"$extra/surprise.txt"
expect_fail "extra bundle file" \
  lc_verilator_verify_harness_v2_bundle \
    "$extra" chip_top design.lcir expected.tsv names.lcnm
nested="$test_root/bundle-nested"
cp -R "$bundle" "$nested"
mkdir "$nested/nested"
printf '%s\n' surprise >"$nested/nested/file"
expect_fail "nested bundle path" \
  lc_verilator_verify_harness_v2_bundle \
    "$nested" chip_top design.lcir expected.tsv names.lcnm
linked="$test_root/bundle-linked"
cp -R "$bundle" "$linked"
rm "$linked/names.lcnm"
ln -s design.lcir "$linked/names.lcnm"
expect_fail "symbolic bundle file" \
  lc_verilator_verify_harness_v2_bundle \
    "$linked" chip_top design.lcir expected.tsv names.lcnm
special="$test_root/bundle-special"
cp -R "$bundle" "$special"
mkfifo "$special/special.fifo"
expect_fail "special bundle path" \
  lc_verilator_verify_harness_v2_bundle \
    "$special" chip_top design.lcir expected.tsv names.lcnm
preexisting="$test_root/bundle-result"
cp -R "$bundle" "$preexisting"
printf '%s\n' stale >"$preexisting/actual.tsv"
expect_fail "pre-existing result in input bundle" \
  lc_verilator_verify_harness_v2_bundle \
    "$preexisting" chip_top design.lcir expected.tsv names.lcnm
bad_manifest="$test_root/bundle-manifest"
cp -R "$bundle" "$bad_manifest"
sed 's/"sources": \["chip_top.sv"\]/"sources": ["other.sv"]/' \
  "$bundle/manifest.json" >"$bad_manifest/manifest.json"
expect_fail "manifest source/top mismatch" \
  lc_verilator_verify_harness_v2_bundle \
    "$bad_manifest" chip_top design.lcir expected.tsv names.lcnm
expect_fail "duplicate caller extra" \
  lc_verilator_verify_harness_v2_bundle \
    "$bundle" chip_top design.lcir expected.tsv expected.tsv names.lcnm
expect_fail "nested caller extra" \
  lc_verilator_verify_harness_v2_bundle \
    "$bundle" chip_top design.lcir sub/expected.tsv names.lcnm

lint_tree="$test_root/lint-tree"
mkdir "$lint_tree"
printf '%s\n' receipt >"$lint_tree/verilator-lint-receipt.txt"
expect_pass "safe exact lint tree" \
  lc_verilator_verify_output_tree "$lint_tree" lint
printf '%s\n' extra >"$lint_tree/extra"
expect_fail "extra lint output" \
  lc_verilator_verify_output_tree "$lint_tree" lint
rm "$lint_tree/extra"
rm "$lint_tree/verilator-lint-receipt.txt"
ln -s missing "$lint_tree/verilator-lint-receipt.txt"
expect_fail "symbolic lint output" \
  lc_verilator_verify_output_tree "$lint_tree" lint

build_tree="$test_root/build-tree"
mkdir -p "$build_tree/obj_dir/vlt/include"
printf '%s\n' binary >"$build_tree/obj_dir/Vlunachip_model"
chmod +x "$build_tree/obj_dir/Vlunachip_model"
printf '%s\n' generated >"$build_tree/obj_dir/Vlunachip_model.cpp"
printf '%s\n' header >"$build_tree/obj_dir/vlt/include/verilated.h"
printf '%s\n' receipt >"$build_tree/verilator-build-receipt.txt"
expect_pass "safe build tree" \
  lc_verilator_verify_output_tree "$build_tree" build
manifest="$test_root/build-tree.manifest"
expect_pass "create build-tree manifest" \
  lc_verilator_create_tree_manifest "$build_tree" "$manifest"
expect_pass "verify unchanged build-tree manifest" \
  lc_verilator_verify_tree_manifest "$build_tree" "$manifest"
printf '%s\n' drift >>"$build_tree/obj_dir/Vlunachip_model.cpp"
expect_fail "artifact manifest detects drift" \
  lc_verilator_verify_tree_manifest "$build_tree" "$manifest"
sed -i.bak '$d' "$build_tree/obj_dir/Vlunachip_model.cpp"
rm "$build_tree/obj_dir/Vlunachip_model.cpp.bak"
mkfifo "$build_tree/obj_dir/special.fifo"
expect_fail "special build output" \
  lc_verilator_verify_output_tree "$build_tree" build
rm "$build_tree/obj_dir/special.fifo"
ln -s Vlunachip_model "$build_tree/obj_dir/model-link"
expect_fail "symbolic build output" \
  lc_verilator_verify_output_tree "$build_tree" build
rm "$build_tree/obj_dir/model-link"
mkdir "$build_tree/obj_dir/empty"
expect_fail "empty unbound build directory" \
  lc_verilator_verify_output_tree "$build_tree" build
rmdir "$build_tree/obj_dir/empty"
mkdir "$build_tree/obj_dir/bad:name"
printf '%s\n' bad >"$build_tree/obj_dir/bad:name/file"
expect_fail "unsafe build directory" \
  lc_verilator_verify_output_tree "$build_tree" build
rm "$build_tree/obj_dir/bad:name/file"
rmdir "$build_tree/obj_dir/bad:name"

printf '%s\n' 'time boundary result' >"$build_tree/actual.tsv"
printf '%s\n' receipt >"$build_tree/verilator-execute-receipt.txt"
expect_pass "safe execute tree" \
  lc_verilator_verify_output_tree "$build_tree" execute
printf '%s\n' stale >"$build_tree/unbound.txt"
expect_fail "extra execute output" \
  lc_verilator_verify_output_tree "$build_tree" execute

printf '%s\n' "verilator-evidence-selftest: PASS ($passed adversarial checks)"
