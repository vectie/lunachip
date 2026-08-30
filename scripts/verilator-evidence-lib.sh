#!/bin/sh
# Shared, phase-neutral verification helpers for pinned Verilator evidence.
#
# The image selected from lock.json is content-addressed by its repository
# digest. Docker's image-inspect .Id is verified and bound into operation
# receipts as IMAGE-ID, but is deliberately not described here as an
# independently lock-pinned value.

lc_verilator_evidence_lib_dir=${LUNACHIP_VERILATOR_EVIDENCE_LIB_DIR-}
if [ -z "$lc_verilator_evidence_lib_dir" ]; then
  case "$0" in
    */scripts/*) lc_verilator_evidence_lib_dir=$(dirname -- "$0") ;;
    *) lc_verilator_evidence_lib_dir=./scripts ;;
  esac
fi

if ! command -v lc_evidence_create_artifact_manifest >/dev/null 2>&1; then
  # shellcheck source=./evidence-manifest-lib.sh
  . "$lc_verilator_evidence_lib_dir/evidence-manifest-lib.sh"
fi
if ! command -v lc_evidence_validate_receipt >/dev/null 2>&1; then
  # shellcheck source=./evidence-receipt-lib.sh
  . "$lc_verilator_evidence_lib_dir/evidence-receipt-lib.sh"
fi
unset lc_verilator_evidence_lib_dir

lc_verilator_evidence_error() {
  printf '%s\n' "verilator-evidence: $*" >&2
  return 1
}

lc_verilator_evidence_hex() {
  [ "$#" -eq 1 ] || return 1
  printf '%s' "$1" | LC_ALL=C od -An -tx1 | tr -d ' \n'
}

# Print: PLATFORM LOCKED_IMAGE LOCKED_REPOSITORY_DIGEST
lc_verilator_select_locked_image() {
  [ "$#" -eq 2 ] || {
    lc_verilator_evidence_error \
      "select_locked_image requires LOCK_FILE HOST_ARCH"
    return 1
  }
  lcvsli_lock=$1
  lcvsli_arch=$2
  [ -f "$lcvsli_lock" ] && [ ! -L "$lcvsli_lock" ] || {
    lc_verilator_evidence_error "lock is absent or symbolic: $lcvsli_lock"
    return 1
  }
  command -v jq >/dev/null 2>&1 || {
    lc_verilator_evidence_error "jq is required"
    return 1
  }
  case "$lcvsli_arch" in
    arm64|aarch64) lcvsli_platform=linux/arm64 ;;
    x86_64|amd64) lcvsli_platform=linux/amd64 ;;
    *)
      lc_verilator_evidence_error \
        "unsupported OCI host architecture: $lcvsli_arch"
      return 1
      ;;
  esac
  lcvsli_selection=$(jq -er --arg platform "$lcvsli_platform" '
    .providers.oci as $oci |
    ($oci.repository | select(type == "string" and
      test("^[A-Za-z0-9][A-Za-z0-9._/-]*[A-Za-z0-9]$"))) as $repository |
    ([ $oci.platforms[] |
      select(.platform == $platform and
        (.digest | type == "string" and
          test("^sha256:[0-9a-f]{64}$"))) ] |
      select(length == 1) | .[0].digest) as $digest |
    "\($repository) \($digest)"
  ' "$lcvsli_lock") || {
    lc_verilator_evidence_error \
      "lock has no unique valid OCI selection for $lcvsli_platform"
    return 1
  }
  set -- $lcvsli_selection
  [ "$#" -eq 2 ] || {
    lc_verilator_evidence_error "unsafe OCI repository in lock"
    return 1
  }
  printf '%s %s@%s %s\n' "$lcvsli_platform" "$1" "$2" "$2"
}

# Verify a saved `docker image inspect` JSON document and print:
# PLATFORM LOCKED_IMAGE OBSERVED_IMAGE_ID
lc_verilator_verify_image_inspect() {
  [ "$#" -eq 3 ] || {
    lc_verilator_evidence_error \
      "verify_image_inspect requires LOCK_FILE HOST_ARCH INSPECT_JSON"
    return 1
  }
  lcvvii_lock=$1
  lcvvii_arch=$2
  lcvvii_inspect=$3
  [ -f "$lcvvii_inspect" ] && [ ! -L "$lcvvii_inspect" ] || {
    lc_verilator_evidence_error \
      "image inspect document is absent or symbolic: $lcvvii_inspect"
    return 1
  }
  lcvvii_selection=$(
    lc_verilator_select_locked_image "$lcvvii_lock" "$lcvvii_arch"
  ) || return 1
  set -- $lcvvii_selection
  [ "$#" -eq 3 ] || return 1
  lcvvii_platform=$1
  lcvvii_image=$2
  lcvvii_digest=$3
  lcvvii_image_id=$(jq -er \
    --arg image "$lcvvii_image" \
    --arg digest "$lcvvii_digest" \
    --arg platform "$lcvvii_platform" '
      ($image | sub("^docker.io/"; "")) as $short_image |
      select(type == "array" and length == 1) |
      .[0] as $item |
      select(($item.RepoDigests | type == "array") and
        (($item.RepoDigests | index($image)) != null or
          ($item.RepoDigests | index($short_image)) != null)) |
      select(($item.Os + "/" + $item.Architecture) == $platform) |
      select(($item.Descriptor.digest? // $digest) == $digest) |
      $item.Id |
      select(type == "string" and test("^sha256:[0-9a-f]{64}$"))
    ' "$lcvvii_inspect") || {
    lc_verilator_evidence_error \
      "Docker image metadata does not match the locked repository digest and platform"
    return 1
  }
  printf '%s %s %s\n' \
    "$lcvvii_platform" "$lcvvii_image" "$lcvvii_image_id"
}

# Verify the exact operation receipt emitted by phase3-verilator-run.sh.
# Arguments after INITIALIZER are the exact logical command arguments.
lc_verilator_verify_operation_receipt() {
  [ "$#" -ge 9 ] || {
    lc_verilator_evidence_error \
      "verify_operation_receipt requires RECEIPT OP PLATFORM IMAGE IMAGE_ID USER MODE INITIALIZER ARG [ARG ...]"
    return 1
  }
  lcvvor_receipt=$1
  lcvvor_operation=$2
  lcvvor_platform=$3
  lcvvor_image=$4
  lcvvor_image_id=$5
  lcvvor_user=$6
  lcvvor_mode=$7
  lcvvor_initializer=$8
  shift 8
  case "$lcvvor_operation" in lint|build|execute) ;; *)
    lc_verilator_evidence_error "invalid operation: $lcvvor_operation"
    return 1 ;;
  esac
  case "$lcvvor_platform" in linux/amd64|linux/arm64) ;; *)
    lc_verilator_evidence_error "invalid platform: $lcvvor_platform"
    return 1 ;;
  esac
  printf '%s\n' "$lcvvor_image" |
    LC_ALL=C grep -Eq \
      '^[A-Za-z0-9][A-Za-z0-9._/-]*[A-Za-z0-9]@sha256:[0-9a-f]{64}$' || {
    lc_verilator_evidence_error "invalid locked image reference"
    return 1
  }
  printf '%s\n' "$lcvvor_image_id" |
    LC_ALL=C grep -Eq '^sha256:[0-9a-f]{64}$' || {
    lc_verilator_evidence_error "invalid observed Docker image ID"
    return 1
  }
  printf '%s\n' "$lcvvor_user" |
    LC_ALL=C grep -Eq '^(0|[1-9][0-9]*):(0|[1-9][0-9]*)$' || {
    lc_verilator_evidence_error "invalid runtime user"
    return 1
  }
  case "$lcvvor_mode:$lcvvor_initializer" in
    bind:not-applicable|volume:pinned-image-chmod-0777-v1) ;;
    *)
      lc_verilator_evidence_error \
        "mount mode and permission initializer are inconsistent"
      return 1
      ;;
  esac
  case "$lcvvor_operation:$1" in
    lint:verilator|build:verilator|execute:/out/obj_dir/Vlunachip_model) ;;
    *)
      lc_verilator_evidence_error \
        "operation receipt command does not use the canonical executable"
      return 1
      ;;
  esac
  [ -f "$lcvvor_receipt" ] && [ ! -L "$lcvvor_receipt" ] || {
    lc_verilator_evidence_error \
      "operation receipt is absent or symbolic: $lcvvor_receipt"
    return 1
  }
  lcvvor_parent=$(dirname -- "$lcvvor_receipt")
  lcvvor_parent=$(lc_manifest_canonical_dir "$lcvvor_parent") || return 1
  lcvvor_command=$(mktemp "$lcvvor_parent/.verilator-command.expected.XXXXXX") ||
    return 1
  lcvvor_expected=$(mktemp "$lcvvor_parent/.verilator-receipt.expected.XXXXXX") || {
    rm -f "$lcvvor_command"
    return 1
  }
  lcvvor_arguments=$#
  {
    printf '%s\n' \
      'LUNACHIP-VERILATOR-COMMAND 1' \
      "ARGUMENTS $lcvvor_arguments"
    lcvvor_index=0
    for lcvvor_argument in "$@"; do
      [ -n "$lcvvor_argument" ] || {
        lc_verilator_evidence_error "empty command argument is forbidden"
        exit 1
      }
      printf 'ARG %s %s\n' \
        "$lcvvor_index" "$(lc_verilator_evidence_hex "$lcvvor_argument")"
      lcvvor_index=$((lcvvor_index + 1))
    done
    printf '%s\n' END
  } >"$lcvvor_command" || {
    lcvvor_status=$?
    rm -f "$lcvvor_command" "$lcvvor_expected"
    return "$lcvvor_status"
  }
  lcvvor_command_sha=$(lc_manifest_sha256_file "$lcvvor_command") || {
    rm -f "$lcvvor_command" "$lcvvor_expected"
    return 1
  }
  {
    printf '%s\n' \
      'LUNACHIP-VERILATOR-OPERATION-RECEIPT 1' \
      "OPERATION $lcvvor_operation" \
      "PLATFORM $lcvvor_platform" \
      "OCI-IMAGE $lcvvor_image" \
      "IMAGE-ID $lcvvor_image_id" \
      "RUNTIME-USER $lcvvor_user" \
      "MOUNT-MODE $lcvvor_mode" \
      "VOLUME-PERMISSION-INITIALIZER $lcvvor_initializer" \
      "COMMAND-SHA256 $lcvvor_command_sha"
    sed -n '2,$p' "$lcvvor_command"
  } >"$lcvvor_expected" || {
    lcvvor_status=$?
    rm -f "$lcvvor_command" "$lcvvor_expected"
    return "$lcvvor_status"
  }
  if cmp -s "$lcvvor_expected" "$lcvvor_receipt"; then
    lcvvor_status=0
  else
    lc_verilator_evidence_error \
      "operation receipt does not exactly match expected metadata and command"
    lcvvor_status=1
  fi
  rm -f "$lcvvor_command" "$lcvvor_expected"
  return "$lcvvor_status"
}

# Enforce the exact flat harness-v2 input bundle. `actual.tsv` is the fixed
# result path in manifest.json and must not pre-exist in the input bundle.
lc_verilator_verify_harness_v2_bundle() {
  [ "$#" -ge 2 ] || {
    lc_verilator_evidence_error \
      "verify_harness_v2_bundle requires BUNDLE TOP_MODULE [EXTRA_FILE ...]"
    return 1
  }
  lcvvhb_root=$(lc_manifest_canonical_dir "$1") || return 1
  lcvvhb_top=$2
  shift 2
  printf '%s\n' "$lcvvhb_top" |
    LC_ALL=C grep -Eq '^[A-Za-z_][A-Za-z0-9_$]*$' || {
    lc_verilator_evidence_error "invalid expected top module"
    return 1
  }
  lcvvhb_parent=$(dirname -- "$lcvvhb_root")
  lcvvhb_expected=$(mktemp "$lcvvhb_parent/.verilator-bundle.expected.XXXXXX") ||
    return 1
  lcvvhb_actual=$(mktemp "$lcvvhb_parent/.verilator-bundle.actual.XXXXXX") || {
    rm -f "$lcvvhb_expected"
    return 1
  }
  {
    printf '%s\n' \
      "$lcvvhb_top.sv" harness.cpp manifest.json stimulus.tsv
    for lcvvhb_extra in "$@"; do
      printf '%s\n' "$lcvvhb_extra" |
        LC_ALL=C grep -Eq '^[A-Za-z0-9][A-Za-z0-9._+-]*$' || {
        lc_verilator_evidence_error \
          "extra bundle file must be a safe flat basename: $lcvvhb_extra"
        exit 1
      }
      case "$lcvvhb_extra" in
        "$lcvvhb_top.sv"|harness.cpp|manifest.json|stimulus.tsv|actual.tsv)
          lc_verilator_evidence_error \
            "extra bundle file overlaps a fixed path: $lcvvhb_extra"
          exit 1
          ;;
      esac
      printf '%s\n' "$lcvvhb_extra"
    done
  } | LC_ALL=C sort >"$lcvvhb_expected" || {
    lcvvhb_status=$?
    rm -f "$lcvvhb_expected" "$lcvvhb_actual"
    return "$lcvvhb_status"
  }
  if [ "$(LC_ALL=C uniq "$lcvvhb_expected" | wc -l | tr -d ' ')" != \
    "$(wc -l <"$lcvvhb_expected" | tr -d ' ')" ]; then
    lc_verilator_evidence_error "bundle file list contains duplicates"
    rm -f "$lcvvhb_expected" "$lcvvhb_actual"
    return 1
  fi
  if lc_manifest_tree_paths "$lcvvhb_root" artifacts "$lcvvhb_actual"; then
    sed 's#^\./##' "$lcvvhb_actual" >"$lcvvhb_actual.stripped"
    mv "$lcvvhb_actual.stripped" "$lcvvhb_actual"
  else
    lcvvhb_status=$?
    rm -f "$lcvvhb_expected" "$lcvvhb_actual" "$lcvvhb_actual.stripped"
    return "$lcvvhb_status"
  fi
  if find "$lcvvhb_root" -mindepth 1 -type d -print | grep -q .; then
    lc_verilator_evidence_error "harness bundle must be flat"
    rm -f "$lcvvhb_expected" "$lcvvhb_actual"
    return 1
  fi
  if ! cmp -s "$lcvvhb_expected" "$lcvvhb_actual"; then
    lc_verilator_evidence_error \
      "harness bundle has missing, extra, or nested paths"
    rm -f "$lcvvhb_expected" "$lcvvhb_actual"
    return 1
  fi
  rm -f "$lcvvhb_expected" "$lcvvhb_actual"
  jq -e --arg top "$lcvvhb_top" '
    ((keys - [
      "$schema", "schema_version", "top_module", "sources", "harness_cpp",
      "stimulus", "stimulus_schema", "result", "domains", "ports"
    ]) | length == 0) and
    .["$schema"] == "https://lunachip.dev/schema/verilator-harness-v2.json" and
    .schema_version == "lunachip.verilator-harness/v2" and
    .top_module == $top and
    .sources == [($top + ".sv")] and
    .harness_cpp == "harness.cpp" and
    .stimulus == "stimulus.tsv" and
    .stimulus_schema == "lunachip.verilator-stimulus/v2" and
    .result == "actual.tsv" and
    (.domains | type == "array" and length > 0) and
    (.ports | type == "array" and length > 0)
  ' "$lcvvhb_root/manifest.json" >/dev/null || {
    lc_verilator_evidence_error \
      "manifest is not the exact single-source harness-v2 contract"
    return 1
  }
}

lc_verilator_verify_output_tree() {
  [ "$#" -eq 2 ] || {
    lc_verilator_evidence_error \
      "verify_output_tree requires ROOT {lint|build|execute}"
    return 1
  }
  lcvvot_root=$(lc_manifest_canonical_dir "$1") || return 1
  lcvvot_operation=$2
  case "$lcvvot_operation" in lint|build|execute) ;; *)
    lc_verilator_evidence_error "invalid output-tree operation"
    return 1 ;;
  esac
  lcvvot_parent=$(dirname -- "$lcvvot_root")
  lcvvot_paths=$(mktemp "$lcvvot_parent/.verilator-output.paths.XXXXXX") ||
    return 1
  if lc_manifest_tree_paths "$lcvvot_root" artifacts "$lcvvot_paths"; then
    :
  else
    lcvvot_status=$?
    rm -f "$lcvvot_paths"
    return "$lcvvot_status"
  fi
  if sed 's#^\./##' "$lcvvot_paths" |
    LC_ALL=C grep -Ev \
      '^[A-Za-z0-9._+$-]+(/[A-Za-z0-9._+$-]+)*$' | grep -q .; then
    lc_verilator_evidence_error "output tree contains an unsafe path"
    rm -f "$lcvvot_paths"
    return 1
  fi
  rm -f "$lcvvot_paths"
  lcvvot_dirs=$(mktemp "$lcvvot_parent/.verilator-output.dirs.XXXXXX") ||
    return 1
  (
    cd "$lcvvot_root"
    find . -mindepth 1 -type d -print | LC_ALL=C sort
  ) >"$lcvvot_dirs" || {
    lcvvot_status=$?
    rm -f "$lcvvot_dirs"
    return "$lcvvot_status"
  }
  if sed 's#^\./##' "$lcvvot_dirs" |
    LC_ALL=C grep -Ev \
      '^[A-Za-z0-9._+$-]+(/[A-Za-z0-9._+$-]+)*$' | grep -q .; then
    lc_verilator_evidence_error "output tree contains an unsafe directory"
    rm -f "$lcvvot_dirs"
    return 1
  fi
  while IFS= read -r lcvvot_dir; do
    [ -n "$lcvvot_dir" ] || continue
    if ! find "$lcvvot_root/${lcvvot_dir#./}" \
      -mindepth 1 -maxdepth 1 -print | grep -q .; then
      lc_verilator_evidence_error \
        "output tree contains an unbound empty directory: ${lcvvot_dir#./}"
      rm -f "$lcvvot_dirs"
      return 1
    fi
  done <"$lcvvot_dirs"
  rm -f "$lcvvot_dirs"
  lcvvot_top=$(mktemp "$lcvvot_parent/.verilator-output.top.XXXXXX") ||
    return 1
  (
    cd "$lcvvot_root"
    find . -mindepth 1 -maxdepth 1 -print | sed 's#^\./##' | LC_ALL=C sort
  ) >"$lcvvot_top" || {
    lcvvot_status=$?
    rm -f "$lcvvot_top"
    return "$lcvvot_status"
  }
  case "$lcvvot_operation" in
    lint)
      lcvvot_expected='verilator-lint-receipt.txt'
      ;;
    build)
      lcvvot_expected=$(printf '%s\n' obj_dir verilator-build-receipt.txt)
      ;;
    execute)
      lcvvot_expected=$(printf '%s\n' \
        actual.tsv obj_dir verilator-build-receipt.txt \
        verilator-execute-receipt.txt)
      ;;
  esac
  if [ "$(cat "$lcvvot_top")" != "$lcvvot_expected" ]; then
    lc_verilator_evidence_error \
      "unexpected top-level $lcvvot_operation output inventory"
    rm -f "$lcvvot_top"
    return 1
  fi
  rm -f "$lcvvot_top"
  case "$lcvvot_operation" in
    lint)
      [ -f "$lcvvot_root/verilator-lint-receipt.txt" ] &&
        [ ! -L "$lcvvot_root/verilator-lint-receipt.txt" ] || {
        lc_verilator_evidence_error "lint receipt is not a regular file"
        return 1
      }
      ;;
    build|execute)
      [ -d "$lcvvot_root/obj_dir" ] && [ ! -L "$lcvvot_root/obj_dir" ] &&
        [ -f "$lcvvot_root/obj_dir/Vlunachip_model" ] &&
        [ ! -L "$lcvvot_root/obj_dir/Vlunachip_model" ] &&
        [ -x "$lcvvot_root/obj_dir/Vlunachip_model" ] &&
        [ -f "$lcvvot_root/verilator-build-receipt.txt" ] &&
        [ ! -L "$lcvvot_root/verilator-build-receipt.txt" ] || {
        lc_verilator_evidence_error "compiled output closure is incomplete"
        return 1
      }
      if [ "$lcvvot_operation" = execute ]; then
        [ -s "$lcvvot_root/actual.tsv" ] &&
          [ ! -L "$lcvvot_root/actual.tsv" ] &&
          [ -f "$lcvvot_root/verilator-execute-receipt.txt" ] &&
          [ ! -L "$lcvvot_root/verilator-execute-receipt.txt" ] || {
          lc_verilator_evidence_error "execute output closure is incomplete"
          return 1
        }
      fi
      ;;
  esac
}

lc_verilator_create_tree_manifest() {
  [ "$#" -eq 2 ] || {
    lc_verilator_evidence_error \
      "create_tree_manifest requires ROOT DESTINATION"
    return 1
  }
  lc_evidence_create_artifact_manifest "$1" "$2"
}

lc_verilator_verify_tree_manifest() {
  [ "$#" -eq 2 ] || {
    lc_verilator_evidence_error \
      "verify_tree_manifest requires ROOT MANIFEST"
    return 1
  }
  lc_evidence_verify_manifest "$1" "$2" artifacts
}
