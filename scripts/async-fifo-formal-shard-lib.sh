#!/bin/sh
# Deterministic internal decomposition for the one public
# valid-async-fifo-bmc task. This file is sourced by the locked runner and the
# typed-artifact verifier; it does not create additional public formal tasks.

. "$repo_dir/scripts/async-fifo-formal-footprint-lib.sh"

lc_async_fifo_shard_error() {
  printf '%s\n' "async-fifo-formal-shards: $*" >&2
  return 1
}

lc_async_fifo_shard_sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    lc_async_fifo_shard_error "shasum or sha256sum is required"
  fi
}

lc_async_fifo_shard_exact_line() {
  [ "$#" -eq 2 ] || return 1
  [ "$(grep -Fxc "$2" "$1")" -eq 1 ] ||
    lc_async_fifo_shard_error "expected one exact '$2' record"
}

lc_async_fifo_shard_require_unique_file() {
  [ "$#" -eq 2 ] || return 1
  lcafsruf_file=$1
  lcafsruf_count=$2
  if [ "$(wc -l <"$lcafsruf_file" | tr -d ' ')" -ne "$lcafsruf_count" ]; then
    lc_async_fifo_shard_error \
      "$lcafsruf_file does not contain $lcafsruf_count records"
    return 1
  fi
  lcafsruf_duplicates=$(sort "$lcafsruf_file" | uniq -d)
  if [ -n "$lcafsruf_duplicates" ]; then
    lc_async_fifo_shard_error "$lcafsruf_file contains duplicate labels"
    return 1
  fi
}

lc_async_fifo_shard_compare_sets() {
  [ "$#" -eq 3 ] || return 1
  sort "$1" >"$3.left.sorted"
  sort "$2" >"$3.right.sorted"
  cmp -s "$3.left.sorted" "$3.right.sorted" ||
    lc_async_fifo_shard_error "formal label sets differ"
}

lc_async_fifo_shard_write_sby() {
  [ "$#" -eq 10 ] || return 1
  lcafsws_bundle=$1
  lcafsws_manifest=$2
  lcafsws_properties=$3
  lcafsws_execution=$4
  lcafsws_top=$5
  lcafsws_sby=$6
  lcafsws_assertions=$7
  lcafsws_bound=$8
  lcafsws_timeout=$9
  lcafsws_transform=${10}
  {
    printf '%s\n' '[options]' 'mode bmc' 'multiclock on'
    printf 'depth %s\n' "$lcafsws_bound"
    printf 'timeout %s\n' "$lcafsws_timeout"
    printf '%s\n' 'expect pass' '[engines]' 'smtbmc bitwuzla' \
      '[script]' 'logger -werror .*'
    printf 'read_verilog -formal -sv -noautowire'
    for lcafsws_source in $(jq -r '.sources[].path' "$lcafsws_manifest"); do
      printf ' %s' "${lcafsws_source##*/}"
    done
    printf '\n'
    printf 'hierarchy -check -top %s\n' "$lcafsws_top"
    while IFS="$(printf '\t')" read -r lcafsws_label lcafsws_role; do
      case "$lcafsws_role" in
        assert)
          if ! grep -Fx "$lcafsws_label" "$lcafsws_assertions" >/dev/null; then
            printf 'chformal -assert -remove %s/%s\n' \
              "$lcafsws_top" "$lcafsws_label"
          fi
          ;;
        assume)
          if ! awk -v label="$lcafsws_label" \
            '$1 == "A" && $3 == label { found += 1 } END { exit(found == 1 ? 0 : 1) }' \
            "$lcafsws_execution"; then
            printf 'chformal -assume -remove %s/%s\n' \
              "$lcafsws_top" "$lcafsws_label"
          fi
          ;;
        cover)
          printf 'chformal -cover -remove %s/%s\n' \
            "$lcafsws_top" "$lcafsws_label"
          ;;
        *)
          lc_async_fifo_shard_error "unknown property role '$lcafsws_role'"
          return 1
          ;;
      esac
    done <<EOF
