#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/yosys/lock.json"
formal_artifact_cli="$repo_dir/scripts/formal-artifact-cli.sh"

fail() {
  echo "phase4-yosys-run: $*" >&2
  exit 1
}

usage() {
  fail "usage: $0 oci version | $0 oci synth BUNDLE_DIR OUTPUT_DIR | $0 oci formal TASK BUNDLE_DIR OUTPUT_DIR"
}

[ "$#" -ge 2 ] || usage
provider=$1
operation=$2
shift 2
[ "$provider" = oci ] || fail "unsupported provider '$provider'; only the locked OCI provider is allowed"

command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v docker >/dev/null 2>&1 || fail "Docker is required"
command -v moon >/dev/null 2>&1 || fail "moon is required"
"$repo_dir/scripts/phase4-yosys-validate.sh" >/dev/null
docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"

platform=$(jq -r '.provider.platform' "$lock_file")
repository=$(jq -r '.provider.repository' "$lock_file")
manifest_digest=$(jq -r '.provider.manifest_digest' "$lock_file")
config_digest=$(jq -r '.provider.config_digest' "$lock_file")
image="$repository@$manifest_digest"
docker image inspect "$image" >/dev/null 2>&1 || fail \
  "pinned image is absent; run scripts/phase4-yosys-provision.sh oci"
observed_id=$(docker image inspect --format '{{.Id}}' "$image")
observed_repo_digests=$(docker image inspect --format '{{range .RepoDigests}}{{println .}}{{end}}' "$image")
printf '%s\n' "$observed_repo_digests" | grep -Fx "$image" >/dev/null || fail \
  "OCI repository manifest mismatch: expected $image"
# Docker's classic image store exposes the config digest as `.Id`; Docker's
# containerd image store exposes the selected manifest digest there instead.
# In both cases RepoDigests above must bind the exact locked repository digest.
case "$observed_id" in
  "$config_digest"|"$manifest_digest") ;;
  *) fail "OCI image identity mismatch: expected config $config_digest or manifest $manifest_digest, observed $observed_id" ;;
esac

uid=$(id -u)
gid=$(id -g)
mount_mode=${LUNACHIP_YOSYS_MOUNT_MODE-bind}
case "$mount_mode" in
  bind|volume) ;;
  *) fail "LUNACHIP_YOSYS_MOUNT_MODE must be 'bind' or 'volume'" ;;
esac

base_run() {
  docker run --rm \
    --platform "$platform" \
    --user "$uid:$gid" \
    --network none \
    --read-only \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --pids-limit 512 \
    --tmpfs /tmp:rw,nosuid,nodev,size=256m \
    --workdir /tmp \
    --env HOME=/tmp \
    --env TMPDIR=/tmp \
    --env PYTHONDONTWRITEBYTECODE=1 \
    "$@"
}

version_command='yosys -V; sby --version; bitwuzla --version'
record_versions='{ yosys -V; sby --version; bitwuzla --version; } > /out/tool-versions.txt'
check_versions() {
  version_file=$1
  yosys_expected=$(jq -r '.tools.yosys.expected_version_prefix' "$lock_file")
  sby_expected=$(jq -r '.tools.sby.expected_version_line' "$lock_file")
  solver_expected=$(jq -r '.tools.solver.expected_version_fragment' "$lock_file")
  grep -F "$yosys_expected" "$version_file" >/dev/null || fail "Yosys version mismatch"
  grep -Fx "$sby_expected" "$version_file" >/dev/null || fail "SBY version mismatch"
  grep -F "$solver_expected" "$version_file" >/dev/null || fail "Bitwuzla version mismatch"
}

if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required"
fi

if [ "$operation" = version ]; then
  [ "$#" -eq 0 ] || usage
  versions=$(base_run --entrypoint /bin/sh "$image" -lc "$version_command")
  printf '%s\n' "$versions"
  version_temp=$(mktemp "${TMPDIR:-/tmp}/lunachip-yosys-version.XXXXXX")
  trap 'rm -f "$version_temp"' EXIT HUP INT TERM
  printf '%s\n' "$versions" >"$version_temp"
  check_versions "$version_temp"
  exit 0
fi

