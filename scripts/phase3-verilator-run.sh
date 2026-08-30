#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/verilator/lock.json"

fail() {
  echo "phase3-verilator-run: $*" >&2
  exit 1
}

usage() {
  fail "usage: $0 {oci|archive} {version|lint|build|execute} [BUNDLE_DIR OUTPUT_DIR]"
}

[ "$#" -ge 2 ] || usage
provider=$1
mode=$2
shift 2

command -v jq >/dev/null 2>&1 || fail "jq is required to read the checked lock"
"$repo_dir/scripts/phase3-verilator-validate.sh" >/dev/null
expected_version=$(jq -r '.tool.expected_version_line' "$lock_file")
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
  sha256_stdin() { shasum -a 256 | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
  sha256_stdin() { sha256sum | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required to verify provider content"
fi

validate_bundle() {
  [ "$#" -eq 2 ] || usage
  bundle_arg=$1
  output_arg=$2
  [ -d "$bundle_arg" ] || fail "bundle directory does not exist: $bundle_arg"
  [ -d "$output_arg" ] || fail "output directory must already exist: $output_arg"
  [ ! -L "$output_arg" ] || fail "output directory must not be a symbolic link"
  [ -f "$bundle_arg/manifest.json" ] || fail "bundle is missing manifest.json"
  if find "$bundle_arg" -type l -print | grep -q .; then
    fail "bundle must not contain symbolic links"
  fi
  "$repo_dir/scripts/phase3-verilator-validate.sh" \
    --harness-json "$bundle_arg/manifest.json" >/dev/null
  harness_schema_version=$(jq -r '.schema_version' "$bundle_arg/manifest.json")
  bundle_dir=$(CDPATH= cd -- "$bundle_arg" && pwd)
  output_dir=$(CDPATH= cd -- "$output_arg" && pwd)
  [ "$bundle_dir" != "$output_dir" ] || fail "bundle and output directories must differ"
  case "$output_dir/" in
    "$bundle_dir"/*) fail "output directory must not be inside the input bundle" ;;
  esac

  sources=$(jq -r '.sources[]' "$bundle_dir/manifest.json")
  for relative_path in $sources; do
    [ -f "$bundle_dir/$relative_path" ] || fail "missing source: $relative_path"
  done
  harness_cpp=$(jq -r '.harness_cpp' "$bundle_dir/manifest.json")
  stimulus=$(jq -r '.stimulus' "$bundle_dir/manifest.json")
  [ -f "$bundle_dir/$harness_cpp" ] || fail "missing harness: $harness_cpp"
  [ -f "$bundle_dir/$stimulus" ] || fail "missing stimulus: $stimulus"
  case "$harness_schema_version" in
    lunachip.verilator-harness/v1) ;;
    lunachip.verilator-harness/v2)
      "$repo_dir/scripts/phase3-verilator-validate.sh" \
        --stimulus-tsv "$bundle_dir/manifest.json" "$bundle_dir/$stimulus" \
        >/dev/null
      ;;
    *) fail "unsupported harness schema: $harness_schema_version" ;;
  esac
  top_module=$(jq -r '.top_module' "$bundle_dir/manifest.json")
  result=$(jq -r '.result' "$bundle_dir/manifest.json")
}

check_version_line() {
  observed=$1
  case "$observed" in
    "$expected_version"*) ;;
    *) fail "version mismatch: expected prefix '$expected_version', observed '$observed'" ;;
  esac
}

receipt_hex() {
  [ "$#" -eq 1 ] || fail "internal error: receipt_hex requires one argument"
  printf '%s' "$1" | LC_ALL=C od -An -tx1 | tr -d ' \n'
}

validate_operation_receipt() (
  receipt_path=$1
  expected_operation=$2
  expected_platform=$3
  expected_image=$4
  expected_image_id=$5
  expected_user=$6
  expected_mode=$7
  expected_initializer=$8
  [ -f "$receipt_path" ] && [ ! -L "$receipt_path" ] || return 1
  command_copy=$(mktemp "$(dirname -- "$receipt_path")/.verilator-command.verify.XXXXXX") ||
    return 1
  if LC_ALL=C awk \
    -v operation="$expected_operation" -v platform="$expected_platform" \
    -v image="$expected_image" -v image_id="$expected_image_id" \
    -v user="$expected_user" -v mode="$expected_mode" \
    -v initializer="$expected_initializer" -v command_copy="$command_copy" '
    NR == 1 && $0 != "LUNACHIP-VERILATOR-OPERATION-RECEIPT 1" { bad = 1 }
    NR == 2 && $0 != "OPERATION " operation { bad = 1 }
    NR == 3 && $0 != "PLATFORM " platform { bad = 1 }
    NR == 4 && $0 != "OCI-IMAGE " image { bad = 1 }
    NR == 5 && $0 != "IMAGE-ID " image_id { bad = 1 }
    NR == 6 && $0 != "RUNTIME-USER " user { bad = 1 }
    NR == 7 && $0 != "MOUNT-MODE " mode { bad = 1 }
    NR == 8 && $0 != "VOLUME-PERMISSION-INITIALIZER " initializer { bad = 1 }
    NR == 9 {
      if ($0 !~ /^COMMAND-SHA256 [0-9a-f]{64}$/) bad = 1
      command_sha = $2
    }
    NR == 10 {
      if ($0 !~ /^ARGUMENTS (0|[1-9][0-9]*)$/) bad = 1
      arguments = $2 + 0
      print "LUNACHIP-VERILATOR-COMMAND 1" > command_copy
      print $0 >> command_copy
    }
    NR >= 11 && NR < 11 + arguments {
      expected_index = NR - 11
      if ($1 != "ARG" || $2 != expected_index || NF != 3 ||
          $3 !~ /^([0-9a-f][0-9a-f])+$/) bad = 1
      print $0 >> command_copy
    }
    NR == 11 + arguments {
      if ($0 != "END") bad = 1
      print "END" >> command_copy
    }
    NR > 11 + arguments { bad = 1 }
    { last = $0 }
    END {
      if (arguments < 1 || NR != 11 + arguments || last != "END" ||
          command_sha == "") bad = 1
      if (bad) exit 1
      print command_sha
    }
  ' "$receipt_path" >"$command_copy.sha"; then
    expected_command_sha=$(sed -n '1p' "$command_copy.sha")
    actual_command_sha=$(sha256_file "$command_copy")
    rm -f "$command_copy" "$command_copy.sha"
    [ "$actual_command_sha" = "$expected_command_sha" ]
  else
    receipt_status=$?
    rm -f "$command_copy" "$command_copy.sha"
    return "$receipt_status"
  fi
)

publish_operation_receipt() {
  receipt_output=$1
  receipt_operation=$2
  receipt_initializer=$3
  shift 3
  receipt_name="verilator-$receipt_operation-receipt.txt"
  receipt_path="$receipt_output/$receipt_name"
  [ ! -e "$receipt_path" ] && [ ! -L "$receipt_path" ] ||
    fail "refusing to overwrite operation receipt: $receipt_path"
  command_temp=$(mktemp "$receipt_output/.verilator-command.XXXXXX") ||
    fail "could not create command-binding temporary file"
  receipt_temp=$(mktemp "$receipt_output/.$receipt_name.XXXXXX") || {
    rm -f "$command_temp"
    fail "could not create operation-receipt temporary file"
  }
  argument_count=$#
  {
    printf '%s\n' 'LUNACHIP-VERILATOR-COMMAND 1' "ARGUMENTS $argument_count"
    argument_index=0
    for argument_value in "$@"; do
      printf 'ARG %s %s\n' "$argument_index" "$(receipt_hex "$argument_value")"
      argument_index=$((argument_index + 1))
    done
    printf '%s\n' END
  } >"$command_temp" || {
    receipt_status=$?
    rm -f "$command_temp" "$receipt_temp"
    return "$receipt_status"
  }
  command_sha=$(sha256_file "$command_temp")
  {
    printf '%s\n' \
      'LUNACHIP-VERILATOR-OPERATION-RECEIPT 1' \
      "OPERATION $receipt_operation" \
      "PLATFORM $platform" \
      "OCI-IMAGE $image" \
      "IMAGE-ID $image_id" \
      "RUNTIME-USER $uid:$gid" \
      "MOUNT-MODE $mount_mode" \
      "VOLUME-PERMISSION-INITIALIZER $receipt_initializer" \
      "COMMAND-SHA256 $command_sha"
    sed -n '2,$p' "$command_temp"
  } >"$receipt_temp" || {
    receipt_status=$?
    rm -f "$command_temp" "$receipt_temp"
    return "$receipt_status"
  }
  rm -f "$command_temp"
  if validate_operation_receipt "$receipt_temp" "$receipt_operation" \
    "$platform" "$image" "$image_id" "$uid:$gid" "$mount_mode" \
    "$receipt_initializer" && ln "$receipt_temp" "$receipt_path"; then
    rm "$receipt_temp"
  else
    receipt_status=$?
    rm -f "$receipt_temp"
    return "$receipt_status"
  fi
}

run_archive() {
  case "$mode" in
    build|execute)
      fail "archive provider cannot $mode: use the digest-pinned OCI provider"
      ;;
  esac
  archive_root=${LUNACHIP_VERILATOR_ARCHIVE_ROOT-}
  [ -n "$archive_root" ] || fail \
    "set LUNACHIP_VERILATOR_ARCHIVE_ROOT to the extracted verilator/5.050 directory"
  [ -d "$archive_root" ] || fail "archive root does not exist: $archive_root"
  archive_root=$(CDPATH= cd -- "$archive_root" && pwd)
  if find "$archive_root" -type l -print | grep -q .; then
    fail "archive root must not contain symbolic links"
  fi

  expected_tree_sha=$(jq -r '.providers.archive.tree_sha256' "$lock_file")
  observed_tree_sha=$(
    find "$archive_root" -type f -print | LC_ALL=C sort |
      while IFS= read -r file; do
        relative=${file#"$archive_root"/}
        digest=$(sha256_file "$file")
        printf '%s  %s\n' "$digest" "$relative"
      done |
      sha256_stdin
  )
  [ "$observed_tree_sha" = "$expected_tree_sha" ] || fail \
    "archive tree digest mismatch: expected $expected_tree_sha, observed $observed_tree_sha"

  for executable in bin/verilator bin/verilator_bin; do
    executable_path="$archive_root/$executable"
    [ -f "$executable_path" ] || fail "archive is missing $executable"
    expected_sha=$(jq -r \
      --arg path "$executable" \
      '.providers.archive.executables[] | select(.path == $path) | .sha256' \
      "$lock_file")
    observed_sha=$(sha256_file "$executable_path")
    [ "$observed_sha" = "$expected_sha" ] || fail \
      "$executable digest mismatch: expected $expected_sha, observed $observed_sha"
  done

  verilator="$archive_root/bin/verilator"
  observed_version=$(env -u VERILATOR_ROOT "$verilator" --version)
  check_version_line "$observed_version"

  case "$mode" in
    version)
      [ "$#" -eq 0 ] || usage
      echo "$observed_version"
      ;;
    lint)
      validate_bundle "$@"
      set -- \
        --lint-only --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
        --top-module "$top_module"
      for relative_path in $sources; do
        set -- "$@" "$bundle_dir/$relative_path"
      done
      env -u VERILATOR_ROOT "$verilator" "$@"
      ;;
    *) usage ;;
  esac
}

run_oci() {
  command -v docker >/dev/null 2>&1 || fail "Docker is required for the OCI provider"
  docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"

  mount_mode=${LUNACHIP_VERILATOR_MOUNT_MODE-bind}
  case "$mount_mode" in
    bind|volume) ;;
    *) fail "LUNACHIP_VERILATOR_MOUNT_MODE must be 'bind' or 'volume'" ;;
  esac

  case $(uname -m) in
    arm64|aarch64) platform=linux/arm64 ;;
    x86_64|amd64) platform=linux/amd64 ;;
    *) fail "unsupported OCI host architecture: $(uname -m)" ;;
  esac
  repository=$(jq -r '.providers.oci.repository' "$lock_file")
  digest=$(jq -r --arg platform "$platform" \
    '.providers.oci.platforms[] | select(.platform == $platform) | .digest' \
    "$lock_file")
  [ -n "$digest" ] || fail "lock has no OCI digest for $platform"
  image="$repository@$digest"
  image_inspect=$(docker image inspect "$image" 2>/dev/null) || fail \
    "pinned image is absent; run scripts/phase3-verilator-provision.sh oci"
  image_id=$(printf '%s\n' "$image_inspect" | jq -er \
    --arg image "$image" --arg digest "$digest" --arg platform "$platform" '
      ($image | sub("^docker.io/"; "")) as $short_image |
      select(length == 1 and
        ((.[0].Descriptor.digest? // $digest) == $digest) and
        ((.[0].RepoDigests | index($image)) != null or
          (.[0].RepoDigests | index($short_image)) != null) and
        (.[0].Os + "/" + .[0].Architecture) == $platform) |
      .[0].Id |
      select(type == "string" and test("^sha256:[0-9a-f]{64}$"))
    ') || fail "pinned image metadata does not match lock and platform"

  uid=$(id -u)
  gid=$(id -g)
  if [ "$mount_mode" = volume ]; then
    permission_initializer=pinned-image-chmod-0777-v1
  else
    permission_initializer=not-applicable
  fi
  run_ephemeral_container() {
    docker run --rm \
      --platform "$platform" \
      --user "$uid:$gid" \
      --network none \
      --read-only \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --pids-limit 512 \
      --tmpfs /tmp:rw,nosuid,nodev,size=256m \
      "$@"
  }

  transport_input_volume=
  transport_output_volume=
  transport_container=
  transport_host_temp=

  cleanup_volume_transport() {
    cleanup_status=$?
    trap - EXIT HUP INT TERM
    set +e
    if [ -n "$transport_container" ]; then
      docker rm -f "$transport_container" >/dev/null 2>&1
    fi
    if [ -n "$transport_input_volume" ]; then
      docker volume rm -f "$transport_input_volume" >/dev/null 2>&1
    fi
    if [ -n "$transport_output_volume" ]; then
      docker volume rm -f "$transport_output_volume" >/dev/null 2>&1
    fi
    if [ -n "$transport_host_temp" ]; then
      rm -f "$transport_host_temp"
    fi
    exit "$cleanup_status"
  }

  remove_transport_container() {
    container_to_remove=$transport_container
    [ -n "$container_to_remove" ] || fail "internal error: no transport container"
    docker rm "$container_to_remove" >/dev/null || fail \
      "could not remove scoped transport container $container_to_remove"
    transport_container=
  }

  create_stopped_transport_container() {
    transport_target=$1
    transport_volume=$2
    transport_container=$(docker create \
      --platform "$platform" \
      --label dev.lunachip.phase3.transport=staging \
      --user "$uid:$gid" \
      --network none \
      --read-only \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --pids-limit 512 \
      --mount "type=volume,source=$transport_volume,target=$transport_target" \
      --entrypoint /bin/true \
      "$image")
  }

  prepare_volume_transport() {
    trap cleanup_volume_transport EXIT
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM

    transport_input_volume=$(docker volume create \
      --label dev.lunachip.phase3.transport=input)
    transport_output_volume=$(docker volume create \
      --label dev.lunachip.phase3.transport=output)

    create_stopped_transport_container /work "$transport_input_volume"
    docker cp -a "$bundle_dir/." "$transport_container:/work" || fail \
      "could not stage the validated input bundle into its scoped volume"
    remove_transport_container

    create_stopped_transport_container /out "$transport_output_volume"
    docker cp -a "$output_dir/." "$transport_container:/out" || fail \
      "could not stage the validated output directory into its scoped volume"
    remove_transport_container

    transport_container=$(docker create \
      --platform "$platform" \
      --label dev.lunachip.phase3.transport=permission-init \
      --user 0:0 \
      --network none \
      --read-only \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --pids-limit 512 \
      --mount "type=volume,source=$transport_output_volume,target=/out" \
      --entrypoint /bin/chmod \
      "$image" 0777 /out)
    if docker start -a "$transport_container"; then
      permission_status=0
    else
      permission_status=$?
    fi
    remove_transport_container
    [ "$permission_status" -eq 0 ] || fail \
      "could not make the scoped output volume writable by numeric user $uid:$gid"
  }

  run_volume_container() {
    transport_container=$(docker create \
      --platform "$platform" \
      --label dev.lunachip.phase3.transport=runtime \
      --user "$uid:$gid" \
      --network none \
      --read-only \
      --cap-drop ALL \
      --security-opt no-new-privileges \
      --pids-limit 512 \
      --tmpfs /tmp:rw,nosuid,nodev,size=256m \
      --mount "type=volume,source=$transport_input_volume,target=/work,readonly" \
      --mount "type=volume,source=$transport_output_volume,target=/out" \
      "$@")
    if docker start -a "$transport_container"; then
      run_status=0
    else
      run_status=$?
    fi
    remove_transport_container
    return "$run_status"
  }

  copy_volume_build_to_host() {
    create_stopped_transport_container /out "$transport_output_volume"
    docker cp "$transport_container:/out/." "$output_dir" || fail \
      "could not copy the build output from its scoped volume"
    remove_transport_container
    if find "$output_dir" -type l -print | grep -q .; then
      fail "compiled output must not contain symbolic links"
    fi
  }

  copy_volume_result_to_host() {
    create_stopped_transport_container /out "$transport_output_volume"
    transport_host_temp="$output_dir/.lunachip-phase3-result.$$"
    [ ! -e "$transport_host_temp" ] || fail \
      "refusing to overwrite stale transport result: $transport_host_temp"
    docker cp "$transport_container:/out/$result" "$transport_host_temp" || fail \
      "could not copy $result from its scoped volume"
    remove_transport_container
    [ -f "$transport_host_temp" ] || fail \
      "scoped volume did not contain a regular $result"
    [ ! -L "$transport_host_temp" ] || fail \
      "scoped volume result must not be a symbolic link"
    mv "$transport_host_temp" "$output_dir/$result"
    transport_host_temp=
  }

  observed_version=$(run_ephemeral_container "$image" --version)
  check_version_line "$observed_version"

  case "$mode" in
    version)
      [ "$#" -eq 0 ] || usage
      echo "$observed_version"
      ;;
    lint)
      validate_bundle "$@"
      if find "$output_dir" -mindepth 1 -print | grep -q .; then
        fail "lint output directory must be empty"
      fi
      if [ "$mount_mode" = volume ]; then
        prepare_volume_transport
        set -- --workdir /work "$image" \
          --lint-only --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
          --top-module "$top_module"
      else
        set -- \
          -v "$bundle_dir:/work:ro" \
          -v "$output_dir:/out:rw" \
          --workdir /work \
          "$image" \
          --lint-only --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
          --top-module "$top_module"
      fi
      for relative_path in $sources; do
        set -- "$@" "/work/$relative_path"
      done
      if [ "$mount_mode" = volume ]; then
        run_volume_container "$@"
      else
        run_ephemeral_container "$@"
      fi
      set -- verilator \
        --lint-only --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
        --top-module "$top_module"
      for relative_path in $sources; do
        set -- "$@" "/work/$relative_path"
      done
      publish_operation_receipt \
        "$output_dir" lint "$permission_initializer" "$@"
      ;;
    build)
      validate_bundle "$@"
      if find "$output_dir" -mindepth 1 -print | grep -q .; then
        fail "build output directory must be empty"
      fi
      if [ "$mount_mode" = volume ]; then
        prepare_volume_transport
        set -- --workdir /work --env CCACHE_DISABLE=1 "$image" \
          --cc --exe --build \
          --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
          --x-initial 0 --x-assign 0 \
          --build-jobs 1 \
          --prefix Vlunachip_model \
          --Mdir /out/obj_dir \
          --top-module "$top_module"
      else
        set -- \
          -v "$bundle_dir:/work:ro" \
          -v "$output_dir:/out:rw" \
          --workdir /work \
          --env CCACHE_DISABLE=1 \
          "$image" \
          --cc --exe --build \
          --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
          --x-initial 0 --x-assign 0 \
          --build-jobs 1 \
          --prefix Vlunachip_model \
          --Mdir /out/obj_dir \
          --top-module "$top_module"
      fi
      for relative_path in $sources; do
        set -- "$@" "/work/$relative_path"
      done
      set -- "$@" "/work/$harness_cpp"
      if [ "$mount_mode" = volume ]; then
        run_volume_container "$@"
        copy_volume_build_to_host
      else
        run_ephemeral_container "$@"
      fi
      set -- verilator \
        --cc --exe --build \
        --language 1800-2017 --Wall -Wpedantic --no-timing --assert \
        --x-initial 0 --x-assign 0 \
        --build-jobs 1 \
        --prefix Vlunachip_model \
        --Mdir /out/obj_dir \
        --top-module "$top_module"
      for relative_path in $sources; do
        set -- "$@" "/work/$relative_path"
      done
      set -- "$@" "/work/$harness_cpp"
      publish_operation_receipt \
        "$output_dir" build "$permission_initializer" "$@"
      ;;
    execute)
      validate_bundle "$@"
      if find "$output_dir" -type l -print | grep -q .; then
        fail "compiled output must not contain symbolic links"
      fi
      executable="$output_dir/obj_dir/Vlunachip_model"
      [ -x "$executable" ] || fail \
        "compiled harness is absent; run the OCI build command first"
      [ ! -e "$output_dir/$result" ] || fail \
        "refusing to overwrite existing result: $output_dir/$result"
      result_parent=$(dirname -- "$result")
      if [ "$result_parent" != "." ]; then
        mkdir -p "$output_dir/$result_parent"
      fi
      if [ "$mount_mode" = volume ]; then
        prepare_volume_transport
        run_volume_container \
          --workdir /work \
          --entrypoint /out/obj_dir/Vlunachip_model \
          "$image" \
          "/work/$stimulus" "/out/$result"
        copy_volume_result_to_host
      else
        run_ephemeral_container \
          -v "$bundle_dir:/work:ro" \
          -v "$output_dir:/out:rw" \
          --workdir /work \
          --entrypoint /out/obj_dir/Vlunachip_model \
          "$image" \
          "/work/$stimulus" "/out/$result"
      fi
      [ -f "$output_dir/$result" ] || fail \
        "harness exited without producing $result"
      publish_operation_receipt "$output_dir" execute "$permission_initializer" \
        /out/obj_dir/Vlunachip_model "/work/$stimulus" "/out/$result"
      ;;
    *) usage ;;
  esac
}

case "$provider" in
  archive) run_archive "$@" ;;
  oci) run_oci "$@" ;;
  *) usage ;;
esac
