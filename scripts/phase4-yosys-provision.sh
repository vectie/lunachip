#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/yosys/lock.json"

fail() {
  echo "phase4-yosys-provision: $*" >&2
  exit 1
}

[ "$#" -eq 1 ] && [ "$1" = oci ] || fail "usage: $0 oci"
command -v jq >/dev/null 2>&1 || fail "jq is required"
command -v docker >/dev/null 2>&1 || fail "Docker is required"
"$repo_dir/scripts/phase4-yosys-validate.sh" >/dev/null
docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"

platform=$(jq -r '.provider.platform' "$lock_file")
repository=$(jq -r '.provider.repository' "$lock_file")
digest=$(jq -r '.provider.manifest_digest' "$lock_file")
image="$repository@$digest"
echo "Pulling pinned $platform image $image"
docker pull --platform "$platform" "$image"
docker image inspect "$image" >/dev/null 2>&1 || fail "pulled image is not inspectable by digest"
"$repo_dir/scripts/phase4-yosys-run.sh" oci version