validate_bundle_output() {
  bundle_arg=$1
  output_arg=$2
  [ -d "$bundle_arg" ] || fail "bundle directory does not exist: $bundle_arg"
  [ -f "$bundle_arg/job.json" ] || fail "bundle is missing job.json"
  [ -d "$output_arg" ] || fail "output directory must already exist: $output_arg"
  [ ! -L "$output_arg" ] || fail "output directory must not be a symbolic link"
  if find "$output_arg" -mindepth 1 -print | grep -q .; then
    fail "output directory must be empty"
  fi
  "$repo_dir/scripts/phase4-yosys-validate.sh" --job-json "$bundle_arg/job.json" "$bundle_arg" >/dev/null
  bundle_dir=$(CDPATH= cd -- "$bundle_arg" && pwd)
  output_dir=$(CDPATH= cd -- "$output_arg" && pwd)
  [ "$bundle_dir" != "$output_dir" ] || fail "bundle and output directories must differ"
  case "$output_dir/" in
    "$bundle_dir"/*) fail "output directory must not be inside the input bundle" ;;
  esac
  manifest="$bundle_dir/job.json"
  top=$(jq -r '.top_module' "$manifest")
}

input_volume=
output_volume=
transport_container=
cleanup_transport() {
  status=$?
  trap - EXIT HUP INT TERM
  set +e
  [ -z "$transport_container" ] || docker rm -f "$transport_container" >/dev/null 2>&1
  [ -z "$input_volume" ] || docker volume rm -f "$input_volume" >/dev/null 2>&1
  [ -z "$output_volume" ] || docker volume rm -f "$output_volume" >/dev/null 2>&1
  exit "$status"
}

remove_transport_container() {
  docker rm "$transport_container" >/dev/null || fail "could not remove scoped transport container"
  transport_container=
}

staging_container() {
  target=$1
  volume=$2
  transport_container=$(docker create \
    --platform "$platform" --label dev.lunachip.phase4.transport=staging \
    --user "$uid:$gid" --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --pids-limit 512 \
    --mount "type=volume,source=$volume,target=$target" \
    --entrypoint /bin/true "$image")
}

prepare_volumes() {
  trap cleanup_transport EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
  input_volume=$(docker volume create --label dev.lunachip.phase4.transport=input)
  output_volume=$(docker volume create --label dev.lunachip.phase4.transport=output)
  permission_receipt=$(docker run --rm \
    --platform "$platform" --label dev.lunachip.phase4.transport=permission-init \
    --user 0:0 --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --pids-limit 512 \
    --env PYTHONDONTWRITEBYTECODE=1 \
    --mount "type=volume,source=$output_volume,target=/out" \
    --entrypoint /usr/bin/python3 "$image" -c \
    'import os; os.chmod("/out", 0o777); print("LUNACHIP-YOSYS-TRANSPORT permission-init=pinned-image-python-os-chmod-v1")') ||
    fail "could not initialize output-volume permissions"
  [ "$permission_receipt" = \
    'LUNACHIP-YOSYS-TRANSPORT permission-init=pinned-image-python-os-chmod-v1' ] ||
    fail "unexpected output-volume permission receipt"
  printf '%s\n' "$permission_receipt"
  staging_container /work "$input_volume"
  docker cp -a "$bundle_dir/." "$transport_container:/work" || fail "could not stage input bundle"
  remove_transport_container
  staging_container /out "$output_volume"
  docker cp -a "$output_dir/." "$transport_container:/out" || fail "could not stage output files"
  remove_transport_container
}

run_volume() {
  transport_container=$(docker create \
    --platform "$platform" --label dev.lunachip.phase4.transport=runtime \
    --user "$uid:$gid" --network none --read-only --cap-drop ALL \
    --security-opt no-new-privileges --pids-limit 512 \
    --tmpfs /tmp:rw,nosuid,nodev,size=256m \
    --workdir /tmp \
    --env HOME=/tmp --env TMPDIR=/tmp --env PYTHONDONTWRITEBYTECODE=1 \
    --mount "type=volume,source=$input_volume,target=/work,readonly" \
    --mount "type=volume,source=$output_volume,target=/out" "$@")
  if docker start -a "$transport_container"; then run_status=0; else run_status=$?; fi
  remove_transport_container
  return "$run_status"
}

copy_volume_output() {
  staging_container /out "$output_volume"
  docker cp "$transport_container:/out/." "$output_dir" || fail "could not copy output volume to host"
  remove_transport_container
  if find "$output_dir" -type l -print | grep -q .; then
    fail "tool output must not contain symbolic links"
  fi
}

run_job_container() {
  container_command=$1
  {
    printf '%s\n' 'LUNACHIP-YOSYS-TRANSPORT 1'
    printf 'MODE %s\n' "$mount_mode"
    if [ "$mount_mode" = volume ]; then
      printf '%s\n' 'PERMISSION-INITIALIZER pinned-image-python-os-chmod-v1'
    else
      printf '%s\n' 'PERMISSION-INITIALIZER none'
    fi
    printf 'RUNTIME-USER %s:%s\n' "$uid" "$gid"
    printf 'OCI-IMAGE %s\n' "$image"
  } >"$output_dir/transport-receipt.txt"
  if [ "$mount_mode" = volume ]; then
    prepare_volumes
    if run_volume --entrypoint /bin/sh "$image" -lc "$container_command"; then
      job_status=0
    else
      job_status=$?
    fi
    copy_volume_output
    [ "$job_status" -eq 0 ] || return "$job_status"
  else
    base_run \
      --mount "type=bind,source=$bundle_dir,target=/work,readonly" \
      --mount "type=bind,source=$output_dir,target=/out" \
      --entrypoint /bin/sh "$image" -lc "$container_command"
  fi
  if find "$output_dir" -type l -print | grep -q .; then
    fail "tool output must not contain symbolic links"
  fi
}

case "$operation" in
  synth)
    [ "$#" -eq 2 ] || usage
    validate_bundle_output "$1" "$2"
    {
      for source in $(jq -r '.sources[].path' "$manifest"); do
        printf 'read_verilog -sv -noautowire /work/%s\n' "$source"
      done
      printf 'hierarchy -check -top %s\n' "$top"
      printf '%s\n' 'proc'
      printf '%s\n' 'memory -nomap'
      printf '%s\n' 'check -assert'
      printf '%s\n' 'write_rtlil /out/pre-map.rtlil'
      printf '%s\n' 'stat'
      # Preserve a complete generic netlist without invoking ABC. This is a
      # memory-inference gate, not a technology-mapping or timing gate.
      printf 'synth -top %s -flatten -latches error -noabc\n' "$top"
      printf '%s\n' 'check -assert'
      printf '%s\n' 'write_json /out/netlist.json'
      printf '%s\n' 'write_verilog -noattr -noexpr -nodec /out/netlist.v'
    } >"$output_dir/yosys.ys"
    printf '%s\n' "yosys -Q -T -e '.*' -l /out/yosys.log -s /out/yosys.ys" >"$output_dir/command.txt"
    run_job_container "$record_versions && yosys -Q -T -e '.*' -l /out/yosys.log -s /out/yosys.ys && printf 'PASS\\n' > /out/status.txt"
    check_versions "$output_dir/tool-versions.txt"
    [ -s "$output_dir/pre-map.rtlil" ] || fail "synthesis did not produce pre-map.rtlil"
    [ -s "$output_dir/netlist.json" ] || fail "synthesis did not produce netlist.json"
    [ -s "$output_dir/netlist.v" ] || fail "synthesis did not produce netlist.v"
    [ "$(tr -d '\r\n' <"$output_dir/status.txt")" = PASS ] || fail "synthesis status is not PASS"
    ;;
  formal)
    [ "$#" -eq 3 ] || usage
    task=$1
    validate_bundle_output "$2" "$3"
    task_count=$(jq -r --arg task "$task" '[.formal_tasks[] | select(.name == $task)] | length' "$manifest")
    [ "$task_count" -eq 1 ] || fail "manifest has no unique formal task named '$task'"
    "$formal_artifact_cli" verify "$bundle_dir" "$task" >/dev/null ||
      fail "formal typed-artifact binding validation failed for '$task'"
    mode=$(jq -r --arg task "$task" '.formal_tasks[] | select(.name == $task) | .mode' "$manifest")
    claim=$(jq -r --arg task "$task" '.formal_tasks[] | select(.name == $task) | .claim' "$manifest")
    bound=$(jq -r --arg task "$task" '.formal_tasks[] | select(.name == $task) | .bound' "$manifest")
    timeout=$(jq -r --arg task "$task" '.formal_tasks[] | select(.name == $task) | .timeout_seconds' "$manifest")
    expect=$(jq -r --arg task "$task" '.formal_tasks[] | select(.name == $task) | .expect' "$manifest")
    execution_manifest="$bundle_dir/$task.lcfg"
    grep -Fx "MODE $mode" "$execution_manifest" >/dev/null ||
      fail "execution manifest mode mismatch"
    grep -Fx "CLAIM $claim" "$execution_manifest" >/dev/null ||
      fail "execution manifest claim mismatch"
    grep -Fx "BOUND $bound" "$execution_manifest" >/dev/null ||
      fail "execution manifest bound mismatch"
    grep -Fx "TIMEOUT-SECONDS $timeout" "$execution_manifest" >/dev/null ||
      fail "execution manifest timeout mismatch"
    grep -Fx "EXPECTED-STATUS $expect" "$execution_manifest" >/dev/null ||
      fail "execution manifest expected-status mismatch"
    grep -Fx "ADDRESS-KNOWNNESS two-state-formal-all-binary" "$execution_manifest" >/dev/null ||
      fail "execution manifest address-knownness mismatch"
    while IFS="$(printf '\t')" read -r source_path source_sha; do
      grep -Fx "SOURCE $source_path sha256 $source_sha" "$bundle_dir/source-set.lcfs" >/dev/null ||
        fail "source set does not bind job source '$source_path'"
    done <<EOF
$(jq -r '.sources[] | [.path, .sha256] | @tsv' "$manifest")
EOF
    {
      printf 'LOCK toolchain/yosys/lock.json sha256 %s\n' "$(sha256_file "$lock_file")"
      printf 'RUNNER scripts/phase4-yosys-run.sh sha256 %s\n' "$(sha256_file "$repo_dir/scripts/phase4-yosys-run.sh")"
      printf 'OCI-IMAGE %s\n' "$image"
      printf 'OCI-CONFIG %s\n' "$config_digest"
      printf 'OBSERVED-IMAGE-ID %s\n' "$observed_id"
    } >"$output_dir/provenance.txt"
    sby_file="$output_dir/$task.sby"
    {
      printf '%s\n' '[options]'
      printf 'mode %s\n' "$mode"
      printf '%s\n' 'multiclock on'
      printf 'depth %s\n' "$bound"
      printf 'timeout %s\n' "$timeout"
      printf 'expect %s\n' "$expect"
      printf '%s\n' '[engines]' 'smtbmc bitwuzla' '[script]' 'logger -werror .*'
      printf 'read_verilog -formal -sv -noautowire'
      for source in $(jq -r '.sources[].path' "$manifest"); do printf ' %s' "${source##*/}"; done
      printf '\n'
      printf 'hierarchy -check -top %s\n' "$top"
      while IFS="$(printf '\t')" read -r property_label property_role; do
        case "$property_role" in
          assert) selection_record=P ; formal_kind=assert ;;
          assume) selection_record=A ; formal_kind=assume ;;
          cover) selection_record=P ; formal_kind=cover ;;
          *) fail "unknown property role '$property_role'" ;;
        esac
        if ! awk -v record="$selection_record" -v label="$property_label" \
          '$1 == record && $3 == label { found += 1 } END { exit(found == 1 ? 0 : 1) }' \
          "$execution_manifest"; then
          printf 'chformal -%s -remove %s/%s\n' "$formal_kind" "$top" "$property_label"
        fi
      done <<EOF
