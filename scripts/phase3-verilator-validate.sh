#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/verilator/lock.json"
lock_schema="$repo_dir/toolchain/verilator/lock.schema.json"
harness_schema="$repo_dir/toolchain/verilator/harness.schema.json"

fail() {
  echo "phase3-verilator-validate: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required to validate JSON contracts"
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required to digest the lock"
fi

validate_lock() {
  jq -e '
    def digest: test("^(sha256:)?[0-9a-f]{64}$");
    def safe_path:
      test("^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$") and
      (startswith("/") | not) and
      (split("/") | all(. != ".."));
    .schema_version == "lunachip.verilator-lock/v1" and
    .tool.name == "Verilator" and
    .tool.version == "5.050" and
    .tool.release_date == "2026-07-01" and
    (.tool.expected_version_line | startswith("Verilator 5.050 2026-07-01")) and
    (.tool.upstream_source.sha256 | digest) and
    .providers.oci.repository == "docker.io/verilator/verilator" and
    .providers.oci.release_tag_for_discovery_only == "v5.050" and
    (.providers.oci.index_digest | digest) and
    (.providers.oci.platforms | length == 2) and
    ([.providers.oci.platforms[].platform] | sort == ["linux/amd64", "linux/arm64"]) and
    (all(.providers.oci.platforms[];
      (.digest | digest) and
      (.capabilities == ["identity", "lint", "compile", "execute"]))) and
    .providers.archive.platform == "darwin/arm64/tahoe" and
    (.providers.archive.sha256 | digest) and
    (.providers.archive.root | safe_path) and
    .providers.archive.tree_digest_algorithm == "sha256-lines-v1" and
    (.providers.archive.tree_sha256 | digest) and
    (all(.providers.archive.executables[];
      (.path | safe_path) and (.sha256 | digest))) and
    .providers.archive.capabilities == ["identity", "lint"] and
    .providers.archive.excluded_capabilities == ["compile", "execute"] and
    .policy.language == "1800-2017" and
    .policy.lint_flags == [
      "--lint-only", "--language", "1800-2017", "--Wall", "-Wpedantic",
      "--no-timing", "--assert"
    ] and
    .policy.compile_flags == [
      "--cc", "--exe", "--build", "--language", "1800-2017", "--Wall",
      "-Wpedantic", "--no-timing", "--assert", "--x-initial", "0",
      "--x-assign", "0", "--build-jobs", "1", "--prefix",
      "Vlunachip_model"
    ] and
    .policy.forbidden_flags == [
      "-Wno-fatal", "-Wno-lint", "-Wno-style", "--bbox-unsup", "--timing"
    ] and
    (. as $root |
      all(($root.policy.lint_flags[], $root.policy.compile_flags[]);
        . as $flag | all($root.policy.forbidden_flags[]; . != $flag))) and
    (.policy.lint_flags | index("--lint-only") != null) and
    (.policy.lint_flags | index("--Wall") != null) and
    (.policy.lint_flags | index("-Wpedantic") != null) and
    (.policy.compile_flags | index("--build") != null) and
    (.policy.compile_flags | index("--build-jobs") != null)
  ' "$lock_file" >/dev/null || fail "lock.json violates the locked Phase 3 policy"

  jq -e . "$lock_schema" >/dev/null || fail "lock.schema.json is not valid JSON"
  jq -e . "$harness_schema" >/dev/null || fail "harness.schema.json is not valid JSON"
}

validate_harness_json() {
  manifest=$1
  [ -f "$manifest" ] || fail "harness manifest does not exist: $manifest"

  jq -e '
    def identifier: test("^[A-Za-z_][A-Za-z0-9_$]*$");
    def safe_path:
      test("^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$") and
      (startswith("/") | not) and
      (split("/") | all(. != ".."));
    ((keys - [
      "$schema", "schema_version", "top_module", "sources", "harness_cpp",
      "stimulus", "result", "clock", "reset", "ports"
    ]) | length == 0) and
    .schema_version == "lunachip.verilator-harness/v1" and
    (.top_module | identifier) and
    (.sources | type == "array" and length > 0 and length == (unique | length)) and
    (all(.sources[]; safe_path and endswith(".sv"))) and
    (.harness_cpp | safe_path and endswith(".cpp")) and
    (.stimulus | safe_path and endswith(".tsv")) and
    (.result | safe_path and endswith(".tsv")) and
    .clock.edge == "rising" and
    (.clock.port | identifier) and
    .reset.active == "high" and
    .reset.timing == "synchronous" and
    (.reset.port | identifier) and
    (.ports | type == "array" and length > 0) and
    ([.ports[].name] | length == (unique | length)) and
    (all(.ports[];
      ((keys - ["name", "direction", "width", "signed"]) | length == 0) and
      (.name | identifier) and
      (.direction == "input" or .direction == "output") and
      (.width | type == "number" and floor == . and . >= 1 and . <= 4096) and
      (.signed | type == "boolean"))) and
    (.clock.port as $clock |
      any(.ports[]; .name == $clock and .direction == "input" and .width == 1)) and
    (.reset.port as $reset |
      any(.ports[]; .name == $reset and .direction == "input" and .width == 1))
  ' "$manifest" >/dev/null || fail "invalid harness manifest: $manifest"
}

validate_lock

case ${1-} in
  "")
    ;;
  --harness-json)
    [ "$#" -eq 2 ] || fail "usage: $0 [--harness-json MANIFEST]"
    validate_harness_json "$2"
    ;;
  *)
    fail "usage: $0 [--harness-json MANIFEST]"
    ;;
esac

lock_digest=$(sha256_file "$lock_file")
echo "Verilator lock and contract schemas pass (lock sha256:$lock_digest)"
