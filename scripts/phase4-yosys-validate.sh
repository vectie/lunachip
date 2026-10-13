#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/yosys/lock.json"
lock_schema="$repo_dir/toolchain/yosys/lock.schema.json"
job_schema="$repo_dir/toolchain/yosys/job.schema.json"

fail() {
  echo "phase4-yosys-validate: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required"
if command -v shasum >/dev/null 2>&1; then
  sha256_file() { shasum -a 256 "$1" | awk '{print $1}'; }
elif command -v sha256sum >/dev/null 2>&1; then
  sha256_file() { sha256sum "$1" | awk '{print $1}'; }
else
  fail "shasum or sha256sum is required"
fi

validate_lock() {
  jq -e '
    def keys_are($allowed): ((keys - $allowed) | length) == 0;
    def sha: test("^[0-9a-f]{64}$");
    def digest: test("^sha256:[0-9a-f]{64}$");
    keys_are(["$schema", "schema_version", "provider", "recipe", "tools", "policy"]) and
    .schema_version == "lunachip.yosys-toolchain-lock/v1" and
    (.provider | keys_are(["kind", "publisher", "repository", "discovery_tag_only", "platform", "manifest_digest", "config_digest", "capabilities"])) and
    .provider.kind == "oci" and .provider.publisher == "Zubax" and
    .provider.repository == "ghcr.io/zubax/zubax-fpga-toolchain-oss" and
    .provider.discovery_tag_only == "latest" and .provider.platform == "linux/amd64" and
    .provider.manifest_digest == "sha256:10433156fa7d19e5e15d09dd0dc348faf981325a8685af92f3864c2a25aa1775" and
    .provider.config_digest == "sha256:5a4191a1b674e2ca9eff5af1929f0fd217c95cce45a641259ce09274ecdde44a" and
    (.provider.manifest_digest | digest) and (.provider.config_digest | digest) and
    .provider.capabilities == ["identity", "synthesis", "bmc", "induction", "cover"] and
    (.recipe | keys_are(["repository", "commit", "path", "sha256"])) and
    .recipe.repository == "https://github.com/Zubax/fpga-toolchain-docker" and
    .recipe.commit == "484793d8832ca010f6e3068f53677fa4f92a1177" and
    .recipe.path == "oss/Dockerfile" and
    .recipe.sha256 == "741a232801ceaec884b5a7f74bcc7862378d34f88ed9632aa71932d3c270ea28" and
    (.tools | keys_are(["yosys", "sby", "solver"])) and
    (.tools.yosys | keys_are(["version", "expected_version_prefix", "source_url", "source_ref", "source_sha256"])) and
    .tools.yosys.version == "0.68" and .tools.yosys.expected_version_prefix == "Yosys 0.68" and
    .tools.yosys.source_ref == "v0.68" and .tools.yosys.source_sha256 == "78faed2a95944eb18cbcfff0aaa77e976ed549e2b1c95493a9b8191eca067cb1" and
    (.tools.sby | keys_are(["version", "expected_version_line", "source_url", "source_ref", "source_sha256"])) and
    .tools.sby.version == "v0.68" and .tools.sby.expected_version_line == "SBY v0.68" and
    .tools.sby.source_ref == "b1a1e98cba941ec8433f8dc27f416cd7bb7f14be" and
    .tools.sby.source_sha256 == "bd2d73f34a5e58c64cbb4d421172c756d918ff8a2220cd0300328cf14d5e085d" and
    (.tools.solver | keys_are(["name", "version", "expected_version_fragment", "archive_url", "archive_sha256"])) and
    .tools.solver.name == "bitwuzla" and .tools.solver.version == "0.9.1" and
    .tools.solver.archive_sha256 == "057f1546ae2068df57beb178f3eeab1678f0e5f0c378787a05b7bb294617c9c6" and
    (all([.tools.yosys.source_sha256, .tools.sby.source_sha256, .tools.solver.archive_sha256][]; sha)) and
    (.policy | keys_are(["synthesis", "formal", "isolation", "forbidden"])) and
    .policy.synthesis.yosys_flags == ["-Q", "-T", "-e", ".*"] and
    .policy.synthesis.read_flags == ["-sv", "-noautowire"] and
    .policy.synthesis.commands == [
      "hierarchy -check -top <top>",
      "proc",
      "memory -nomap",
      "check -assert",
      "write_rtlil /out/pre-map.rtlil",
      "write_json /out/pre-map.json",
      "stat",
      "synth -top <top> -flatten -latches error",
      "check -assert",
      "write_json /out/netlist.json",
      "write_verilog -noattr -noexpr -nodec /out/netlist.v"
    ] and
    (.policy.formal | keys_are(["engine", "solver", "multiclock", "yosys_warning_policy", "modes", "maximum_bound", "maximum_timeout_seconds"])) and
    .policy.formal.engine == "smtbmc" and .policy.formal.solver == "bitwuzla" and
    .policy.formal.multiclock == true and
    .policy.formal.yosys_warning_policy == "logger -werror .*" and
    .policy.formal.modes == ["bmc", "prove", "cover"] and
    .policy.formal.maximum_bound == 100000 and .policy.formal.maximum_timeout_seconds == 3600 and
    .policy.isolation == {"network":"none","read_only_root":true,"drop_capabilities":"ALL","no_new_privileges":true,"pids_limit":512} and
    .policy.forbidden == ["mutable-image-reference", "provider-fallback", "networked-execution", "warning-waiver", "host-tool-execution"]
  ' "$lock_file" >/dev/null || fail "lock.json violates the exact Phase 4 toolchain policy"
  jq -e . "$lock_schema" >/dev/null || fail "lock.schema.json is invalid JSON"
  jq -e . "$job_schema" >/dev/null || fail "job.schema.json is invalid JSON"
}

validate_job_json() {
  manifest=$1
  bundle=${2-}
  [ -f "$manifest" ] || fail "job manifest is not a regular file: $manifest"
  [ ! -L "$manifest" ] || fail "job manifest must not be a symbolic link"
  jq -e '
    def keys_are($allowed): ((keys - $allowed) | length) == 0;
    def identifier: test("^[A-Za-z_][A-Za-z0-9_$]*$");
    def safe_path:
      test("^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$") and
      (startswith("/") | not) and (split("/") | all(. != ".."));
    def sha: test("^[0-9a-f]{64}$");
    keys_are(["$schema", "schema_version", "top_module", "sources", "formal_tasks"]) and
    .schema_version == "lunachip.yosys-job/v1" and (.top_module | identifier and length <= 256) and
    (.sources | type == "array" and length >= 1 and length <= 256) and
    ([.sources[].path] | length == (unique | length)) and
    (all(.sources[];
      keys_are(["path", "sha256"]) and (.path | safe_path and length <= 512) and (.path | endswith(".sv")) and (.sha256 | sha))) and
    (.formal_tasks | type == "array" and length <= 64) and
    ([.formal_tasks[].name] | length == (unique | length)) and
    (all(.formal_tasks[];
      keys_are(["name", "mode", "claim", "bound", "timeout_seconds", "engine", "solver", "expect"]) and
      (.name | test("^[a-z][a-z0-9-]*$") and length <= 128) and
      (.mode == "bmc" or .mode == "prove" or .mode == "cover") and
      ((.mode == "bmc" and .claim == "bounded-safety-up-to-bound") or
       (.mode == "prove" and .claim == "unbounded-safety-if-base-and-induction-pass") or
       (.mode == "cover" and .claim == "reachability-within-bound")) and
      (.bound | type == "number" and floor == . and . >= 1 and . <= 100000) and
      (.timeout_seconds | type == "number" and floor == . and . >= 1 and . <= 3600) and
      .engine == "smtbmc" and .solver == "bitwuzla" and
      (.expect == "pass" or .expect == "fail")))
  ' "$manifest" >/dev/null || fail "job manifest violates the exact Phase 4 schema: $manifest"

  [ -n "$bundle" ] || return 0
  [ -d "$bundle" ] || fail "bundle directory does not exist: $bundle"
  [ ! -L "$bundle" ] || fail "bundle directory must not be a symbolic link"
  if find "$bundle" -type l -print | grep -q .; then
    fail "bundle must not contain symbolic links"
  fi
  basenames=
  while IFS="$(printf '\t')" read -r relative expected; do
    source_file="$bundle/$relative"
    [ -f "$source_file" ] || fail "bundle source is missing: $relative"
    [ ! -L "$source_file" ] || fail "bundle source must not be a symbolic link: $relative"
    observed=$(sha256_file "$source_file")
    [ "$observed" = "$expected" ] || fail "source digest mismatch for $relative: expected $expected, observed $observed"
    base=${relative##*/}
    case " $basenames " in
      *" $base "*) fail "source basenames must be unique for deterministic SBY staging: $base" ;;
    esac
    basenames="$basenames $base"
  done <<EOF
$(jq -r '.sources[] | [.path, .sha256] | @tsv' "$manifest")
EOF
}

validate_lock
case ${1-} in
  "") ;;
  --job-json)
    [ "$#" -eq 2 ] || [ "$#" -eq 3 ] || fail "usage: $0 [--job-json MANIFEST [BUNDLE_DIR]]"
    validate_job_json "$2" "${3-}"
    ;;
  *) fail "usage: $0 [--job-json MANIFEST [BUNDLE_DIR]]" ;;
esac

echo "Yosys/SBY lock and schemas pass (lock sha256:$(sha256_file "$lock_file"))"
