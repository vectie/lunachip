#!/bin/sh
set -eu

fail() {
  echo "phase4-yosys-inference-check: $*" >&2
  exit 1
}

[ "$#" -eq 6 ] || fail \
  "usage: $0 FIXTURE EXPECTATION EXPECTED_SHAPES PRE_MAP_RTLIL YOSYS_LOG REPORT_JSON"

fixture=$1
expectation=$2
expected_spec=$3
rtlil=$4
log=$5
report=$6

case "$fixture" in
  *[!a-z0-9-]*|'') fail "fixture must be a non-empty lowercase slug" ;;
esac
case "$expectation" in
  require-memory-cell|observe-only-multiwrite) ;;
  *) fail "unsupported expectation '$expectation'" ;;
esac
if [ "$expectation" = require-memory-cell ]; then
  case "$expected_spec" in
    ''|*[!0-9:,]*) fail "expected shapes must use SIZE:WIDTH:RD_PORTS:WR_PORTS[,..]" ;;
  esac
else
  [ "$expected_spec" = observe ] || fail "observe-only fixtures must use EXPECTED_SHAPES=observe"
fi
[ -s "$rtlil" ] || fail "pre-map RTLIL is missing or empty: $rtlil"
[ -s "$log" ] || fail "Yosys log is missing or empty: $log"
[ ! -e "$report" ] || fail "report path already exists: $report"
command -v jq >/dev/null 2>&1 || fail "jq is required"

shape_root=$(mktemp -d "${TMPDIR:-/tmp}/lunachip-inference-shapes.XXXXXX")
trap 'rm -rf "$shape_root"' EXIT HUP INT TERM
if ! awk '
  $1 == "cell" && $2 == "$mem_v2" {
    inside = 1; width = -1; size = -1; read_ports = -1; write_ports = -1; next
  }
  inside && $1 == "parameter" {
    key = substr($2, 2)
    if (key == "WIDTH") width = $3 + 0
    else if (key == "SIZE") size = $3 + 0
    else if (key == "RD_PORTS") read_ports = $3 + 0
    else if (key == "WR_PORTS") write_ports = $3 + 0
    next
  }
  inside && $1 == "end" {
    if (width < 0 || size < 0 || read_ports < 0 || write_ports < 0) exit 2
    print size ":" width ":" read_ports ":" write_ports
    inside = 0
  }
  END { if (inside) exit 3 }
' "$rtlil" >"$shape_root/observed.unsorted"; then
  fail "could not extract complete memory-cell shapes from pre-map RTLIL"
fi
sort "$shape_root/observed.unsorted" >"$shape_root/observed"
observed_shapes=$(paste -sd, "$shape_root/observed")
mem_v2_count=$(awk 'END { print NR + 0 }' "$shape_root/observed")
legacy_memory_count=$(awk '$1 == "memory" { count += 1 } END { print count + 0 }' "$rtlil")
stat_mem_v2_max=$(awk '
  $1 ~ /^[0-9]+$/ && $2 == "$mem_v2" && ($1 + 0) > maximum { maximum = $1 + 0 }
  END { print maximum + 0 }
' "$log")
observed_count=$((mem_v2_count + legacy_memory_count))
observed_shapes_json=$(jq -Rn --arg shapes "$observed_shapes" '
  $shapes | if length == 0 then [] else split(",") | map(
    split(":") | {
      size: (.[0] | tonumber), width: (.[1] | tonumber),
      read_ports: (.[2] | tonumber), write_ports: (.[3] | tonumber)
    }) end
')
expected_shapes_json='[]'
expected_count=0
expected_shapes=observe
if [ "$expectation" = require-memory-cell ]; then
  printf '%s\n' "$expected_spec" | tr ',' '\n' | sort >"$shape_root/expected"
  expected_shapes=$(paste -sd, "$shape_root/expected")
  expected_count=$(awk 'END { print NR + 0 }' "$shape_root/expected")
  expected_shapes_json=$(jq -Rn --arg shapes "$expected_shapes" '
    $shapes | split(",") | map(
      split(":") | {
        size: (.[0] | tonumber), width: (.[1] | tonumber),
        read_ports: (.[2] | tonumber), write_ports: (.[3] | tonumber)
      })
  ')
fi

pass=true
claim=false
if [ "$expectation" = require-memory-cell ]; then
  claim=true
  classification=memory-cell-retained
  if [ "$legacy_memory_count" -ne 0 ] || [ "$observed_shapes" != "$expected_shapes" ] ||
    [ "$stat_mem_v2_max" -ne "$expected_count" ]; then
    pass=false
    classification=required-memory-shape-mismatch
  fi
elif [ "$observed_count" -gt 0 ]; then
  classification=memory-cell-retained-observe-only
else
  classification=logic-lowered-observe-only
fi

jq -n \
  --arg fixture "$fixture" \
  --arg expectation "$expectation" \
  --arg classification "$classification" \
  --argjson expected_shapes "$expected_shapes_json" \
  --argjson mem_v2 "$mem_v2_count" \
  --argjson legacy "$legacy_memory_count" \
  --argjson observed "$observed_count" \
  --argjson stat_mem_v2_max "$stat_mem_v2_max" \
  --argjson memory_shapes "$observed_shapes_json" \
  --argjson claim "$claim" \
  --argjson pass "$pass" \
  '{
    schema_version: 1,
    fixture: $fixture,
    expectation: $expectation,
    expected_memory_shapes: $expected_shapes,
    observed: {
      pre_map_mem_v2_cells: $mem_v2,
      pre_map_legacy_memory_declarations: $legacy,
      pre_map_memory_total: $observed,
      yosys_stat_mem_v2_max: $stat_mem_v2_max,
      memory_shapes: $memory_shapes
    },
    classification: $classification,
    inferred_memory_claim: $claim,
    physical_ram_claim: false,
    pass: $pass
  }' >"$report"

schema=$(CDPATH= cd -- "$(dirname -- "$0")/../toolchain/yosys" && pwd)/inference-report.schema.json
jq -e --argjson document "$(jq -c . "$report")" \
  'def check($schema; $value):
     ($schema.type == "object") and ($value | type == "object") and
     (($schema.required // []) | all(. as $key | $value | has($key))) and
     (($value | keys) - ($schema.properties | keys) | length == 0);
   check(.; $document)' "$schema" >/dev/null || fail "report failed structural schema validation"

[ "$pass" = true ] || fail \
  "$fixture observed shapes '$observed_shapes' and stat count $stat_mem_v2_max; expected '$expected_shapes'"
