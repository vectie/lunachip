#!/bin/sh
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
lock_file="$repo_dir/toolchain/verilator/lock.json"
lock_schema="$repo_dir/toolchain/verilator/lock.schema.json"
harness_schema="$repo_dir/toolchain/verilator/harness.schema.json"
harness_v2_schema="$repo_dir/toolchain/verilator/harness-v2.schema.json"

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
  jq -e . "$harness_v2_schema" >/dev/null || fail "harness-v2.schema.json is not valid JSON"
}

validate_harness_v1_json() {
  manifest=$1
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

validate_harness_v2_json() {
  manifest=$1
  jq -e '
    def identifier: test("^[A-Za-z_][A-Za-z0-9_$]*$");
    def safe_path:
      test("^[A-Za-z0-9._+-]+(/[A-Za-z0-9._+-]+)*$") and
      (startswith("/") | not) and
      (split("/") | all(. != ".."));
    ((keys - [
      "$schema", "schema_version", "top_module", "sources", "harness_cpp",
      "stimulus", "stimulus_schema", "result", "domains", "ports"
    ]) | length == 0) and
    .schema_version == "lunachip.verilator-harness/v2" and
    (.top_module | identifier) and
    (.sources | type == "array" and length > 0 and length == (unique | length)) and
    (all(.sources[]; safe_path and endswith(".sv"))) and
    (.harness_cpp | safe_path and endswith(".cpp")) and
    (.stimulus | safe_path and endswith(".tsv")) and
    .stimulus_schema == "lunachip.verilator-stimulus/v2" and
    (.result | safe_path and endswith(".tsv")) and
    (.domains | type == "array" and length > 0) and
    ([.domains[].id] as $ids |
      ($ids | length) == ($ids | unique | length) and
      $ids == ($ids | sort)) and
    ([.domains[].clock_port] | length == (unique | length)) and
    (all(.domains[];
      ((keys - ["id", "clock_port", "edge"]) | length == 0) and
      (.id | type == "number" and floor == . and . >= 0) and
      (.clock_port | identifier) and .edge == "rising")) and
    (.ports | type == "array" and length > 0) and
    ([.ports[].name] | length == (unique | length)) and
    (all(.ports[];
      ((keys - ["name", "direction", "width", "signed"]) | length == 0) and
      (.name | identifier) and
      (.direction == "input" or .direction == "output") and
      (.width | type == "number" and floor == . and . >= 1 and . <= 64) and
      (.signed | type == "boolean"))) and
    (. as $root |
      all($root.domains[].clock_port;
        . as $clock |
        any($root.ports[];
          .name == $clock and .direction == "input" and .width == 1)))
  ' "$manifest" >/dev/null || fail "invalid harness manifest: $manifest"
}

validate_harness_json() {
  manifest=$1
  [ -f "$manifest" ] || fail "harness manifest does not exist: $manifest"
  schema_version=$(jq -r '.schema_version // empty' "$manifest")
  case "$schema_version" in
    lunachip.verilator-harness/v1) validate_harness_v1_json "$manifest" ;;
    lunachip.verilator-harness/v2) validate_harness_v2_json "$manifest" ;;
    *) fail "unsupported harness schema: $schema_version" ;;
  esac
}