$(awk '$1 == "F" { print $4 "\t" $5 }' "$lcafsws_properties")
EOF
    if [ "$lcafsws_transform" = integrity-memory-map ]; then
      printf '%s\n' 'proc' 'flatten' 'memory -nomap' 'memory_map' \
        'opt -full' 'wreduce' 'opt_clean'
    elif [ "$lcafsws_transform" != default-prep ]; then
      lc_async_fifo_shard_error \
        "unknown shard preparation transform '$lcafsws_transform'"
      return 1
    fi
    printf 'prep -top %s\n' "$lcafsws_top"
    printf '%s\n' '[files]'
    for lcafsws_source in $(jq -r '.sources[].path' "$lcafsws_manifest"); do
      printf '%s /work/%s\n' "${lcafsws_source##*/}" "$lcafsws_source"
    done
  } >"$lcafsws_sby"
}

lc_async_fifo_shard_append() {
  [ "$#" -eq 7 ] || return 1
  lcafsa_plan=$1
  lcafsa_id=$2
  lcafsa_mode=$3
  lcafsa_bound=$4
  lcafsa_transform=$5
  lcafsa_assumptions=$6
  lcafsa_assertions=$7
  {
    printf 'SHARD %s\n' "$lcafsa_id"
    printf 'MODE %s\n' "$lcafsa_mode"
    printf 'BOUND %s\n' "$lcafsa_bound"
    case "$lcafsa_transform" in
      default-prep) printf '%s\n' 'PREP-TRANSFORM prep' ;;
      integrity-memory-map)
        printf '%s\n' \
          'PREP-TRANSFORM proc ; flatten ; memory -nomap ; memory_map ; opt -full ; wreduce ; opt_clean ; prep'
        ;;
      *) return 1 ;;
    esac
    printf 'ASSUMPTIONS %s\n' \
      "$(wc -l <"$lcafsa_assumptions" | tr -d ' ')"
    awk '{ print "A " NR - 1 " " $0 }' "$lcafsa_assumptions"
    printf 'PROPERTIES %s\n' \
      "$(wc -l <"$lcafsa_assertions" | tr -d ' ')"
    awk '{ print "P " NR - 1 " " $0 }' "$lcafsa_assertions"
    printf '%s\n' 'END-SHARD'
  } >>"$lcafsa_plan"
}