$(awk '$1 == "F" { print $4 "\t" $5 }' "$bundle_dir/properties.lcfp")
EOF
      printf 'prep -top %s\n' "$top"
      printf '%s\n' '[files]'
      for source in $(jq -r '.sources[].path' "$manifest"); do printf '%s /work/%s\n' "${source##*/}" "$source"; done
    } >"$sby_file"
    printf 'sby -f -d /out/%s-work /out/%s.sby\n' "$task" "$task" >"$output_dir/command.txt"
    run_job_container "$record_versions && sby -f -d /out/$task-work /out/$task.sby"
    check_versions "$output_dir/tool-versions.txt"
    [ -f "$output_dir/$task-work/status" ] || fail "SBY did not produce a status file"
    expected_status=$(printf '%s' "$expect" | tr '[:lower:]' '[:upper:]')
    observed_status=$(awk 'NR == 1 { print $1; exit }' "$output_dir/$task-work/status")
    [ "$observed_status" = "$expected_status" ] || fail \
      "SBY status mismatch: expected $expected_status, observed $observed_status"
    expected_failure=$(awk '$1 == "EXPECTED-FAILURE" { print $2 }' "$execution_manifest")
    if [ "$expect" = fail ]; then
      [ -n "$expected_failure" ] && [ "$expected_failure" != none ] ||
        fail "negative task lacks an expected failing stable label"
      failure_lines=$(grep -R -h -F 'Assert failed' "$output_dir/$task-work" || true)
      [ -n "$failure_lines" ] || fail "negative task produced no named assertion failure"
      printf '%s\n' "$failure_lines" | grep -F "$expected_failure" >/dev/null ||
        fail "negative task did not fail its declared stable property"
      unexpected_failure=$(printf '%s\n' "$failure_lines" | grep -F -v "$expected_failure" || true)
      [ -z "$unexpected_failure" ] ||
        fail "negative task failed a property other than its declared defect"
    else
      [ "$expected_failure" = none ] ||
        fail "passing task must not declare an expected failing property"
    fi
    evidence_kind=none
    evidence_name=-
    evidence_file=-
    work_dir="$output_dir/$task-work"
    if [ "$mode" = cover ] && [ "$observed_status" = PASS ]; then
      traces=$(find "$work_dir" -type f -name 'trace*.vcd' -print | sort)
      trace_count=$(printf '%s\n' "$traces" | awk 'NF { count += 1 } END { print count + 0 }')
      [ "$trace_count" -eq 1 ] || fail "cover task must retain exactly one witness trace"
      evidence_file=$traces
      evidence_name=${evidence_file#"$work_dir/"}
      evidence_kind=cover
    elif [ "$mode" = bmc ] && [ "$observed_status" = FAIL ]; then
      traces=$(find "$work_dir" -type f -name 'trace.vcd' -print | sort)
      trace_count=$(printf '%s\n' "$traces" | awk 'NF { count += 1 } END { print count + 0 }')
      [ "$trace_count" -eq 1 ] ||
        fail "bounded failure must retain exactly one reachable counterexample trace"
      evidence_file=$traces
      evidence_name=${evidence_file#"$work_dir/"}
      evidence_kind=base
    elif [ "$mode" = prove ] && { [ "$observed_status" = FAIL ] || [ "$observed_status" = UNKNOWN ]; }; then
      base_trace=$(find "$work_dir" -type f -name 'trace.vcd' -print | sort | head -n 1)
      induction_trace=$(find "$work_dir" -type f -name 'trace_induct.vcd' -print | sort | head -n 1)
      if [ -n "$base_trace" ]; then
        evidence_file=$base_trace
        evidence_name=${evidence_file#"$work_dir/"}
        evidence_kind=base
      elif [ -n "$induction_trace" ]; then
        evidence_file=$induction_trace
        evidence_name=${evidence_file#"$work_dir/"}
        evidence_kind=induction
      else
        fail "prove failure has neither reachable base nor induction diagnostic trace"
      fi
    fi
    (
      cd "$output_dir"
      find . -type f ! -name outputs.sha256 ! -name result.lcfr ! -name receipt.lcfe -print |
        sort |
        while IFS= read -r relative; do
          digest=$(sha256_file "$relative")
          printf '%s  %s\n' "$digest" "${relative#./}"
        done
    ) >"$output_dir/outputs.sha256"
    "$formal_artifact_cli" collect \
      "$bundle_dir/$task.lcft" \
      "$work_dir/status" \
      "$evidence_kind" \
      "$evidence_name" \
      "$evidence_file" \
      "$output_dir/tool-versions.txt" \
      "$output_dir/outputs.sha256" \
      "$output_dir/provenance.txt" \
      "$execution_manifest" \
      0 \
      "$output_dir/result.lcfr" \
      "$output_dir/receipt.lcfe" ||
      fail "typed formal result collection failed"
    ;;
  *) usage ;;
esac