validate_atomic_stimulus() {
  manifest=$1
  stimulus=$2
  validate_harness_json "$manifest"
  [ -f "$stimulus" ] || fail "stimulus does not exist: $stimulus"
  [ "$(jq -r '.schema_version' "$manifest")" = "lunachip.verilator-harness/v2" ] ||
    fail "atomic stimulus validation requires a v2 harness manifest"
  expected_domains=$(jq -r \
    '[.domains[] | "\(.id):\(.clock_port)"] | join(",")' "$manifest")
  input_ports=$(jq -r '
    [.domains[].clock_port] as $clocks |
    [.ports[] |
      select(.direction == "input" and
        (.name as $name | $clocks | index($name) | not)) |
      "\(.name):\(.width)"] |
    join(",")
  ' "$manifest")
  awk -F '\t' \
    -v expected_domains="$expected_domains" \
    -v input_ports="$input_ports" '
    function reject(message) {
      print "phase3-verilator-validate: invalid atomic stimulus at line " NR ": " message > "/dev/stderr"
      exit 1
    }
    function canonical_uint(value) {
      return value ~ /^(0|[1-9][0-9]*)$/
    }
    function identifier(value) {
      return value ~ /^[A-Za-z_][A-Za-z0-9_$]*$/
    }
    function uint_le(left, right) {
      if (length(left) != length(right))
        return length(left) < length(right)
      return ("x" left) <= ("x" right)
    }
    function finish_event() {
      event_index += 1
      state = event_index == declared_events ? "end" : "event"
    }
    BEGIN {
      split(expected_domains, domain_lines, ",")
      for (item = 1; item <= length(domain_lines); item += 1) {
        split(domain_lines[item], cells, ":")
        expected_clock[cells[1]] = cells[2]
        expected_domain_id[item - 1] = cells[1]
        expected_domain_count += 1
      }
      split(input_ports, port_lines, ",")
      for (item in port_lines) {
        split(port_lines[item], cells, ":")
        input_width[cells[1]] = cells[2]
      }
      state = "header"
      domain_index = 0
      event_index = 0
      remaining_drives = 0
      remaining_domains = 0
      have_event = 0
    }
    state == "done" { reject("trailing content after END") }
    state == "header" {
      if (NF != 2 || $1 != "LUNACHIP-VERILATOR-STIMULUS" || $2 != "2")
        reject("expected schema-v2 header")
      state = "timebase"; next
    }
    state == "timebase" {
      if (NF != 2 || $1 != "TIMEBASE" || !canonical_uint($2) || $2 == "0")
        reject("expected nonzero canonical TIMEBASE")
      state = "domain_count"; next
    }
    state == "domain_count" {
      if (NF != 2 || $1 != "DOMAINS" || !canonical_uint($2))
        reject("expected canonical DOMAINS count")
      if ($2 != expected_domain_count)
        reject("domain count differs from manifest")
      declared_domains = $2
      state = declared_domains == 0 ? "event_count" : "domain"; next
    }
    state == "domain" {
      if (NF != 4 || $1 != "DOMAIN" || !canonical_uint($2) ||
          $2 != expected_domain_id[domain_index] ||
          !identifier($3) || $4 != "rising")
        reject("noncanonical domain declaration")
      if (!($2 in expected_clock) || expected_clock[$2] != $3)
        reject("domain differs from manifest")
      domain_index += 1
      if (domain_index == declared_domains) state = "event_count"
      next
    }
    state == "event_count" {
      if (NF != 2 || $1 != "EVENTS" || !canonical_uint($2))
        reject("expected canonical EVENTS count")
      declared_events = $2
      state = declared_events == 0 ? "end" : "event"; next
    }
    state == "event" {
      if (NF != 6 || $1 != "EVENT" || !canonical_uint($2) ||
          $2 != event_index || !canonical_uint($3) ||
          !canonical_uint($4) || !canonical_uint($5) ||
          !canonical_uint($6) || ($5 == "0" && $6 == "0"))
        reject("noncanonical EVENT record")
      if (have_event && uint_le($3, previous_time))
        reject("event time must increase; coincident work belongs in one batch")
      if (have_event && uint_le($4, previous_boundary))
        reject("event boundary must increase")
      previous_time = $3
      previous_boundary = $4
      have_event = 1
      remaining_drives = $5
      remaining_domains = $6
      previous_drive = ""
      previous_domain = ""
      state = remaining_drives > 0 ? "drive" : "edge"
      next
    }
    state == "drive" {
      if (NF != 5 || $1 != "DRIVE" || !identifier($2) ||
          !canonical_uint($3) || !($2 in input_width) ||
          $3 != input_width[$2] || length($4) != $3 ||
          length($5) != $3 || $4 !~ /^[01]+$/ || $5 !~ /^1+$/)
        reject("invalid fully-known input drive")
      if (previous_drive != "" && $2 <= previous_drive)
        reject("drives must be strictly name-sorted")
      previous_drive = $2
      remaining_drives -= 1
      if (remaining_drives == 0) {
        if (remaining_domains > 0) {
          state = "edge"
        } else {
          finish_event()
        }
      }
      next
    }
    state == "edge" {
      if (NF != 2 || $1 != "DOMAIN" || !canonical_uint($2) ||
          !($2 in expected_clock))
        reject("invalid event domain")
      if (previous_domain != "" && uint_le($2, previous_domain))
        reject("event domains must be strictly sorted and unique")
      previous_domain = $2
      remaining_domains -= 1
      if (remaining_domains == 0) finish_event()
      next
    }
    state == "end" {
      if (NF != 1 || $1 != "END") reject("expected END")
      state = "done"; next
    }
    { reject("unexpected record") }
    END {
      if (state != "done") {
        print "phase3-verilator-validate: invalid atomic stimulus: truncated document" > "/dev/stderr"
        exit 1
      }
    }
  ' "$stimulus" || fail "invalid atomic stimulus: $stimulus"
}

validate_lock

case ${1-} in
  "")
    ;;
  --harness-json)
    [ "$#" -eq 2 ] || fail "usage: $0 [--harness-json MANIFEST]"
    validate_harness_json "$2"
    ;;
  --stimulus-tsv)
    [ "$#" -eq 3 ] ||
      fail "usage: $0 --stimulus-tsv MANIFEST STIMULUS"
    validate_atomic_stimulus "$2" "$3"
    ;;
  *)
    fail "usage: $0 [--harness-json MANIFEST] [--stimulus-tsv MANIFEST STIMULUS]"
    ;;
esac

lock_digest=$(sha256_file "$lock_file")
echo "Verilator lock and contract schemas pass (lock sha256:$lock_digest)"