lc_async_fifo_prepare_internal_shards() {
  [ "$#" -eq 3 ] || {
    lc_async_fifo_shard_error "prepare requires BUNDLE TASK OUTPUT"
    return 1
  }
  lcafpis_bundle=$1
  lcafpis_task=$2
  lcafpis_output=$3
  if [ "$lcafpis_task" != valid-async-fifo-bmc ]; then
    lc_async_fifo_shard_error "unsupported aggregate task '$lcafpis_task'"
    return 1
  fi
  lcafpis_manifest="$lcafpis_bundle/job.json"
  lcafpis_execution="$lcafpis_bundle/$lcafpis_task.lcfg"
  lcafpis_properties="$lcafpis_bundle/properties.lcfp"
  lcafpis_helper="$repo_dir/scripts/async-fifo-formal-shard-lib.sh"
  lcafpis_footprint_helper="$repo_dir/scripts/async-fifo-formal-footprint-lib.sh"
  for lcafpis_input in \
    "$lcafpis_manifest" "$lcafpis_execution" "$lcafpis_properties"; do
    if [ ! -f "$lcafpis_input" ] || [ -L "$lcafpis_input" ]; then
      lc_async_fifo_shard_error "missing or symbolic input $lcafpis_input"
      return 1
    fi
  done
  lcafpis_top=$(jq -r '.top_module' "$lcafpis_manifest")
  lcafpis_bound=$(jq -r --arg task "$lcafpis_task" \
    '.formal_tasks[] | select(.name == $task) | .bound' "$lcafpis_manifest")
  lcafpis_timeout=$(jq -r --arg task "$lcafpis_task" \
    '.formal_tasks[] | select(.name == $task) | .timeout_seconds' \
    "$lcafpis_manifest")
  lcafpis_mode=$(jq -r --arg task "$lcafpis_task" \
    '.formal_tasks[] | select(.name == $task) | .mode' "$lcafpis_manifest")
  lcafpis_expect=$(jq -r --arg task "$lcafpis_task" \
    '.formal_tasks[] | select(.name == $task) | .expect' "$lcafpis_manifest")
  if [ "$lcafpis_bound" != 128 ] || [ "$lcafpis_mode" != bmc ] ||
    [ "$lcafpis_expect" != pass ]; then
    lc_async_fifo_shard_error "aggregate parent must be passing BMC bound 128"
    return 1
  fi
  for lcafpis_line in \
    'MODE bmc' 'BOUND 128' 'SELECTED-ASSUMPTIONS 7' \
    'SELECTED-PROPERTIES 22' 'EXPECTED-STATUS pass' \
    'EXPECTED-FAILURE none'; do
    lc_async_fifo_shard_exact_line "$lcafpis_execution" "$lcafpis_line" ||
      return 1
  done

  lcafpis_work="$lcafpis_output/$lcafpis_task-work"
  lcafpis_shards="$lcafpis_work/shards"
  mkdir -p "$lcafpis_shards"
  cp "$lcafpis_footprint_helper" "$lcafpis_work/footprint-verifier.sh"
  awk '$1 == "A" { print $3 }' "$lcafpis_execution" \
    >"$lcafpis_work/parent.assumptions"
  awk '$1 == "P" { print $3 }' "$lcafpis_execution" \
    >"$lcafpis_work/parent.assertions"
  awk '$1 == "F" && $2 >= 0 && $2 <= 6 && $5 == "assume" { print $4 }' \
    "$lcafpis_properties" >"$lcafpis_work/expected.assumptions"
  awk '$1 == "F" && $2 >= 7 && $2 <= 28 && $5 == "assert" { print $4 }' \
    "$lcafpis_properties" >"$lcafpis_work/expected.assertions"
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_work/parent.assumptions" 7 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_work/expected.assumptions" 7 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_work/parent.assertions" 22 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_work/expected.assertions" 22 || return 1
  lc_async_fifo_shard_compare_sets "$lcafpis_work/parent.assumptions" \
    "$lcafpis_work/expected.assumptions" "$lcafpis_work/assumption-set" ||
    return 1
  lc_async_fifo_shard_compare_sets "$lcafpis_work/parent.assertions" \
    "$lcafpis_work/expected.assertions" "$lcafpis_work/assertion-set" ||
    return 1

  lcafpis_ids='protocol-pointer-gray sync-status-address backpressure-order integrity completion completion-nonvacuity'
  for lcafpis_id in $lcafpis_ids; do
    cp "$lcafpis_work/parent.assumptions" \
      "$lcafpis_shards/$lcafpis_id.assumptions"
  done
  awk '$1 == "F" && $2 >= 7 && $2 <= 14 { print $4 }' \
    "$lcafpis_properties" >"$lcafpis_shards/protocol-pointer-gray.assertions"
  awk '$1 == "F" && $2 >= 15 && $2 <= 24 { print $4 }' \
    "$lcafpis_properties" >"$lcafpis_shards/sync-status-address.assertions"
  awk '$1 == "F" && $2 >= 25 && $2 <= 26 { print $4 }' \
    "$lcafpis_properties" >"$lcafpis_shards/backpressure-order.assertions"
  awk '$1 == "F" && $2 == 27 { print $4 }' "$lcafpis_properties" \
    >"$lcafpis_shards/integrity.assertions"
  awk '$1 == "F" && $2 == 28 { print $4 }' "$lcafpis_properties" \
    >"$lcafpis_shards/completion.assertions"
  cp "$lcafpis_shards/completion.assertions" \
    "$lcafpis_shards/completion-nonvacuity.assertions"
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_shards/protocol-pointer-gray.assertions" 8 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_shards/sync-status-address.assertions" 10 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_shards/backpressure-order.assertions" 2 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_shards/integrity.assertions" 1 || return 1
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_shards/completion.assertions" 1 || return 1
  cat "$lcafpis_shards/protocol-pointer-gray.assertions" \
    "$lcafpis_shards/sync-status-address.assertions" \
    "$lcafpis_shards/backpressure-order.assertions" \
    "$lcafpis_shards/integrity.assertions" \
    "$lcafpis_shards/completion.assertions" \
    >"$lcafpis_work/base-union.assertions"
  lc_async_fifo_shard_require_unique_file \
    "$lcafpis_work/base-union.assertions" 22 || return 1
  lc_async_fifo_shard_compare_sets "$lcafpis_work/base-union.assertions" \
    "$lcafpis_work/parent.assertions" "$lcafpis_work/base-union-set" ||
    return 1
  if ! cmp -s "$lcafpis_shards/completion.assertions" \
    "$lcafpis_shards/completion-nonvacuity.assertions"; then
    lc_async_fifo_shard_error "supplemental completion relation differs"
    return 1
  fi

  lcafpis_plan="$lcafpis_work/internal-shards.lcfs"
  {
    printf '%s\n' 'LUNACHIP-PHASE5-ASYNC-FIFO-INTERNAL-SHARDS 1'
    printf 'PARENT-TASK %s\n' "$lcafpis_task"
    printf 'PARENT-EXECUTION %s.lcfg sha256 %s\n' "$lcafpis_task" \
      "$(lc_async_fifo_shard_sha256_file "$lcafpis_execution")"
    printf 'PROPERTY-MANIFEST properties.lcfp sha256 %s\n' \
      "$(lc_async_fifo_shard_sha256_file "$lcafpis_properties")"
    printf 'SHARD-HELPER scripts/async-fifo-formal-shard-lib.sh sha256 %s\n' \
      "$(lc_async_fifo_shard_sha256_file "$lcafpis_helper")"
    printf 'FOOTPRINT-HELPER scripts/async-fifo-formal-footprint-lib.sh sha256 %s\n' \
      "$(lc_async_fifo_shard_sha256_file "$lcafpis_footprint_helper")"
    printf 'FOOTPRINT-ARTIFACT footprint-verifier.sh sha256 %s\n' \
      "$(lc_async_fifo_shard_sha256_file "$lcafpis_work/footprint-verifier.sh")"
    printf '%s\n' 'PARENT-MODE bmc' 'PARENT-BOUND 128' \
      'PARENT-ASSUMPTIONS 7'
    awk '{ print "A " NR - 1 " " $0 }' "$lcafpis_work/parent.assumptions"
    printf '%s\n' 'PARENT-PROPERTIES 22'
    awk '{ print "P " NR - 1 " " $0 }' "$lcafpis_work/parent.assertions"
    printf '%s\n' 'BASE-SHARDS 5'
  } >"$lcafpis_plan"
  lc_async_fifo_shard_append "$lcafpis_plan" protocol-pointer-gray \
    base-claim 128 default-prep "$lcafpis_work/parent.assumptions" \
    "$lcafpis_shards/protocol-pointer-gray.assertions" || return 1
  lc_async_fifo_shard_append "$lcafpis_plan" sync-status-address \
    base-claim 128 default-prep "$lcafpis_work/parent.assumptions" \
    "$lcafpis_shards/sync-status-address.assertions" || return 1
  lc_async_fifo_shard_append "$lcafpis_plan" backpressure-order \
    base-claim 128 default-prep "$lcafpis_work/parent.assumptions" \
    "$lcafpis_shards/backpressure-order.assertions" || return 1
  lc_async_fifo_shard_append "$lcafpis_plan" integrity base-claim 128 \
    integrity-memory-map "$lcafpis_work/parent.assumptions" \
    "$lcafpis_shards/integrity.assertions" || return 1
  lc_async_fifo_shard_append "$lcafpis_plan" completion base-claim 128 \
    default-prep "$lcafpis_work/parent.assumptions" \
    "$lcafpis_shards/completion.assertions" || return 1
  printf '%s\n' 'BASE-UNION properties 22 duplicates 0 missing 0 extra 0' \
    'SUPPLEMENTAL-SHARDS 1' >>"$lcafpis_plan"
  lc_async_fifo_shard_append "$lcafpis_plan" completion-nonvacuity \
    supplemental-nonvacuity 204 default-prep \
    "$lcafpis_work/parent.assumptions" \
    "$lcafpis_shards/completion-nonvacuity.assertions" || return 1
  printf '%s\n' \
    'SUPPLEMENTAL-RELATION completion-nonvacuity repeats completion property-exact bound 204 parent-claim false' \
    'END' >>"$lcafpis_plan"

  for lcafpis_id in protocol-pointer-gray sync-status-address \
    backpressure-order completion; do
    lc_async_fifo_shard_write_sby "$lcafpis_bundle" "$lcafpis_manifest" \
      "$lcafpis_properties" "$lcafpis_execution" "$lcafpis_top" \
      "$lcafpis_shards/$lcafpis_id.sby" \
      "$lcafpis_shards/$lcafpis_id.assertions" 128 "$lcafpis_timeout" \
      default-prep || return 1
  done
  lc_async_fifo_shard_write_sby "$lcafpis_bundle" "$lcafpis_manifest" \
    "$lcafpis_properties" "$lcafpis_execution" "$lcafpis_top" \
    "$lcafpis_shards/integrity.sby" \
    "$lcafpis_shards/integrity.assertions" 128 "$lcafpis_timeout" \
    integrity-memory-map || return 1
  lc_async_fifo_shard_write_sby "$lcafpis_bundle" "$lcafpis_manifest" \
    "$lcafpis_properties" "$lcafpis_execution" "$lcafpis_top" \
    "$lcafpis_shards/completion-nonvacuity.sby" \
    "$lcafpis_shards/completion-nonvacuity.assertions" 204 \
    "$lcafpis_timeout" default-prep || return 1

  lcafpis_command="$lcafpis_work/internal-shards-command.sh"
  {
    printf '%s\n' '#!/bin/sh' 'set -eu' \
      ". /out/$lcafpis_task-work/footprint-verifier.sh"
    for lcafpis_id in $lcafpis_ids; do
      printf 'sby -f -d /out/%s-work/shards/%s-work /out/%s-work/shards/%s.sby\n' \
        "$lcafpis_task" "$lcafpis_id" "$lcafpis_task" "$lcafpis_id"
    done
    for lcafpis_id in $lcafpis_ids; do
      printf '%s\n' \
        "[ -f /out/$lcafpis_task-work/shards/$lcafpis_id-work/status ] || { echo 'missing shard status: $lcafpis_id' >&2; exit 1; }"
      printf '%s\n' \
        "[ \"\$(wc -l < /out/$lcafpis_task-work/shards/$lcafpis_id-work/status | tr -d ' ')\" -eq 1 ] || { echo 'malformed shard status: $lcafpis_id' >&2; exit 1; }"
      printf '%s\n' \
        "grep -Eq '^PASS( [0-9]+){2}\$' /out/$lcafpis_task-work/shards/$lcafpis_id-work/status || { echo 'nonpassing shard: $lcafpis_id' >&2; exit 1; }"
      lcafpis_child_bound=128
      if [ "$lcafpis_id" = completion-nonvacuity ]; then
        lcafpis_child_bound=204
      fi
      printf '%s\n' \
        "lc_async_fifo_verify_child_footprint /out/$lcafpis_task-work/shards/$lcafpis_id.sby /out/$lcafpis_task-work/shards/$lcafpis_id-work $lcafpis_id $lcafpis_child_bound"
    done
    printf '%s\n' "printf '%s\\n' PASS > /out/$lcafpis_task-work/status"
  } >"$lcafpis_command"
}

