#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/verilator/lock.json"

fail() {
  echo "phase3-verilator-provision: $*" >&2
  exit 1
}

[ "$#" -ge 1 ] || fail "usage: $0 oci | archive ARCHIVE_FILE EXTRACT_PARENT"
provider=$1
shift

command -v jq >/dev/null 2>&1 || fail "jq is required to read the checked lock"
"$repo_dir/scripts/phase3-verilator-validate.sh" >/dev/null
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required to verify provider content"
fi

case "$provider" in
  oci)
    [ "$#" -eq 0 ] || fail "usage: $0 oci"
    command -v docker >/dev/null 2>&1 || fail "Docker is required for OCI provisioning"
    docker info >/dev/null 2>&1 || fail "Docker daemon is unavailable"
    case $(uname -m) in
      arm64|aarch64) platform=linux/arm64 ;;
      x86_64|amd64) platform=linux/amd64 ;;
      *) fail "unsupported OCI host architecture: $(uname -m)" ;;
    esac
    repository=$(jq -r '.providers.oci.repository' "$lock_file")
    digest=$(jq -r --arg platform "$platform" \
      '.providers.oci.platforms[] | select(.platform == $platform) | .digest' \
      "$lock_file")
    image="$repository@$digest"
    echo "Pulling pinned $platform image $image"
    docker pull --platform "$platform" "$image"
    docker image inspect "$image" >/dev/null 2>&1 || fail "pulled image is not inspectable by digest"
    "$repo_dir/scripts/phase3-verilator-run.sh" oci version
    ;;
  archive)
    [ "$#" -eq 2 ] || fail "usage: $0 archive ARCHIVE_FILE EXTRACT_PARENT"
    archive_file=$1
    extract_parent=$2
    [ -f "$archive_file" ] || {
      url=$(jq -r '.providers.archive.url' "$lock_file")
      expected=$(jq -r '.providers.archive.sha256' "$lock_file")
      fail "archive absent: fetch $url as $archive_file, expected sha256:$expected"
    }
    expected=$(jq -r '.providers.archive.sha256' "$lock_file")
    observed=$(sha256_file "$archive_file")
    [ "$observed" = "$expected" ] || fail \
      "archive digest mismatch: expected $expected, observed $observed"
    if tar -tzf "$archive_file" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
      fail "archive contains an absolute or parent-traversal path"
    fi
    root=$(jq -r '.providers.archive.root' "$lock_file")
    [ ! -e "$extract_parent/$root" ] || fail "refusing to overwrite $extract_parent/$root"
    mkdir -p "$extract_parent"
    tar -xzf "$archive_file" -C "$extract_parent" --no-same-owner
    LUNACHIP_VERILATOR_ARCHIVE_ROOT="$extract_parent/$root" \
      "$repo_dir/scripts/phase3-verilator-run.sh" archive version
    ;;
  *)
    fail "unknown provider '$provider'; expected oci or archive"
    ;;
esac