lc_async_fifo_verify_internal_shards() {
  [ "$#" -eq 3 ] || {
    lc_async_fifo_shard_error "verify requires BUNDLE TASK OUTPUT"
    return 1
  }
  lcafvis_bundle=$1
  lcafvis_task=$2
  lcafvis_output=$3
  lcafvis_expected=$(mktemp -d \
    "${TMPDIR:-/tmp}/lunachip-async-fifo-shards.XXXXXX") || return 1
  if ! lc_async_fifo_prepare_internal_shards \
    "$lcafvis_bundle" "$lcafvis_task" "$lcafvis_expected"; then
    rm -rf "$lcafvis_expected"
    return 1
  fi
  lcafvis_work="$lcafvis_output/$lcafvis_task-work"
  lcafvis_expected_work="$lcafvis_expected/$lcafvis_task-work"
  for lcafvis_file in internal-shards.lcfs internal-shards-command.sh \
    footprint-verifier.sh parent.assumptions parent.assertions expected.assumptions \
    expected.assertions base-union.assertions assumption-set.left.sorted \
    assumption-set.right.sorted assertion-set.left.sorted \
    assertion-set.right.sorted base-union-set.left.sorted \
    base-union-set.right.sorted; do
    if ! cmp -s "$lcafvis_expected_work/$lcafvis_file" \
      "$lcafvis_work/$lcafvis_file"; then
      rm -rf "$lcafvis_expected"
      lc_async_fifo_shard_error "aggregate artifact differs: $lcafvis_file"
      return 1
    fi
  done
  for lcafvis_id in protocol-pointer-gray sync-status-address \
    backpressure-order integrity completion completion-nonvacuity; do
    for lcafvis_suffix in assumptions assertions sby; do
      if ! cmp -s \
        "$lcafvis_expected_work/shards/$lcafvis_id.$lcafvis_suffix" \
        "$lcafvis_work/shards/$lcafvis_id.$lcafvis_suffix"; then
        rm -rf "$lcafvis_expected"
        lc_async_fifo_shard_error \
          "shard artifact differs: $lcafvis_id.$lcafvis_suffix"
        return 1
      fi
    done
    lcafvis_status="$lcafvis_work/shards/$lcafvis_id-work/status"
    [ -f "$lcafvis_status" ] && [ ! -L "$lcafvis_status" ] &&
      [ "$(wc -l <"$lcafvis_status" | tr -d ' ')" -eq 1 ] &&
      grep -Eq '^PASS( [0-9]+){2}$' "$lcafvis_status" || {
      rm -rf "$lcafvis_expected"
      lc_async_fifo_shard_error "shard status is not pinned PASS: $lcafvis_id"
      return 1
    }
    lcafvis_bound=128
    if [ "$lcafvis_id" = completion-nonvacuity ]; then
      lcafvis_bound=204
    fi
    if ! lc_async_fifo_verify_child_footprint \
      "$lcafvis_work/shards/$lcafvis_id.sby" \
      "$lcafvis_work/shards/$lcafvis_id-work" "$lcafvis_id" \
      "$lcafvis_bound"; then
      rm -rf "$lcafvis_expected"
      return 1
    fi
  done
  [ -f "$lcafvis_work/status" ] && [ ! -L "$lcafvis_work/status" ] &&
    [ "$(tr -d '\r\n' <"$lcafvis_work/status")" = PASS ] || {
    rm -rf "$lcafvis_expected"
    lc_async_fifo_shard_error "synthetic parent status is not PASS"
    return 1
  }
  rm -rf "$lcafvis_expected"
}
